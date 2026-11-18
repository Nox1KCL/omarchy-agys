import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  required property var item
  property string mode: "sessions" // "sessions" | "archive" | "trash"
  property var strings: null
  property bool confirmingPurge: false
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property color urgent: Commons.Color.urgent
  property string fontFamily: Style.font.family

  readonly property bool isTrash: mode === "trash"
  readonly property bool isArchive: mode === "archive"
  readonly property bool isActive: !isTrash && Boolean(item && item.active)
  readonly property bool isWorking: !isTrash && Boolean(item && item.working)
  readonly property bool isPinned: !isTrash && Boolean(item && item.pinned)
  readonly property int subCount: (!isTrash && item && item.sub_count) ? Number(item.sub_count) : 0
  readonly property bool hoveredOrConfirming: rowHover.hovered || confirmingPurge
  readonly property color dim: Qt.darker(foreground, 1.45)

  signal activated(var sessionItem)
  signal actionTriggered(string actionName, string targetId)
  signal requestPurgeConfirm(string trashName)
  signal cancelPurgeConfirm()

  function t(key, fallback) {
    if (strings && typeof strings.t === "function") return strings.t(key, fallback)
    return fallback !== undefined ? fallback : key
  }

  function tn(key, count, fallback) {
    var tmpl = (strings && typeof strings.tn === "function")
      ? strings.tn(key, count, fallback)
      : (fallback !== undefined ? fallback : String(count))
    return tmpl.indexOf("%1") !== -1 ? tmpl.arg(String(count)) : tmpl
  }

  function sessionTitle() {
    var raw = item && item.title ? String(item.title).trim() : ""
    return raw !== "" ? raw : t("session.untitled", "(untitled)")
  }

  function formatRelativeUnix(unixSec) {
    var sec = Number(unixSec || 0)
    if (!sec || sec <= 0) return ""
    var diff = Math.max(0, Math.floor(Date.now() / 1000) - sec)
    if (diff < 45) return t("quota.updatedNow", "now")
    var dur = diff < 3600 ? Math.floor(diff / 60) + "m"
      : (diff < 86400 ? Math.floor(diff / 3600) + "h"
        : (diff < 604800 ? Math.floor(diff / 86400) + "d" : Math.floor(diff / 604800) + "w"))
    return t("quota.updatedAgo", "%1 ago").arg(dur)
  }

  function metaLine() {
    var parts = []
    if (!isTrash && item && item.display_dir) {
      parts.push(String(item.display_dir))
    }
    var age = ""
    if (isTrash && item && item.deleted_unix > 0) {
      var dt = new Date(Number(item.deleted_unix) * 1000)
      age = Qt.formatDateTime(dt, "MMM d HH:mm")
    } else if (!isTrash && item && item.updated_unix > 0) {
      age = formatRelativeUnix(item.updated_unix)
    } else {
      age = isTrash
        ? String((item && item.deleted_at) || "")
        : String((item && item.updated_at) || "")
    }
    if (age) parts.push(age)
    return parts.join(" \u00b7 ")
  }

  width: parent ? parent.width : implicitWidth
  implicitHeight: rowBody.implicitHeight + Style.space(10)

  HoverHandler {
    id: rowHover
  }

  CursorSurface {
    id: surface
    anchors.fill: parent
    hasCursor: root.hoveredOrConfirming
    current: root.isActive
    foreground: root.foreground
    accent: root.accent
  }

  MouseArea {
    id: activateMouse
    anchors.fill: parent
    z: 0
    enabled: !root.isTrash
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: root.activated(root.item)
  }

  Item {
    id: rowBody
    z: 2
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(8)
    anchors.rightMargin: Style.space(6)
    implicitHeight: textCol.implicitHeight

    Rectangle {
      id: statusDot
      width: Style.space(7)
      height: width
      radius: width / 2
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.topMargin: Math.round((titleRow.implicitHeight - height) / 2)
      color: (root.isWorking || root.isActive)
        ? root.accent
        : (root.isPinned
          ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.65)
          : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.25))

      SequentialAnimation on opacity {
        running: root.isWorking
        loops: Animation.Infinite
        alwaysRunToEnd: false
        onRunningChanged: if (!running) statusDot.opacity = 1.0
        NumberAnimation { from: 1.0; to: 0.4; duration: Style.duration(700); easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.4; to: 1.0; duration: Style.duration(700); easing.type: Easing.InOutSine }
      }
    }

    Column {
      id: textCol
      anchors.left: statusDot.right
      anchors.leftMargin: Style.space(8)
      anchors.right: actionsRow.visible ? actionsRow.left : parent.right
      anchors.rightMargin: actionsRow.visible ? Style.space(6) : 0
      spacing: Style.space(1)

      Row {
        id: titleRow
        width: parent.width
        spacing: Style.space(6)

        Text {
          id: titleText
          textFormat: Text.PlainText
          text: root.sessionTitle()
          color: root.isActive ? root.foreground : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.92)
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: root.isActive || root.isPinned
          elide: Text.ElideRight
          width: Math.min(implicitWidth, Math.max(0, parent.width - (subPill.visible ? subPill.implicitWidth + Style.space(6) : 0)))
        }

        BorderSurface {
          id: subPill
          visible: root.subCount > 0
          anchors.verticalCenter: parent.verticalCenter
          radius: Style.cornerRadius
          color: Style.selectedFillFor(root.foreground, root.accent)
          borderSpec: Border.none()
          implicitWidth: subText.implicitWidth + Style.space(8)
          implicitHeight: subText.implicitHeight + Style.space(2)

          Text {
            id: subText
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: root.tn("session.subagents", root.subCount, "+" + root.subCount)
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      Text {
        id: metaText
        width: parent.width
        textFormat: Text.PlainText
        text: root.metaLine()
        visible: text !== ""
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideMiddle
      }
    }

    Row {
      id: actionsRow
      z: 2
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)
      visible: root.hoveredOrConfirming
      opacity: visible ? 1 : 0

      // Main & Archive mode: Pin / Unpin
      PanelActionButton {
        visible: !root.isTrash
        iconText: "\uf08d"
        tooltipText: root.isPinned ? root.t("action.unpin", "Unpin session") : root.t("action.pin", "Pin session")
        foreground: root.isPinned ? root.accent : root.foreground
        hoverColor: root.accent
        fontFamily: root.fontFamily
        fontSize: Style.font.iconSmall
        onClicked: root.actionTriggered(root.isPinned ? "unpin" : "pin", String(root.item.id))
      }

      // Main & Archive mode: Archive / Unarchive
      PanelActionButton {
        visible: !root.isTrash
        iconText: root.isArchive ? "\uf0e2" : "\uf187"
        tooltipText: root.isArchive ? root.t("action.unarchive", "Unarchive session") : root.t("action.archive", "Archive session")
        foreground: root.foreground
        hoverColor: root.foreground
        fontFamily: root.fontFamily
        fontSize: Style.font.iconSmall
        onClicked: root.actionTriggered(root.isArchive ? "unarchive" : "archive", String(root.item.id))
      }

      // Main & Archive mode: Move to Trash
      PanelActionButton {
        visible: !root.isTrash
        iconText: "\uf1f8"
        tooltipText: root.t("action.trash", "Move to Trash")
        foreground: root.foreground
        hoverColor: root.urgent
        fontFamily: root.fontFamily
        fontSize: Style.font.iconSmall
        onClicked: root.actionTriggered("trash", String(root.item.id))
      }

      // Trash mode: Restore or inline permanent-delete confirmation
      PanelActionButton {
        visible: root.isTrash && !root.confirmingPurge
        iconText: "\uf0e2"
        tooltipText: root.t("action.restore", "Restore session")
        foreground: root.foreground
        hoverColor: root.accent
        fontFamily: root.fontFamily
        fontSize: Style.font.iconSmall
        onClicked: root.actionTriggered("restore", String(root.item.trash_name || root.item.id))
      }

      PanelActionButton {
        visible: root.isTrash && !root.confirmingPurge
        iconText: "\uf1f8"
        tooltipText: root.t("action.purge", "Delete permanently")
        foreground: root.foreground
        hoverColor: root.urgent
        fontFamily: root.fontFamily
        fontSize: Style.font.iconSmall
        onClicked: root.requestPurgeConfirm(String(root.item.trash_name || root.item.id))
      }

      Text {
        visible: root.isTrash && root.confirmingPurge
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: root.t("confirm.purgeQuestion", "Delete?")
        color: root.urgent
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        rightPadding: Style.space(2)
      }

      PanelActionButton {
        visible: root.isTrash && root.confirmingPurge
        iconText: "\uf00c"
        tooltipText: root.t("action.confirmPurge", "Confirm permanent deletion")
        foreground: root.urgent
        hoverColor: root.urgent
        bordered: true
        fontFamily: root.fontFamily
        fontSize: Style.font.iconSmall
        onClicked: root.actionTriggered("purge", String(root.item.trash_name || root.item.id))
      }

      PanelActionButton {
        visible: root.isTrash && root.confirmingPurge
        iconText: "\u00d7"
        tooltipText: root.t("action.cancelPurge", "Cancel")
        foreground: root.foreground
        hoverColor: root.foreground
        fontFamily: root.fontFamily
        fontSize: Style.font.iconSmall
        onClicked: root.cancelPurgeConfirm()
      }
    }
  }
}
