import QtQuick
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  property var app: null

  readonly property var audio: app.audio
  readonly property var calibration: audio.calibration || ({})
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
    title: "Calibrated speakers"
    visible: calibration.available !== false
    Ui.NumberRow {
      label: "Preamp boost"
      description: "Gain before the protected calibration and final limiter; it does not change master volume or the measured EQ."
      value: audio.preampDb !== undefined && audio.preampDb !== null ? Number(audio.preampDb) : 18; from: 0; to: 36; step: 3; suffix: "dB"
      onCommitted: function(next) { app.run(["audio", "preamp", String(next)]) }
    }
    Ui.ReadingRow {
      label: "Calibration"
      value: calibration.profile
        ? "Measured " + String(calibration.profile.created_at || "profile")
        : "No profile installed"
    }
    Ui.ActionRow {
      label: "Calibrated output"
      description: "Route playback through the measured correction and safety limiter."
      buttonText: "Use calibrated"
      enabled: calibration.profile !== null && calibration.profile !== undefined
      onTriggered: app.run(["calibration", "use-calibrated-output"])
    }
    Ui.SwitchRow {
      label: "Bypass correction"
      description: "Temporarily hear the same output without the measured EQ."
      checked: calibration.bypass === true
      enabled: calibration.profile !== null && calibration.profile !== undefined
      onRequested: function(next) { app.run(["calibration", "bypass-toggle"]) }
    }
    Ui.ActionRow {
      label: "Compare profiles"
      description: "Switch between the current and previous measured profiles at matched loudness."
      buttonText: "Compare"
      enabled: (calibration.compare || {}).available === true
      onTriggered: app.run(["calibration", "compare-toggle"])
    }
    Ui.SwitchRow {
      label: "Loudness compensation"
      description: "Adjusts tonal balance at lower listening levels while preserving safe output headroom."
      checked: calibration.loudnessCompensation === "on"
      enabled: calibration.profile !== null && calibration.profile !== undefined
      onRequested: function(next) { app.run(["calibration", "loudness-toggle"]) }
    }
    Ui.SwitchRow {
      label: "Deep bass"
      description: calibration.bassEnhancer && calibration.bassEnhancer.usable === true
        ? "Adds harmonic bass enhancement without driving the speakers below their protected range."
        : "Install the optional Deep Bass add-on from the calibration plugin before enabling."
      checked: calibration.deepBass === "on"
      enabled: calibration.bassEnhancer && calibration.bassEnhancer.usable === true
      onRequested: function(next) { app.run(["calibration", "deep-bass-toggle"]) }
    }
    Ui.ActionRow {
      label: "Check calibration"
      description: "Plays verification sweeps and reports whether the installed correction still matches its measurement."
      buttonText: "Check"
      enabled: calibration.profile !== null && calibration.profile !== undefined
      onTriggered: app.run(["calibration", "verify-json"])
    }
    Ui.ActionRow {
      label: "Recalibrate current setup"
      description: "Measures the same speaker and microphone used by the active profile, then installs the new protected correction."
      buttonText: "Recalibrate"
      enabled: calibration.profile !== null && calibration.profile !== undefined
      onTriggered: {
        var p = calibration.profile
        app.run(["calibration", "calibrate-json", "--sink", String((p.speaker || {}).name),
          "--mic", String((p.microphone || {}).name), "--channel", String((p.microphone || {}).channel || "0"),
          "--voicing", String(p.voicing || "neutral"), "--loudness", String(p.loudness || "protected"),
          "--bass", String(p.bass || "normal"), "--channel-trim", String(p.channel_trim || "off"), "--install"])
      }
    }
    Ui.ActionRow {
      label: "Disable calibration"
      description: "Restores playback to the physical output. Your saved profile is kept."
      buttonText: "Disable"
      enabled: calibration.profile !== null && calibration.profile !== undefined
      onTriggered: app.run(["calibration", "disable"])
    }
  }

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
}
