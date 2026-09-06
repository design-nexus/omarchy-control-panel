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
                     shown: (if ($o.fullscreen // $t.fullscreen) == true then "fullscreen"
                             elif ($o.float // $t.float) == true then "floating" else "tiled" end),
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
    # How the window shows: one of three, since a fullscreen window is neither
    # tiled nor floating in any way you can see. Stored as the two Hyprland
    # fields, never both at once.
    shown)
      case $value in
        tiled) workspace_set "$class" float false; workspace_set "$class" fullscreen false; return 0 ;;
        floating) workspace_set "$class" fullscreen false; workspace_set "$class" float true; return 0 ;;
        fullscreen) workspace_set "$class" float false; workspace_set "$class" fullscreen true; return 0 ;;
        *) die "'$value' is not tiled, floating or fullscreen" ;;
      esac ;;
    *) die "unknown window setting '$field'" ;;
  esac

  # An empty workspace or a switch turned off is the absence of the rule, not
  # a rule saying so: `float = false` would pin a window tiled against the
  # user's own config, which is more than "off" promises.
  # Turning one of float and fullscreen on turns the other off, so a rule can
  # never ask for both.
  edit_store '.windowRules = ((.windowRules // {})
    | .[$c] = ((.[$c] // {})
        | if $v == "" or $v == false then del(.[$f]) else .[$f] = $v end
        | if $v == true and $f == "float" then del(.fullscreen)
          elif $v == true and $f == "fullscreen" then del(.float) else . end))' \
    --arg c "$class" --arg f "$field" --argjson v "$json"
  hyprctl reload >/dev/null 2>&1 || true

  workspace_apply_live "$class"
  return 0
}

# A window rule applies to windows that open from now on. The ones already
# open are what the user is looking at, so the rule in force is applied to them
# as well — otherwise "Shown as: Floating" leaves a fullscreen window
# fullscreen, and an application that remembers how it was closed (Typora,
# most Electron apps) opens fullscreen again next time however the rule reads.
#
# Through `hyprctl eval`, not `hyprctl dispatch`: on a Lua config the latter
# parses its argument as Lua, so the old `movetoworkspacesilent 7,class:...`
# form fails — and did so silently here for a while.
workspace_apply_live() {
  local class=$1 rule ws float fullscreen addr floating lua
  rule=$(jq -c --arg c "$class" '(.windowRules // {})[$c] // {}' <<<"$(read_store)")
  ws=$(jq -r '.workspace // ""' <<<"$rule")
  float=$(jq -r '.float // false' <<<"$rule")
  fullscreen=$(jq -r '.fullscreen // false' <<<"$rule")

  while IFS=$'\t' read -r addr floating; do
    [[ -n $addr ]] || continue
    lua="local w = 'address:$addr'"
    # Fullscreen mode 2 is what the rule gives a window; 0 takes it back.
    lua+="; hl.dispatch(hl.dsp.window.fullscreen_state({ internal = $([[ $fullscreen == true ]] && echo 2 || echo 0), client = 0, window = w }))"
    # The float dispatcher toggles whatever it is told — every key tried
    # (action, state, mode, floating) flipped the window — so it is sent only
    # to a window that is on the wrong side.
    [[ $floating != "$float" ]] && lua+="; hl.dispatch(hl.dsp.window.float({ window = w }))"
    # A workspace is only a place to go; "wherever it was" moves nothing.
    [[ -n $ws ]] && lua+="; hl.dispatch(hl.dsp.window.move({ workspace = '$ws', follow = false, window = w }))"
    hyprctl eval "$lua" >/dev/null 2>&1 </dev/null || true
  done < <(capture hyprctl -j clients \
           | jq -r --arg c "$class" '.[] | select(.class == $c) | "\(.address)\t\(.floating)"' 2>/dev/null)
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
    *) die "usage: omasettings workspaces state | add <class> | set <class> workspace|silent|shown|float|fullscreen <value> | remove <class>" ;;
  esac
}
