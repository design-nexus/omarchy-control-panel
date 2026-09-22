import QtQuick
import qs.Commons
import qs.Ui
import "../ui" as Ui

Ui.SectionBody {
  property var app: null
  readonly property var info: app.system || ({})

  Ui.SettingGroup {
    title: "This computer"
    Ui.ReadingRow { label: "Model"; value: String(info.host || "Unknown") }
    Ui.ReadingRow { label: "Operating system"; value: String(info.os || "Unknown") }
    Ui.ReadingRow { label: "Kernel"; value: String(info.kernel || "Unknown") }
    Ui.ReadingRow { label: "Processor"; value: String(info.cpu || "Unknown") }
    Ui.ReadingRow { label: "Memory"; value: String(info.memory || "Unknown") }
    Ui.ReadingRow { label: "Storage"; value: String(info.storage || "Unknown") }
    Ui.ReadingRow { label: "Uptime"; value: String(info.uptime || "Unknown") }
  }

  Ui.SettingGroup {
    title: "Maintenance"
    note: "These open the established Omarchy or system tool."
    Ui.ActionRow { label: "System updates"; description: "Update Omarchy and installed packages."; buttonText: "Open"; onTriggered: app.run(["system", "launch", "updates"]) }
    Ui.ActionRow { label: "System snapshots"; description: "Create or restore Snapper snapshots."; buttonText: "Open"; onTriggered: app.run(["system", "launch", "snapshots"]) }
    Ui.ActionRow { label: "Disks"; description: "Inspect drives, partitions, and filesystems."; buttonText: "Open"; onTriggered: app.run(["system", "launch", "disks"]) }
    Ui.ActionRow { label: "Printers"; description: "Add and manage printers."; buttonText: "Open"; onTriggered: app.run(["system", "launch", "printers"]) }
    Ui.ActionRow { label: "Security setup"; description: "Configure fingerprint, FIDO2, SSH, and related features."; buttonText: "Open"; onTriggered: app.run(["system", "launch", "security"]) }
    Ui.ActionRow { label: "Advanced networking"; description: "Edit connections, routes, DNS, and VPNs."; buttonText: "Open"; onTriggered: app.run(["system", "launch", "networking"]) }
  }
}
