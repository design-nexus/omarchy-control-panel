import QtQuick
import qs.Commons
import qs.Ui
import "../ui" as Ui

Ui.SectionBody {
  property var app: null
  readonly property var audio: app.audio || ({})
  readonly property var calibration: audio.calibration || ({})
  readonly property bool hasProfile: calibration.profile !== null && calibration.profile !== undefined

  Ui.SettingGroup {
    title: "Profile"
    Ui.ReadingRow {
      label: "Measured profile"
      value: hasProfile
        ? String((calibration.profile.speaker || {}).description || "Speakers") + " · " + String(calibration.profile.created_at || "saved")
        : "No profile installed"
    }
    Ui.ReadingRow {
      label: "Current state"
      value: calibration.enabled === true ? "Active" : (calibration.bypass === true ? "Bypassed" : "Not in the output path")
    }
  }

  Ui.SettingGroup {
    title: "Correction"
    Ui.ActionRow {
      label: "Use calibrated output"
      description: "Route playback through the measured correction and safety limiter."
      buttonText: "Use"
      enabled: hasProfile
      onTriggered: app.run(["calibration", "use-calibrated-output"])
    }
    Ui.SwitchRow {
      label: "Bypass correction"
      description: "Temporarily hear the same output without the measured EQ."
      checked: calibration.bypass === true
      enabled: hasProfile
      onRequested: function(next) { app.run(["calibration", "bypass-toggle"]) }
    }
    Ui.SwitchRow {
      label: "Loudness compensation"
      description: "Adjust tonal balance at lower listening levels while preserving headroom."
      checked: calibration.loudnessCompensation === "on"
      enabled: hasProfile
      onRequested: function(next) { app.run(["calibration", "loudness-toggle"]) }
    }
    Ui.SwitchRow {
      label: "Deep bass"
      description: calibration.bassEnhancer && calibration.bassEnhancer.usable === true
        ? "Add protected harmonic bass enhancement."
        : "The optional Deep Bass component is not installed."
      checked: calibration.deepBass === "on"
      enabled: calibration.bassEnhancer && calibration.bassEnhancer.usable === true
      onRequested: function(next) { app.run(["calibration", "deep-bass-toggle"]) }
    }
  }

  Ui.SettingGroup {
    title: "Measure and verify"
    Ui.ActionRow {
      label: "New calibration"
      description: "Choose speakers and microphone, measure the room, review response curves, and install a protected profile."
      buttonText: "Start"
      onTriggered: app.run(["calibration", "open-panel"])
    }
    Ui.ActionRow {
      label: "Check calibration"
      description: "Play verification sweeps and compare the result with the installed profile."
      buttonText: "Check"
      enabled: hasProfile
      onTriggered: app.run(["calibration", "verify-json"])
    }
    Ui.ActionRow {
      label: "Compare profiles"
      description: "Switch between current and previous profiles at matched loudness."
      buttonText: "Compare"
      enabled: (calibration.compare || {}).available === true
      onTriggered: app.run(["calibration", "compare-toggle"])
    }
    Ui.ActionRow {
      label: "Disable calibration"
      description: "Restore the physical output while keeping the saved profile."
      buttonText: "Disable"
      enabled: hasProfile
      onTriggered: app.run(["calibration", "disable"])
    }
  }
}
