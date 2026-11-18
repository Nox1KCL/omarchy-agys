# Agys (`nox.agys`)

Compact native [Omarchy](https://omarchy.org/) shell bar plugin for **Google Antigravity CLI** sessions and live **Quota Limits**, powered by [`agys`](https://github.com/Nox1KCL/Agys).

## Features

- **Bar status indicator**: Theme-aligned Antigravity star with a glowing corner orb showing the active session count (pulsing when an agent is working).
- **Quota Limits**: Live model family limits, remaining percentages, and reset countdowns.
- **Paginated session lists**: Dedicated **Pinned** and **Recent** sections paginated cleanly at 5 items per page (`‹ 1 2 3 … ›`), plus **Archive** and **Trash** tabs.
- **One-click resume & hover actions**: Click any active/archived session to resume `agy --conversation <uuid>` in its project directory, or hover for `Pin`, `Archive`, `Move to Trash`, `Restore`, and `Delete permanently` (with inline confirmation).
- **Quick header launchers**: Start a new `agy` session (`+`), open the full `agys` TUI (`>_`), or refresh live state & quotas (`↻`).
- **Low-quota desktop alerts**: Sends desktop notifications via `omarchy-notification-send` when any bucket drops below the configured threshold.
- **Live Omarchy i18n**: Ships English and Ukrainian catalogs following Omarchy's language setting.

## Installation

### Step 1 — Install the `agys` CLI backend

This plugin queries sessions, presence locks, Trash, and cached quotas through the [`agys`](https://github.com/Nox1KCL/Agys) binary (`>= v0.1.0` with `--plugin-state` support). Install it via any of the options below:

```bash
# Option A: installer script (no sudo; installs to ~/.local/bin/agys)
curl -fsSL https://raw.githubusercontent.com/Nox1KCL/Agys/main/install.sh | bash

# Option B: Go toolchain
go install github.com/Nox1KCL/Agys/cmd/agys@latest
```

Or download `agys-linux-amd64` / `agys-linux-arm64` directly from [Agys Releases](https://github.com/Nox1KCL/Agys/releases/latest) and place it in `~/.local/bin/agys`.

### Step 2 — Add the plugin to Omarchy

```bash
omarchy plugin add https://github.com/Nox1KCL/omarchy-agys.git --enable
```

## Updating & Uninstalling

```bash
omarchy plugin update nox.agys
omarchy plugin remove nox.agys
```

## Settings

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `refreshIntervalSec` | integer (`10–1800`) | `60` | Quota refresh interval in seconds |
| `pageSize` | integer (`3–10`) | `5` | Number of sessions per page |
| `showBadge` | boolean | `true` | Show active session count inside the bar corner orb |
| `enableQuotaAlerts` | boolean | `true` | Notify via `omarchy-notification-send` on low quota |
| `quotaAlertThreshold` | integer (`5–50`) | `15` | Remaining percentage threshold for alerts |
| `terminalCommand` | string | `""` | Custom terminal command (empty uses `xdg-terminal-exec`) |
