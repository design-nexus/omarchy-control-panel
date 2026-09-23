# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.
# Everyday system controls and hand-offs to the tools that own larger jobs.

system_info_state() {
  local os kernel host cpu memory storage uptime brightness dnd="" auto_brightness='{}'
  os=$(awk -F= '$1 == "PRETTY_NAME" { gsub(/^"|"$/, "", $2); print $2 }' /etc/os-release 2>/dev/null)
  kernel=$(uname -r 2>/dev/null || true)
  host=$(cat /sys/class/dmi/id/product_name 2>/dev/null || hostname 2>/dev/null || true)
  cpu=$(awk -F': +' '/model name/ { print $2; exit }' /proc/cpuinfo 2>/dev/null)
  memory=$(awk '/MemTotal:/ { printf "%.1f GB", $2 / 1024 / 1024 }' /proc/meminfo 2>/dev/null)
  storage=$(df -h --output=size,avail / 2>/dev/null | awk 'NR == 2 { print $1 " total · " $2 " available" }')
  uptime=$(uptime -p 2>/dev/null | sed 's/^up //' || true)
  brightness=$(capture omarchy brightness display | awk 'NR == 1 && /^[0-9]+$/ { print; exit }')
  command -v omarchy-shell >/dev/null 2>&1 && dnd=$(capture omarchy-shell notifications isDnd)
  auto_brightness=$(capture python3 "$OMASETTINGS_BIN_DIR/auto-brightness.py" state)

  jq -cn --arg os "$os" --arg kernel "$kernel" --arg host "$host" \
    --arg cpu "$cpu" --arg memory "$memory" --arg storage "$storage" \
    --arg uptime "$uptime" --arg brightness "$brightness" --arg dnd "$dnd" \
    --argjson autoBrightness "${auto_brightness:-\{\}}" \
    '{ os: $os, kernel: $kernel, host: $host, cpu: $cpu,
       memory: $memory, storage: $storage, uptime: $uptime,
       brightness: (($brightness | tonumber?) // null),
       autoBrightness: $autoBrightness,
       notifications: { available: ($dnd == "on" or $dnd == "off"),
                        doNotDisturb: ($dnd == "on") } }'
}

system_launch() {
  local target=$1 terminal="" gui="" menu=""
  case $target in
    updates) menu=update ;;
    snapshots) terminal='limine-snapper-list' ;;
    security) menu=setup.security ;;
    networking) terminal='nmtui' ;;
    disks) gui=gnome-disks ;;
    printers) gui=system-config-printer ;;
    *) die "unknown system tool '$target'" ;;
  esac
  if [[ -n $menu ]]; then
    setsid omarchy menu summon "$menu" >/dev/null 2>&1 &
  elif [[ -n $gui ]]; then
    command -v "$gui" >/dev/null 2>&1 || die "$gui is not installed"
    setsid uwsm-app -- "$gui" >/dev/null 2>&1 &
  else
    setsid omarchy-launch-floating-terminal-with-presentation "$terminal" >/dev/null 2>&1 &
  fi
  disown 2>/dev/null || true
}

system_cmd() {
  local action=${1:-} value=${2:-} extra=${3:-}
  case $action in
    state) system_info_state ;;
    brightness)
      [[ $value =~ ^[0-9]+$ ]] && (( value >= 1 && value <= 100 )) || die "brightness must be between 1 and 100"
      omarchy brightness display --no-osd "${value}%" >/dev/null || die "could not set display brightness" ;;
    auto-brightness)
      case $value in
        state) python3 "$OMASETTINGS_BIN_DIR/auto-brightness.py" state ;;
        enabled) [[ $extra == on || $extra == off ]] || die "enabled expects on or off"
          python3 "$OMASETTINGS_BIN_DIR/auto-brightness.py" enabled "$extra" ;;
        bias) python3 "$OMASETTINGS_BIN_DIR/auto-brightness.py" bias "$extra" ;;
        sample) python3 "$OMASETTINGS_BIN_DIR/auto-brightness.py" sample ;;
        *) die "usage: auto-brightness state | enabled on|off | bias <-30..30> | sample" ;;
      esac ;;
    notifications)
      [[ $value == on || $value == off ]] || die "notifications expects on or off"
      local dnd=false; [[ $value == off ]] && dnd=true
      omarchy-shell notifications setDnd "$dnd" >/dev/null || die "the notification service is not available" ;;
    notification-history)
      omarchy-shell notifications showHistory >/dev/null || die "the notification service is not available" ;;
    launch) system_launch "$value" ;;
    *) die "unknown system action '$action'" ;;
  esac
}
