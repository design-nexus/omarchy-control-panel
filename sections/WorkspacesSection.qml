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
  readonly property var apps: app.workspaceApps

  // An application already on the page is picked from its own group, not from
  // the list again.
  readonly property var unbound: apps.filter(function(entry) {
    return !rules.some(function(rule) { return String(rule.class) === String(entry.class) })
  })

  function workspaceOptions() {
    var out = [{ value: "", label: "Wherever it was last open" }]
    for (var i = 1; i <= 10; i++) out.push({ value: String(i), label: "Workspace " + i })
    out.push({ value: "special", label: "Scratchpad" })
    return out
  }

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

      width: parent.width
      title: name
      // The class is machinery, but it is also the one thing that says which
      // windows this rule catches — shown where it differs from the name.
      note: (cls !== name ? "Windows of class " + cls + ". " : "")
        + (theirs && !ours ? "Set in your own Hyprland config; a value picked here goes on top of it."
           : theirs ? "Also set in your own Hyprland config. The values here win."
           : "")

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

      // A rule the user wrote lives in their file, which this page never
      // rewrites; only what was set here can be taken off here.
      Ui.ActionRow {
        label: "Remove"
        description: theirs ? "Takes off what was set here. Your own config's rule stays." : ""
        visible: ours
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
}
