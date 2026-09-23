import QtQuick
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  property var app: null

  readonly property var audio: app.audio
  readonly property var effects: audio.effects || ({})
  readonly property var outputs: audio.outputs !== undefined ? audio.outputs : []
  readonly property var inputs: audio.inputs !== undefined ? audio.inputs : []

  function selected(list) {
    for (var i = 0; i < list.length; i++)
      if (list[i].default === true) return list[i]
    return null
  }

  // The same marks the bar's audio widget uses, chosen from what the device
  // says it is rather than from its name.
  function deviceGlyph(device, isInput) {
    var blob = (String(device.description) + " " + String(device.icon)).toLowerCase()
    if (blob.indexOf("headphone") !== -1 || blob.indexOf("headset") !== -1
      || blob.indexOf("earbud") !== -1 || blob.indexOf("airpod") !== -1) return "\uf025"
    if (isInput) return "\uf130"
    if (blob.indexOf("hdmi") !== -1 || blob.indexOf("displayport") !== -1) return "\uf108"
    if (blob.indexOf("bluetooth") !== -1) return "\uf294"
    return "\uf028"
  }

  readonly property var currentOutput: selected(outputs)
  readonly property var currentInput: selected(inputs)

  Ui.SettingGroup {
    title: "Output"

    Ui.PercentRow {
      label: "Volume"
      value: currentOutput ? Number(currentOutput.volume) / 100 : 0
      onCommitted: function(next) { app.run(["audio", "volume", "output", String(Math.round(next * 100))]) }
    }

    Ui.SwitchRow {
      label: "Muted"
      checked: currentOutput ? currentOutput.muted === true : false
      onRequested: function(next) { app.run(["audio", "mute", "output", next ? "on" : "off"]) }
    }

    Repeater {
      model: outputs
      delegate: Ui.PickableRow {
        required property var modelData
        width: parent.width
        label: modelData.description
        glyph: deviceGlyph(modelData, false)
        detail: modelData.volume + "%"
        selected: modelData.default === true
        onPicked: app.run(["audio", "default", "output", modelData.name])
      }
    }
  }

  Ui.SettingGroup {
    title: "Preamp & 9-band equalizer"
    note: effects.active === true
      ? "Processing the selected output. A limiter controls peaks; master volume stays separate."
      : "Choose Use on this output to route playback through the preamp and equalizer."

    Ui.ActionRow {
      label: "Use on this output"
      description: effects.active === true ? "Active" : "Audio effects are currently outside the playback path."
      buttonText: "Use"
      enabled: effects.available === true && effects.active !== true
      onTriggered: app.run(["audio", "effects", "activate"])
    }
    Ui.SwitchRow {
      label: "Enable preamp and EQ"
      checked: effects.enabled !== false
      enabled: effects.available === true
      onRequested: function(next) { app.run(["audio", "effects", "enabled", next ? "true" : "false"]) }
    }
    Ui.NumberRow {
      label: "Preamp boost"
      description: "Independent gain before the EQ. At high boost the limiter may prevent further loudness increases."
      value: Number(effects.preampDb || 0)
      from: -24; to: 36; step: 1; suffix: "dB"
      enabled: effects.available === true && effects.enabled !== false
      onCommitted: function(next) { app.run(["audio", "preamp", String(next)]) }
    }
    Repeater {
      model: [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000]
      delegate: Ui.NumberRow {
        required property int index
        required property int modelData
        label: modelData < 1000 ? modelData + " Hz" : (modelData / 1000) + " kHz"
        description: "Equalizer band"
        value: Number((effects.gains || [])[index] || 0)
        from: -12; to: 12; step: 1; suffix: "dB"
        enabled: effects.available === true && effects.enabled !== false
        onCommitted: function(next) { app.run(["audio", "effects", "eq", String(index), String(next)]) }
      }
    }
    Ui.ActionRow {
      label: "Reset preamp and EQ"
      description: "Return the preamp and all nine bands to 0 dB."
      buttonText: "Reset"
      enabled: effects.available === true
      onTriggered: app.run(["audio", "effects", "reset"])
    }
  }

  Ui.SettingGroup {
    title: "Input"

    Ui.PercentRow {
      label: "Volume"
      value: currentInput ? Number(currentInput.volume) / 100 : 0
      onCommitted: function(next) { app.run(["audio", "volume", "input", String(Math.round(next * 100))]) }
    }

    Ui.SwitchRow {
      label: "Muted"
      checked: currentInput ? currentInput.muted === true : false
      onRequested: function(next) { app.run(["audio", "mute", "input", next ? "on" : "off"]) }
    }

    Repeater {
      model: inputs
      delegate: Ui.PickableRow {
        required property var modelData
        width: parent.width
        label: modelData.description
        glyph: deviceGlyph(modelData, true)
        selected: modelData.default === true
        onPicked: app.run(["audio", "default", "input", modelData.name])
      }
    }
  }

  Ui.SettingGroup {
    title: "Troubleshooting"

    Ui.ActionRow {
      label: "Restart audio service"
      description: "Restart WirePlumber to redetect sound devices if audio drops or only dummy output shows."
      buttonText: "Restart"
      onTriggered: app.run(["audio", "restart"])
    }
  }
}
