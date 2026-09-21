import QtQuick
import qs.Commons
import qs.Ui
import "../ui" as Ui

// The detailed calibration interface remains its original, purpose-built
// panel.  Settings owns and opens that vendored panel so the separate plugin
// can be removed once this replacement has been confirmed working.
Ui.SectionBody {
  property var app: null
  readonly property var calibration: (app.audio || {}).calibration || ({})

  Ui.SettingGroup {
    title: "Speaker calibration"
    Ui.ReadingRow {
      label: "Profile"
      value: calibration.profile ? "Saved calibration for " + String((calibration.profile.speaker || {}).description || "speakers") : "No calibration saved"
    }
    Ui.ReadingRow {
      label: "Current state"
      value: calibration.enabled === true ? "Active" : (calibration.bypass === true ? "Bypassed" : "Not currently in the output path")
    }
    Ui.ActionRow {
      label: "Open calibration controls"
      description: "Full measurement, microphone selection, response curves, profile comparison, verification, and Deep Bass controls."
      buttonText: "Open"
      onTriggered: app.run(["calibration", "open-panel"])
    }
  }
}
