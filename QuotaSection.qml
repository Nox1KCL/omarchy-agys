import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Column {
  id: root

  required property var service
  property var strings: null
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property color urgent: Commons.Color.urgent
  property string fontFamily: Style.font.family
  property int alertThreshold: 15

  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property color trackColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.14)
  readonly property var groups: service ? service.quotaGroups : []
  readonly property string planTier: service ? service.planTier : ""
  readonly property string usageError: service ? service.usageError : ""
  readonly property string fetchedAt: service ? service.usageFetchedAt : ""
  readonly property double nowMs: service ? service.nowMs : 0

  function t(key, fallback) {
    if (strings && typeof strings.t === "function") return strings.t(key, fallback)
    return fallback !== undefined ? fallback : key
  }

  function groupDotColor(group) {
    return (group && group.warm_color) ? "#FB923C" : "#38BDF8"
  }

  function bucketFillColor(pct, warmColor) {
    if (pct <= alertThreshold) return root.urgent
    if (pct <= 30) return "#F59E0B"
    return warmColor ? "#FB923C" : "#38BDF8"
  }

  function shortBucketLabel(bucket) {
    if (!bucket) return ""
    var lbl = String(bucket.label || bucket.name || bucket.window || "")
    return lbl.replace(/\s+Limit$/i, "")
  }

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(8)

  Item {
    id: sectionHead
    width: parent.width
    implicitHeight: Math.max(leftHead.implicitHeight, fetchedText.implicitHeight)

    Row {
      id: leftHead
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      PanelSectionHeader {
        text: root.t("quota.title", "Quota Limits")
        foreground: root.foreground
        fontFamily: root.fontFamily
        anchors.verticalCenter: parent.verticalCenter
      }

      BorderSurface {
        visible: root.planTier !== ""
        anchors.verticalCenter: parent.verticalCenter
        radius: Style.cornerRadius
        color: Style.selectedFillFor(root.foreground, root.accent)
        borderSpec: Border.controlSpec("normal", root.foreground, root.accent)
        implicitWidth: planText.implicitWidth + Style.space(10)
        implicitHeight: planText.implicitHeight + Style.space(2)

        Text {
          id: planText
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: root.planTier
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }

    Text {
      id: fetchedText
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      visible: text !== ""
      textFormat: Text.PlainText
      text: root.service ? root.service.formatRelativeFromIso(root.fetchedAt, root.nowMs) : ""
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Text {
    visible: root.groups.length === 0
    width: parent.width
    textFormat: Text.PlainText
    text: root.usageError !== ""
      ? root.usageError
      : root.t("quota.unavailable", "Quota data unavailable")
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  Repeater {
    model: root.groups

    Column {
      id: groupCol
      required property var modelData
      readonly property bool warm: Boolean(modelData && modelData.warm_color)
      readonly property var buckets: (modelData && modelData.buckets && modelData.buckets.length !== undefined) ? modelData.buckets : []

      width: parent.width
      spacing: Style.space(5)

      Row {
        width: parent.width
        spacing: Style.space(6)

        Rectangle {
          width: Style.space(6)
          height: width
          radius: width / 2
          anchors.verticalCenter: parent.verticalCenter
          color: root.groupDotColor(groupCol.modelData)
        }

        Text {
          textFormat: Text.PlainText
          text: String((groupCol.modelData && groupCol.modelData.name) || "")
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
          elide: Text.ElideRight
          width: parent.width - Style.space(12)
        }
      }

      Repeater {
        model: groupCol.buckets

        Column {
          id: bucketCol
          required property var modelData
          readonly property int pct: Math.max(0, Math.min(100, Number((modelData && modelData.remaining_percent) || 0)))
          readonly property real frac: (modelData && modelData.remaining_fraction !== undefined)
            ? Math.max(0, Math.min(1, Number(modelData.remaining_fraction)))
            : (pct / 100.0)
          readonly property string resetText: root.service
            ? root.service.formatResetLabel(String((modelData && modelData.reset_time) || ""), root.nowMs)
            : ""

          width: parent.width
          spacing: Style.space(3)

          Item {
            width: parent.width
            implicitHeight: Math.max(bucketName.implicitHeight, bucketMeta.implicitHeight)

            Text {
              id: bucketName
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: root.shortBucketLabel(bucketCol.modelData)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Row {
              id: bucketMeta
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Text {
                visible: bucketCol.resetText !== ""
                textFormat: Text.PlainText
                text: bucketCol.resetText
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Text {
                textFormat: Text.PlainText
                text: bucketCol.pct + "%"
                color: bucketCol.pct <= root.alertThreshold ? root.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }
          }

          Rectangle {
            width: parent.width
            height: Math.max(3, Style.space(4))
            radius: height / 2
            color: root.trackColor
            clip: true

            Rectangle {
              height: parent.height
              width: Math.round(parent.width * bucketCol.frac)
              radius: parent.radius
              color: root.bucketFillColor(bucketCol.pct, groupCol.warm)

              Behavior on width {
                NumberAnimation {
                  duration: Style.duration(180)
                  easing.type: Easing.Bezier
                  easing.bezierCurve: Style.easeOut
                }
              }
            }
          }
        }
      }
    }
  }
}
