import QtQuick
import qs.Commons
import qs.Ui
import "../ui" as Ui

Ui.SectionBody {
  property var app: null
  readonly property var notifications: app.system.notifications || ({})

  Ui.SettingGroup {
    title: "Attention"
    note: notifications.available === true ? "" : "The notification service is not currently running."

    Ui.SwitchRow {
      label: "Show notifications"
      description: "Turn this off to silence notification popups."
      enabled: notifications.available === true
      checked: notifications.doNotDisturb !== true
      onRequested: function(next) { app.run(["system", "notifications", next ? "on" : "off"]) }
    }

    Ui.ActionRow {
      label: "Notification history"
      description: "Show recent notifications."
      buttonText: "Open"
      enabled: notifications.available === true
      onTriggered: app.run(["system", "notification-history"])
    }
  }
}
