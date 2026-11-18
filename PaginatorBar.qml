import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  property int currentPage: 0
  property int totalItems: 0
  property int pageSize: 5
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.family
  property string prevTooltip: "Previous page"
  property string nextTooltip: "Next page"

  readonly property int totalPages: Math.max(1, Math.ceil(totalItems / Math.max(1, pageSize)))
  readonly property var pageTokens: computeTokens(currentPage, totalPages)

  signal pageSelected(int page)

  function computeTokens(cur, total) {
    if (total <= 1) return []
    if (total <= 7) {
      var simple = []
      for (var i = 0; i < total; i++) simple.push(i)
      return simple
    }

    var start = Math.max(1, cur - 1)
    var end = Math.min(total - 2, cur + 1)
    if (cur <= 2) {
      start = 1
      end = 2
    } else if (cur >= total - 3) {
      start = total - 3
      end = total - 2
    }

    var out = [0]
    if (start > 2) out.push(-1)
    else if (start === 2) out.push(1)

    for (var p = start; p <= end; p++) out.push(p)

    if (end < total - 3) out.push(-2)
    else if (end === total - 3) out.push(total - 2)

    out.push(total - 1)
    return out
  }

  visible: totalPages > 1
  width: parent ? parent.width : implicitWidth
  implicitHeight: visible ? row.implicitHeight + Style.space(2) : 0

  Row {
    id: row
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: Style.space(4)

    PanelActionButton {
      iconText: "\uf053"
      tooltipText: root.prevTooltip
      foreground: root.foreground
      hoverColor: root.accent
      fontFamily: root.fontFamily
      fontSize: Style.font.caption
      size: Style.space(22)
      enabled: root.currentPage > 0
      onClicked: root.pageSelected(Math.max(0, root.currentPage - 1))
    }

    Repeater {
      model: root.pageTokens

      Item {
        id: tokenDelegate
        required property int modelData
        readonly property bool isEllipsis: modelData < 0
        readonly property bool isSelected: !isEllipsis && modelData === root.currentPage

        implicitWidth: isEllipsis ? ellipsisText.implicitWidth + Style.space(4)
          : Math.max(Style.space(22), pageLabel.implicitWidth + Style.space(10))
        implicitHeight: Style.space(22)

        Text {
          id: ellipsisText
          visible: tokenDelegate.isEllipsis
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: "\u2026"
          color: Qt.darker(root.foreground, 1.55)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        BorderSurface {
          visible: !tokenDelegate.isEllipsis
          anchors.fill: parent
          radius: Style.cornerRadius
          color: tokenDelegate.isSelected
            ? Style.selectedFillFor(root.foreground, root.accent)
            : (pageMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent")
          borderSpec: tokenDelegate.isSelected
            ? Border.controlSpec("selected", root.foreground, root.accent)
            : Border.none()

          Behavior on color { ColorAnimation { duration: Style.duration(80) } }

          Text {
            id: pageLabel
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: String(tokenDelegate.modelData + 1)
            color: tokenDelegate.isSelected
              ? root.foreground
              : (pageMouse.containsMouse ? root.foreground : Qt.darker(root.foreground, 1.4))
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: tokenDelegate.isSelected
          }

          MouseArea {
            id: pageMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.pageSelected(tokenDelegate.modelData)
          }
        }
      }
    }

    PanelActionButton {
      iconText: "\uf054"
      tooltipText: root.nextTooltip
      foreground: root.foreground
      hoverColor: root.accent
      fontFamily: root.fontFamily
      fontSize: Style.font.caption
      size: Style.space(22)
      enabled: root.currentPage < root.totalPages - 1
      onClicked: root.pageSelected(Math.min(root.totalPages - 1, root.currentPage + 1))
    }
  }
}
