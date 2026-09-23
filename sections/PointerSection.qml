import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  property var app: null
  readonly property var rogConfig: (app.asus || {}).config || ({})
  readonly property var rogTouchpad: rogConfig.touchpad || ({})
  readonly property var rogGestures: rogConfig.gestures || ({})
  readonly property bool hasRogTouchpad: rogConfig.touchpad !== undefined
  Ui.SettingGroup {

    Ui.PercentRow {
      label: "Sensitivity"
      description: "How far the pointer travels for the same hand movement."
      value: (Number(app.hyprValue("sensitivity", 0)) + 1) / 2
      onCommitted: function(next) { app.setHypr("sensitivity", (next * 2 - 1).toFixed(2)) }
      changed: app.isChanged("sensitivity")
      onResetRequested: app.resetSetting("sensitivity")
    }

    Ui.PickerRow {
      label: "Acceleration"
      value: String(app.hyprValue("accel-profile", ""))
      options: [
        { value: "", label: "Default (adaptive)" },
        { value: "flat", label: "Flat — no acceleration" },
        { value: "adaptive", label: "Adaptive" }
      ]
      onPicked: function(next) { app.setHypr("accel-profile", next) }
      changed: app.isChanged("accel-profile")
      onResetRequested: app.resetSetting("accel-profile")
    }

    Ui.PickerRow {
      label: "Focus follows mouse"
      value: String(app.hyprValue("follow-mouse", 1))
      options: [
        { value: "0", label: "Off — click to focus" },
        { value: "1", label: "On" },
        { value: "2", label: "On, but keyboard stays" },
        { value: "3", label: "On, without raising" }
      ]
      onPicked: function(next) { app.setHypr("follow-mouse", next) }
      changed: app.isChanged("follow-mouse")
      onResetRequested: app.resetSetting("follow-mouse")
    }
  }

  Ui.SettingGroup {
    title: "Touchpad"
    visible: !hasRogTouchpad

    Ui.SwitchRow {
      label: "Natural scrolling"
      checked: app.hyprValue("natural-scroll", false) === true
      onRequested: function(next) { app.setHypr("natural-scroll", next ? "true" : "false") }
      changed: app.isChanged("natural-scroll")
      onResetRequested: app.resetSetting("natural-scroll")
    }

    Ui.SwitchRow {
      label: "Tap to click"
      checked: app.hyprValue("tap-to-click", true) === true
      onRequested: function(next) { app.setHypr("tap-to-click", next ? "true" : "false") }
      changed: app.isChanged("tap-to-click")
      onResetRequested: app.resetSetting("tap-to-click")
    }

    Ui.SwitchRow {
      label: "Two-finger right click"
      description: "Off uses the lower-right corner instead."
      checked: app.hyprValue("clickfinger", false) === true
      onRequested: function(next) { app.setHypr("clickfinger", next ? "true" : "false") }
      changed: app.isChanged("clickfinger")
      onResetRequested: app.resetSetting("clickfinger")
    }

    Ui.SwitchRow {
      label: "Disable while typing"
      checked: app.hyprValue("disable-while-typing", true) === true
      onRequested: function(next) { app.setHypr("disable-while-typing", next ? "true" : "false") }
      changed: app.isChanged("disable-while-typing")
      onResetRequested: app.resetSetting("disable-while-typing")
    }

    Ui.FactorRow {
      label: "Scroll speed"
      value: Number(app.hyprValue("scroll-factor", 1))
      onCommitted: function(next) { app.setHypr("scroll-factor", next) }
      changed: app.isChanged("scroll-factor")
      onResetRequested: app.resetSetting("scroll-factor")
    }
  }

  // The G16 controller generates a device-specific Hyprland module.  Keep
  // these in one group instead of showing the generic controls above as a
  // second, conflicting set of touchpad settings.
  Ui.SettingGroup {
    title: "ROG G16 trackpad"
    visible: hasRogTouchpad

    Ui.SwitchRow { label: "Trackpad"; description: "Enable the built-in ASUP1207 touchpad."; checked: rogTouchpad.enabled !== false; onRequested: function(next) { app.run(["asus", "set", "touchpad.enabled", next ? "true" : "false"]) } }
    Ui.SwitchRow { label: "Natural scrolling"; description: "Content follows your fingers."; checked: rogTouchpad.naturalScroll === true; onRequested: function(next) { app.run(["asus", "set", "touchpad.naturalScroll", next ? "true" : "false"]) } }
    Ui.SwitchRow { label: "Tap to click"; description: "One-finger tap clicks; the map below controls two- and three-finger taps."; checked: rogTouchpad.tapToClick !== false; onRequested: function(next) { app.run(["asus", "set", "touchpad.tapToClick", next ? "true" : "false"]) } }
    Ui.PickerRow {
      label: "Two / three-finger taps"; value: String(rogTouchpad.tapMap || "lrm")
      options: [{value:"lrm",label:"2 = right click, 3 = middle click"},{value:"lmr",label:"2 = middle click, 3 = right click"}]
      onPicked: function(next) { app.run(["asus", "set", "touchpad.tapMap", next]) }
    }
    Ui.SwitchRow { label: "Clickfinger behavior"; description: "Physical two- and three-finger clicks become right and middle click."; checked: rogTouchpad.clickfinger !== false; onRequested: function(next) { app.run(["asus", "set", "touchpad.clickfinger", next ? "true" : "false"]) } }
    Ui.SwitchRow { label: "Disable while typing"; description: "Prevents accidental palm movement."; checked: rogTouchpad.disableWhileTyping !== false; onRequested: function(next) { app.run(["asus", "set", "touchpad.disableWhileTyping", next ? "true" : "false"]) } }
    Ui.SwitchRow { label: "Drag lock"; description: "Keep dragging after lifting your finger."; checked: rogTouchpad.dragLock === true; onRequested: function(next) { app.run(["asus", "set", "touchpad.dragLock", next ? "true" : "false"]) } }
    Ui.SwitchRow { label: "Middle-button emulation"; description: "Press left and right buttons together for middle click."; checked: rogTouchpad.middleButtonEmulation === true; onRequested: function(next) { app.run(["asus", "set", "touchpad.middleButtonEmulation", next ? "true" : "false"]) } }
    Ui.FactorRow { label: "Scroll speed"; value: Number(rogTouchpad.scrollFactor !== undefined ? rogTouchpad.scrollFactor : 0.4); minimum: 0.1; maximum: 2; onCommitted: function(next) { app.run(["asus", "set", "touchpad.scrollFactor", String(next)]) } }
    Ui.FactorRow { label: "Pointer speed"; value: Number(rogTouchpad.sensitivity !== undefined ? rogTouchpad.sensitivity : 0); minimum: -1; maximum: 1; onCommitted: function(next) { app.run(["asus", "set", "touchpad.sensitivity", String(next)]) } }
  }

  Ui.SettingGroup {
    title: "ROG G16 swipe gestures"
    visible: hasRogTouchpad
    Ui.ReadingRow { label: "Two fingers"; value: "Scrolling is reserved for normal two-finger movement." }
    Ui.ReadingRow { label: "Four-finger taps"; value: "This touchpad does not emit four-finger taps; use the swipe actions below." }
    Ui.PickerRow { label: "3 fingers · left / right"; value: String(rogGestures.threeHorizontal || "workspace"); options: gestureOptions; onPicked: function(next) { app.run(["asus", "set", "gestures.threeHorizontal", next]) } }
    Ui.SwitchRow {
      visible: !searchHidden && (rogGestures.threeHorizontal || "workspace") === "workspace"
      label: "Reverse swipe direction"
      description: "Swipe left switches to the next workspace, right to previous."
      checked: rogGestures.threeHorizontalReverse === true
      onRequested: function(next) { app.run(["asus", "set", "gestures.threeHorizontalReverse", next ? "true" : "false"]) }
    }
    Ui.PickerRow { label: "3 fingers · up"; value: String(rogGestures.threeUp || "launcher"); options: gestureOptions; onPicked: function(next) { app.run(["asus", "set", "gestures.threeUp", next]) } }
    Ui.PickerRow { label: "3 fingers · down"; value: String(rogGestures.threeDown || "special-workspace"); options: gestureOptions; onPicked: function(next) { app.run(["asus", "set", "gestures.threeDown", next]) } }
    Ui.PickerRow { label: "4 fingers · left"; value: String(rogGestures.fourLeft || "previous-workspace"); options: gestureOptions; onPicked: function(next) { app.run(["asus", "set", "gestures.fourLeft", next]) } }
    Ui.PickerRow { label: "4 fingers · right"; value: String(rogGestures.fourRight || "next-workspace"); options: gestureOptions; onPicked: function(next) { app.run(["asus", "set", "gestures.fourRight", next]) } }
    Ui.PickerRow { label: "4 fingers · up"; value: String(rogGestures.fourUp || "fullscreen"); options: gestureOptions; onPicked: function(next) { app.run(["asus", "set", "gestures.fourUp", next]) } }
    Ui.PickerRow { label: "4 fingers · down"; value: String(rogGestures.fourDown || "none"); options: gestureOptions; onPicked: function(next) { app.run(["asus", "set", "gestures.fourDown", next]) } }
  }

  readonly property var gestureOptions: [
    {value:"none",label:"Disabled"}, {value:"workspace",label:"Workspace swipe"},
    {value:"launcher",label:"App launcher"}, {value:"special-workspace",label:"Special workspace"},
    {value:"previous-workspace",label:"Previous workspace"}, {value:"next-workspace",label:"Next workspace"},
    {value:"focus-left",label:"Focus left"}, {value:"focus-right",label:"Focus right"},
    {value:"fullscreen",label:"Toggle fullscreen"}, {value:"close-window",label:"Close window"},
    {value:"play-pause",label:"Play / pause"}, {value:"screenshot",label:"Screenshot"}
  ]

  // Every pointer that can depart from the settings above gets its own group,
  // so what a control writes is never in doubt: the ones under a device name
  // write that device, the ones above write every device.
  //
  // A device shows the value in force for it — what was set here, else what
  // the user's own config gives it, else the global setting above.

  // A device is only worth a group of its own once it departs from the
  // settings above. The rest are one dropdown away, so a page with five
  // devices and no overrides stays a page about settings, not a list of
  // hardware.
  property var opened: []

  function isCustomised(device) {
    return Object.keys(device.settings || ({})).length > 0
      || Object.keys(device.configured || ({})).length > 0
      || opened.indexOf(String(device.name)) !== -1
  }

  readonly property var allDevices: app.devices.pointers !== undefined ? app.devices.pointers : []
  readonly property var customised: allDevices.filter(isCustomised)
  readonly property var untouched: allDevices.filter(function(device) { return !isCustomised(device) })

  function openDevice(name) {
    var next = opened.slice()
    next.push(String(name))
    opened = next
  }

  // Closing a group that was only opened to look at it: nothing was written,
  // so nothing has to be removed.
  function closeDevice(name) {
    opened = opened.filter(function(entry) { return entry !== String(name) })
  }

  Repeater {
    model: customised

    delegate: Ui.SettingGroup {
      required property var modelData

      readonly property string name: String(modelData.name)
      readonly property var settings: modelData.settings || ({})
      readonly property var configured: modelData.configured || ({})
      readonly property bool ours: Object.keys(settings).length > 0

      // Not called `value`: inside a row, that name resolves to the row's own
      // value property rather than to this.
      function inForce(key, fallback) {
        if (settings[key] !== undefined && settings[key] !== null) return settings[key]
        if (configured[key] !== undefined && configured[key] !== null) return configured[key]
        return fallback
      }

      width: parent.width
      // Named as a device so the heading cannot be mistaken for another
      // group of settings.
      title: "Device: " + name + (modelData.connected === false ? "  (not connected)" : "")
      note: Object.keys(configured).length > 0 && !ours
        ? "Set in your own Hyprland config."
        : ""

      Ui.PercentRow {
        label: "Sensitivity"
        value: (Number(inForce("sensitivity", app.hyprValue("sensitivity", 0))) + 1) / 2
        onCommitted: function(next) { app.setDevice(name, "sensitivity", (next * 2 - 1).toFixed(2), "pointer") }
        changed: app.isChanged("sensitivity")
        onResetRequested: app.resetSetting("sensitivity")
      }

      Ui.PickerRow {
        label: "Acceleration"
        value: String(inForce("accel_profile", app.hyprValue("accel-profile", "")))
        options: [
          { value: "", label: "Default (adaptive)" },
          { value: "flat", label: "Flat — no acceleration" },
          { value: "adaptive", label: "Adaptive" }
        ]
        onPicked: function(next) { app.setDevice(name, "accel_profile", next, "pointer") }
        changed: app.isChanged("accel-profile")
        onResetRequested: app.resetSetting("accel-profile")
      }

      Ui.SwitchRow {
        label: "Natural scrolling"
        checked: inForce("natural_scroll", app.hyprValue("natural-scroll", false)) === true
        onRequested: function(next) { app.setDevice(name, "natural_scroll", next ? "true" : "false", "pointer") }
        changed: app.isChanged("natural-scroll")
        onResetRequested: app.resetSetting("natural-scroll")
      }

      Ui.SwitchRow {
        label: "Left handed"
        checked: inForce("left_handed", false) === true
        onRequested: function(next) { app.setDevice(name, "left_handed", next ? "true" : "false", "pointer") }
        changed: app.isChanged("device:" + name + ":left_handed")
        onResetRequested: app.resetSetting("device:" + name + ":left_handed")
      }

      Ui.FactorRow {
        label: "Scroll speed"
        minimum: 0.1
        maximum: 3
        value: Number(inForce("scroll_factor", app.hyprValue("scroll-factor", 1)))
        onCommitted: function(next) { app.setDevice(name, "scroll_factor", next, "pointer") }
        changed: app.isChanged("scroll-factor")
        onResetRequested: app.resetSetting("scroll-factor")
      }

      // No label: what the button removes is the group it sits in, and how
      // that is undone in a config file is not the reader's problem.
      Ui.ActionRow {
        readonly property bool theirs: Object.keys(configured).length > 0

        buttonText: "Remove Device"
        onTriggered: {
          if (theirs) app.removeDevice(name)
          else if (ours) app.clearDevice(name)
          else closeDevice(name)
        }
      }
    }
  }

  Ui.SettingGroup {
    visible: !searchEmpty && untouched.length > 0

    Ui.PickerRow {
      label: "Settings for one device"
      description: "Give a single mouse or touchpad its own settings, apart from the ones above."
      value: ""
      options: [{ value: "", label: "Pick a device…" }].concat(untouched.map(function(device) {
        return {
          value: String(device.name),
          label: String(device.name) + (device.connected === false ? " (not connected)" : "")
        }
      }))
      onPicked: function(next) { if (next !== "") openDevice(next) }
    }
  }
}
