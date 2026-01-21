-- File: ClickLinks.lua
-- Name: Click Links
-- Original Author: tannerng
-- Continued by : Milestorme
-- Description: Makes URLs clickable + automatic version checking
-- notes: Adds clickable URL links to chat, plus in-game version announcement + one-time update warning.

local ADDON_NAME = ...

local L = LibStub("AceLocale-3.0"):GetLocale("ClickLinks")

-------------------------------------------------
-- FUNCTION INDEX
-------------------------------------------------
-- URL / Formatting
--   formatURL(url)                   -> Wraps a URL string into a clickable |Hurl:| hyperlink

-- Chat Filtering
--   makeClickable(self, event, msg, ...)
--                                   -> Chat message event filter; replaces URL-like patterns with clickable links

-- URL Copy Popup / Hyperlink Hook
--   StaticPopupDialogs["CLICK_LINK_CLICKURL"].OnShow(self)
--                                   -> Populates the edit box with the clicked URL and highlights for copy
--   ItemRefTooltip:SetHyperlink(link)
--                                   -> Intercepts "url:" links and opens copy popup; otherwise calls original handler

-- Version Checking
--   VersionToNumber(ver)            -> Converts "X.Y.Z" to comparable integer
--   SendVersionToGroup()            -> Broadcasts local version to guild and (once per group) party/raid
--   f:SetScript("OnEvent", ...)     -> Handles login/group roster changes/addon messages for update detection

-- Slash Commands
--   /clicklinks version|ver         -> Prints addon version
--   /cl version|ver                 -> Short alias for version command
-------------------------------------------------


-------------------------------------------------
-- URL Patterns
-------------------------------------------------
-- notes: Patterns used to detect URLs/emails/IPs in chat text. Each match is replaced with a clickable hyperlink.
local URL_PATTERNS = {
    -- X://Y most urls
    "^(%a[%w+.-]+://%S+)",
    "%f[%S](%a[%w+.-]+://%S+)",
    -- www.X.Y domain and path
    "^(www%.[-%w_%%]+%.(%a%a+)/%S+)",
    "%f[%S](www%.[-%w_%%]+%.(%a%a+)/%S+)",
    -- www.X.Y domain
    "^(www%.[-%w_%%]+%.(%a%a+))",
    "%f[%S](www%.[-%w_%%]+%.(%a%a+))",
    -- email
    "(%S+@[%w_.-%%]+%.(%a%a+))",
    -- ip address with port and path
    "^([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d:[0-6]?%d?%d?%d?%d/%S+)",
    "%f[%S]([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d:[0-6]?%d?%d?%d?%d/%S+)",
    -- ip address with port
    "^([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d:[0-6]?%d?%d?%d?%d)%f[%D]",
    "%f[%S]([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d:[0-6]?%d?%d?%d?%d)%f[%D]",
    -- ip address with path
    "^([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%/%S+)",
    "%f[%S]([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%/%S+)",
    -- ip address
    "^([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d)%f[%D]",
    "%f[%S]([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d)%f[%D]"
}

local function formatURL(url)
    -- notes: Converts a raw URL string into a colored clickable hyperlink using the "url:" hyperlink type.
    -- notes: The ItemRefTooltip:SetHyperlink hook below intercepts "url:" to show the copy popup.
    -- notes: Escape "|" because it is a control character in WoW hyperlink formatting.
    url = tostring(url or "")
    url = url:gsub("%|", "||")
    return "|cff149bfd|Hurl:" .. url .. "|h[" .. url .. "]|h|r "
end


-- ------------------------------------------------
-- Safety helpers (Retail 12.x "secret" chat values)
-- ------------------------------------------------
-- notes:
--   Retail 12.x may pass "secret" values into chat frames (e.g. in PvP instances).
--   These values behave like strings in some contexts but error on indexing/string methods.
--   We defensively wrap string operations with pcall and/or skip processing.

local function _CL_SafeCall(fn, ...)
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return true, a, b, c, d end
    return false
end

local function _CL_CanTreatAsString(v)
    if type(v) ~= "string" then return false end
    -- Some secret values report as "string" but throw on operations; # is a cheap probe.
    return _CL_SafeCall(function(s) return #s end, v)
end

local function _CL_SafeFind(s, pattern, plain)
    local ok, idx = _CL_SafeCall(function(str, pat, isPlain)
        return string.find(str, pat, 1, isPlain)
    end, s, pattern, plain == true)
    if ok then return idx end
    return nil
end

local function _CL_IsRuntimeDisabled()
    return false
end

-------------------------------------------------
-- Chat message filter
-------------------------------------------------
local function makeClickable(self, event, msg, ...)
    -- notes: ChatFrame_AddMessageEventFilter callback.
    -- notes: Performs a cheap pre-check, then gsubs all URL patterns into clickable links.
    -- notes: Returns (false, msg, ...) so the message continues through normal rendering.

    -- If the line already contains hyperlinks (items/spells/etc), don't touch it.
    -- This avoids edge-case corruption and plays nicer with other chat addons.
    if _CL_IsRuntimeDisabled() then
        return false, msg, ...
    end

    -- Retail 12.x can pass "secret" chat values that error on string methods.
    if not _CL_CanTreatAsString(msg) then
        return false, msg, ...
    end

    -- If the line already contains hyperlinks (items/spells/etc), don't touch it.
    if _CL_SafeFind(msg, "|H", true) then
        return false, msg, ...
    end

    -- Quick pre-check to avoid unnecessary gsub
    if not (_CL_SafeFind(msg, "://", true)
        or _CL_SafeFind(msg, "www%.")
        or _CL_SafeFind(msg, "@", true)
        or _CL_SafeFind(msg, "%d+%.%d+%.%d+%.%d+"))
    then
        return false, msg, ...
    end


    local ok, newMsg = _CL_SafeCall(function(m)
        for _, pattern in ipairs(URL_PATTERNS) do
            m = m:gsub(pattern, formatURL)
        end
        return m
    end, msg)
    if ok and type(newMsg) == "string" then
        msg = newMsg
    end
    return false, msg, ...
end

local CHAT_TYPES = {
    -- notes: Chat event suffixes to attach the filter to. "SYSTEM" included for system messages too.
    "AFK","BATTLEGROUND_LEADER","BATTLEGROUND","BN_WHISPER","BN_WHISPER_INFORM",
    "CHANNEL","COMMUNITIES_CHANNEL","DND","EMOTE","GUILD","OFFICER",
    "PARTY_LEADER","PARTY",
    "INSTANCE_CHAT_LEADER","INSTANCE_CHAT",
    "RAID_LEADER","RAID_WARNING","RAID",
    "SAY","WHISPER","WHISPER_INFORM","YELL","SYSTEM"
}

for _, chatType in ipairs(CHAT_TYPES) do
    -- notes: Registers message filter for each chat channel/event type.
    ChatFrame_AddMessageEventFilter("CHAT_MSG_" .. chatType, makeClickable)
end


-------------------------------------------------
-- Ensure system-style messages (e.g. GUILD_MOTD) also get clickable URLs
-------------------------------------------------
-- notes: Some messages (guild MOTD, addon prints, certain system lines) are written directly via ChatFrame:AddMessage
-- notes: and do NOT go through CHAT_MSG_* filters. We wrap AddMessage to catch those too.
local HookCommunitiesFramesForClickableURLs -- forward declare (used before definition)
local function HookChatFramesForClickableURLs()
HookCommunitiesFramesForClickableURLs()
    if not _G.ChatFrame1 then return end

    for i = 1, (NUM_CHAT_WINDOWS or 0) do
        local cf = _G["ChatFrame" .. i]
        if cf and not cf.__ClickLinksHooked then
            cf.__ClickLinksHooked = true

            local origAddMessage = cf.AddMessage
            cf.AddMessage = function(self, text, ...)
                -- Auto-disable (and avoid "secret value" errors) in PvP instances if enabled.
                if _CL_IsRuntimeDisabled() then
                    return origAddMessage(self, text, ...)
                end

                if _CL_CanTreatAsString(text) then
                    -- Reuse the same safety rules as makeClickable:
                    -- 1) Do not touch existing hyperlinks
                    -- 2) Only process if it looks like it contains a URL/email/IP
                    if not _CL_SafeFind(text, "|H", true) then
                        -- makeClickable returns (false, msg, ...) because it's a filter; we only need the transformed msg.
                        local ok, _, newText = _CL_SafeCall(makeClickable, self, "ADD_MESSAGE", text, ...)
                        if ok and newText then
                            text = newText
                        end
                    end
                end
                return origAddMessage(self, text, ...)
            end
        end
    end
end


-------------------------------------------------
-- Communities / Guild UI message frames (Retail)
-------------------------------------------------
-- notes: The Communities/Guild UI uses its own scrolling message frame and does not always
-- go through CHAT_MSG_* filters or ChatFrame:AddMessage. We hook its AddMessage too.

local function _TryHookMessageFrame(frame)
    if not frame or frame.__ClickLinksHooked then return end
    if type(frame.AddMessage) ~= "function" then return end

    frame.__ClickLinksHooked = true
    local origAddMessage = frame.AddMessage
    frame.AddMessage = function(self, msg, ...)
        if _CL_IsRuntimeDisabled() then
            return origAddMessage(self, msg, ...)
        end

        if _CL_CanTreatAsString(msg) and not _CL_SafeFind(msg, "|H", true) then
            local ok, _, newMsg = _CL_SafeCall(makeClickable, self, "MESSAGE_FRAME_ADD_MESSAGE", msg, ...)
            if ok and newMsg then
                msg = newMsg
            end
        end
        return origAddMessage(self, msg, ...)
    end
end

HookCommunitiesFramesForClickableURLs = function()
    local cf = _G.CommunitiesFrame
    if not cf then return end

    local candidates = {
        cf.Chat and cf.Chat.MessageFrame,
        cf.Chat and cf.Chat.InsetFrame and cf.Chat.InsetFrame.Chat and cf.Chat.InsetFrame.Chat.MessageFrame,
        cf.Chat and cf.Chat.InsetFrame and cf.Chat.InsetFrame.ChatFrame and cf.Chat.InsetFrame.ChatFrame.MessageFrame,
        cf.ChatFrame and cf.ChatFrame.MessageFrame,
        cf.ChatFrame,
    }

    for _, f in ipairs(candidates) do
        _TryHookMessageFrame(f)
    end
end

-- Try immediately (addon load), and also after login in case chat frames are not fully built yet.
HookChatFramesForClickableURLs()
local __clHookFrame = CreateFrame("Frame")
__clHookFrame:RegisterEvent("PLAYER_LOGIN")
__clHookFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
__clHookFrame:RegisterEvent("ADDON_LOADED")
__clHookFrame:SetScript("OnEvent", function(_, event, addonName)
    HookChatFramesForClickableURLs()
    -- Communities/Guild UI is loaded on-demand on Retail
    if event == "ADDON_LOADED" then
        if addonName == "Blizzard_Communities" or addonName == "Blizzard_GuildUI" then
            HookCommunitiesFramesForClickableURLs()
        end
    else
        HookCommunitiesFramesForClickableURLs()
    end
end)

-------------------------------------------------
-- StaticPopup for copying URLs
-------------------------------------------------
-- notes: Popup with editbox: user can Ctrl+C the URL.
StaticPopupDialogs["CLICK_LINK_CLICKURL"] = {
    text = L["COPYBOX_HINT"],
    button1 = CLOSE,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    hasEditBox = true,

    OnShow = function(self)
        -- notes: When shown, loads URL into the edit box, highlights it, and focuses for quick copy.
        local editBox = _G[self:GetName() .. "EditBox"]
        editBox:SetText("")
        if self.data and self.data.url then
            editBox:SetText(self.data.url)
            editBox:HighlightText()
            editBox:SetFocus()
        end
    end,
}

local _AddToJournal -- forward declared (used by ItemRefTooltip hook)

local OriginalSetHyperlink = ItemRefTooltip.SetHyperlink
function ItemRefTooltip:SetHyperlink(link)
    -- notes: Hook ItemRefTooltip hyperlink handler.
    -- notes: Intercepts our custom "url:" hyperlinks and shows copy popup; otherwise passes through.
    if link:match("^url:") then
        local u = link:sub(5)
        _AddToJournal(u)
        StaticPopup_Show("CLICK_LINK_CLICKURL", nil, nil, { url = u })
    else
        OriginalSetHyperlink(self, link)
    end
end

-------------------------------------------------
-- Automatic Version Check
-------------------------------------------------
local PREFIX = "CLICKLINKS_VER"

-- notes: SavedVariables: stores a one-time warning flag so users don't get spammed repeatedly.
ClickLinksDB = ClickLinksDB or { warned = false }

-- ------------------------------------------------
-- Journal + Minimap Button (Saved clicked links)
-- ------------------------------------------------
-- notes:
--   ClickLinksDB.journal: array of { url = "...", t = time() }
--   ClickLinksDB.minimap: { hide = false, angle = 220 }
--   Use /cl journal (or minimap button) to open the journal.

ClickLinksDB.journal = ClickLinksDB.journal or {}
ClickLinksDB.journalMax = ClickLinksDB.journalMax or 200
ClickLinksDB.minimap = ClickLinksDB.minimap or { hide = false, angle = 220 }

-- ------------------------------------------------
-- Auto-disable in PvP instances (Retail 12.x safety)
-- ------------------------------------------------
-- notes:
--   In Retail 12.x, certain chat messages in PvP instances may carry "secret" values.
--   We automatically skip ClickLinks processing while in battlegrounds/arenas (and resume on exit).
--   Users can disable this behavior by setting ClickLinksDB.autoDisablePvP = false.

ClickLinksDB.autoDisablePvP = (ClickLinksDB.autoDisablePvP ~= false)

local ClickLinksRuntimeDisabled = false
local function _CL_UpdateRuntimeDisabled()
    if ClickLinksDB and ClickLinksDB.autoDisablePvP then
        local inInstance, instanceType = IsInInstance()
        ClickLinksRuntimeDisabled = inInstance and (instanceType == "pvp" or instanceType == "arena")
    else
        ClickLinksRuntimeDisabled = false
    end
end

-- Replace the forward stub with the real runtime flag.
_CL_IsRuntimeDisabled = function()
    return ClickLinksRuntimeDisabled
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    f:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
    f:SetScript("OnEvent", function()
        _CL_UpdateRuntimeDisabled()
    end)
    _CL_UpdateRuntimeDisabled()
end



-- ---- Journal data normalization ----
-- notes:
--   Older test builds (or manual edits) may leave the journal as a sparse table or with non-entry values.
--   Normalize it into a clean array so #journal, table.remove, and UI iteration are safe.
local function _NormalizeJournal()
    local j = ClickLinksDB.journal
    if type(j) ~= "table" then
        ClickLinksDB.journal = {}
        return
    end

    local arr = {}

    for _, v in pairs(j) do
        if type(v) == "table" then
            local url = v.url or v[1]
            local t = v.t or v.time or v[2]
            if type(url) == "string" and url ~= "" then
                table.insert(arr, { url = url, t = tonumber(t) or time() })
            end
        elseif type(v) == "string" and v ~= "" then
            table.insert(arr, { url = v, t = time() })
        end
    end

    table.sort(arr, function(a, b)
        return (a.t or 0) < (b.t or 0) -- oldest -> newest
    end)

    ClickLinksDB.journal = arr
end

_NormalizeJournal()

local function _TrimJournal()
    local maxKeep = tonumber(ClickLinksDB.journalMax) or 200
    if maxKeep < 10 then maxKeep = 10 end
    local j = ClickLinksDB.journal
    local extra = #j - maxKeep
    if extra > 0 then
        for i = 1, extra do
            table.remove(j, 1)
        end
    end
end

local function _ClearJournal()
    local j = ClickLinksDB.journal
    for i = #j, 1, -1 do
        j[i] = nil
    end
end

-- Journal UI forward declarations (so journal updates live while the window is open)
local JournalFrame, JournalScrollChild, JournalButtons = nil, nil, nil
local _UpdateJournalUI  -- forward declaration (used by _AddToJournal and journal actions)

_AddToJournal = function(url)
    url = tostring(url or ""):gsub("%s+$", ""):gsub("^%s+", "")
    if url == "" then return end

    local j = ClickLinksDB.journal
    local last = j[#j]
    if last and last.url == url then
        last.t = time()
        return
    end

    j[#j + 1] = { url = url, t = time() }
    _TrimJournal()
    if JournalFrame and JournalFrame:IsShown() then
        _UpdateJournalUI()
    end
end

-- ---- Journal UI ----
-- (JournalFrame locals were forward-declared above so _AddToJournal can refresh the list live)

local function _FormatTime(ts)
    if type(date) == "function" and ts then
        return date("%Y-%m-%d %H:%M", ts)
    end
    return ""
end

local function _EnsureJournalUI()
    if JournalFrame then return end

    local template = (BackdropTemplateMixin and "BackdropTemplate") or nil
    JournalFrame = CreateFrame("Frame", "ClickLinks_JournalFrame", UIParent, template)
    JournalFrame:SetSize(520, 420)
    JournalFrame:SetPoint("CENTER")
    JournalFrame:SetFrameStrata("DIALOG")
    JournalFrame:EnableMouse(true)
    JournalFrame:SetMovable(true)
    JournalFrame:RegisterForDrag("LeftButton")
    JournalFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    JournalFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    JournalFrame:Hide()

    if JournalFrame.SetBackdrop then
        JournalFrame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        JournalFrame:SetBackdropColor(0, 0, 0, 0.95)
    end

    local title = JournalFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText(L["JOURNAL_TITLE"])

    local hint = JournalFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", title, "BOTTOM", 0, -6)
    hint:SetText(L["JOURNAL_HINT"])

    local close = CreateFrame("Button", nil, JournalFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    local clear = CreateFrame("Button", nil, JournalFrame, "UIPanelButtonTemplate")
    clear:SetSize(90, 22)
    clear:SetPoint("TOPRIGHT", -38, -28)
    clear:SetText(L["CLEAR_ALL"])
    clear:SetScript("OnClick", function()
        -- Confirm before wiping the entire journal (prevents misclicks)
        StaticPopupDialogs["CLICKLINKS_CLEAR_JOURNAL_CONFIRM"] = StaticPopupDialogs["CLICKLINKS_CLEAR_JOURNAL_CONFIRM"] or {
            text = L["CLEAR_ALL_CONFIRM"],
            button1 = L["OK"],
            button2 = L["CANCEL"],
            OnAccept = function()
                _ClearJournal()
                if JournalFrame and JournalFrame:IsShown() and _UpdateJournalUI then
                    _UpdateJournalUI()
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("CLICKLINKS_CLEAR_JOURNAL_CONFIRM")
    end)


    local scroll = CreateFrame("ScrollFrame", "ClickLinks_JournalScrollFrame", JournalFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -58)
    scroll:SetPoint("BOTTOMRIGHT", -34, 16)

    JournalScrollChild = CreateFrame("Frame", nil, scroll)
    JournalScrollChild:SetSize(1, 1)
    scroll:SetScrollChild(JournalScrollChild)

    JournalButtons = {}
end

_UpdateJournalUI = function()
    if not JournalFrame or not JournalFrame:IsShown() then return end
    _EnsureJournalUI()

    -- Ensure journal is a clean array (protects against old saved data / sparse tables)
    _NormalizeJournal()
    local j = ClickLinksDB.journal

    local rowH = 20
    local width = 460

    for i = 1, #JournalButtons do
        JournalButtons[i]:Hide()
    end

    local shown = 0

    -- Newest-first (journal is oldest->newest, so iterate backwards)
    for i = #j, 1, -1 do
        local entry = j[i]
        if entry and type(entry.url) == "string" and entry.url ~= "" then
            shown = shown + 1
            local idx = shown -- 1..shown newest first
            local btn = JournalButtons[idx]
            if not btn then
                btn = CreateFrame("Button", nil, JournalScrollChild)
                btn:SetHeight(rowH)
                btn:SetWidth(width)
                btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                btn.text:SetPoint("LEFT", 2, 0)
                btn.text:SetJustifyH("LEFT")
                btn.text:SetWidth(width - 4)
                btn.text:SetWordWrap(false)

                btn:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight")
                btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                btn:SetScript("OnClick", function(self, button)
                    local url = self._url
                    if not url then return end
                    if button == "RightButton" then
                        -- remove the first matching entry (newest-first is fine)
                        for k = #ClickLinksDB.journal, 1, -1 do
                            if ClickLinksDB.journal[k] and ClickLinksDB.journal[k].url == url then
                                table.remove(ClickLinksDB.journal, k)
                                break
                            end
                        end
                        _UpdateJournalUI()
                    else
                        StaticPopup_Show("CLICK_LINK_CLICKURL", nil, nil, { url = url })
                    end
                end)

                JournalButtons[idx] = btn
            end

            local ts = _FormatTime(entry.t)
            local display = entry.url or ""
            if #display > 300 then display = display:sub(1, 300) .. "..." end

            btn._url = entry.url
            btn.text:SetText((ts ~= "" and ("|cffaaaaaa" .. ts .. "|r  ") or "") .. display)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", 0, -((idx - 1) * rowH))
            btn:Show()
        end
    end

    JournalScrollChild:SetHeight(math.max(1, shown * rowH))
end


local function ToggleJournal()
    _EnsureJournalUI()
    if JournalFrame:IsShown() then
        JournalFrame:Hide()
    else
        JournalFrame:Show()
        _UpdateJournalUI()
    end
end

-- ---- Minimap button (LibDBIcon-1.0) ----
-- notes:
--   Uses LibDataBroker + LibDBIcon for a standard, drag-to-move minimap icon.
--   SavedVariables:
--     ClickLinksDB.minimap = { hide = false, minimapPos = 220 }
--   (Older builds used `angle`; we migrate it to `minimapPos` automatically.)

-- Forward declaration:
-- The minimap icon's OnClick closure is created before the localization table is assigned.
local DBIcon = nil
local LDB = nil
local LDBObj = nil

local function _InitMinimap()
    if DBIcon and LDBObj then return end
    if type(LibStub) ~= "table" or type(LibStub.GetLibrary) ~= "function" then return end

    DBIcon = LibStub:GetLibrary("LibDBIcon-1.0", true)
    LDB = LibStub:GetLibrary("LibDataBroker-1.1", true)
    if not (DBIcon and LDB) then return end

    ClickLinksDB.minimap = ClickLinksDB.minimap or { hide = false, minimapPos = 220 }

    -- migrate legacy key
    if ClickLinksDB.minimap.angle and not ClickLinksDB.minimap.minimapPos then
        ClickLinksDB.minimap.minimapPos = ClickLinksDB.minimap.angle
    end
    ClickLinksDB.minimap.angle = nil

    LDBObj = LDB:NewDataObject("ClickLinks", {
        label = L["ADDON_TITLE"],
        text = L["ADDON_TITLE"],
        type = "launcher",
        icon = "Interface/ICONS/INV_Misc_Note_04",
        OnClick = function(_, button)
            if button == "LeftButton" then
                ToggleJournal()
            end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine(L["ADDON_TITLE"], 0.08, 0.63, 0.85)
            tt:AddLine(L["TOOLTIP_LEFTCLICK_JOURNAL"], 1, 1, 1)
            tt:AddLine(L["TOOLTIP_DRAG_MOVE"], 1, 1, 1)
        end,
    })

    DBIcon:Register("ClickLinks", LDBObj, ClickLinksDB.minimap)
    if ClickLinksDB.minimap.hide then
        DBIcon:Hide("ClickLinks")
    end
end

local function ToggleMinimapButton()
    ClickLinksDB.minimap = ClickLinksDB.minimap or { hide = false, minimapPos = 220 }
    ClickLinksDB.minimap.hide = not ClickLinksDB.minimap.hide
    _InitMinimap()
    if DBIcon then
        if ClickLinksDB.minimap.hide then
            DBIcon:Hide("ClickLinks")
        else
            DBIcon:Show("ClickLinks")
        end
    end
end

-- notes: Localization-ready strings (single table).
-- notes: Reads the addon Version field from the TOC metadata.
local localVersion = ( (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata )(ADDON_NAME, "Version")
    or ( (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata )("ClickLinks", "Version")
    or "0"
localVersion = tostring(localVersion)

local function VersionToNumber(ver)
    -- notes: Converts semantic X.Y.Z into an integer so versions can be compared numerically.
    -- notes: Example: 1.2.3 -> 10203 (via a*10000 + b*100 + c)
    local a, b, c = ver:match("(%d+)%.(%d+)%.(%d+)")
    if not a then return 0 end
    return a * 10000 + b * 100 + c
end

local localVerNum = VersionToNumber(localVersion)

-- notes: Must register prefix before sending/receiving addon messages.
C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

local f = CreateFrame("Frame")
-- notes: PLAYER_LOGIN = initial broadcast; GROUP_ROSTER_UPDATE = broadcast when joining a group; CHAT_MSG_ADDON = receive versions.
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("GROUP_ROSTER_UPDATE")

-- notes: Prevents repeatedly blasting PARTY/RAID every roster change; resets when leaving group.
local sentVersionThisGroup = false

local function SendVersionToGroup()
    -- notes: Broadcasts version to:
    -- notes: - GUILD (always when in guild)
    -- notes: - PARTY/RAID (only once per group session)
    if IsInGuild() then
        C_ChatInfo.SendAddonMessage(PREFIX, localVersion, "GUILD")
    end
    if IsInRaid() or IsInGroup() then
        if not sentVersionThisGroup then
            local channel = IsInRaid() and "RAID" or "PARTY"
            C_ChatInfo.SendAddonMessage(PREFIX, localVersion, channel)
            sentVersionThisGroup = true
        end
    end
end

f:SetScript("OnEvent", function(_, event, prefix, message)
    -- notes: Central event router for version system.
    if event == "PLAYER_LOGIN" then
        -- notes: On login, announce version to guild and current group (if any).
        SendVersionToGroup()
        _InitMinimap()

    elseif event == "GROUP_ROSTER_UPDATE" then
        -- notes: When group changes:
        -- notes: - If we are no longer grouped, clear the one-shot flag.
        -- notes: - If we are grouped, send version (once per group).
        if not IsInGroup() and not IsInRaid() then
            sentVersionThisGroup = false
        else
            SendVersionToGroup()
        end

    elseif event == "CHAT_MSG_ADDON" and prefix == PREFIX then
        -- notes: On receiving another player's version, compare and (once) warn if theirs is newer.
        local remoteVerNum = VersionToNumber(message)
        if remoteVerNum > localVerNum and not ClickLinksDB.warned then
            ClickLinksDB.warned = true
            print("|cffff0000" .. L["ADDON_NAME"] .. ":|r " .. L["UPDATE_AVAILABLE"])
            print("|cffffcc00" .. L["YOUR_VERSION"] .. "|r", localVersion)
            print("|cffffcc00" .. L["NEWER_VERSION"] .. "|r", message)
            print("|cffffcc00" .. L["UPDATE_HINT"] .. "|r")
        end
    end
end)

-------------------------------------------------
-- Slash Commands
-------------------------------------------------
SLASH_CLICKLINKS1 = "/clicklinks"
SLASH_CLICKLINKS2 = "/cl"

SlashCmdList["CLICKLINKS"] = function(msg)
    -- notes: Slash handler.
    msg = msg and msg:lower() or ""

    if msg == "version" or msg == "ver" then
        print("|cff149bfd" .. L["ADDON_NAME"] .. "|r")
        print("|cffffcc00" .. L["VERSION_CMD"] .. "|r", localVersion)

    elseif msg == "journal" or msg == "log" then
        ToggleJournal()

    elseif msg == "minimap" then
        ToggleMinimapButton()

    elseif msg == "pvp" or msg == "bg" then
        ClickLinksDB.autoDisablePvP = not (ClickLinksDB.autoDisablePvP == true)
        _CL_UpdateRuntimeDisabled()
        print("|cff149bfd" .. (L and L["ADDON_NAME"] or "ClickLinks") .. "|r: Auto-disable in PvP is now " .. (ClickLinksDB.autoDisablePvP and "|cff00ff00ON|r" or "|cffff0000OFF|r"))

    else
        print("|cff149bfd" .. L["ADDON_NAME"] .. "|r")
        print("|cffffcc00" .. L["HELP_LINE_VERSION"] .. "|r")
        print("|cffffcc00" .. L["HELP_LINE_JOURNAL"] .. "|r")
        print("|cffffcc00" .. L["HELP_LINE_MINIMAP"] .. "|r")
    end
end
