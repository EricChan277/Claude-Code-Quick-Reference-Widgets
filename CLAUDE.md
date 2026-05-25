# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Rainmeter desktop widget for Windows that displays live Claude Code usage (session/weekly
rate limits, context window, installed agents). A macOS equivalent is planned under `mac/`.
The skin makes **no network calls** — it renders a local file written by the user's Claude
Code statusline script.

## Critical: the repo is also the live skin

This git repository lives at `…\Documents\Rainmeter\Skins\ClaudeUsage\`, which is simultaneously
the installed Rainmeter skin. Consequences:

- `ClaudeUsage.ini` and `@Resources/` **must stay at the repo root** — Rainmeter loads
  `Skins\ClaudeUsage\ClaudeUsage.ini` and will break if they move into a subfolder.
- Editing the root files edits the live widget. After changing `ClaudeUsage.ini` or
  `usage.lua`, refresh the skin to see changes (right-click the widget → Refresh, or refresh
  via the Rainmeter Manager). There is no build/compile step for the skin itself.
- `@Resources/usage.txt` and `@Resources/agents.txt` are runtime-generated and gitignored.
  `usage.txt` is written by an external `~/.claude/statusline.ps1`; do not commit or hand-edit
  it as source.

## Architecture

Data flows one direction, refreshed every 1000 ms:

```
~/.claude/statusline.ps1  (external, not in this repo)
   ↓ writes flat KEY=VALUE
@Resources/usage.txt  +  @Resources/agents.txt
   ↓ readKV() / loadAgents()
usage.lua  Update()  → computes countdowns, colors, agent column split → vals{} table
   ↓ [&MeasureData:Func()] references
ClaudeUsage.ini  meters
```

- **`usage.lua`** is the engine. `Update()` runs every tick, reparses both data files into the
  `vals` table, and derives everything (reset countdowns from stored Unix epochs vs `os.time()`,
  bar colors, two-column agent layout). INI meters pull values through exposed functions:
  `GetStr(k)`, `GetPct(k)`, `BarW(key,w)`, `Chevron()`, `ToggleAgents()`.
- **The Lua↔INI bridge** is Rainmeter's `[&MeasureData:Function()]` inline syntax. To surface a
  new value: write `KEY=value` from the statusline script → read `vals['KEY']` in Lua → reference
  it from a meter via `GetStr('KEY')` or a new exposed function.
- **Naming aliases:** the statusline writes `FIVEH_*`/`SEVEND_*`; `Update()` aliases these to the
  meter-facing `SESSION_*`/`WEEK_ALL_*` names. Keep that in mind when tracing a value end-to-end.
- **Color thresholds** live in `pctColor()`: green <50%, amber 50–79%, red ≥80%.
- **Collapsible agents panel:** `AgentsOpen` (0/1) drives panel height by interpolating
  `CollapseH`↔`ExpandH` in the `MeterBackground` shape. `ToggleAgents()` persists the value with
  `!WriteKeyValue` so it survives reloads. `agents.txt` lines are `CATEGORY|agent-name`; Lua groups
  by category (preserving file order) and greedily balances them into two columns by line count.

## Installers

Two paths, both in `windows/`. Both source the skin **from the repo root** (not a copy) and
exclude runtime files (`usage.txt`, `agents.txt`):

- **`install.ps1`** (launched by `install.bat`) — installs directly from a clone. Reads
  `SkinPath` from `%APPDATA%\Rainmeter\Rainmeter.ini` (falls back to `Documents\Rainmeter\Skins`),
  copies `ClaudeUsage.ini` + `@Resources\usage.lua` into `<SkinPath>\ClaudeUsage\`, then loads
  the skin via `Rainmeter.exe !ActivateConfig` / `!Refresh`. If source and destination resolve
  to the same path (the dev setup where this repo *is* the installed skin), it skips the copy
  and just activates. Ends on a `Read-Host` so the double-clicked window stays open — that will
  hang under a non-interactive host.

  ```powershell
  powershell -ExecutionPolicy Bypass -File windows/install.ps1
  ```

- **`build-rmskin.ps1`** — packages a distributable `windows/ClaudeUsage-<version>.rmskin`
  (gitignored): stages files under `Skins\ClaudeUsage\` with a generated `RMSKIN.ini` and zips.
  Pass `-Version` to override the version string.

  ```powershell
  powershell -ExecutionPolicy Bypass -File windows/build-rmskin.ps1
  ```

## Repo layout

- Root: the live skin (`ClaudeUsage.ini`, `@Resources/`) plus `README.md`, `LICENSE`.
- `windows/`: platform tooling — `build-rmskin.ps1`, `install-agents.sh` (interactive Bash
  installer that populates `agents.txt` from VoltAgent/awesome-claude-code-subagents),
  `ARCHITECTURE.md` (deeper technical reference), `screenshots/`.
- `mac/`: placeholder for the planned macOS widget.
