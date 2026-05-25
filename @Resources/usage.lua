-- ClaudeUsage skin logic
-- Reads a single flat key=value file:
--   usage.txt  (model, context window, five_hour + seven_day rate limits, agents)
--   written by ~/.claude/statusline.ps1 on every Claude Code statusline render.
-- Computes live reset countdowns from the resets_at epochs vs os.time() (tz-safe),
-- and builds the grouped, two-column agents list (collapsible via the AgentsOpen var).

function Initialize()
    DataFile   = SKIN:GetVariable('DataFile')
    AgentsFile = SKIN:GetVariable('AgentsFile')
    vals = {}
end

local function readKV(path, t)
    local f = io.open(path, 'r')
    if not f then return end
    for line in f:lines() do
        line = line:gsub('\r', ''):gsub('^\239\187\191', '')
        local k, v = line:match('^([%w_]+)=(.*)$')
        if k then t[k] = v end
    end
    f:close()
end

function Update()
    vals = {}
    readKV(DataFile, vals)      -- usage.txt (the only data source)

    -- statusline exposes five_hour + seven_day; alias to the meters' names
    vals['SESSION_PCT']    = vals['FIVEH_PCT']
    vals['SESSION_RESET']  = vals['FIVEH_RESET']
    vals['WEEK_ALL_PCT']   = vals['SEVEND_PCT']
    vals['WEEK_ALL_RESET'] = vals['SEVEND_RESET']

    local now = os.time()

    -- reset countdowns for the two live limits
    vals['SESSION_CD']  = countdown(vals['SESSION_RESET'], now)
    vals['WEEK_ALL_CD'] = countdown(vals['WEEK_ALL_RESET'], now)

    -- actual wall-clock time each limit resets at (shown after the countdown)
    vals['SESSION_AT']  = resetClock(vals['SESSION_RESET'], now)
    vals['WEEK_ALL_AT'] = resetFull(vals['WEEK_ALL_RESET'])

    -- bar colors
    for _, p in ipairs({ 'SESSION', 'WEEK_ALL', 'CTX' }) do
        vals[p .. '_COLOR'] = pctColor(vals[p .. '_PCT'])
    end

    vals['CTX_LABEL'] = fmtTokens(vals['CTX_IN']) .. ' / ' .. fmtTokens(vals['CTX_SIZE'])

    -- freshness: usage.txt UPDATED advances on every statusline render while CC is open
    local upd = tonumber(vals['UPDATED'])
    vals['LIMITS_AGE'] = upd and ('updated ' .. ageStr(now - upd)) or 'no data'

    loadAgents()
    return 0
end

-- Chevron: reflects the live AgentsOpen skin variable
function Chevron()
    local open = SKIN:GetVariable('AgentsOpen', '1')
    if tostring(open) == '1' then return '[-]' else return '[+]' end
end

-- Toggle the agents section open/closed; persists a clean 0/1 and redraws.
function ToggleAgents()
    local open = tonumber(SKIN:GetVariable('AgentsOpen', '1')) or 1
    local nv = (open == 1) and 0 or 1
    SKIN:Bang('!SetVariable', 'AgentsOpen', tostring(nv))
    SKIN:Bang('!WriteKeyValue', 'Variables', 'AgentsOpen', tostring(nv))
    SKIN:Bang('!UpdateMeterGroup', 'Agents')
    SKIN:Bang('!UpdateMeterGroup', 'AgentsToggle')
    SKIN:Bang('!UpdateMeter', 'MeterBackground')
    SKIN:Bang('!Redraw')
end

-- short category labels for the flat search-results view
local SHORT_CAT = {
    ['AI & ML']            = 'AI/ML',
    ['Frontend & UI']      = 'FRONTEND',
    ['Backend & API']      = 'BACKEND',
    ['Mobile & Desktop']   = 'MOBILE',
    ['Languages']          = 'LANG',
    ['Quality & Security'] = 'QUALITY',
    ['Ops & Performance']  = 'OPS',
    ['Coordination & PM']  = 'COORD',
    ['Other']              = 'OTHER',
}

-- current, trimmed search query from the SearchQuery skin variable ('' = no filter)
local function searchQuery()
    local q = SKIN:GetVariable('SearchQuery', '') or ''
    return (q:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function agentsOpen()
    return tostring(SKIN:GetVariable('AgentsOpen', '1')) == '1'
end

-- read agents.txt ("CATEGORY|name" per line), group preserving category order,
-- then render either the categorical two-column view or, when a search query is
-- active, a flat list of case-insensitive substring matches.
function loadAgents()
    local order, byCat, count = {}, {}, 0
    local f = io.open(AgentsFile, 'r')
    if f then
        for line in f:lines() do
            line = line:gsub('\r', ''):gsub('^\239\187\191', '')
            local cat, name = line:match('^(.-)|(.+)$')
            if cat and name then
                if not byCat[cat] then byCat[cat] = {}; order[#order + 1] = cat end
                table.insert(byCat[cat], name)
                count = count + 1
            end
        end
        f:close()
    end

    local query = searchQuery()
    if query ~= '' then
        buildSearchView(order, byCat, count, query)
    else
        buildCategoryView(order, byCat, count)
    end
end

-- default view: whole categories split into two balanced columns (greedy by line count)
function buildCategoryView(order, byCat, count)
    vals['AGENTS_COUNT'] = tostring(count)

    -- render lines per category = 1 header + N agents, with a blank gap between groups
    local total = count + #order
    local half = math.ceil(total / 2)
    local colA, colB, running = {}, {}, 0
    for _, cat in ipairs(order) do
        local target = (running < half) and colA or colB
        if #target > 0 then target[#target + 1] = '' end   -- blank gap between groups in a column
        target[#target + 1] = string.upper(cat)
        for _, n in ipairs(byCat[cat]) do target[#target + 1] = '  ' .. n end
        running = running + 1 + #byCat[cat]
    end
    vals['AGENTS_L'] = table.concat(colA, '\n')
    vals['AGENTS_R'] = table.concat(colB, '\n')
end

-- search view: flat list of matches (ordered by category, then file order),
-- balanced across the two columns; header count shows "matched/total".
function buildSearchView(order, byCat, count, query)
    local needle = query:lower()
    local matches = {}
    for _, cat in ipairs(order) do
        for _, n in ipairs(byCat[cat]) do
            if n:lower():find(needle, 1, true) then
                matches[#matches + 1] = '  ' .. n .. '   ' .. (SHORT_CAT[cat] or cat)
            end
        end
    end
    vals['AGENTS_COUNT'] = #matches .. '/' .. count

    if #matches == 0 then
        vals['AGENTS_L'] = '  no agents match "' .. query .. '"'
        vals['AGENTS_R'] = ''
        return
    end

    local half = math.ceil(#matches / 2)
    local colA, colB = {}, {}
    for i, line in ipairs(matches) do
        if i <= half then colA[#colA + 1] = line else colB[#colB + 1] = line end
    end
    vals['AGENTS_L'] = table.concat(colA, '\n')
    vals['AGENTS_R'] = table.concat(colB, '\n')
end

-- re-filter immediately (called from the InputText / clear bangs so the list
-- updates on the keystroke instead of waiting up to a full Update() tick)
function ApplySearch()
    loadAgents()
    SKIN:Bang('!UpdateMeterGroup', 'Agents')
    SKIN:Bang('!UpdateMeterGroup', 'AgentsToggle')
    SKIN:Bang('!Redraw')
end

-- The search field's placeholder, query text, and clear button are three
-- overlapping meters; these drive their Hidden flags (1 = hidden). All three
-- hide when the agents panel is collapsed.
function PlaceholderHidden()
    if not agentsOpen() then return '1' end
    return (searchQuery() == '') and '0' or '1'
end

function SearchTextHidden()
    if not agentsOpen() then return '1' end
    return (searchQuery() == '') and '1' or '0'
end

function ClearHidden()
    return SearchTextHidden()
end

-- the typed query, for the active-query text meter
function SearchText()
    return searchQuery()
end

function countdown(epochStr, now)
    local e = tonumber(epochStr)
    if not e then return '--' end
    local s = e - now
    if s <= 0 then return 'ready now' end
    local d = math.floor(s / 86400)
    local h = math.floor((s % 86400) / 3600)
    local m = math.floor((s % 3600) / 60)
    if d > 0 then return string.format('%dd %dh', d, h)
    elseif h > 0 then return string.format('%dh %02dm', h, m)
    else return string.format('%dm', m) end
end

-- wall-clock time the reset lands at, e.g. "11:00 PM" today or "Tue 4:30 PM" later
function resetClock(epochStr, now)
    local e = tonumber(epochStr)
    if not e then return '--' end
    local hr   = tonumber(os.date('%I', e))      -- drop the leading zero off the hour
    local time = hr .. os.date(':%M %p', e)
    if os.date('%Y%j', e) == os.date('%Y%j', now) then
        return time                               -- same calendar day: time only
    else
        return os.date('%a ', e) .. time          -- another day: prefix weekday
    end
end

-- full reset stamp for the weekly limit, e.g. "9:00 PM, Sunday, 05/25/2026"
function resetFull(epochStr)
    local e = tonumber(epochStr)
    if not e then return '--' end
    local hr = tonumber(os.date('%I', e))          -- drop the leading zero off the hour
    return hr .. os.date(':%M %p, %A, %m/%d/%Y', e)
end

function ageStr(s)
    if s < 0 then s = 0 end
    if s < 60 then return math.floor(s) .. 's ago'
    elseif s < 3600 then return math.floor(s / 60) .. 'm ago'
    elseif s < 86400 then return math.floor(s / 3600) .. 'h ago'
    else return math.floor(s / 86400) .. 'd ago' end
end

function fmtTokens(v)
    local n = tonumber(v)
    if not n then return '--' end
    if n >= 1000000 then return string.format('%.1fM', n / 1000000)
    elseif n >= 1000 then return string.format('%.0fk', n / 1000)
    else return tostring(math.floor(n)) end
end

function pctColor(p)
    local n = tonumber(p) or 0
    if n >= 80 then return '232,90,82,255'
    elseif n >= 50 then return '230,170,70,255'
    else return '120,200,140,255' end
end

function BarW(key, w)
    local n = tonumber(vals[key .. '_PCT']) or 0
    if n < 0 then n = 0 elseif n > 100 then n = 100 end
    return math.floor(n / 100 * w)
end

function GetStr(k)
    local v = vals[k]
    if v == nil or v == '' then return '--' end
    return tostring(v)
end

function GetPct(k)
    local v = vals[k]
    if v == nil or v == '' then return '--' end
    return tostring(v) .. '%'
end
