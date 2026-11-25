-- ClickLinks 2.3.0: account-wide journal, no passive capture.
ClickLinks = ClickLinks or {}
local J = {}
local readyDB, readyEntries
local DUPLICATE_REPAIR_VERSION = 1
ClickLinks.Journal = J
local function now() return (type(time) == "function" and time()) or 0 end
local function trim(s) return s:match("^%s*(.-)%s*$") end
local function hostOf(url)
    local authority = url:match("^https?://([^/%?#]+)") or url:match("^([^/%?#]+)")
    if not authority then return nil end
    authority = authority:match("^[^@]*@(.+)$") or authority
    local host = authority:match("^([^:]+)") or authority
    return host:lower()
end
local function validHost(host)
    if type(host) ~= "string" or #host == 0 or #host > 253 then return false end
    if host:find("%.%.", 1, false) or host:sub(1,1) == "." or host:sub(-1) == "." then return false end
    for label in host:gmatch("[^.]+") do
        if #label > 63 or not label:match("^[%w][%w%-]*[%w]$") and not label:match("^%w$") then return false end
    end
    return true
end
local function validPort(port)
    return port == "" or (tonumber(port) ~= nil and tonumber(port) >= 1 and tonumber(port) <= 65535)
end
local function normalise(raw)
    if type(raw) ~= "string" then return nil, "invalid_type" end
    local ok, value = pcall(function() return trim(raw) end)
    if not ok then return nil, "protected_value" end
    if #value == 0 or #value > 2048 or value:find("[%c|]") then return nil, "invalid_url" end
    if value:match("^[^%s@]+@[%w%.%-]+%.[%a]+$") then return value:lower() end
    local scheme, rest = value:match("^(%a[%w+.-]*)://(.+)$")
    if scheme then
        scheme = scheme:lower()
        if scheme ~= "http" and scheme ~= "https" then return nil, "unsupported_scheme" end
        local authority, tail = rest:match("^([^/%?#]+)(.*)$")
        if not authority then return nil, "invalid_host" end
        local host, port = authority:match("^([%w%.%-]+):?(%d*)$")
        if not host or not validHost(host) or authority:sub(-1) == ":" then return nil, "invalid_host" end
        if not validPort(port) then return nil, "invalid_port" end
        if (scheme == "http" and port == "80") or (scheme == "https" and port == "443") then port = "" end
        value = scheme .. "://" .. host:lower() .. (port ~= "" and ":" .. port or "") .. tail
    else
        local authority, tail = value:match("^([^/%?#]+)(.*)$")
        if not authority or not authority:match("^[%w%.%-]+:?%d*$") then return nil, "invalid_host" end
        local h, p = authority:match("^([%w%.%-]+):?(%d*)$")
        if not h or not validHost(h) or authority:sub(-1) == ":" or not h:find("%.") then return nil, "invalid_host" end
        if not validPort(p) then return nil, "invalid_port" end
        value = h:lower() .. (p ~= "" and ":" .. p or "") .. tail
    end
    return value
end
J.Normalize = normalise
J.Host = hostOf
local function category(url)
    local host = hostOf(url) or ""
    if host == "wowhead.com" or host:match("%.wowhead%.com$") then return "wowhead" end
    if host == "discord.gg" or host == "discord.com" or host:match("%.discord%.com$") then return "discord" end
    return "websites"
end
local function copy(v, seen)
    if type(v) ~= "table" then return v end
    seen = seen or {}
    if seen[v] then return seen[v] end
    local t = {}; seen[v] = t
    for k,x in pairs(v) do t[copy(k,seen)] = copy(x,seen) end
    return t
end
local function rebuild()
    J.index = {}
    J.entriesById = {}
    local db = ClickLinksDB
    for i,e in ipairs(db.journal.entries) do
        if type(e) == "table" then
            local key = normalise(e.url)
            if key and key == e.normalizedUrl then J.index[key] = i end
            if type(e.id) == "number" then J.entriesById[e.id] = e end
        end
    end
end

-- Repair old normalization keys and merge only exact canonical URL matches.
-- Keep the first stored entry's ID and metadata when both entries have values.
local function repairJournal(db)
    local journal = db.journal
    local entries = journal.entries
    local kept, byKey, remap = {}, {}, {}
    local changed = false
    local function beforeChange()
        if not changed then
            -- Latest pre-repair snapshot, written only when repair changes data.
            db.journalRepairBackup = copy({
                journal=journal, copyHistory=db.copyHistory, time=now()
            })
            changed = true
        end
    end
    local function earlier(a,b)
        a,b=tonumber(a),tonumber(b)
        if a and b then return math.min(a,b) end
        return a or b
    end
    local function later(a,b)
        a,b=tonumber(a),tonumber(b)
        if a and b then return math.max(a,b) end
        return a or b
    end
    for _,e in ipairs(entries) do
        local key = type(e) == "table" and normalise(e.url)
        if key and type(e.id) == "number" then
            local first = byKey[key]
            if first then
                beforeChange()
                if e.id ~= first.id then remap[e.id] = first.id end
                first.firstSeen=earlier(first.firstSeen,e.firstSeen)
                first.lastSeen=later(first.lastSeen,e.lastSeen)
                first.lastCopied=later(first.lastCopied,e.lastCopied)
                first.seenCount=(tonumber(first.seenCount) or 1)+(tonumber(e.seenCount) or 1)
                first.copyCount=(tonumber(first.copyCount) or 0)+(tonumber(e.copyCount) or 0)
                first.favorite=not not (first.favorite or e.favorite)
                first.pinned=not not (first.pinned or e.pinned)
                for k,v in pairs(e) do
                    if first[k] == nil and k ~= "id" then first[k] = v end
                end
            else
                if e.normalizedUrl ~= key then
                    beforeChange()
                    e.normalizedUrl = key
                    e.category = category(key)
                end
                byKey[key] = e
                kept[#kept+1] = e
            end
        else
            -- Leave unrecognized records untouched; do not guess a URL.
            kept[#kept+1] = e
        end
    end
    if not changed then return false end
    journal.entries = kept
    local validIds, seen, history = {}, {}, {}
    for _,e in ipairs(kept) do
        if type(e) == "table" and type(e.id) == "number" then validIds[e.id] = true end
    end
    for _,id in ipairs(db.copyHistory) do
        id = remap[id] or id
        if validIds[id] and not seen[id] then
            history[#history+1] = id
            seen[id] = true
        end
    end
    db.copyHistory = history
    return true
end
function J.Initialize(forceRepair)
    ClickLinksDB = type(ClickLinksDB) == "table" and ClickLinksDB or {}
    local db = ClickLinksDB
    if db.schemaVersion ~= nil and db.schemaVersion ~= 3 then return nil, "unsupported_schema" end
    if db.schemaVersion ~= 3 then
        local old = type(db.journal) == "table" and db.journal or {}
        local backup = copy(old)
        local entries, lookup, nextId = {}, {}, 1
        for _,v in pairs(old) do
            local url, stamp
            if type(v) == "string" then url = v
            elseif type(v) == "table" then url = v.url or v[1]; stamp = v.t or v.time or v[2] end
            local key = normalise(url)
            if key then
                local ts = tonumber(stamp) or now()
                local e = lookup[key]
                if e then
                    e.firstSeen = math.min(e.firstSeen, ts)
                    e.lastSeen = math.max(e.lastSeen, ts)
                    e.seenCount = e.seenCount + 1
                else
                    e = {id=nextId,url=url,normalizedUrl=key,category=category(key),
                         firstSeen=ts,lastSeen=ts,seenCount=1,favorite=false,pinned=false}
                    nextId = nextId + 1; entries[#entries+1] = e; lookup[key] = e
                end
            end
        end
        table.sort(entries, function(a,b) return a.id < b.id end)
        db.migrationBackup = backup
        db.journal = {entries=entries,nextId=nextId}
        db.settings = db.settings or {}
        db.settings.maxEntries = math.max(10, tonumber(db.journalMax) or 200)
        db.schemaVersion = 3
    end
    db.settings = type(db.settings) == "table" and db.settings or {}
    if db.settings.maxEntries == nil then db.settings.maxEntries = 500 end
    if db.settings.securityWarnings == nil then db.settings.securityWarnings = true end
    if db.settings.sharingEnabled == nil then db.settings.sharingEnabled = false end
    db.settings.captureMode = "clicked"
    db.journal = type(db.journal) == "table" and db.journal or {entries={},nextId=1}
    if type(db.journal.entries) ~= "table" then
        db.journal.entries = {}
        db.journal.duplicateRepairVersion = nil
    end
    local maxId = 0
    for _, entry in ipairs(db.journal.entries) do
        if type(entry) == "table" and type(entry.id) == "number" and entry.id > maxId then
            maxId = entry.id
        end
    end
    local nextId = tonumber(db.journal.nextId)
    if not nextId or nextId < 1 or nextId <= maxId or nextId % 1 ~= 0 then nextId = maxId + 1 end
    db.journal.nextId = nextId
    db.copyHistory = type(db.copyHistory) == "table" and db.copyHistory or {}
    db.trustedDomains = type(db.trustedDomains) == "table" and db.trustedDomains or {}
    db.blockedDomains = type(db.blockedDomains) == "table" and db.blockedDomains or {}
    db.minimap = db.minimap or {hide=false,minimapPos=220}
    local before = #db.journal.entries
    -- A persistent migration flag avoids repeating the duplicate cleanup on
    -- reloads. Manual repair deliberately bypasses it.
    if forceRepair or db.journal.duplicateRepairVersion ~= DUPLICATE_REPAIR_VERSION then
        repairJournal(db)
        db.journal.duplicateRepairVersion = DUPLICATE_REPAIR_VERSION
    end
    rebuild()
    readyDB, readyEntries = db, db.journal.entries
    return true, nil, before - #db.journal.entries
end

-- Constant-time readiness check for normal journal use.
function J.EnsureReady()
    local db = ClickLinksDB
    if type(db) == "table" and db == readyDB and db.schemaVersion == 3
        and type(db.journal) == "table" and db.journal.entries == readyEntries
        and type(readyEntries) == "table" and J.index and J.entriesById then
        return true
    end
    return J.Initialize()
end

function J.Repair()
    return J.Initialize(true)
end

function J.Get(id)
    return J.entriesById and J.entriesById[id]
end
local function cleanHistory()
    local h = ClickLinksDB.copyHistory
    if type(h) ~= "table" then return end
    for i=#h,1,-1 do
        if not (J.entriesById and J.entriesById[h[i]]) then table.remove(h,i) end
    end
end
local function notify()
    if ClickLinks.UI and ClickLinks.UI.RefreshJournal then ClickLinks.UI.RefreshJournal() end
end
function J.Add(url, metadata)
    local key,err = normalise(url); if not key then return nil,err end
    -- Click-only capture: use the canonical URL index in normal operation.
    local ok,initErr=J.EnsureReady()
    if not ok then return nil,initErr end
    local db=ClickLinksDB; local entries=db.journal.entries
    local slot=J.index[key]
    local existing=slot and entries[slot]
    if slot and (not existing or existing.normalizedUrl ~= key) then
        rebuild()
        existing=J.index[key] and entries[J.index[key]]
    end
    if existing then
        existing.seenCount=(existing.seenCount or 1)+1
        existing.lastSeen=now()
        notify()
        return existing.id
    end
    local max=math.floor(math.max(10,math.min(10000,tonumber(db.settings.maxEntries) or 500)))
    local needed = #entries - max + 1
    if needed > 0 then
        local eligible = 0
        for _,e in ipairs(entries) do
            if not e.pinned and not e.favorite then eligible = eligible + 1 end
        end
        if eligible < needed then return nil,"journal_full_protected" end
    end
    while #entries >= max do
        local victim
        for i,e in ipairs(entries) do
            if not e.pinned and not e.favorite and (not victim or (e.lastSeen or 0)<(entries[victim].lastSeen or 0)) then victim=i end
        end
        if not victim then return nil,"journal_full_protected" end
        table.remove(entries,victim)
    end
    local id=db.journal.nextId
    db.journal.nextId=id+1
    local e={id=id,url=url,normalizedUrl=key,title=metadata and metadata.title or nil,
        category=category(key),firstSeen=now(),lastSeen=now(),seenCount=1,
        favorite=false,pinned=false}
    entries[#entries+1]=e
    if needed > 0 then
        -- Eviction shifted array offsets.
        rebuild(); cleanHistory()
    else
        J.index[key] = #entries
        J.entriesById[id] = e
    end
    notify()
    return id
end
function J.SetFavorite(id,enabled)
    local e=J.Get(id); if not e then return nil,"not_found" end
    e.favorite=not not enabled; notify(); return true
end
function J.SetPinned(id,enabled)
    local e=J.Get(id); if not e then return nil,"not_found" end
    e.pinned=not not enabled; notify(); return true
end
function J.Delete(id)
    for i,e in ipairs(ClickLinksDB.journal.entries) do
        if e.id==id then table.remove(ClickLinksDB.journal.entries,i);rebuild();cleanHistory();notify();return true end
    end
    return nil,"not_found"
end
function J.Clear(includeProtected)
    local entries=ClickLinksDB.journal.entries
    for i=#entries,1,-1 do
        if includeProtected or (not entries[i].favorite and not entries[i].pinned) then table.remove(entries,i) end
    end
    rebuild();cleanHistory();notify();return true
end
function J.RecordCopy(id)
    local e=J.Get(id); if not e then return nil,"not_found" end
    e.lastCopied=now()
    e.copyCount=(e.copyCount or 0)+1
    local h=ClickLinksDB.copyHistory
    for i=#h,1,-1 do if h[i]==id then table.remove(h,i) end end
    table.insert(h,1,id)
    while #h>30 do table.remove(h) end
    notify();return true
end
function J.Search(filters)
    if not J.EnsureReady() then
        return {} -- Never crash the UI for an unsupported database.
    end
    filters=filters or {}
    local query=tostring(filters.query or ""):lower()
    local results={}
    for _,e in ipairs(ClickLinksDB.journal.entries) do
        local match=filters.category==nil or filters.category=="all" or filters.category==e.category
        if filters.favoritesOnly and not e.favorite then match=false end
        if filters.historyOnly and not e.lastCopied then match=false end
        if match and query~="" then
            local text=((e.url or "").." "..(e.title or "").." "..(e.sender or "").." "..(e.channel or "")):lower()
            match=text:find(query,1,true)~=nil
        end
        if match then results[#results+1]=e end
    end
    local sort=filters.sort or "recent"
    table.sort(results,function(a,b)
        if a.pinned~=b.pinned then return a.pinned==true end
        local av,bv
        if sort=="title" then av=(a.title or a.url):lower();bv=(b.title or b.url):lower()
        elseif sort=="oldest" then av=a.firstSeen or 0;bv=b.firstSeen or 0
        elseif sort=="copies" then av=a.copyCount or 0;bv=b.copyCount or 0
        else av=a.lastSeen or 0;bv=b.lastSeen or 0 end
        if av~=bv then
            if sort=="title" or sort=="oldest" then return av<bv end
            return av>bv
        end
        return a.id>b.id
    end)
    return results
end
function J.Export(filters)
    local lines={}
    for _,e in ipairs(J.Search(filters)) do lines[#lines+1]=e.url end
    return table.concat(lines,"\n")
end
