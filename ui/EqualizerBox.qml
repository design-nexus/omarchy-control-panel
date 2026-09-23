import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

Item {
  id: root

  property var app: null
  property var effects: ({})
  property string label: "Graphic equalizer"

  readonly property var frequencies: [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000]
  readonly property var frequencyLabels: ["32", "64", "125", "250", "500", "1k", "2k", "4k", "8k"]
  readonly property var frequencyUnits: ["Hz", "Hz", "Hz", "Hz", "Hz", "kHz", "kHz", "kHz", "kHz"]

  readonly property var gains: effects.gains !== undefined && effects.gains !== null
    ? effects.gains : [0, 0, 0, 0, 0, 0, 0, 0, 0]
  readonly property bool isEnabled: effects.available === true && effects.enabled !== false

  // Local state for smooth interaction while dragging
  property var liveGains: [0, 0, 0, 0, 0, 0, 0, 0, 0]
  property int draggingBand: -1

  function syncGains() {
    if (draggingBand !== -1) return
    var next = []
    for (var i = 0; i < 9; i++) {
      var val = (gains && gains[i] !== undefined) ? Number(gains[i]) : 0
      next.push(isNaN(val) ? 0 : val)
    }
    liveGains = next
  }

  onGainsChanged: syncGains()
  Component.onCompleted: syncGains()

  readonly property bool hasNonZeroGain: {
    for (var i = 0; i < liveGains.length; i++) {
      if (Math.abs(Number(liveGains[i])) > 0.01) return true
    }
    return false
  }

  function commitGain(index, val) {
    var clamped = Math.max(-12, Math.min(12, Math.round(val)))
    var next = liveGains.slice()
    next[index] = clamped
    liveGains = next
    if (app && app.run) {
      app.run(["audio", "effects", "eq", String(index), String(clamped)])
    }
  }

  function flattenAll() {
    var next = [0, 0, 0, 0, 0, 0, 0, 0, 0]
    liveGains = next
    if (app && app.run) {
      app.run(["audio", "effects", "flat"])
    }
  }

  width: parent ? parent.width : 0
  implicitHeight: container.implicitHeight

  Rectangle {
    id: container
    width: parent.width
    implicitHeight: boxColumn.implicitHeight + Style.space(24)
    radius: Style.cornerRadius
    color: Qt.rgba(Local.Palette.foreground.r, Local.Palette.foreground.g, Local.Palette.foreground.b, 0.035)
    border.color: Local.Palette.hairline
    border.width: 1

    opacity: root.isEnabled ? 1.0 : 0.45
    enabled: root.isEnabled
    Behavior on opacity { NumberAnimation { duration: 140 } }

    Column {
      id: boxColumn
      anchors {
        left: parent.left
        right: parent.right
        top: parent.top
        margins: Style.space(14)
      }
      spacing: Style.space(12)

      // Header row inside the box
      Item {
        width: parent.width
        height: Math.max(headerTextCol.implicitHeight, flatBtn.height)

        Column {
          id: headerTextCol
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Text {
            text: "Graphic Equalizer"
            font.family: Local.Palette.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            color: Local.Palette.foreground
          }

          Text {
            text: "9 bands · ±12 dB range · Double-click to zero"
            font.family: Local.Palette.fontFamily
            font.pixelSize: Style.font.tiny
            color: Local.Palette.muted
          }
        }

        // Flat (0 dB) quick action button
        Rectangle {
          id: flatBtn
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: flatBtnText.implicitWidth + Style.space(20)
          height: Style.space(28)
          radius: Style.cornerRadius
          color: flatBtnMouse.containsMouse ? Local.Palette.hover : "transparent"
          border.color: Local.Palette.hairline
          border.width: 1
          opacity: (root.isEnabled && root.hasNonZeroGain) ? 1.0 : 0.4

          Text {
            id: flatBtnText
            anchors.centerIn: parent
            text: "Flat (0 dB)"
            font.family: Local.Palette.fontFamily
            font.pixelSize: Style.font.caption
            color: flatBtnMouse.containsMouse ? Local.Palette.accent : Local.Palette.foreground
          }

          MouseArea {
            id: flatBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: root.isEnabled && root.hasNonZeroGain
            onClicked: root.flattenAll()
          }
        }
      }

      // Sliders area with scale and 9 vertical faders
      Item {
        id: eqArea
        width: parent.width
        height: Style.space(190)

        readonly property real trackHeight: Style.space(120)
        readonly property real knobHeight: Style.space(14)
        readonly property real knobWidth: Style.space(26)
        readonly property real usableHeight: trackHeight - knobHeight

        // Left dB scale labels
        Item {
          id: scaleCol
          width: Style.space(34)
          anchors.left: parent.left
          anchors.top: slidersRow.top
          anchors.topMargin: slidersRow.topLabelHeight
          height: eqArea.trackHeight

          Text {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.rightMargin: Style.space(6)
            text: "+12"
            font.family: Local.Palette.fontFamily
            font.pixelSize: Style.font.tiny
            color: Local.Palette.muted
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Style.space(6)
            text: "0"
            font.family: Local.Palette.fontFamily
            font.pixelSize: Style.font.tiny
            color: Local.Palette.muted
          }

          Text {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.rightMargin: Style.space(6)
            text: "-12"
            font.family: Local.Palette.fontFamily
            font.pixelSize: Style.font.tiny
            color: Local.Palette.muted
          }
        }

        // Horizontal reference line at +12 dB
        Rectangle {
          anchors.left: scaleCol.right
          anchors.right: parent.right
          y: slidersRow.topLabelHeight + (eqArea.knobHeight / 2)
          height: 1
          color: Local.Palette.hairline
          opacity: 0.3
        }

        // Center zero reference line (0 dB)
        Rectangle {
          anchors.left: scaleCol.right
          anchors.right: parent.right
          y: slidersRow.topLabelHeight + (eqArea.trackHeight / 2)
          height: 1
          color: Local.Palette.hairline
          opacity: 0.75
        }

        // Horizontal reference line at -12 dB
        Rectangle {
          anchors.left: scaleCol.right
          anchors.right: parent.right
          y: slidersRow.topLabelHeight + eqArea.trackHeight - (eqArea.knobHeight / 2)
          height: 1
          color: Local.Palette.hairline
          opacity: 0.3
        }

        // Row of 9 vertical sliders
        Row {
          id: slidersRow
          anchors.left: scaleCol.right
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.bottom: parent.bottom

          readonly property real topLabelHeight: Style.space(22)
          readonly property real trackHeight: eqArea.trackHeight
          readonly property real bottomLabelHeight: Style.space(38)
          readonly property real bandWidth: width / 9

          Repeater {
            model: 9
            delegate: Item {
              id: bandItem
              required property int index
              width: slidersRow.bandWidth
              height: slidersRow.height

              readonly property real currentGain: Number(
                (root.liveGains && root.liveGains[index] !== undefined) ? root.liveGains[index] : 0
              )
              readonly property bool isDragging: root.draggingBand === index
              readonly property bool isHovered: bandMouse.containsMouse

              // Gain Readout (Top)
              Text {
                id: gainLabel
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                height: slidersRow.topLabelHeight
                verticalAlignment: Text.AlignVCenter
                text: (bandItem.currentGain > 0 ? "+" : "") + Math.round(bandItem.currentGain)
                font.family: Local.Palette.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: bandItem.currentGain !== 0
                color: bandItem.currentGain !== 0 ? Local.Palette.accent : Local.Palette.muted
              }

              // Vertical Track Area
              Item {
                id: trackArea
                anchors.top: gainLabel.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: slidersRow.trackHeight

                readonly property real centerY: height / 2
                readonly property real progress: Math.max(0, Math.min(1, (bandItem.currentGain - (-12)) / 24))
                readonly property real knobY: (1.0 - progress) * eqArea.usableHeight
                readonly property real knobCenterY: knobY + (eqArea.knobHeight / 2)

                // Groove (Track)
                Rectangle {
                  id: groove
                  width: Style.space(4)
                  radius: width / 2
                  color: Qt.rgba(Local.Palette.foreground.r, Local.Palette.foreground.g, Local.Palette.foreground.b, 0.12)
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.top: parent.top
                  anchors.topMargin: eqArea.knobHeight / 2
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: eqArea.knobHeight / 2
                }

                // Center 0 dB notch on track
                Rectangle {
                  width: Style.space(12)
                  height: 1.5
                  radius: 1
                  color: Local.Palette.muted
                  opacity: 0.5
                  anchors.centerIn: parent
                }

                // Active fill from center 0 dB
                Rectangle {
                  id: fill
                  width: groove.width
                  radius: width / 2
                  color: Local.Palette.accent
                  anchors.horizontalCenter: parent.horizontalCenter
                  y: bandItem.currentGain >= 0 ? trackArea.knobCenterY : trackArea.centerY
                  height: Math.abs(trackArea.centerY - trackArea.knobCenterY)
                  visible: height > 1
                }

                // Hardware-style fader cap / knob
                Rectangle {
                  id: knob
                  width: eqArea.knobWidth
                  height: eqArea.knobHeight
                  radius: Style.space(3)
                  anchors.horizontalCenter: parent.horizontalCenter
                  y: trackArea.knobY
                  color: (bandItem.isDragging || bandItem.isHovered) ? Local.Palette.accent : Local.Palette.foreground
                  border.color: Qt.rgba(0, 0, 0, 0.35)
                  border.width: 1
                  scale: (bandItem.isDragging || bandItem.isHovered) ? 1.15 : 1.0

                  Behavior on y {
                    enabled: !bandItem.isDragging
                    NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                  }
                  Behavior on scale {
                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                  }
                  Behavior on color {
                    ColorAnimation { duration: 90 }
                  }

                  // Center grip groove line across fader
                  Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - Style.space(6)
                    height: 1.5
                    radius: 0.5
                    color: Local.Palette.background
                  }
                }
              }

              // Frequency label (Bottom)
              Column {
                anchors.top: trackArea.bottom
                anchors.topMargin: Style.space(4)
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: root.frequencyLabels[index]
                  font.family: Local.Palette.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: (bandItem.isHovered || bandItem.isDragging) ? Local.Palette.accent : Local.Palette.foreground
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: root.frequencyUnits[index]
                  font.family: Local.Palette.fontFamily
                  font.pixelSize: Style.font.tiny
                  color: Local.Palette.muted
                }
              }

              // Mouse Interaction Area
              MouseArea {
                id: bandMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                function calcGainFromY(my) {
                  var trackY = my - slidersRow.topLabelHeight
                  var clamped = Math.max(0, Math.min(eqArea.usableHeight, trackY - (eqArea.knobHeight / 2)))
                  var p = 1.0 - (clamped / eqArea.usableHeight)
                  var g = -12 + (p * 24)
                  if (Math.abs(g) < 0.5) g = 0
                  return Math.max(-12, Math.min(12, Math.round(g)))
                }

                function setLive(my) {
                  var g = calcGainFromY(my)
                  var next = root.liveGains.slice()
                  next[bandItem.index] = g
                  root.liveGains = next
                  return g
                }

                onPressed: function(mouse) {
                  if (mouse.button === Qt.RightButton) {
                    root.commitGain(bandItem.index, 0)
                    return
                  }
                  root.draggingBand = bandItem.index
                  setLive(mouse.y)
                }

                onPositionChanged: function(mouse) {
                  if (root.draggingBand === bandItem.index) {
                    setLive(mouse.y)
                  }
                }

                onReleased: function(mouse) {
                  if (mouse.button !== Qt.LeftButton) return
                  var finalGain = setLive(mouse.y)
                  root.draggingBand = -1
                  root.commitGain(bandItem.index, finalGain)
                }

                onDoubleClicked: {
                  root.commitGain(bandItem.index, 0)
                }

                onWheel: function(wheel) {
                  var delta = wheel.angleDelta.y > 0 ? 1 : -1
                  var cur = Number(root.liveGains[bandItem.index] || 0)
                  var next = Math.max(-12, Math.min(12, Math.round(cur + delta)))
                  root.commitGain(bandItem.index, next)
                }
              }
            }
          }
        }
      }
    }
  }
}
