# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.

# ---------------------------------------------------------------- workspaces
#
# Which workspace an application opens on, and how its window arrives there:
# the `o.window("slack", { workspace = "3" })` lines people end up writing at
# the foot of hyprland.lua by hand. Ours land in the managed Lua like every
# other Hyprland setting, keyed by window class, so a rule survives the window
# it was made for and applies again the next time the application starts.
#
# A rule is an override in the Hyprland sense — remove it and the application
# goes back to opening wherever it was closed — so these rows carry Remove
# rather than a reset, the way bindings and compose sequences do.
#
# Rules the user wrote themselves are read, never rewritten: they show on the
# page as "set in your own config", and a value picked here for the same
# class goes into our file, which loads last and therefore wins per property.

# The class an application's windows carry, as best it can be known without
# running it. A desktop entry says so in StartupWMClass when it bothers to;
# otherwise the file's own name is the convention most toolkits follow.
#
# The casing is the trap: Slack's entry says "Slack" and its windows say
# "slack", and a Hyprland regex is case-sensitive. A running window is the
# truth, so where one is open under the same name in any case, its class is
# the one kept.
workspace_apps() {
  local dirs=() dir live
  IFS=: read -ra dirs <<<"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
  dirs=("${XDG_DATA_HOME:-$HOME/.local/share}" "${dirs[@]}")

  live=$(capture hyprctl -j clients | jq -c '[.[] | .class] | map(select(. != "")) | unique' 2>/dev/null || echo '[]')

  {
    for dir in "${dirs[@]}"; do
      [[ -d $dir/applications ]] || continue
      # Only the [Desktop Entry] group: actions below it carry their own Name.
      awk '
        FNR == 1 { name = ""; class = ""; hidden = 0; type = ""; ingroup = 0 }
        /^\[/ { ingroup = ($0 == "[Desktop Entry]"); next }
        !ingroup { next }
        /^Name=/ && name == "" { name = substr($0, 6) }
        /^StartupWMClass=/ { class = substr($0, 16) }
        /^NoDisplay=true/ || /^Hidden=true/ { hidden = 1 }
        /^Type=/ { type = substr($0, 6) }
        ENDFILE {
          if (!hidden && type == "Application" && name != "") {
            file = FILENAME
            sub(/.*\//, "", file); sub(/\.desktop$/, "", file)
            if (class == "") class = file
            print name "\t" class "\t" file
          }
        }' "$dir"/applications/*.desktop 2>/dev/null
    done
  } | jq -R -s -c --argjson live "$live" '
    # An entry name wins the first time it appears: XDG_DATA_HOME comes first,
    # so a local override shadows the packaged file the way the launcher does.
    [ split("\n")[] | select(. != "") | split("\t")
      | { name: .[0], class: .[1], file: .[2] } ]
    | unique_by(.file)
    | (. as $entries
       | map(.class as $c
             | ($live | map(select(ascii_downcase == ($c | ascii_downcase))) | first) as $seen
             | { name: .name, class: ($seen // $c), running: ($seen != null) })
       # A window with no desktop entry — a script, a flatpak with an odd id —
       # is still something you might want on a workspace.
       + [ $live[] as $c
           | select(($entries | map(.class | ascii_downcase) | index($c | ascii_downcase)) == null)
           | { name: $c, class: $c, running: true } ])
    | unique_by(.class)
    | sort_by(.name | ascii_downcase)'
}

# Their own o.window("<class>", { ... }) lines, one call per line, read from
# every Lua under the Hyprland directory except ours. A match given as a table
# ({ class = ..., title = ... }) is a rule about more than a class and is left
# to say nothing rather than be half understood.
workspace_config_rules() {
  local file line class body out='{}'
  while IFS= read -r line; do
    class=$(sed -nE 's/^[[:space:]]*o\.window\("([^"]+)",[[:space:]]*\{(.*)\}\).*/\1/p' <<<"$line")
    [[ -n $class ]] || continue
    body=$(sed -nE 's/^[[:space:]]*o\.window\("[^"]+",[[:space:]]*\{(.*)\}\).*/\1/p' <<<"$line")
    out=$(jq -c --arg c "$class" --arg body "$body" '
      # capture yields nothing rather than null when the key is absent, and a
      # nothing bound with `as` empties the whole filter — hence the array.
      def field($k): ([$body | capture("(^|,)\\s*" + $k + "\\s*=\\s*(?<v>\"[^\"]*\"|[a-z0-9.]+)")] | first
                      | if . == null then null else .v | ltrimstr("\"") | rtrimstr("\"") end);
      def bool($k): field($k) | if . == "true" then true elif . == "false" then false else null end;
      field("workspace") as $ws
      | .[$c] = ((.[$c] // {})
          + (if $ws == null then {} else
               { workspace: ($ws | split(" ")[0]), silent: ($ws | endswith(" silent")) } end)
          + (if bool("float") == null then {} else { float: bool("float") } end)
          + (if bool("fullscreen") == null then {} else { fullscreen: bool("fullscreen") } end))
      | with_entries(select(.value != {}))' <<<"$out")
  done < <(for file in "$HYPR_DIR"/*.lua; do
             [[ -f $file ]] || continue
             [[ $file == "$MANAGED_LUA" ]] && continue
             grep -E '^[[:space:]]*o\.window\("' "$file" 2>/dev/null
           done)
  printf '%s\n' "$out"
}

workspace_rules_ours() {
  jq -c '.windowRules // {}' <<<"$(read_store)"
}

# The page's model: every application that can be picked, and every rule in
# force — ours, theirs, or both for the same class, with ours on top since
# that is the order Hyprland applies them in.
workspaces_state() {
  local apps ours theirs
  apps=$(workspace_apps)
  ours=$(workspace_rules_ours)
  theirs=$(workspace_config_rules)
  jq -cn --argjson apps "$apps" --argjson ours "$ours" --argjson theirs "$theirs" '
    def name_of($c): ($apps | map(select(.class == $c)) | first | .name) // $c;
    (($ours | keys) + ($theirs | keys) | unique) as $classes
    | { apps: $apps,
        rules: [ $classes[] as $c
                 | ($ours[$c] // {}) as $o | ($theirs[$c] // {}) as $t
                 | { class: $c,
                     name: name_of($c),
                     workspace: ($o.workspace // $t.workspace // ""),
                     silent: ($o.silent // $t.silent // false),
                     float: ($o.float // $t.float // false),
                     fullscreen: ($o.fullscreen // $t.fullscreen // false),
                     ours: ($ours | has($c)),
                     theirs: ($t != {}) } ] }'
}

# One field of one class. A class is a regex to Hyprland, so the two
# characters that would break the Lua string are refused rather than escaped.
workspace_set() {
  local class=$1 field=$2 value=$3 json
  [[ -n $class ]] || die "no application given"
  [[ $class =~ ^[^\"\\]+$ ]] || die "'$class' is not a window class"
  case $field in
    workspace)
      [[ -z $value || $value =~ ^[0-9]+$ || $value == special ]] || die "'$value' is not a workspace"
      json=$(jq -Rn --arg v "$value" '$v') ;;
    silent|float|fullscreen)
      [[ $value == true || $value == false ]] || die "'$value' is not true or false"
      json=$value ;;
    *) die "unknown window setting '$field'" ;;
  esac

  # An empty workspace or a switch turned off is the absence of the rule, not
  # a rule saying so: `float = false` would pin a window tiled against the
  # user's own config, which is more than "off" promises.
  edit_store '.windowRules = ((.windowRules // {})
    | .[$c] = ((.[$c] // {}) | if $v == "" or $v == false then del(.[$f]) else .[$f] = $v end))' \
    --arg c "$class" --arg f "$field" --argjson v "$json"
  hyprctl reload >/dev/null 2>&1 || true

  # A rule applies to windows that open from now on. The ones already open are
  # what the user is looking at, so they are moved as well — silently, since
  # the point of binding an application to a workspace is not having to go
  # and find it.
  if [[ $field == workspace && -n $value ]]; then
    hyprctl dispatch movetoworkspacesilent "$value,class:^($class)\$" >/dev/null 2>&1 || true
  fi
  return 0
}

# Drops our rule. One the user wrote stays: their file is theirs, and the page
# says so beside it.
workspace_remove() {
  local class=$1
  [[ -n $class ]] || die "no application given"
  edit_store '.windowRules = ((.windowRules // {}) | del(.[$c]))' --arg c "$class"
  hyprctl reload >/dev/null 2>&1 || true
}

# Add an application to the page with nothing set yet, so it has a group to
# be configured in. An empty rule renders nothing until a field arrives.
workspace_add() {
  local class=$1
  [[ -n $class ]] || die "no application given"
  [[ $class =~ ^[^\"\\]+$ ]] || die "'$class' is not a window class"
  edit_store '.windowRules = ((.windowRules // {}) | .[$c] = (.[$c] // {}))' --arg c "$class"
}

# Lua for the managed file: one o.window call per class, in the shape the
# hand-written ones take so the two read alike side by side.
render_window_rules_lua() {
  local rules
  rules=$(workspace_rules_ours)
  [[ $rules == "{}" ]] && return 0
  echo ""
  echo "-- Applications bound to a workspace, from the Workspaces page."
  jq -r 'to_entries[] | select(.value != {})
    | .value as $r
    | [ (if ($r.workspace // "") != "" then
           "workspace = \"" + $r.workspace + (if $r.silent == true then " silent" else "" end) + "\""
         else empty end),
        (if $r.float == true then "float = true" else empty end),
        (if $r.fullscreen == true then "fullscreen = true" else empty end) ] as $fields
    | select(($fields | length) > 0)
    | "o.window(\"" + .key + "\", { " + ($fields | join(", ")) + " })"' <<<"$rules"
}

workspaces_cmd() {
  case ${1:-} in
    state) workspaces_state ;;
    add) workspace_add "${2:-}" ;;
    set) workspace_set "${2:-}" "${3:-}" "${4:-}" ;;
    remove) workspace_remove "${2:-}" ;;
    *) die "usage: omasettings workspaces state | add <class> | set <class> workspace|silent|float|fullscreen <value> | remove <class>" ;;
  esac
}
