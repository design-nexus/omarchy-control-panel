import QtQuick
import qs.Commons
import qs.Ui
import "../ui" as Ui

Ui.SectionBody {
  id: page
  property var app: null
  readonly property var asus: app.asus || ({})
  readonly property var lighting: asus.lighting || ({})
  readonly property var slash: (asus.config || {}).slash || ({})
  readonly property var aura: (asus.config || {}).aura || ({})

  function hex(color) {
    var rgb = String(color).replace("#", "")
    return rgb.length >= 6 ? rgb.slice(0, 6) : "7c3aed"
  }
  function applyAura(effect, primary, secondary, speed, direction) {
    app.run(["asus", "set-led-effect", effect, primary, secondary, speed, direction])
  }

  Ui.SettingGroup {
    title: "Keyboard lighting"
    Ui.ChoiceRow {
      label: "Brightness"; value: lighting.brightness || "med"
      options: [{value:"off",label:"Off"},{value:"low",label:"Low"},{value:"med",label:"Medium"},{value:"high",label:"High"}]
      onPicked: function(next) { app.run(["asus", "set-led-brightness", next]) }
    }
    Ui.ChoiceRow {
      label: "Aura effect"; value: aura.effect || "static"
      options: [{value:"static",label:"Static"},{value:"breathe",label:"Breathe"},{value:"rainbow-wave",label:"Rainbow"}]
      onPicked: function(next) { page.applyAura(next, String(aura.primaryColor || "7c3aed"), String(aura.secondaryColor || "00d4ff"), String(aura.speed || "med"), String(aura.direction || "right")) }
    }
    Ui.TextRow {
      label: "Primary color"; description: "Choose the static color, or the first color used by Breathe."
      value: String(aura.primaryColor || "7c3aed")
      placeholder: "RRGGBB"
      onCommitted: function(next) { page.applyAura(String(aura.effect || "static"), page.hex(next), String(aura.secondaryColor || "00d4ff"), String(aura.speed || "med"), String(aura.direction || "right")) }
    }
    Ui.TextRow {
      label: "Secondary color"; description: "The second color used by the Breathe effect."
      value: String(aura.secondaryColor || "00d4ff")
      placeholder: "RRGGBB"
      onCommitted: function(next) { page.applyAura(String(aura.effect || "breathe"), String(aura.primaryColor || "7c3aed"), page.hex(next), String(aura.speed || "med"), String(aura.direction || "right")) }
    }
    Ui.ChoiceRow {
      label: "Animation speed"; value: aura.speed || "med"
      visible: (aura.effect || "static") !== "static"
      options: [{value:"low",label:"Slow"},{value:"med",label:"Medium"},{value:"high",label:"Fast"}]
      onPicked: function(next) { page.applyAura(String(aura.effect || "static"), String(aura.primaryColor || "7c3aed"), String(aura.secondaryColor || "00d4ff"), next, String(aura.direction || "right")) }
    }
    Ui.ChoiceRow {
      label: "Rainbow direction"; value: aura.direction || "right"
      visible: (aura.effect || "static") === "rainbow-wave"
      options: [{value:"left",label:"Left"},{value:"right",label:"Right"},{value:"up",label:"Up"},{value:"down",label:"Down"}]
      onPicked: function(next) { page.applyAura("rainbow-wave", String(aura.primaryColor || "7c3aed"), String(aura.secondaryColor || "00d4ff"), String(aura.speed || "med"), next) }
    }
    Ui.NumberRow {
      label: "Backlight timeout"; description: "Turns the keyboard light off when idle and restores it on activity or resume."
      value: Number((asus.config || {}).backlightTimeout || 30); from: 0; to: 600; step: 5; suffix: "sec"
      onCommitted: function(next) { app.run(["asus", "set", "backlightTimeout", String(next)]) }
    }
  }
  Ui.SettingGroup {
    title: "Slash lighting"
    Ui.SwitchRow { label: "Slash LED"; checked: slash.enabled !== false; onRequested: function(next) { app.run(["asus", "set-slash", "enabled", next ? "true" : "false"]) } }
    Ui.NumberRow { label: "Brightness"; value: Number(slash.brightness !== undefined ? slash.brightness : 255); from: 0; to: 255; step: 16; onCommitted: function(next) { app.run(["asus", "set-slash", "brightness", String(next)]) } }
    Ui.NumberRow { label: "Animation interval"; value: Number(slash.interval !== undefined ? slash.interval : 0); from: 0; to: 5; step: 1; onCommitted: function(next) { app.run(["asus", "set-slash", "interval", String(next)]) } }
    Ui.SwitchRow { label: "Show on boot"; checked: slash.showOnBoot !== false; onRequested: function(next) { app.run(["asus", "set-slash", "showOnBoot", next ? "true" : "false"]) } }
    Ui.SwitchRow { label: "Show on shutdown"; checked: slash.showOnShutdown !== false; onRequested: function(next) { app.run(["asus", "set-slash", "showOnShutdown", next ? "true" : "false"]) } }
    Ui.SwitchRow { label: "Show on sleep"; checked: slash.showOnSleep !== false; onRequested: function(next) { app.run(["asus", "set-slash", "showOnSleep", next ? "true" : "false"]) } }
    Ui.SwitchRow { label: "Allow on battery"; checked: slash.showOnBattery !== false; onRequested: function(next) { app.run(["asus", "set-slash", "showOnBattery", next ? "true" : "false"]) } }
    Ui.SwitchRow { label: "Low battery warning"; checked: slash.showBatteryWarning !== false; onRequested: function(next) { app.run(["asus", "set-slash", "showBatteryWarning", next ? "true" : "false"]) } }
  }
}
