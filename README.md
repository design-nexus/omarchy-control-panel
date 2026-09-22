# Omarchy Control Panel

One organized home for everyday Omarchy and system settings, from Hyprland to
hardware, networking, calibration, and applications.

<p align="center"><img src="preview.png" alt="The OmaSettings window" width="800"></p>

- **Six clear categories.** Appearance, Desktop & Input, Devices,
  Connectivity, Power & System, and Applications keep the sidebar short while
  putting related controls together.
- **Find anything.** Type "blur" or "gaps" and every setting that touches it
  appears with its current value, whatever file it normally lives in.
- **Look and feel.** Theme, font, text size, gaps, borders, rounding, opacity,
  blur, shadows, animations and their speed, window group tabs, tiling layout.
- **The bar.** Position, transparency, which widgets sit where, and which
  plugins are enabled, plus add, remove and update them.
- **Workspaces.** Bind an application to a workspace or a display, open it
  there in the background, floating, pinned or fullscreen, start it when you
  log in, keep the screen awake or hide it from screen sharing. And set up the workspaces themselves: name,
  display, layout, kept when empty, borderless.
- **Keybindings.** Browse every binding you have, add your own, turn Omarchy's
  off, put them back. No Lua.
- **Compose keys.** Your `~/.XCompose` sequences as a list you can add to and
  remove from.
- **Input and displays.** Keyboard layout, repeat rate, mouse and touchpad
  behaviour, per-monitor scale, and one device can differ from the rest.
- **Applications.** Settings for tmux, Herdr and Neovim, written into their
  real configs.
- **The live stuff.** Audio, network, bluetooth and power, so those widgets can
  leave the bar, if you want more space for other widgets.
- **The computer too.** Display brightness, battery charge limits,
  notifications, system information, and entry points for updates, snapshots,
  disks, printers, security, and advanced networking.
- **Sound shaping.** Sound includes an independent preamp (-24 to +36 dB),
  nine EQ bands (32 Hz–8 kHz, ±12 dB), bypass, and a flat reset. A persistent
  PipeWire filter and peak limiter process the selected output. Controls are
  read back from the running graph; master volume remains separate. Choose
  "Use on this output" if another application changes the default output.
- **One calibration home.** Speaker correction, comparison, verification, and
  measurement now live together under Devices instead of being repeated on
  the Sound page.
- **Undo.** Anything you changed is marked and goes back, one setting or all of
  them at once.

## Why I built it

I wanted a fast overview of everything I could change, and an easier way to find
out which settings Hyprland actually has. Easier management of keybindings and
`~/.XCompose` was the other part.

Dropping a few widgets like audio from the bar frees space for ones I get more
out of. And hopefully someone else finds it useful too.

## Install

```sh
omarchy plugin add https://github.com/design-nexus/omarchy-control-panel.git --enable
```

## Usage

Click the gear in the bar to open the window, or find it in the launcher as
Settings.

## Credits and attribution

This project is a fork and integration of existing Omarchy plugins. The
settings foundation and much of the original settings UI are based on
[OmaSettings](https://github.com/twiking/omasettings) by **Tobias Wiking**.
The speaker measurement, calibration, correction, and verification engine and
its detailed calibration panel are based on the
[Speaker Calibrator](https://github.com/thefreshoffice/omarchy-speaker-calibrator)
plugin by **Michael de By**. Their MIT-licensed work remains credited here;
please refer to the upstream projects for their original history and notices.

## How it writes

Your config files are never parsed and rewritten, since that is how a settings
app eats someone's setup. Instead:

- **Hyprland settings** are applied live with `hyprctl eval` and written to a
  file of its own, `~/.config/hypr/omasettings.lua`, loaded last from a single
  `require` line appended to your `hyprland.lua`. Your own files keep saying
  exactly what you wrote.
- **Keybindings** live in a marked block in `bindings.lua`. Everything outside
  the markers is copied through untouched.
- **Everything else**, meaning Herdr, tmux and Neovim, is edited one value at a
  time, in place, keeping the comment attached to the line it belongs to.

Before the first write to any file you could have written yourself, a copy is
kept beside it as `<file>.omasettings.bak`. Every write is checked in the
format's own terms, with `herdr config check`, by compiling the Lua, or by
applying the tmux option, and rolled back if it fails.

## Requirements

| Tool                         | Needed for                                            |
| ---------------------------- | ----------------------------------------------------- |
| `jq`                         | Everything, it does every read and write              |
| `pactl`                      | Audio                                                 |
| `nmcli`                      | Network                                               |
| `bluetoothctl`               | Bluetooth                                             |
| `upower`, `powerprofilesctl` | Power                                                 |
| `timedatectl`                | Date & Time                                           |
| `tmux`, `nvim`, `herdr`      | Their own pages under Applications                    |
| `xkbcli`                     | Checking a keyboard layout compiles before writing it |

Only `jq` is required. A page whose tool is missing says so instead of failing.
Nothing here needs root, and nothing is installed on your behalf.

The preamp/EQ uses PipeWire, `/usr/bin/python3`, and `lsp-plugins-lv2` (also
used by speaker calibration). Its user service is `settings-audio-effects`.
Settings are stored in `~/.config/omarchy/settings-audio-effects.json` and
survive login. The obsolete volume-offset file `settings-preamp-db` is kept
but is no longer applied; the replacement starts at 0 dB to avoid reapplying
an unknown gain. Selecting a different output within Settings retargets the
EQ; switching outside Settings is respected and shown as inactive.

## Remove

```sh
omarchy plugin remove design-nexus.settings
```

The launcher entry it wrote is deleted with it.

## License

MIT, see [LICENSE](LICENSE).
