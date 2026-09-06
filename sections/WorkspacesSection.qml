import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  property var app: null

  readonly property var rules: app.workspaceRules
  readonly property var setups: app.workspaceSetups
  readonly property var apps: app.workspaceApps
  readonly property var displays: (app.monitors !== undefined ? app.monitors : []).filter(function(m) {
    return m.connected !== false
  })

  // An application already on the page is picked from its own group, not from
  // the list again; the same for a workspace.
  readonly property var unbound: apps.filter(function(entry) {
    return !rules.some(function(rule) { return String(rule.class) === String(entry.class) })
  })
  readonly property var unsetWorkspaces: {
    var out = []
    for (var i = 1; i <= 10; i++) {
      var id = String(i)
      if (!setups.some(function(s) { return String(s.id) === id })) out.push(id)
    }
    return out
  }

  function workspaceOptions() {
    var out = [{ value: "", label: "Wherever it was last open" }]
    for (var i = 1; i <= 10; i++) out.push({ value: String(i), label: "Workspace " + i })
    out.push({ value: "special", label: "Scratchpad" })
    return out
  }

  // Displays are named by what they say about themselves, so a rule follows
  // the screen rather than the socket it happens to be in.
  function displayOptions(noneLabel) {
    return [{ value: "", label: noneLabel }].concat(displays.map(function(m) {
      return { value: String(m.name), label: String(m.label || m.name) }
    }))
  }

  // ---------------------------------------------------------- applications
  //
  // Every bound application gets its own group, titled with its name, so what
  // a control writes is never in doubt: the rows under Slack are about Slack.
  Repeater {
    model: rules

    delegate: Ui.SettingGroup {
      required property var modelData

      readonly property string cls: String(modelData.class)
      readonly property string name: String(modelData.name || modelData.class)
      readonly property bool ours: modelData.ours === true
      readonly property bool theirs: modelData.theirs === true
      readonly property bool onWorkspace: String(modelData.workspace || "") !== ""
      readonly property bool floating: modelData.shown === "floating"

      width: parent.width
      title: name
      note: theirs && !ours ? "Set in your own Hyprland config. A value picked here goes on top of it."
        : theirs ? "Also set in your own Hyprland config. The values here win."
        : ""

      Ui.PickerRow {
        label: "Opens on"
        value: String(modelData.workspace || "")
        options: workspaceOptions()
        onPicked: function(next) { app.run(["workspaces", "set", cls, "workspace", next]) }
      }

      Ui.SwitchRow {
        label: "Open in the background"
        description: "Send the window to its workspace without switching to it."
        visible: onWorkspace
        checked: modelData.silent === true
        onRequested: function(next) { app.run(["workspaces", "set", cls, "silent", next ? "true" : "false"]) }
      }

      Ui.PickerRow {
        label: "Open on display"
        visible: displays.length > 1
        value: String(modelData.monitor || "")
        options: displayOptions("Whichever has the focus")
        onPicked: function(next) { app.run(["workspaces", "set", cls, "monitor", next]) }
      }

      // One choice, not two switches: a fullscreen window is neither tiled nor
      // floating in any way you can see, so offering both was offering a
      // combination with no meaning.
      Ui.ChoiceRow {
        label: "Shown as"
        description: "Floating opens a free window rather than one tiled into the layout."
        options: [
          { value: "tiled", label: "Tiled" },
          { value: "floating", label: "Floating" },
          { value: "fullscreen", label: "Fullscreen" }
        ]
        value: String(modelData.shown || "tiled")
        onPicked: function(next) { app.run(["workspaces", "set", cls, "shown", next]) }
      }

      // What only a floating window can do sits under Floating, and goes away
      // with it — Hyprland ignores a pin on a tiled window rather than saying so.
      // A share of the screen rather than pixels, so one rule fits every
      // display. Empty hands the size back to the application.
      Ui.TextRow {
        label: "Width"
        description: "Percent of the screen. Leave empty to let the application decide."
        visible: floating
        value: Number(modelData.width) > 0 ? String(modelData.width) : ""
        placeholder: "e.g. 60"
        onCommitted: function(next) { app.run(["workspaces", "set", cls, "width", next.trim()]) }
      }

      Ui.TextRow {
        label: "Height"
        description: "Percent of the screen."
        visible: floating
        value: Number(modelData.height) > 0 ? String(modelData.height) : ""
        placeholder: "e.g. 60"
        onCommitted: function(next) { app.run(["workspaces", "set", cls, "height", next.trim()]) }
      }

      Ui.SwitchRow {
        label: "Centred"
        description: "Opens in the middle of the screen."
        visible: floating
        checked: modelData.center === true
        onRequested: function(next) { app.run(["workspaces", "set", cls, "center", next ? "true" : "false"]) }
      }

      Ui.SwitchRow {
        label: "Pinned"
        description: "Stays on screen whichever workspace you switch to."
        visible: floating
        checked: modelData.pin === true
        onRequested: function(next) { app.run(["workspaces", "set", cls, "pin", next ? "true" : "false"]) }
      }

      Ui.SwitchRow {
        label: "Don't take focus when opening"
        description: "The window appears without pulling you away from what you were doing."
        checked: modelData.noInitialFocus === true
        onRequested: function(next) { app.run(["workspaces", "set", cls, "no_initial_focus", next ? "true" : "false"]) }
      }

      Ui.SwitchRow {
        label: "Keep the screen awake"
        description: "No dimming or locking while a window of this application is open."
        checked: modelData.idleInhibit === true
        onRequested: function(next) { app.run(["workspaces", "set", cls, "idle_inhibit", next ? "true" : "false"]) }
      }

      Ui.SwitchRow {
        label: "Hide from screen sharing"
        description: "Shows as a black rectangle to anyone you share your screen with."
        checked: modelData.noScreenShare === true
        onRequested: function(next) { app.run(["workspaces", "set", cls, "no_screen_share", next ? "true" : "false"]) }
      }

      // A rule the user wrote is commented out in their own file, not deleted:
      // two dashes to delete is an easier way back than a backup.
      Ui.ActionRow {
        buttonText: "Remove"
        onTriggered: app.run(["workspaces", "remove", cls])
      }
    }
  }

  Ui.SettingGroup {
    visible: unbound.length > 0
    note: rules.length === 0 ? "Nothing bound yet. Pick an application to give it a workspace." : ""

    Ui.PickerRow {
      label: "Bind an application"
      description: "Applications with a running window are listed by the class their windows actually report."
      value: ""
      searchable: true
      options: [{ value: "", label: "Pick an application…" }].concat(unbound.map(function(entry) {
        return {
          value: String(entry.class),
          label: String(entry.name) + (entry.running ? "  (running)" : "")
        }
      }))
      onPicked: function(next) { if (next !== "") app.run(["workspaces", "add", next]) }
    }
  }

  // ------------------------------------------------------------ workspaces
  //
  // The place rather than what opens there. Only a workspace with something
  // set gets a group, so ten empty groups do not bury the applications above.
  Repeater {
    model: setups

    delegate: Ui.SettingGroup {
      required property var modelData

      readonly property string id: String(modelData.id)
      readonly property bool ours: modelData.ours === true
      readonly property bool theirs: modelData.theirs === true

      width: parent.width
      title: "Workspace " + id
      note: theirs && !ours ? "Set in your own Hyprland config. A value picked here goes on top of it."
        : theirs ? "Also set in your own Hyprland config. The values here win."
        : ""

      Ui.TextRow {
        label: "Name"
        description: "Shown in the bar instead of the number."
        value: String(modelData.name || "")
        placeholder: id
        onCommitted: function(next) { app.run(["workspaces", "setup", "set", id, "name", next]) }
      }

      Ui.PickerRow {
        label: "Display"
        visible: displays.length > 1
        value: String(modelData.monitor || "")
        options: displayOptions("Any")
        onPicked: function(next) { app.run(["workspaces", "setup", "set", id, "monitor", next]) }
      }

      Ui.SwitchRow {
        label: "Default on its display"
        description: "The workspace a display shows when it is plugged in."
        visible: String(modelData.monitor || "") !== ""
        checked: modelData.default === true
        onRequested: function(next) { app.run(["workspaces", "setup", "set", id, "default", next ? "true" : "false"]) }
      }

      Ui.SwitchRow {
        label: "Keep when empty"
        description: "Stays in the bar with no windows on it."
        checked: modelData.persistent === true
        onRequested: function(next) { app.run(["workspaces", "setup", "set", id, "persistent", next ? "true" : "false"]) }
      }

      Ui.ChoiceRow {
        label: "Layout"
        options: [
          { value: "", label: "Default" },
          { value: "dwindle", label: "Dwindle" },
          { value: "master", label: "Master" },
          { value: "scrolling", label: "Scrolling" }
        ]
        value: String(modelData.layout || "")
        onPicked: function(next) { app.run(["workspaces", "setup", "set", id, "layout", next]) }
      }

      Ui.SwitchRow {
        label: "Borderless, no gaps"
        description: "Windows edge to edge with no borders, rounding or decorations."
        checked: modelData.minimal === true
        onRequested: function(next) { app.run(["workspaces", "setup", "set", id, "minimal", next ? "true" : "false"]) }
      }

      Ui.ActionRow {
        buttonText: "Remove"
        onTriggered: app.run(["workspaces", "setup", "remove", id])
      }
    }
  }

  Ui.SettingGroup {
    visible: unsetWorkspaces.length > 0

    Ui.PickerRow {
      label: "Set up a workspace"
      description: "Its display, name, layout, and whether it stays when empty."
      value: ""
      options: [{ value: "", label: "Pick a workspace…" }].concat(unsetWorkspaces.map(function(id) {
        return { value: id, label: "Workspace " + id }
      }))
      onPicked: function(next) { if (next !== "") app.run(["workspaces", "setup", "add", next]) }
    }
  }
}
