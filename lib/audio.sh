# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.
#
# Audio devices through PulseAudio's protocol (pipewire-pulse answers it), the
# same interface the bar's audio widget uses. Nothing here is stored: the
# server owns the defaults, the volumes and the mutes.

# Which sinks are worth offering. An HDMI output with no cable in it still
# exists in the graph, and a speaker tuning puts a virtual sink in front of the
# real speakers — picking the physical one would only bypass the tuning. The
# bar's audio widget asks omarchy-audio-sink-availability about both; so does
# this, or the two lists disagree about what you own.
audio_availability() {
  omarchy-audio-sink-availability 2>/dev/null \
    | jq -R -s -c 'split("\n")
      | map(select(length > 0) | split("\t") | { key: .[0], value: (.[1] != "0") })
      | from_entries'
}

# Monitor sources are loopbacks of an output, not microphones; showing them
# under Input would offer to record the speakers.
audio_devices() {
  local kind=$1
  capture pactl -f json list "$kind" | jq -c --arg kind "$kind" '
    # The same label the widget shows: the short nickname a device gives
    # itself, not the sentence-long description PulseAudio assembles.
    def short_name(device):
      (device.properties["node.nick"] //
       device.properties["device.profile.description"] //
       device.description // device.name)
      | gsub("^sof-soundwire\\s+"; "")
      | gsub("(?i)^built-?in audio\\s+"; "")
      | sub("\\s+Output$"; "")
      | sub("\\s+Input$"; "")
      | gsub("Microphones"; "Microphone");

    [ .[]
      | select($kind != "sources" or (.name | test("\\.monitor$") | not))
      # Quickshell publishes a node of its own; it is not a microphone.
      | select(.name != "quickshell")
      | { name: .name,
          description: short_name(.),
          icon: (.properties["device.icon-name"] // ""),
          muted: (.mute == true),
          volume: (( .volume | to_entries | map(.value.value_percent | rtrimstr("%") | tonumber) | add / length ) | round) } ]'
}

# Loudness for the current output does not necessarily live on the current
# output: a speaker tuning or EasyEffects sits in front as a DSP sink, and the
# volume and mute that matter are the physical sink's underneath. The media
# keys resolve through it; so must this, or the panel moves one sink while the
# keyboard moves another and neither agrees with the OSD.
audio_output_sink() {
  local sink
  sink=$(capture omarchy-audio-output-sink)
  [[ -n $sink ]] && printf '%s\n' "$sink" && return
  capture pactl get-default-sink
}

audio_state() {
  command -v pactl >/dev/null 2>&1 || { echo '{"available": false}'; return; }

  # A temporarily unavailable PipeWire/PulseAudio server must not make the
  # entire Settings state payload invalid.  The window can render an empty
  # audio list and will populate it on the next event instead.
  local outputs inputs availability
  outputs="$(audio_devices sinks)"
  inputs="$(audio_devices sources)"
  availability="$(audio_availability)"
  [[ $outputs == \[* ]] || outputs='[]'
  [[ $inputs == \[* ]] || inputs='[]'
  [[ $availability == \{* ]] || availability='{}'

  jq -cn --arg resolved "$(audio_output_sink)" \
    --argjson outputs "$outputs" \
    --argjson inputs "$inputs" \
    --argjson availability "$availability" \
    --arg defaultOutput "$(capture pactl get-default-sink)" \
    --arg defaultInput "$(capture pactl get-default-source)" \
    '# What the selected output really sounds like, taken from the sink the
     # keys move rather than from the DSP sink fronting it.
     ($outputs | map(select(.name == $resolved)) | first) as $real
     | { available: true,
       outputs: [$outputs[]
         | . + { default: (.name == $defaultOutput) }
         | if .default and $real != null and .name != $resolved
           then . + { muted: $real.muted, volume: $real.volume }
           else . end
         # Whatever is playing right now stays listed even if it reports
         # itself unavailable, so the current output is never missing.
         | select(.default or ($availability[.name] != false))],
       inputs: [$inputs[] | . + { default: (.name == $defaultInput) }] }'
}

# The server owns mute and volume, and the keyboard keys, the bar widget and
# any other panel all move them behind this window's back. Rather than re-read
# on a timer, follow PulseAudio's own event stream and print the whole audio
# state again whenever something about a sink, a source or the server itself
# changes — one compact line per change, so the window can just parse and show.
audio_watch() {
  command -v pactl >/dev/null 2>&1 || { echo '{"available": false}'; return; }

  audio_state
  pactl subscribe 2>/dev/null \
    | grep --line-buffered -E "on (sink|source|server)" \
    | while read -r _; do
        # A single key press emits several events; draining the burst first
        # means one state read per change rather than four.
        while read -r -t 0.1 _; do :; done
        audio_state
      done
}

# The preamp is deliberately separate from volume and calibration.  It only
# changes the two linear nodes placed before the measured correction; the
# limiter remains the final node in the generated chain.
audio_preamp_db() {
  local fragment="$HOME_DIR/.config/pipewire/omarchy-speaker-tuning.conf.d/90-tuning.conf"
  [[ -f $fragment ]] || die "no calibrated speaker chain is installed"
  python3 - "$fragment" "$1" <<'PY'
import math, pathlib, re, sys
path, raw = pathlib.Path(sys.argv[1]), sys.argv[2]
try: value = int(raw)
except ValueError: raise SystemExit("preamp must be an integer")
if value < 0 or value > 36 or value % 3: raise SystemExit("preamp must be 0..36 dB in 3 dB steps")
text = path.read_text()
factor = f"{10 ** (value / 20):.6f}"
text, left = re.subn(r'(name = preamp_l label = linear control = \{ "Mult" = )[^ ]+', r'\g<1>' + factor, text, count=1)
text, right = re.subn(r'(name = preamp_r label = linear control = \{ "Mult" = )[^ ]+', r'\g<1>' + factor, text, count=1)
if left != 1 or right != 1: raise SystemExit("calibrated chain has no compatible preamp")
tmp = path.with_suffix(path.suffix + ".settings.tmp")
tmp.write_text(text)
tmp.replace(path)
PY
  systemctl --user restart omarchy-speaker-tuning.service >/dev/null 2>&1 || die "could not restart calibrated audio"
}

audio_preamp_state() {
  local fragment="$HOME_DIR/.config/pipewire/omarchy-speaker-tuning.conf.d/90-tuning.conf" mult
  [[ -f $fragment ]] || { echo null; return; }
  mult=$(sed -n 's/.*name = preamp_l label = linear control = { "Mult" = \([0-9.]*\).*/\1/p' "$fragment" | head -1)
  python3 - "$mult" <<'PY'
import math, sys
try: print(round(20 * math.log10(float(sys.argv[1]))))
except Exception: print('null')
PY
}

# Switching the default alone leaves whatever is already playing on the old
# device, which reads as the setting not working. Move the streams too, the
# way every audio panel does.
audio_move_streams() {
  local kind=$1 target=$2 stream
  local list_kind=sink-inputs move=move-sink-input
  [[ $kind == input ]] && { list_kind=source-outputs; move=move-source-output; }

  while read -r stream _; do
    [[ -n $stream ]] || continue
    pactl "$move" "$stream" "$target" >/dev/null 2>&1 || true
  done < <(capture pactl list short "$list_kind")
}

audio_cmd() {
  local action=${1:-} kind=${2:-} value=${3:-}
  if [[ $action == preamp ]]; then audio_preamp_db "$kind"; return; fi
  command -v pactl >/dev/null 2>&1 || die "PulseAudio is not available"
  [[ $action == state || $action == watch ]] || [[ $kind == output || $kind == input ]] || die "expected output or input"

  local device=sink
  [[ $kind == input ]] && device=source

  # Output actions land on the resolved sink, the same one the media keys use;
  # input has no DSP equivalent, so it stays on the default source.
  local target="@DEFAULT_SOURCE@"
  [[ $kind == output ]] && target=$(audio_output_sink)

  case $action in
    state) audio_state ;;
    watch) audio_watch ;;
    default)
      [[ -n $value ]] || die "no device given"
      pactl "set-default-$device" "$value" >/dev/null 2>&1 || die "could not switch to that device"
      audio_move_streams "$kind" "$value" ;;
    volume)
      [[ $value =~ ^[0-9]+$ ]] || die "'$value' is not a percentage"
      ((value <= 150)) || die "that is louder than this will go"
      pactl "set-$device-volume" "$target" "${value}%" >/dev/null 2>&1 \
        || die "could not set the volume" ;;
    mute)
      case $value in
        on|off|toggle)
          local flag=$value
          [[ $value == on ]] && flag=1
          [[ $value == off ]] && flag=0
          pactl "set-$device-mute" "$target" "$flag" >/dev/null 2>&1 \
            || die "could not change the mute" ;;
        *) die "expected on, off or toggle" ;;
      esac ;;
    *) die "unknown audio action '$action'" ;;
  esac
}
