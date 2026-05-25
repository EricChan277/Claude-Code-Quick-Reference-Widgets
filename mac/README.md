# Claude Usage — macOS Widget

Native macOS Notification Center widget showing live Claude Code session usage, weekly usage, context window, and your installed agents list with search and click-to-copy.

Two sizes: **V4 systemLarge** (338×338) and **V6 systemExtraLarge** (688×338). Both support light and dark mode automatically.

---

## Requirements

- macOS 14.0 Sonoma or later
- Xcode 15 or later
- A free Apple Developer account (for signing; no paid membership needed for personal use)

---

## Open and build

### Command-line (no Xcode GUI required)

The project uses ad-hoc signing (`-` identity, no developer team required). Run from the repo root:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project mac/ClaudeUsage/ClaudeUsage.xcodeproj \
             -scheme ClaudeUsage -configuration Debug \
             -destination 'platform=macOS' build
```

After a successful build, register the app so macOS recognises the widget extension:

```bash
APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/ClaudeUsage-*/Build/Products/Debug/ClaudeUsage.app | head -1)
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$APP"
# Confirm the widget is visible to WidgetKit:
pluginkit -m -p com.apple.widgetkit-extension | grep -i claude
```

### Xcode GUI

1. Open `mac/ClaudeUsage/ClaudeUsage.xcodeproj` in Xcode 15+.
2. Select the **ClaudeUsage** scheme and your Mac as the run destination.
3. No team configuration is needed — both targets are set to ad-hoc signing.
4. Build and run (`Cmd+R`). The host app window opens.

The host app is intentionally minimal. Its main job is to hold the widget extension and provide a Rescan button. The widget itself lives in Notification Center.

---

## Install the widget

1. Build and run the app at least once so macOS registers the widget extension.
2. Open Notification Center (click the clock in the menu bar, or swipe left from the right edge of the trackpad on a MacBook).
3. Scroll to the bottom of Notification Center and click **Edit Widgets**.
4. Search for **Claude Usage**. Drag the Large or Extra-Large tile onto the widget area.

---

## Data sources

The widget reads three local paths. No network calls are made.

| Path | What it contains | Writer |
|---|---|---|
| `~/.claude/usage.txt` | KEY=VALUE snapshot: `FIVEH_PCT`, `WEEK_ALL_PCT`, `CONTEXT_USED`, `CONTEXT_TOTAL`, `MODEL`, `UPDATED_EPOCH` | `~/.claude/statusline.sh` (Claude Code statusline hook) |
| `~/.claude/agents/*.md` | Installed sub-agents (one `.md` file per agent slug; optional `category:` front-matter) | You / `install-agents.sh` |
| `~/.claude/context.json` | Fallback context-window source if `usage.txt` omits `CONTEXT_USED`/`CONTEXT_TOTAL` | Optional statusline hook |

The widget polls all three paths every 60 seconds via `TimelineProvider`. `usage.txt` is treated as stale if `UPDATED_EPOCH` is more than 5 minutes old; in that case the session/weekly/context meters show `—` silently rather than rendering a stale value.

This is the same `usage.txt` contract used by the [Windows Rainmeter skin](../README.md) — install the statusline writer once and both widgets light up. Token tallying is no longer done locally; the statusline script is the single source of truth for rate-limit percentages.

### File access permissions

The widget extension runs in App Sandbox without app-group entitlements (ad-hoc signing precludes them). It uses `getpwuid()` to resolve the real home directory (the sandbox container path that `FileManager.homeDirectoryForCurrentUser` returns inside an extension is not where `~/.claude/` lives), then reads `~/.claude/` directly through a user-granted security-scoped bookmark.

If the widget shows "cannot read ~/.claude/", open the **Claude Usage** host app and click **Grant ~/.claude/ access** in Preferences. A file panel will open — navigate to your home directory's `.claude` folder and click Open. This grants the app sandbox the read permission it needs.

---

## Wiring up the statusline hook

The widget is a renderer; it does no math of its own. A statusline script must produce `~/.claude/usage.txt`. Claude Code already runs `~/.claude/statusline.sh` on every tick — extend it to emit the keys below (any subset works; missing keys just render as `—`):

```
FIVEH_PCT=42
WEEK_ALL_PCT=18
CONTEXT_USED=78231
CONTEXT_TOTAL=200000
MODEL=Sonnet 4.6
UPDATED_EPOCH=1748185600
```

The Windows side of this repo ships a reference PowerShell implementation (`~/.claude/statusline.ps1` mentioned in the root `CLAUDE.md`) that emits the same keys — a Mac/bash port follows the same contract. If only some keys are present, the widget renders the rows it can and dashes the rest.

If `CONTEXT_USED`/`CONTEXT_TOTAL` are not in `usage.txt`, the widget falls back to `~/.claude/context.json` (`{ "used_tokens": …, "total_tokens": …, "written_at": "ISO-8601" }`, stale after 120 s). Provide whichever is easier to wire into your hook.

---

## Installing agents

The agents panel reads `~/.claude/agents/*.md`. Each `.md` file is one agent; the filename without `.md` is the agent slug shown in the widget.

To populate agents, run the installer from the repo root:

```sh
bash windows/install-agents.sh
```

(The script works on macOS with bash despite living in `windows/`.)

Or place any `.md` file manually in `~/.claude/agents/`. The widget rescans on every 60-second tick. Use the **Rescan Agents Now** button in the host app to force an immediate refresh.

### Category front-matter

The widget groups agents by category. Specify a category in the agent's YAML front-matter:

```markdown
---
name: My Agent
category: AI & ML
---
Agent description here.
```

Valid categories (exact strings): `AI & ML`, `FRONTEND & UI`, `BACKEND & API`, `MOBILE & DESKTOP`, `LANGUAGES`, `QUALITY & SECURITY`, `OPS & PERFORMANCE`, `COORDINATION & PM`, `OTHER`.

If no `category` field is present, the widget falls back to a built-in slug-to-category mapping for the 40+ canonical agents.

---

## Preferences

Open the host app and press `Cmd+,` (or **ClaudeUsage > Settings**) to:

- Adjust the refresh interval (30s / 60s / 2 min).
- Check whether `context.json` is connected.
- Re-trigger the file-access grant panel.

---

## Architecture overview

```
TimelineProvider (60-second poll)
  ├── UsageScanner  → ~/.claude/usage.txt        (parses KEY=VALUE; 5-min stale check)
  │                 → ~/.claude/context.json     (fallback for CONTEXT_USED/TOTAL)
  └── AgentScanner  → ~/.claude/agents/*.md      (slug, category from YAML front-matter)

Paths.realHome   → getpwuid()-resolved $HOME (bypasses extension sandbox redirection)

AppIntents (interactive widget actions, macOS 14+ only)
  ├── CopyAgentIntent             – writes "@slug" to NSPasteboard, records lastCopied{Slug,At}
  ├── ClearSearchIntent           – clears committedQuery and reloads timelines
  ├── ToggleAgentsCollapseIntent  – toggles V4 agents panel collapse state
  └── SetSearchQueryIntent        – kept as a named type for stored-intent compatibility;
                                    only invoked from the host app, never from the widget

Host app (claudeusage:// URL handler)
  ├── claudeusage://search  →  SearchSheetView (real NSTextField; commits query on Enter/Done)
  └── claudeusage://grant   →  Settings → file-access bookmark panel

WidgetState  →  ~/.claude/widget-state.json   (JSON file, shared by host app + extension)
  ├── committedQuery    – last committed search string
  ├── agentsCollapsed   – V4 collapse/expand state
  ├── lastCopiedSlug    – for the 1.4-second "copied" affordance
  └── lastCopiedAt      – timestamp for auto-revert
```

### Why a JSON file instead of an app group

`UserDefaults(suiteName: "group.dev.claudewidget")` silently falls back to `.standard` under ad-hoc signing (the app-group entitlement requires a real Apple Developer team). That would split state between the host process and the extension process. `~/.claude/widget-state.json` sidesteps the entitlement entirely — both processes can read/write through normal sandbox file access, and the data lives next to the existing `usage.txt` the user already trusts.

### Why the search sheet lives in the host app

WidgetKit forbids `TextField` inside widget views on macOS 14+, so the spec's in-widget search bar was relocated. Tapping the search affordance fires a `Link(destination: URL(string: "claudeusage://search"))`, which opens the host app and presents `SearchSheetView` as a real native sheet. Committing a query writes `committedQuery` to `widget-state.json` and calls `WidgetCenter.shared.reloadTimelines(ofKind: "ClaudeUsage")`; the widget re-renders with the filter applied on the next timeline build. Clearing the query stays in-widget via `ClearSearchIntent` (no host app round-trip).

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Widget shows only dashes everywhere | Grant `~/.claude/` read access via host app Preferences, **or** verify `~/.claude/usage.txt` exists and `UPDATED_EPOCH` is fresh (under 5 minutes old). |
| Session/weekly rows show `—` | `usage.txt` is missing the `FIVEH_PCT` / `WEEK_ALL_PCT` keys, or `UPDATED_EPOCH` is stale. Check your statusline script. |
| Context row always shows `—` | Either add `CONTEXT_USED` and `CONTEXT_TOTAL` to `usage.txt`, or write `~/.claude/context.json` (stale after 120 s). |
| Agents section empty | Run `install-agents.sh` or place `.md` files in `~/.claude/agents/`. |
| Search button does nothing | The `claudeusage://` URL scheme isn't registered — quit the host app, run it once with `open ~/Applications/ClaudeUsage_test.app`, then retry. `lsregister -f` (see build instructions) usually fixes this. |
| Widget does not update | Click Rescan in the host app, or wait for the 60-second poll. |
| App icon shows as a generic placeholder in the Dock | Old build was copied before `Assets.xcassets` was added. Clean build (`Cmd+Shift+K`), rebuild, replace the `.app` in `~/Applications/`, then `killall Dock`. |
| Build error: no development team | Not required — the project uses ad-hoc (`-`) signing. No Apple Developer account needed. |
| Widget not visible in Notification Center | Quit and relaunch the host app, then re-add from Edit Widgets. |
