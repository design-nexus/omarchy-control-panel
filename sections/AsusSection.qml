import QtQuick
import qs.Commons
import qs.Ui
import "../ui" as Ui

Ui.SectionBody {
  property var app: null
  readonly property var asus: app.asus || ({})
  readonly property var armoury: asus.armoury || ({})
  Ui.SettingGroup {
    title: "Firmware"
    Ui.SwitchRow { visible: (armoury.bootSound || {}).supported === true; label: "Boot sound"; checked: (armoury.bootSound || {}).value === true; onRequested: function(next) { app.run(["asus", "set-armoury", "boot_sound", next ? "1" : "0"]) } }
    Ui.SwitchRow { visible: (armoury.panelOverdrive || {}).supported === true; label: "Panel overdrive"; checked: (armoury.panelOverdrive || {}).value === true; onRequested: function(next) { app.run(["asus", "set-armoury", "panel_overdrive", next ? "1" : "0"]) } }
    Ui.SwitchRow { visible: (armoury.dgpuDisable || {}).supported === true; label: "Eco GPU mode"; checked: (armoury.dgpuDisable || {}).value === true; onRequested: function(next) { app.run(["asus", "set-armoury", "dgpu_disable", next ? "1" : "0"]) } }
    Ui.SwitchRow { visible: (armoury.gpuMuxMode || {}).supported === true; label: "Discrete GPU MUX"; checked: (armoury.gpuMuxMode || {}).value === true; onRequested: function(next) { app.run(["asus", "set-armoury", "gpu_mux_mode", next ? "1" : "0"]) } }
  }
  Ui.SettingGroup {
    title: "Advanced power tuning"
    Ui.NumberRow { visible: (armoury.dynamicBoost || {}).supported === true; label: "NVIDIA Dynamic Boost"; value: Number((armoury.dynamicBoost || {}).value || 20); from: 5; to: 20; suffix: "W"; onCommitted: function(next) { app.run(["asus", "set-armoury", "nv_dynamic_boost", String(next)]) } }
    Ui.NumberRow { visible: (armoury.tgp || {}).supported === true; label: "NVIDIA TGP"; value: Number((armoury.tgp || {}).value || 90); from: 80; to: 110; suffix: "W"; onCommitted: function(next) { app.run(["asus", "set-armoury", "nv_tgp", String(next)]) } }
    Ui.NumberRow { visible: (armoury.tempTarget || {}).supported === true; label: "NVIDIA temperature target"; value: Number((armoury.tempTarget || {}).value || 87); from: 75; to: 87; suffix: "°C"; onCommitted: function(next) { app.run(["asus", "set-armoury", "nv_temp_target", String(next)]) } }
    Ui.NumberRow { visible: (armoury.pl1 || {}).supported === true; label: "CPU sustained power"; value: Number((armoury.pl1 || {}).value || 45); from: 45; to: 85; suffix: "W"; onCommitted: function(next) { app.run(["asus", "set-armoury", "ppt_pl1_spl", String(next)]) } }
    Ui.NumberRow { visible: (armoury.pl2 || {}).supported === true; label: "CPU short boost"; value: Number((armoury.pl2 || {}).value || 56); from: 56; to: 110; suffix: "W"; onCommitted: function(next) { app.run(["asus", "set-armoury", "ppt_pl2_sppt", String(next)]) } }
  }
}
