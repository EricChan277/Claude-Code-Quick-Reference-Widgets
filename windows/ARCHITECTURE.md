# Claude Usage Rainmeter Skin — Technical Overview (v3.0)

## Overview

**Claude Usage** is a minimal, data-driven Rainmeter skin that displays live Claude Code usage metrics and a collapsible agent registry. The skin reads a single flat key-value file (`usage.txt`) written externally by a PowerShell statusline script, processes it with Lua logic, and renders the results through a responsive INI interface. All computation happens locally—no remote API calls.

**Key characteristics:**
- Single data source: `@Resources/usage.txt` (refreshed every ~1 second)
- Metric-to-INI bridge: Lua script exposes computed values via `[&MeasureData:Function()]` syntax
- Dynamic layout: Agent section collapses/expands, resizing the panel height
- Color-coded utilization: Green (< 50%), amber (50–79%), red (≥ 80%)

---

## Architecture

### Files

**ClaudeUsage.ini** — Main skin definition (286 lines)
- Update cycle: 1000 ms
- Single Script measure (`MeasureData`) running `usage.lua`
- Meters grouped into sections: header, three limit blocks (SESSION / WEEK_ALL / CTX), divider, agents section
- Dynamic window height: `AgentsOpen` variable interpolates between `CollapseH` (242px) and `ExpandH` (696px)
- Color palette defined as variables (`cText`, `cDim`, `cAgent`, `cAccent`, `cTrack`)

**@Resources/usage.lua** — Computation engine (186 lines)
- Single entry point: `Update()` called every 1000 ms
- Reads `usage.txt` via custom `readKV()` parser (handles BOM, carriage returns)
- Computes: reset countdowns, wall-clock reset times, bar widths, agent column split
- Exposes functions: `GetStr(k)`, `GetPct(k)`, `BarW(key, w)`, `Chevron()`, `ToggleAgents()`

**@Resources/usage.txt** — Runtime data (read-only in skin)
- Written externally by `~/.claude/statusline.ps1`
- Key data: `MODEL`, `SESSION` (task description), `COST`, `CTX_PCT` / `CTX_IN` / `CTX_SIZE`, `FIVEH_PCT` / `FIVEH_RESET`, `SEVEND_PCT` / `SEVEND_RESET`, `TODAY_TOKENS`, `UPDATED` (Unix epoch)
- No dependencies on network—data originates from Claude Code's local runtime state

**@Resources/agents.txt** — Agent registry
- Format: `CATEGORY|agent-name` (one per line)
- Read at every update to pick up dynamic changes
- Populated externally (install-agents.sh, or manual edit)

---

## Data Flow

```
usage.txt (external writer)
    ↓
readKV() parser
    ↓
Update() logic (compute countdowns, colors, split agents)
    ↓
vals table (in-memory)
    ↓
GetStr(k) / GetPct(k) / BarW() / Chevron()
    ↓
INI meters via [&MeasureData:FunctionName()]
```

### Key Computations

**Reset countdown** (`countdown(epochStr, now)`)
- Subtracts `os.time()` from reset epoch
- Formats as `1d 4h`, `5h 30m`, or `45m`; returns `ready now` if time has passed

**Reset wall-clock time** (`resetClock()` for session, `resetFull()` for weekly)
- Session: time only if same day (`11:00 PM`), otherwise weekday + time (`Tue 4:30 PM`)
- Weekly: full format (`9:00 PM, Sunday, 05/25/2026`)

**Bar width** (`BarW(key, w)`)
- Reads `vals[key .. '_PCT']`, clamps 0–100
- Returns `math.floor(pct / 100 * barWidth)` pixels

**Color mapping** (`pctColor(p)`)
- `< 50%` → green (120, 200, 140, 255)
- `50–79%` → amber (230, 170, 70, 255)
- `≥ 80%` → red (232, 90, 82, 255)

---

## Agent Column Balancing

The `loadAgents()` function preserves category order while splitting entries into two balanced columns:

1. **Read & group:** Parse `agents.txt` line-by-line; for each `CATEGORY|name`, append to `byCat[cat]` and record category order
2. **Calculate split point:** `half = ceil((agent_count + category_count) / 2)` lines total
3. **Greedy assignment:** Iterate categories in order; if running line count < half, assign to column A; else column B
4. Each category gets a header (uppercase) + indented agent names, separated by blank lines

**Example:**
```
Agents.txt (12 items, 3 categories):
  FRONTEND|dev
  FRONTEND|designer
  BACKEND|api
  BACKEND|db
  ML|train
  ML|eval

Total lines: 3 (headers) + 5 (items) = 8; half = 4
Column A (running: 0→3): FRONTEND (3 lines)
Column B (running: 3→7): BACKEND + ML (4 lines)
```

This keeps related agents visually grouped even when split across columns.

---

## Adding a New Limit Section

To add a fourth limit (e.g., `MONTHLY`):

1. **Update `usage.txt` writer** (statusline.ps1): Add keys `MONTHLY_PCT` and `MONTHLY_RESET` (epoch)
2. **Add alias in `usage.lua` Update():**
   ```lua
   vals['MONTHLY_PCT']   = vals['MONTHLY_PCT']
   vals['MONTHLY_RESET'] = vals['MONTHLY_RESET']
   vals['MONTHLY_CD'] = countdown(vals['MONTHLY_RESET'], now)
   vals['MONTHLY_AT'] = resetFull(vals['MONTHLY_RESET'])
   vals['MONTHLY_COLOR'] = pctColor(vals['MONTHLY_PCT'])
   ```
3. **Copy meter block in ClaudeUsage.ini:** Duplicate the SESSION block (MeterMonthlyLabel, MeterMonthlyPct, MeterMonthlyTrack, MeterMonthlyFill, MeterMonthlyReset), adjust Y positions
4. **Update MeterBackground shape:** Adjust computations or add offset to accommodate new section

---

## Customization Guide

### Changing Color Thresholds

Edit `pctColor()` in `usage.lua`:
```lua
function pctColor(p)
    local n = tonumber(p) or 0
    if n >= 80 then return '232,90,82,255'      -- red
    elseif n >= 50 then return '230,170,70,255' -- amber
    else return '120,200,140,255' end            -- green
end
```

Modify thresholds (50, 80) and RGB values. Colors are RGBA (0–255).

### Adding a New Data Key

1. **External writer** (statusline.ps1): Output `KEY=value` to `usage.txt`
2. **Lua script** `usage.lua`: Access via `vals['KEY']` in `Update()` or helper functions
3. **Expose to INI:** Call `GetStr('KEY')` or wrap in a new function:
   ```lua
   function MyNewValue()
       return fmtTokens(vals['MY_KEY'])
   end
   ```
4. **INI meter:** Reference as `[&MeasureData:MyNewValue()]`

### Persisting Agent Toggle State

The `ToggleAgents()` function uses Rainmeter's `!WriteKeyValue` bang to persist the `AgentsOpen` variable across restarts:
```lua
SKIN:Bang('!WriteKeyValue', 'Variables', 'AgentsOpen', tostring(nv))
```

This writes to the INI file itself. On restart, Rainmeter loads the saved value.

---

## Event Handling

**Agent toggle (MeterAgentsHeader click):**
- Calls `ToggleAgents()`
- Updates `AgentsOpen` skin variable and INI
- Bangs `!UpdateMeterGroup 'Agents'` to show/hide `MeterAgentsLeft` / `MeterAgentsRight`
- Bangs `!UpdateMeter 'MeterBackground'` to recalculate height
- Redraws the skin

This is the only user interaction in the skin.

---

## Debugging

**No data displayed?**
- Verify `usage.txt` exists and has correct keys
- Check `DataFile` variable in INI points to `#@#usage.txt`
- Confirm `MeasureData` script measure is enabled

**Wrong colors or percentages?**
- Verify `usage.txt` contains `*_PCT` and `*_RESET` keys with valid numbers
- Check `pctColor()` logic in Lua
- Use Rainmeter's Log feature to inspect `vals` table

**Agents list empty?**
- Verify `agents.txt` exists and has lines in `CATEGORY|name` format
- Ensure no invisible BOM or trailing spaces breaking the regex

---

## Summary

Claude Usage couples a minimal INI interface with a focused Lua engine, enabling live metric display and agent registry in a single, collapsible panel. The architecture favors simplicity: a single data source, clear function responsibilities, and Rainmeter-native state persistence. Extending the skin requires only copying meter blocks and adding corresponding Lua calculations.
