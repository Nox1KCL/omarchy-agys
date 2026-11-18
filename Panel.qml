import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "nox.agys"
  ipcTarget: "nox.agys"
  manageIpc: false

  readonly property int refreshIntervalSec: Math.max(10, Math.min(1800, Number(root.setting("refreshIntervalSec", 60))))
  readonly property int pageSize: Math.max(3, Math.min(10, Number(root.setting("pageSize", 5))))
  readonly property bool showBadge: Boolean(root.setting("showBadge", true))
  readonly property bool enableQuotaAlerts: Boolean(root.setting("enableQuotaAlerts", true))
  readonly property int quotaAlertThreshold: Math.max(5, Math.min(50, Number(root.setting("quotaAlertThreshold", 15))))
  readonly property string terminalCommand: String(root.setting("terminalCommand", "") || "")

  readonly property color foreground: (bar && bar.foreground && bar.foreground.a > 0) ? bar.foreground : "#D8DEE9"
  readonly property color background: (Commons.Color.background && Commons.Color.background.a > 0) ? Commons.Color.background : "#101315"
  readonly property color accent: (Commons.Color.accent && Commons.Color.accent.a > 0) ? Commons.Color.accent : "#89B4FA"
  readonly property color urgent: (bar && bar.urgent && bar.urgent.a > 0) ? bar.urgent : "#F38BA8"
  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property string activeTab: "sessions" // "sessions" | "archive" | "trash"
  property int pinnedPage: 0
  property int recentPage: 0
  property int archivePage: 0
  property int trashPage: 0
  property string pendingPurgeTrashName: ""

  readonly property var i18n: i18nStrings
  readonly property var service: agysService

  function t(key, fallback) {
    return i18nStrings.t(key, fallback)
  }

  function clampPage(page, totalItems) {
    var maxPage = Math.max(0, Math.ceil(totalItems / root.pageSize) - 1)
    return Math.max(0, Math.min(page, maxPage))
  }

  function slicePage(list, page) {
    if (!Array.isArray(list) || list.length === 0) return []
    var clamped = clampPage(page, list.length)
    var start = clamped * root.pageSize
    return list.slice(start, start + root.pageSize)
  }

  function clampAllPages() {
    pinnedPage = clampPage(pinnedPage, service.pinnedSessions.length)
    recentPage = clampPage(recentPage, service.recentSessions.length)
    archivePage = clampPage(archivePage, service.archivedSessions.length)
    trashPage = clampPage(trashPage, service.trashSessions.length)
    if (pendingPurgeTrashName !== "") {
      var found = false
      for (var i = 0; i < service.trashSessions.length; i++) {
        if (String(service.trashSessions[i].trash_name || service.trashSessions[i].id) === pendingPurgeTrashName) {
          found = true
          break
        }
      }
      if (!found) pendingPurgeTrashName = ""
    }
  }

  function statusLabel() {
    if (service.activeStatus === "Working") return t("status.working", "Working")
    if (service.activeStatus === "Waiting") return t("status.waiting", "Waiting")
    return t("status.idle", "Idle")
  }

  function statusColor() {
    if (service.activeStatus === "Working") return root.accent
    if (service.activeStatus === "Waiting") return Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.72)
    return root.dim
  }

  function barTooltip() {
    if (service.hasCriticalQuota) {
      return t("bar.tooltip.lowQuota", "Agys · %1 · Low quota (%2% left)")
        .arg(statusLabel())
        .arg(String(service.minRemainingPercent))
    }
    if (service.activeCount > 0) {
      return t("bar.tooltip.active", "Agys · %1 (%2 active)")
        .arg(statusLabel())
        .arg(String(service.activeCount))
    }
    return t("bar.tooltip.idle", "Agys · Idle")
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: {
    if (opened) {
      pendingPurgeTrashName = ""
      service.refreshOnOpen()
    } else {
      pendingPurgeTrashName = ""
    }
  }

  onPageSizeChanged: clampAllPages()

  Commons.Translations {
    id: i18nStrings
    directory: Qt.resolvedUrl("i18n")
  }

  AgysService {
    id: agysService
    refreshIntervalSec: root.refreshIntervalSec
    enableQuotaAlerts: root.enableQuotaAlerts
    quotaAlertThreshold: root.quotaAlertThreshold
    terminalCommand: root.terminalCommand
    panelOpened: root.opened
    strings: root.i18n
    onSnapshotUpdated: root.clampAllPages()
  }

  ShellIpc {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { service.refresh(true); return "ok" }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    useActiveColor: false
    fixedWidth: vertical ? -1 : Style.bar.iconSlot
    fixedHeight: vertical ? Style.bar.iconSlot : -1
    tooltipText: root.barTooltip()

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) {
        service.openAgysTui()
      } else if (buttonCode === Qt.MiddleButton) {
        service.refresh(true)
      } else {
        root.toggle()
      }
    }

    Item {
      id: barCanvas
      anchors.centerIn: parent
      width: Style.bar.iconCanvas
      height: Style.bar.iconCanvas
      scale: button.pressScale

      Image {
        id: barStarImg
        x: Math.round((parent.width - width) / 2) - (statusOrb.visible ? Style.space(2) : 0)
        y: Math.round((parent.height - height) / 2) - (statusOrb.visible ? Style.space(1) : 0)
        width: Style.bar.iconCanvas
        height: Style.bar.iconCanvas
        source: Qt.resolvedUrl("assets/antigravity.svg")
        sourceSize: Qt.size(Math.max(24, Math.round(Style.bar.iconCanvas * 2)), Math.max(24, Math.round(Style.bar.iconCanvas * 2)))
        smooth: true
        mipmap: true
        visible: false
      }

      MultiEffect {
        anchors.fill: barStarImg
        source: barStarImg
        colorization: 1.0
        colorizationColor: button.foreground
      }

      Item {
        id: statusOrb
        readonly property bool showCount: service.activeCount > 0 && root.showBadge
        readonly property bool showDotOnly: (service.activeCount > 0 && !root.showBadge) || (service.activeCount === 0 && service.hasCriticalQuota)
        readonly property color orbColor: service.hasCriticalQuota ? root.urgent : root.accent
        readonly property real coreHeight: showCount ? Math.max(11, Math.round(Style.space(12))) : Math.max(5, Math.round(Style.space(6)))
        readonly property real coreWidth: showCount ? Math.max(coreHeight, Math.ceil(orbCountText.implicitWidth) + Style.space(5)) : coreHeight

        visible: showCount || showDotOnly
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -Style.space(4)
        anchors.bottomMargin: -Style.space(2)
        width: coreWidth + Style.space(2)
        height: coreHeight + Style.space(2)

        Rectangle {
          id: orbHalo
          anchors.centerIn: parent
          width: statusOrb.coreWidth + Style.space(2)
          height: statusOrb.coreHeight + Style.space(2)
          radius: height / 2
          color: Qt.rgba(statusOrb.orbColor.r, statusOrb.orbColor.g, statusOrb.orbColor.b, 0.28)

          SequentialAnimation on opacity {
            running: service.activeStatus === "Working" && statusOrb.visible
            loops: Animation.Infinite
            alwaysRunToEnd: false
            onRunningChanged: if (!running) orbHalo.opacity = 1.0
            NumberAnimation { from: 1.0; to: 0.25; duration: Style.duration(750); easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.25; to: 1.0; duration: Style.duration(750); easing.type: Easing.InOutSine }
          }
        }

        Rectangle {
          anchors.centerIn: parent
          width: statusOrb.coreWidth
          height: statusOrb.coreHeight
          radius: height / 2
          color: statusOrb.orbColor
          border.width: 1
          border.color: root.background

          FontMetrics {
            id: orbMetrics
            font: orbCountText.font
          }

          Text {
            id: orbCountText
            visible: statusOrb.showCount
            anchors.centerIn: parent
            anchors.verticalCenterOffset: Math.round((orbMetrics.descent - orbMetrics.ascent + orbMetrics.tightBoundingRect("0").height) / 2)
            textFormat: Text.PlainText
            text: String(service.activeCount)
            color: root.background
            font.family: root.fontFamily
            font.pixelSize: Math.max(8, Math.round(Style.space(8)))
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
        }
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(760))

    content: PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      implicitHeight: mainColumn.implicitHeight
      onCloseRequested: {
        if (root.pendingPurgeTrashName !== "") root.pendingPurgeTrashName = ""
        else root.close()
      }
      onTabRequested: function(dir) { root.switchPanel(dir) }
      onTextKey: function(txt) {
        if (txt === "r" || txt === "R") service.refresh(true)
        else if (txt === "1") { root.activeTab = "sessions"; root.pendingPurgeTrashName = "" }
        else if (txt === "2") { root.activeTab = "archive"; root.pendingPurgeTrashName = "" }
        else if (txt === "3") { root.activeTab = "trash"; root.pendingPurgeTrashName = "" }
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar {
          id: panelScroll
          policy: ScrollBar.AsNeeded
        }

        Column {
          id: mainColumn
          width: panelFlick.width - (panelFlick.interactive ? panelScroll.width + Style.space(6) : 0)
          spacing: Style.space(10)

          // ---------- Top Header Bar ----------
          Item {
            width: parent.width
            implicitHeight: Math.max(brandRow.implicitHeight, headerActions.implicitHeight)

            Row {
              id: brandRow
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(8)

              Item {
                width: Style.space(18)
                height: Style.space(18)
                anchors.verticalCenter: parent.verticalCenter

                Image {
                  id: headerStarImg
                  anchors.fill: parent
                  source: Qt.resolvedUrl("assets/antigravity.svg")
                  sourceSize: Qt.size(36, 36)
                  smooth: true
                  mipmap: true
                  visible: false
                }

                MultiEffect {
                  anchors.fill: headerStarImg
                  source: headerStarImg
                  colorization: 1.0
                  colorizationColor: root.foreground
                }
              }

              Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: root.t("panel.title", "Agys")
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              BorderSurface {
                anchors.verticalCenter: parent.verticalCenter
                radius: Style.cornerRadius
                color: service.activeCount > 0
                  ? Qt.rgba(root.statusColor().r, root.statusColor().g, root.statusColor().b, 0.16)
                  : "transparent"
                borderSpec: Border.controlSpec("normal", root.foreground, root.accent)
                implicitWidth: statusInner.implicitWidth + Style.space(10)
                implicitHeight: statusInner.implicitHeight + Style.space(4)

                Row {
                  id: statusInner
                  anchors.centerIn: parent
                  spacing: Style.space(4)

                  Rectangle {
                    width: Style.space(6)
                    height: width
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.statusColor()
                  }

                  Text {
                    textFormat: Text.PlainText
                    anchors.verticalCenter: parent.verticalCenter
                    text: service.activeCount > 0
                      ? root.statusLabel() + " \u00b7 " + service.activeCount
                      : root.statusLabel()
                    color: service.activeCount > 0 ? root.foreground : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: service.activeCount > 0
                  }
                }
              }
            }

            Row {
              id: headerActions
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)

              PanelActionButton {
                iconText: "\uf067"
                tooltipText: root.t("header.newSession", "New agy session")
                foreground: root.foreground
                hoverColor: root.accent
                bordered: true
                fontFamily: root.fontFamily
                onClicked: {
                  service.launchNewSession()
                  root.close()
                }
              }

              PanelActionButton {
                iconText: "\uf120"
                tooltipText: root.t("header.openTui", "Open Agys TUI")
                foreground: root.foreground
                hoverColor: root.accent
                bordered: true
                fontFamily: root.fontFamily
                onClicked: {
                  service.openAgysTui()
                  root.close()
                }
              }

              PanelActionButton {
                iconText: "\uf021"
                tooltipText: root.t("header.refresh", "Refresh status and quota")
                foreground: service.busy ? root.accent : root.foreground
                hoverColor: root.accent
                bordered: true
                fontFamily: root.fontFamily
                onClicked: service.refresh(true)
              }
            }
          }

          // ---------- Compact View Tabs (Sessions | Archive | Trash) ----------
          Row {
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: [
                { id: "sessions", label: root.t("tab.sessions", "Sessions"), count: service.pinnedSessions.length + service.recentSessions.length },
                { id: "archive", label: root.t("tab.archive", "Archive"), count: service.archivedSessions.length },
                { id: "trash", label: root.t("tab.trash", "Trash"), count: service.trashSessions.length }
              ]

              BorderSurface {
                id: tabBtn
                required property var modelData
                readonly property bool selected: root.activeTab === modelData.id

                width: Math.floor((parent.width - Style.space(12)) / 3)
                implicitHeight: tabText.implicitHeight + Style.space(10)
                radius: Style.cornerRadius
                color: selected
                  ? Style.selectedFillFor(root.foreground, root.accent)
                  : (tabMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent")
                borderSpec: selected
                  ? Border.controlSpec("selected", root.foreground, root.accent)
                  : Border.controlSpec("normal", root.foreground, root.accent)

                Behavior on color { ColorAnimation { duration: Style.duration(80) } }

                Text {
                  id: tabText
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: tabBtn.modelData.count > 0
                    ? tabBtn.modelData.label + " \u00b7 " + tabBtn.modelData.count
                    : tabBtn.modelData.label
                  color: tabBtn.selected ? root.foreground : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: tabBtn.selected
                  elide: Text.ElideRight
                  width: Math.min(implicitWidth, parent.width - Style.space(10))
                }

                MouseArea {
                  id: tabMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.activeTab = tabBtn.modelData.id
                    root.pendingPurgeTrashName = ""
                    panelFlick.contentY = 0
                  }
                }
              }
            }
          }

          Text {
            visible: service.errorText !== ""
            width: parent.width
            textFormat: Text.PlainText
            text: service.errorText
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          PanelSeparator {
            foreground: root.foreground
          }

          // ---------- Sessions View ----------
          Column {
            visible: root.activeTab === "sessions"
            width: parent.width
            spacing: Style.space(10)

            QuotaSection {
              width: parent.width
              service: root.service
              strings: root.i18n
              foreground: root.foreground
              accent: root.accent
              urgent: root.urgent
              fontFamily: root.fontFamily
              alertThreshold: root.quotaAlertThreshold
            }

            PanelSeparator {
              visible: service.pinnedSessions.length > 0
              foreground: root.foreground
            }

            // Pinned Sessions
            Column {
              visible: service.pinnedSessions.length > 0
              width: parent.width
              spacing: Style.space(4)

              Item {
                width: parent.width
                implicitHeight: pinnedHeader.implicitHeight

                PanelSectionHeader {
                  id: pinnedHeader
                  anchors.left: parent.left
                  text: root.t("section.pinned", "Pinned") + " (" + service.pinnedSessions.length + ")"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                }

                Text {
                  visible: service.pinnedSessions.length > root.pageSize
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: (root.pinnedPage + 1) + "/" + Math.max(1, Math.ceil(service.pinnedSessions.length / root.pageSize))
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              Repeater {
                model: root.slicePage(service.pinnedSessions, root.pinnedPage)

                SessionRow {
                  required property var modelData
                  width: parent.width
                  item: modelData
                  mode: "sessions"
                  strings: root.i18n
                  foreground: root.foreground
                  accent: root.accent
                  urgent: root.urgent
                  fontFamily: root.fontFamily
                  onActivated: function(sess) {
                    service.openSession(sess)
                    root.close()
                  }
                  onActionTriggered: function(act, id) { service.runAction(act, id) }
                }
              }

              PaginatorBar {
                width: parent.width
                currentPage: root.pinnedPage
                totalItems: service.pinnedSessions.length
                pageSize: root.pageSize
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                prevTooltip: root.t("pagination.prev", "Previous page")
                nextTooltip: root.t("pagination.next", "Next page")
                onPageSelected: function(p) { root.pinnedPage = p }
              }
            }

            PanelSeparator {
              foreground: root.foreground
            }

            // Recent Sessions
            Column {
              width: parent.width
              spacing: Style.space(4)

              Item {
                width: parent.width
                implicitHeight: recentHeader.implicitHeight

                PanelSectionHeader {
                  id: recentHeader
                  anchors.left: parent.left
                  text: root.t("section.recent", "Recent") + " (" + service.recentSessions.length + ")"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                }

                Text {
                  visible: service.recentSessions.length > root.pageSize
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: (root.recentPage + 1) + "/" + Math.max(1, Math.ceil(service.recentSessions.length / root.pageSize))
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              Text {
                visible: service.recentSessions.length === 0 && service.pinnedSessions.length === 0
                width: parent.width
                textFormat: Text.PlainText
                text: service.ready
                  ? root.t("empty.sessions", "No active sessions")
                  : root.t("empty.loading", "Loading Agys state...")
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                topPadding: Style.space(4)
                bottomPadding: Style.space(4)
              }

              Repeater {
                model: root.slicePage(service.recentSessions, root.recentPage)

                SessionRow {
                  required property var modelData
                  width: parent.width
                  item: modelData
                  mode: "sessions"
                  strings: root.i18n
                  foreground: root.foreground
                  accent: root.accent
                  urgent: root.urgent
                  fontFamily: root.fontFamily
                  onActivated: function(sess) {
                    service.openSession(sess)
                    root.close()
                  }
                  onActionTriggered: function(act, id) { service.runAction(act, id) }
                }
              }

              PaginatorBar {
                width: parent.width
                currentPage: root.recentPage
                totalItems: service.recentSessions.length
                pageSize: root.pageSize
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                prevTooltip: root.t("pagination.prev", "Previous page")
                nextTooltip: root.t("pagination.next", "Next page")
                onPageSelected: function(p) { root.recentPage = p }
              }
            }
          }

          // ---------- Archive View ----------
          Column {
            visible: root.activeTab === "archive"
            width: parent.width
            spacing: Style.space(4)

            Item {
              width: parent.width
              implicitHeight: archiveHeader.implicitHeight

              PanelSectionHeader {
                id: archiveHeader
                anchors.left: parent.left
                text: root.t("section.archive", "Archive") + " (" + service.archivedSessions.length + ")"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              Text {
                visible: service.archivedSessions.length > root.pageSize
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: (root.archivePage + 1) + "/" + Math.max(1, Math.ceil(service.archivedSessions.length / root.pageSize))
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Text {
              visible: service.archivedSessions.length === 0
              width: parent.width
              textFormat: Text.PlainText
              text: root.t("empty.archive", "No archived sessions")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              topPadding: Style.space(6)
              bottomPadding: Style.space(6)
            }

            Repeater {
              model: root.slicePage(service.archivedSessions, root.archivePage)

              SessionRow {
                required property var modelData
                width: parent.width
                item: modelData
                mode: "archive"
                strings: root.i18n
                foreground: root.foreground
                accent: root.accent
                urgent: root.urgent
                fontFamily: root.fontFamily
                onActivated: function(sess) {
                  service.openSession(sess)
                  root.close()
                }
                onActionTriggered: function(act, id) { service.runAction(act, id) }
              }
            }

            PaginatorBar {
              width: parent.width
              currentPage: root.archivePage
              totalItems: service.archivedSessions.length
              pageSize: root.pageSize
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              prevTooltip: root.t("pagination.prev", "Previous page")
              nextTooltip: root.t("pagination.next", "Next page")
              onPageSelected: function(p) { root.archivePage = p }
            }
          }

          // ---------- Trash View ----------
          Column {
            visible: root.activeTab === "trash"
            width: parent.width
            spacing: Style.space(4)

            Item {
              width: parent.width
              implicitHeight: trashHeader.implicitHeight

              PanelSectionHeader {
                id: trashHeader
                anchors.left: parent.left
                text: root.t("section.trash", "Trash") + " (" + service.trashSessions.length + ")"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              Text {
                visible: service.trashSessions.length > root.pageSize
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: (root.trashPage + 1) + "/" + Math.max(1, Math.ceil(service.trashSessions.length / root.pageSize))
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Text {
              visible: service.trashSessions.length === 0
              width: parent.width
              textFormat: Text.PlainText
              text: root.t("empty.trash", "Trash is empty")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              topPadding: Style.space(6)
              bottomPadding: Style.space(6)
            }

            Repeater {
              model: root.slicePage(service.trashSessions, root.trashPage)

              SessionRow {
                required property var modelData
                width: parent.width
                item: modelData
                mode: "trash"
                strings: root.i18n
                confirmingPurge: root.pendingPurgeTrashName !== ""
                  && root.pendingPurgeTrashName === String((modelData && (modelData.trash_name || modelData.id)) || "")
                foreground: root.foreground
                accent: root.accent
                urgent: root.urgent
                fontFamily: root.fontFamily
                onRequestPurgeConfirm: function(trashName) { root.pendingPurgeTrashName = trashName }
                onCancelPurgeConfirm: root.pendingPurgeTrashName = ""
                onActionTriggered: function(act, id) {
                  root.pendingPurgeTrashName = ""
                  service.runAction(act, id)
                }
              }
            }

            PaginatorBar {
              width: parent.width
              currentPage: root.trashPage
              totalItems: service.trashSessions.length
              pageSize: root.pageSize
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              prevTooltip: root.t("pagination.prev", "Previous page")
              nextTooltip: root.t("pagination.next", "Next page")
              onPageSelected: function(p) { root.trashPage = p }
            }
          }
        }
      }
    }
  }
}
