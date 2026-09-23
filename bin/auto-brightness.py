#!/usr/bin/env python3
"""Private automatic-brightness controller for OmaSettings.

It deliberately uses command line V4L2 tools instead of retaining a camera
handle.  Frames travel through a pipe, are reduced to a scalar, and are never
written to disk.
"""
import argparse, json, math, os, pathlib, re, signal, statistics, subprocess, sys, tempfile, time

HOME = pathlib.Path.home()
CONFIG = pathlib.Path(os.environ.get("OMASETTINGS_AUTO_BRIGHTNESS_CONFIG", HOME / ".config/omarchy/settings-auto-brightness.json"))
RUNTIME = pathlib.Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "omasettings-auto-brightness.json"
INTERVAL = 30
LUX_POINTS = [(0,5),(1,10),(10,20),(100,45),(500,65),(2000,85),(10000,100)]
CAMERA_POINTS = [(0,5),(8,10),(24,20),(64,45),(128,65),(192,85),(255,100)]

def run(args, timeout=5, data=None):
    try:
        return subprocess.run(args, input=data, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                              timeout=timeout, check=False).stdout.decode(errors="replace")
    except (OSError, subprocess.TimeoutExpired):
        return ""

def config():
    try: raw = json.loads(CONFIG.read_text())
    except (OSError, ValueError): raw = {}
    return {"enabled": bool(raw.get("enabled", False)), "bias": max(-30, min(30, int(raw.get("bias", 0))))}

def write_config(value):
    CONFIG.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".settings-auto-brightness.", dir=CONFIG.parent)
    try:
        with os.fdopen(fd, "w") as out:
            json.dump(value, out, separators=(",", ":")); out.write("\n"); out.flush(); os.fsync(out.fileno())
        os.replace(temporary, CONFIG)
    finally:
        try: os.unlink(temporary)
        except FileNotFoundError: pass

def read_runtime():
    try: return json.loads(RUNTIME.read_text())
    except (OSError, ValueError): return {}

def runtime(value):
    RUNTIME.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".omasettings-auto.", dir=RUNTIME.parent)
    try:
        with os.fdopen(fd, "w") as out: json.dump(value, out, separators=(",", ":")); out.write("\n")
        os.replace(temporary, RUNTIME)
    finally:
        try: os.unlink(temporary)
        except FileNotFoundError: pass

def interpolate(points, value, logarithmic=False):
    value = max(points[0][0], min(points[-1][0], float(value)))
    for (x0,y0),(x1,y1) in zip(points, points[1:]):
        if value <= x1:
            if logarithmic and x0 > 0 and value > 0:
                ratio = (math.log10(value)-math.log10(x0))/(math.log10(x1)-math.log10(x0))
            elif logarithmic and x0 == 0: ratio = value / x1
            else: ratio = (value-x0)/(x1-x0)
            return y0+(y1-y0)*ratio
    return points[-1][1]

def target_for(source, level, bias):
    return max(5, min(100, round(interpolate(LUX_POINTS if source == "sensor" else CAMERA_POINTS, level, source == "sensor") + bias)))

def smooth(values, proposed, previous=None):
    median = statistics.median((values + [proposed])[-3:])
    if previous is None: return round(median)
    if abs(median - previous) < 3: return previous
    return round(previous + max(-15, min(15, median - previous)))

def panel_awake():
    panel = run(["omarchy-hyprland-monitor-laptop"], 2).strip()
    if not panel: return False
    try:
        monitors = json.loads(run(["hyprctl", "monitors", "-j"], 3))
        return any(m.get("name") == panel and m.get("disabled") is not True for m in monitors)
    except (ValueError, subprocess.TimeoutExpired): return True

def sensor():
    for path in pathlib.Path("/sys/bus/iio/devices").glob("iio:device*"):
        for name in ("in_illuminance_input", "in_illuminance_raw"):
            try: return path, name, float((path/name).read_text().strip())
            except (OSError, ValueError): pass
    return None

def camera_device():
    # Metadata nodes and IR cameras routinely have video numbers too; prefer a
    # capture node explicitly advertised by V4L2 and avoid virtual loopbacks.
    for dev in sorted(pathlib.Path("/dev").glob("video*")):
        description = run(["v4l2-ctl", "-d", str(dev), "--all"], 3).lower()
        if "video capture" in description and "loopback" not in description:
            return str(dev)
    return None

def controls(dev):
    raw = run(["v4l2-ctl", "-d", dev, "--get-ctrl=exposure_auto,exposure_time_absolute"], 3)
    return dict(re.findall(r"([a-z_]+):\s*(\d+)", raw))

def camera_level(dev):
    saved = controls(dev)
    try:
        # Fixed exposure makes the level comparable from one short sample to the next.
        run(["v4l2-ctl", "-d", dev, "--set-ctrl=exposure_auto=1"], 3)
        raw = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-f", "video4linux2", "-video_size", "160x120", "-i", dev, "-t", "1", "-f", "rawvideo", "-pix_fmt", "gray", "pipe:1"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=2, check=False).stdout
        if len(raw) < 100: return None
        return sorted(raw)[int((len(raw)-1)*.75)]
    except (OSError, subprocess.TimeoutExpired): return None
    finally:
        if saved:
            run(["v4l2-ctl", "-d", dev, "--set-ctrl=" + ",".join(k+"="+v for k,v in saved.items())], 3)

def brightness():
    candidates = list(pathlib.Path("/sys/class/backlight").glob("*"))
    # A hybrid GPU can expose its own auxiliary backlight (for example
    # nvidia_0). The panel's native connector is the only one that matters;
    # its backlight device resolves through a card*-eDP-* DRM connector.
    candidates.sort(key=lambda item: 0 if "-eDP-" in os.path.realpath(item / "device") else 1)
    for backlight in candidates:
        try:
            current = int((backlight / "brightness").read_text()); maximum = int((backlight / "max_brightness").read_text())
            return round(current * 100 / maximum), backlight.name
        except (OSError, ValueError, ZeroDivisionError): pass
    return None

def apply(device, value):
    # brightnessctl targets the kernel backlight, never an external DDC output.
    try:
        return subprocess.run(["brightnessctl", "-d", device, "set", str(value) + "%"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    except OSError:
        return False

def sample(immediate=False):
    cfg, old = config(), read_runtime()
    base = {"available": False, "enabled": cfg["enabled"], "bias": cfg["bias"], "source": "none", "lightLevel": None,
            "targetBrightness": None, "lastSampleAt": old.get("lastSampleAt"), "intervalSeconds": INTERVAL}
    if not cfg["enabled"]: base["status"] = "disabled"; runtime(base); return base
    # Availability is reported even while the panel is asleep, so the UI can
    # distinguish a deliberate pause from missing hardware.
    base["available"] = sensor() is not None or camera_device() is not None
    if not panel_awake(): base.update(status="paused: internal display is asleep"); runtime(base); return base
    found = sensor()
    if found:
        _, _, level = found; source = "sensor"; base["available"] = True
    else:
        dev = camera_device()
        if not dev: base.update(status="unavailable: no ambient sensor or camera"); runtime(base); return base
        level = camera_level(dev); source = "camera"; base["available"] = True
        if level is None: base.update(source=source, status="paused: camera is in use or unavailable"); runtime(base); return base
    wanted = target_for(source, level, cfg["bias"])
    history = old.get("history", []) if old.get("source") == source else []
    current_info = brightness()
    current = current_info[0] if current_info else None
    # A preference is an explicit user request, not sensor noise. Apply its
    # recalculated target straight away; regular periodic samples retain the
    # median, hysteresis, and 15-point movement limit.
    final = wanted if immediate else smooth(history, wanted, current)
    base.update(source=source, lightLevel=round(level, 1), targetBrightness=final, lastSampleAt=int(time.time()), history=(history+[wanted])[-3:], status="active")
    if current_info is None: base["status"] = "unavailable: internal backlight not found"
    elif final != current:
        if not apply(current_info[1], final): base["status"] = "error: could not set internal brightness"
    runtime(base); return base

def state():
    cfg, value = config(), read_runtime()
    result = {"available": bool(value.get("available", sensor() is not None or camera_device() is not None)), "enabled": cfg["enabled"],
              "source": value.get("source", "none"), "bias": cfg["bias"], "lightLevel": value.get("lightLevel"),
              "targetBrightness": value.get("targetBrightness"), "status": value.get("status", "disabled" if not cfg["enabled"] else "waiting"),
              "lastSampleAt": value.get("lastSampleAt"), "intervalSeconds": INTERVAL}
    print(json.dumps(result, separators=(",", ":")))

def main():
    def interrupted(_signum, _frame): raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, interrupted)
    p = argparse.ArgumentParser(); p.add_argument("command", choices=["run","sample","state","enabled","bias"]); p.add_argument("value", nargs="?"); a=p.parse_args()
    if a.command == "state": state(); return
    if a.command == "enabled":
        if a.value not in ("on", "off"): raise SystemExit("enabled expects on or off")
        c=config(); c["enabled"] = a.value == "on"; write_config(c); sample(); return
    if a.command == "bias":
        try: value=int(a.value)
        except (TypeError, ValueError): raise SystemExit("bias must be between -30 and 30")
        if not -30 <= value <= 30: raise SystemExit("bias must be between -30 and 30")
        c=config(); c["bias"] = value; write_config(c); sample(immediate=True); return
    if a.command == "sample": sample(); return
    while True:
        sample(); time.sleep(INTERVAL)
if __name__ == "__main__": main()
