import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons

Item {
  id: root
  visible: false
  width: 0
  height: 0

  property int refreshIntervalSec: 60
  property bool enableQuotaAlerts: true
  property int quotaAlertThreshold: 15
  property string terminalCommand: ""
  property bool panelOpened: false
  property var strings: null

  property bool ready: false
  readonly property bool busy: stateProc.running || actionProc.running
  property string errorText: ""
  property string usageError: ""

  property int activeCount: 0
  property string activeStatus: "Idle"
  property var activeIds: []

  property string planTier: ""
  property var quotaGroups: []
  property int minRemainingPercent: -1
  property string usageFetchedAt: ""

  property var pinnedSessions: []
  property var recentSessions: []
  property var archivedSessions: []
  property var trashSessions: []

  property double nowMs: Date.now()

  property var _alertCooldowns: ({})
  property bool _pendingRefresh: false
  property bool _pendingForceUsage: false
  property bool _initialUsageFetchTriggered: false
  property double _lastUsageFetchMs: 0

  readonly property bool hasCriticalQuota: enableQuotaAlerts && minRemainingPercent >= 0 && minRemainingPercent <= quotaAlertThreshold

  signal snapshotUpdated()

  function t(key, fallback) {
    if (strings && typeof strings.t === "function") return strings.t(key, fallback)
    return fallback !== undefined ? fallback : key
  }

  function agysArgv(extraArgs) {
    return [
      "sh", "-c",
      "bin=\"$(command -v agys || printf '%s' \"$HOME/.local/bin/agys\")\"; [ -x \"$bin\" ] || exit 127; exec \"$bin\" \"$@\"",
      "agys"
    ].concat(extraArgs || [])
  }

  function buildTerminalArgv(cmdArgs, workspacePath) {
    var ws = String(workspacePath || "").trim()
    if (ws.indexOf("file://") === 0) ws = decodeURIComponent(ws.substring(7))

    var term = String(terminalCommand || "").trim()
    if (!term) {
      var args = ["xdg-terminal-exec"]
      if (ws) args.push("--dir=" + ws)
      args.push("--")
      return args.concat(cmdArgs)
    }

    var parts = term.split(/\s+/).filter(function(p) { return p.length > 0 })
    if (parts.length === 0) {
      var fallback = ["xdg-terminal-exec"]
      if (ws) fallback.push("--dir=" + ws)
      fallback.push("--")
      return fallback.concat(cmdArgs)
    }

    var bin = parts[0].split("/").pop()
    if (bin === "xdg-terminal-exec") {
      if (ws) parts.push("--dir=" + ws)
      parts.push("--")
      return parts.concat(cmdArgs)
    }
    if (bin === "foot") {
      if (ws) parts.push("-D", ws)
      return parts.concat(cmdArgs)
    }
    if (bin === "kitty") {
      if (ws) parts.push("-d", ws)
      return parts.concat(cmdArgs)
    }
    if (bin === "ghostty") {
      if (ws) parts.push("--working-directory=" + ws)
      if (parts.indexOf("-e") === -1) parts.push("-e")
      return parts.concat(cmdArgs)
    }
    if (bin === "alacritty") {
      if (ws) parts.push("--working-directory", ws)
      if (parts.indexOf("-e") === -1) parts.push("-e")
      return parts.concat(cmdArgs)
    }
    if (parts.indexOf("-e") !== -1 || parts.indexOf("--") !== -1) {
      return parts.concat(cmdArgs)
    }
    return parts.concat(["-e"]).concat(cmdArgs)
  }

  function launchInTerminal(cmdArgs, workspacePath) {
    var argv = buildTerminalArgv(cmdArgs, workspacePath)
    Commons.Util.execArgv(argv)
  }

  function openSession(item) {
    if (!item || !item.id) return
    var agyCmd = [
      "sh", "-lc",
      "exec \"$(command -v agy || printf '%s' \"$HOME/.local/bin/agy\")\" \"$@\"",
      "agy", "--conversation", String(item.id)
    ]
    launchInTerminal(agyCmd, String(item.work_dir || ""))
  }

  function launchNewSession() {
    var agyCmd = [
      "sh", "-lc",
      "exec \"$(command -v agy || printf '%s' \"$HOME/.local/bin/agy\")\" \"$@\"",
      "agy"
    ]
    launchInTerminal(agyCmd, "")
  }

  function openAgysTui() {
    launchInTerminal(agysArgv([]), "")
  }

  function refresh(forceUsage) {
    var wantUsage = Boolean(forceUsage)
    if (stateProc.running) {
      _pendingRefresh = true
      _pendingForceUsage = _pendingForceUsage || wantUsage
      return
    }
    var args = ["--plugin-state"]
    if (wantUsage) {
      args.push("--refresh-usage")
      _lastUsageFetchMs = Date.now()
    }
    stateProc.command = agysArgv(args)
    stateProc.running = true
  }

  function refreshOnOpen() {
    var now = Date.now()
    nowMs = now
    var intervalMs = Math.max(10, refreshIntervalSec) * 1000
    var needUsage = quotaGroups.length === 0 || (now - _lastUsageFetchMs) >= intervalMs
    refresh(needUsage)
  }

  function runAction(actionName, targetId) {
    if (!actionName || !targetId || actionProc.running) return
    actionProc.command = agysArgv(["--action", String(actionName), "--id", String(targetId)])
    actionProc.running = true
  }

  function _applySnapshot(data) {
    if (!data || typeof data !== "object") return
    ready = Boolean(data.ready)
    errorText = ""
    usageError = String(data.usage_error || "")
    activeCount = Number(data.active_count || 0)
    activeStatus = String(data.active_status || "Idle")
    activeIds = Array.isArray(data.active_ids) ? data.active_ids : []

    var usage = data.usage || {}
    planTier = String(usage.plan_tier || "")
    quotaGroups = Array.isArray(usage.groups) ? usage.groups : []
    minRemainingPercent = (usage.min_remaining_percent !== undefined && usage.min_remaining_percent !== null)
      ? Number(usage.min_remaining_percent) : -1
    usageFetchedAt = String(usage.fetched_at || "")
    if (usageFetchedAt && _lastUsageFetchMs === 0) {
      var parsedFetch = Date.parse(usageFetchedAt)
      if (!isNaN(parsedFetch)) _lastUsageFetchMs = parsedFetch
    }

    pinnedSessions = Array.isArray(data.pinned) ? data.pinned : []
    recentSessions = Array.isArray(data.recent) ? data.recent : []
    archivedSessions = Array.isArray(data.archived) ? data.archived : []
    trashSessions = Array.isArray(data.trash) ? data.trash : []

    nowMs = Date.now()
    _checkQuotaAlerts(quotaGroups)
    snapshotUpdated()

    if (!_initialUsageFetchTriggered && quotaGroups.length === 0 && !usageError) {
      _initialUsageFetchTriggered = true
      refresh(true)
    }
  }

  function _checkQuotaAlerts(groups) {
    if (!enableQuotaAlerts || !groups || groups.length === undefined) return
    var now = Date.now()
    var cooldownMs = 2 * 3600 * 1000
    var threshold = Math.max(1, quotaAlertThreshold)
    var updated = false
    var nextMap = Object.assign({}, _alertCooldowns)

    for (var i = 0; i < groups.length; i++) {
      var group = groups[i]
      var groupName = String(group.name || "Antigravity")
      var buckets = (group.buckets && group.buckets.length !== undefined) ? group.buckets : []
      for (var j = 0; j < buckets.length; j++) {
        var bucket = buckets[j]
        var pct = Number(bucket.remaining_percent)
        if (isNaN(pct) || pct < 0) continue
        var bucketLabel = String(bucket.label || bucket.window || bucket.id || "Limit")
        var key = groupName + "::" + bucketLabel

        if (pct <= threshold) {
          var prevTs = Number(nextMap[key] || 0)
          if (now - prevTs >= cooldownMs) {
            nextMap[key] = now
            updated = true
            var title = t("alert.lowQuota.title", "Antigravity Quota Low")
            var body = t("alert.lowQuota.body", "%1 (%2) has %3% remaining")
              .arg(groupName)
              .arg(bucketLabel)
              .arg(String(pct))
            Commons.Util.execArgv(["omarchy-notification-send", title, body])
          }
        } else if (pct >= threshold + 5 && nextMap[key]) {
          delete nextMap[key]
          updated = true
        }
      }
    }
    if (updated) _alertCooldowns = nextMap
  }

  function formatDurationShort(totalSeconds) {
    var sec = Math.max(0, Math.floor(totalSeconds))
    if (sec < 60) return "1m"
    var days = Math.floor(sec / 86400)
    var hours = Math.floor((sec % 86400) / 3600)
    var mins = Math.floor((sec % 3600) / 60)
    if (days > 0) return days + "d" + (hours > 0 ? " " + hours + "h" : "")
    if (hours > 0) return hours + "h" + (mins > 0 ? " " + mins + "m" : "")
    return mins + "m"
  }

  function formatRelativeFromIso(isoStr, nowVal) {
    if (!isoStr) return ""
    var ts = Date.parse(isoStr)
    if (isNaN(ts)) return ""
    var diffSec = Math.max(0, Math.floor(((nowVal || nowMs) - ts) / 1000))
    if (diffSec < 45) return t("quota.updatedNow", "now")
    var dur = diffSec < 3600 ? Math.floor(diffSec / 60) + "m"
      : (diffSec < 86400 ? Math.floor(diffSec / 3600) + "h" : Math.floor(diffSec / 86400) + "d")
    return t("quota.updatedAgo", "%1 ago").arg(dur)
  }

  function formatResetLabel(resetIso, nowVal) {
    if (!resetIso) return ""
    var targetMs = Date.parse(resetIso)
    if (isNaN(targetMs)) return ""
    var diffSec = Math.floor((targetMs - (nowVal || nowMs)) / 1000)
    var d = new Date(targetMs)
    var clockStr = Qt.formatTime(d, "HH:mm")
    if (diffSec <= 30) {
      return t("quota.resetsSoon", "Resets soon") + (clockStr ? " · " + clockStr : "")
    }
    return t("quota.resetsIn", "Resets in %1").arg(formatDurationShort(diffSec)) + (clockStr ? " · " + clockStr : "")
  }

  function formatExitError(exitCode, errOutput, fallbackLabel) {
    if (exitCode === 127) {
      return root.t("error.missingBinary", "agys CLI not found in PATH or ~/.local/bin. Install it from github.com/Nox1KCL/Agys")
    }
    var errMsg = String(errOutput || "").trim()
    return errMsg || (fallbackLabel + " (" + exitCode + ")")
  }

  Process {
    id: stateProc
    stdout: StdioCollector { id: stateOut; waitForEnd: true }
    stderr: StdioCollector { id: stateErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.errorText = root.formatExitError(exitCode, stateErr.text, "agys exited with code")
      } else {
        var raw = String(stateOut.text || "").trim()
        if (raw) {
          try {
            root._applySnapshot(JSON.parse(raw))
          } catch (e) {
            root.errorText = String(e)
          }
        }
      }
      if (root._pendingRefresh) {
        var nextForce = root._pendingForceUsage
        root._pendingRefresh = false
        root._pendingForceUsage = false
        root.refresh(nextForce)
      }
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { id: actionOut; waitForEnd: true }
    stderr: StdioCollector { id: actionErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.errorText = root.formatExitError(exitCode, actionErr.text, "action failed")
      }
      root.refresh(false)
    }
  }

  Timer {
    id: pollTimer
    interval: (root.panelOpened || root.activeCount > 0)
      ? Math.min(4000, Math.max(10, root.refreshIntervalSec) * 1000)
      : Math.max(10, root.refreshIntervalSec) * 1000
    running: true
    repeat: true
    onTriggered: root.refresh(false)
  }

  Timer {
    id: usageTimer
    interval: Math.max(10, root.refreshIntervalSec) * 1000
    running: true
    repeat: true
    onTriggered: root.refresh(true)
  }

  Timer {
    id: clockTimer
    interval: 30000
    running: root.panelOpened
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  Component.onCompleted: refresh(false)
}
