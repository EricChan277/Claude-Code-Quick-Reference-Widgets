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

1. Open `mac/ClaudeUsage/ClaudeUsage.xcodeproj` in Xcode 15+.
2. Select the **ClaudeUsage** scheme and your Mac as the run destination.
3. Set your development team in both targets:
   - Select the project in the navigator, choose the **ClaudeUsage** target, open Signing & Capabilities, and pick your Team.
   - Repeat for the **ClaudeUsageWidgetExtension** target.
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

| Path | What it contains |
|---|---|
| `~/.claude/projects/**/*.jsonl` | Claude Code conversation history (token counts, timestamps, model name) |
| `~/.claude/agents/*.md` | Installed sub-agents (one `.md` file per agent slug) |
| `~/.claude/context.json` | Current context window usage (written by your statusline hook) |

The widget polls all three paths every 60 seconds via `TimelineProvider`.

### File access permissions

If the widget shows "cannot read ~/.claude/", open the **Claude Usage** host app and click **Grant ~/.claude/ access** in Preferences. A file panel will open — navigate to your home directory's `.claude` folder and click Open. This grants the app sandbox the read permission it needs.

---

## Wiring up context.json (statusline hook)

The context window meter (`— / 200k tokens`) requires a writer. Claude Code exposes current context usage via its statusline hook system.

Add the snippet below to your Claude Code statusline configuration (wherever you currently run the statusline hook — `~/.zshrc`, a custom script sourced by Claude Code's hook, etc.):

```sh
#!/usr/bin/env bash
# claude-context-writer.sh
# Paste this into your Claude Code statusline hook.
# It writes ~/.claude/context.json each time the statusline refreshes.

CONTEXT_FILE="$HOME/.claude/context.json"

# Adjust these variable names to match what your statusline script exposes.
USED="${CLAUDE_CONTEXT_USED:-0}"
TOTAL="${CLAUDE_CONTEXT_TOTAL:-200000}"
MODEL="${CLAUDE_MODEL:-claude-sonnet-4-6}"

cat > "$CONTEXT_FILE" <<EOF
{
  "schema": 1,
  "used_tokens": $USED,
  "total_tokens": $TOTAL,
  "model": "$MODEL",
  "written_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
```

The widget treats the file as stale if `written_at` is more than 120 seconds old. A missing or stale file causes the context row to show `—` silently — no error state, by design — so users who have not installed the hook see a clean widget rather than an error.

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
  ├── UsageScanner  → ~/.claude/projects/**/*.jsonl  (session + weekly tokens, sparkline)
  ├── AgentScanner  → ~/.claude/agents/*.md           (slug, category)
  └── UsageScanner.readContext() → ~/.claude/context.json

AppIntents (interactive widget actions, macOS 14+ only)
  ├── CopyAgentIntent           – writes "@slug" to NSPasteboard
  ├── SetSearchQueryIntent      – persists debounced query to app-group UserDefaults
  └── ToggleAgentsCollapseIntent – toggles the V4 agents panel

Shared UserDefaults  (app group: group.dev.claudewidget)
  ├── committedQuery    – last debounced search string (survives 60s reloads)
  ├── agentsCollapsed   – V4 collapse/expand state
  ├── lastCopiedSlug    – for the 1.4-second "copied" affordance
  └── lastCopiedAt      – timestamp for auto-revert
```

Search is local-only per keystroke (`@State var queryDraft` in the view). The `SetSearchQueryIntent` fires only after a 250 ms typing pause to avoid WidgetKit rate-limit issues. Between keystrokes and the committed reload, the matched/total header count may lag by up to 250 ms — this is intentional. See the design spec at `../claude-usage-widget-review/design_handoff_mac_widget/README.md` § Interactions → Search for full rationale.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Widget shows only dashes everywhere | Grant `~/.claude/` read access via host app Preferences |
| Context row always shows `—` | Install the statusline hook; verify `~/.claude/context.json` exists and is being updated |
| Agents section empty | Run `install-agents.sh` or place `.md` files in `~/.claude/agents/` |
| Widget does not update | Click Rescan in the host app, or wait for the 60-second poll |
| Build error: no development team | Set your Apple ID team in Xcode Signing & Capabilities for both targets |
| Widget not visible in Notification Center | Quit and relaunch the host app, then re-add from Edit Widgets |
