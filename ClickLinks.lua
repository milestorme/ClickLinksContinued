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
    "^(%a[%w+.-]+://[^%s|]+)",
    "%f[%S](%a[%w+.-]+://[^%s|]+)",
    -- www.X.Y domain and path
    "^(www%.[-%w_%%]+%.(%a%a+)/[^%s|]+)",
    "%f[%S](www%.[-%w_%%]+%.(%a%a+)/[^%s|]+)",
    -- www.X.Y domain
    "^(www%.[-%w_%%]+%.(%a%a+))",
    "%f[%S](www%.[-%w_%%]+%.(%a%a+))",
    -- domain.tld/path (no scheme/www)
    "^(%w[%w%._-]+%.(%a%a+)/[^%s|]+)",
    "%f[%S](%w[%w%._-]+%.(%a%a+)/[^%s|]+)",
    -- domain.tld (no scheme/www)
    "^(%w[%w%._-]+%.(%a%a+))",
    "%f[%S](%w[%w%._-]+%.(%a%a+))",
    -- email
    "(%S+@[%w_.-%%]+%.(%a%a+))",
    -- ip address with port and path
    "^([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d:[0-6]?%d?%d?%d?%d/[^%s|]+)",
    "%f[%S]([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d:[0-6]?%d?%d?%d?%d/[^%s|]+)",
    -- ip address with port
    "^([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d:[0-6]?%d?%d?%d?%d)%f[%D]",
    "%f[%S]([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d:[0-6]?%d?%d?%d?%d)%f[%D]",
    -- ip address with path
    "^([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%/[^%s|]+)",
    "%f[%S]([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%/[^%s|]+)",
    -- ip address
    "^([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d)%f[%D]",
    "%f[%S]([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d)%f[%D]"
}

-- Characters commonly appended after URLs that should not be clickable
local URL_TRAILING = {
    ["."] = true, [","] = true, [";"] = true, [":"] = true,
    ["!"] = true, ["?"] = true, [")"] = true,
    ["\""] = true, ["'"] = true,
    ["]"] = true, ["}"] = true,
}

local function _SplitTrailingURLPunctuation(url)
    url = tostring(url or "")
    local trailing = ""


    while #url > 0 do
        local c = url:sub(-1)
        if URL_TRAILING[c] then
            trailing = c .. trailing
            url = url:sub(1, -2)
        else
            break
        end
    end

    return url, trailing
end


-------------------------------------------------
-- Bare domain TLD whitelist (prevents false positives)
-------------------------------------------------
local ALLOWED_TLDS = {
    com = true, net = true, org = true,
    io = true, gg = true, co = true,
    au = true, uk = true, us = true, nz = true, ca = true,
    de = true, fr = true, jp = true, kr = true,
}

local function _CL_IsAllowedTLD(domain)
    local tld = domain:match("%.([%a][%a]+)$")
    if not tld then return false end
    return ALLOWED_TLDS[string.lower(tld)] == true
end


local function formatURL(url)
    local trailing
    url, trailing = _SplitTrailingURLPunctuation(url)

    -- If this is a bare domain (no scheme, no www), enforce TLD whitelist
    if not string.find(url, "://", 1, true)
        and not string.find(url, "www.", 1, true)
    then
        if not _CL_IsAllowedTLD(url) then
            return url .. trailing
        end
    end

    url = url:gsub("%|", "||")
    return "|cff149bfd|Hurl:" .. url .. "|h[" .. url .. "]|h|r" .. trailing
end




local function formatURL(url)
    local trailing
    url, trailing = _SplitTrailingURLPunctuation(url)

    -- If this is a bare domain (no scheme, no www), enforce TLD whitelist
    if not string.find(url, "://", 1, true)
        and not string.find(url, "www.", 1, true)
    then
        if not _CL_IsAllowedTLD(url) then
            return url .. trailing
        end
    end

    url = url:gsub("%|", "||")
    return "|cff149bfd|Hurl:" .. url .. "|h[" .. url .. "]|h|r" .. trailing
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

local function _CL_SafeMatch(s, pattern)
    local ok, a, b, c, d = _CL_SafeCall(function(str, pat)
        return string.match(str, pat)
    end, s, pattern)
    if ok then return a, b, c, d end
    return nil
end

    return nil
end

-------------------------------------------------
-- Chat message filter
-------------------------------------------------
local function makeClickable(self, event, msg, ...)
    -- notes: ChatFrame_AddMessageEventFilter callback.
    -- notes: Performs a cheap pre-check, then gsubs all URL patterns into clickable links.
    -- notes: Returns (false, msg, ...) so the message continues through normal rendering.

    -- ElvUI has its own URL filter (CH:FindURL) that also produces |Hurl: links.
    -- If both run on the same message, ElvUI re-processes ClickLinks' already-formatted
    -- |Hurl: text, matching www. patterns inside it twice and producing garbage like
    -- |Hurl:[[www.test.com]www.test.com[www.test.com]].
    -- When ElvUI is active and its URL feature is enabled (the default), let ElvUI handle
    -- formatting entirely. ClickLinks' SetItemRef copy-box hook still fires on the
    -- resulting |Hurl: links, so copy-on-click continues to work.
    if _G.ElvUI then
        local E = _G.ElvUI[1]
        local CH = E and E.GetModule and E:GetModule("Chat", true)
        -- CH.db.url defaults to true; skip unless the user has explicitly disabled it in ElvUI
        if not (CH and CH.db and CH.db.url == false) then
            return false, msg, ...
        end
    end

    -- If the line already contains hyperlinks (items/spells/etc), don't touch it.
    -- This avoids edge-case corruption and plays nicer with other chat addons.
    -- Retail 12.x can pass "secret" chat values that error on string methods.
    if not _CL_CanTreatAsString(msg) then
        return false, msg, ...
    end

    -- If the line already contains hyperlinks (items/spells/etc), don't touch it.
    if _CL_SafeFind(msg, "|H", true) then
        return false, msg, ...
    end

    
    
    -- Quick pre-check to avoid unnecessary gsub
    -- We include a literal '.' trigger so bare domains like google.com are processed.
    -- False positives are prevented by the TLD whitelist inside formatURL().
    if not (_CL_SafeFind(msg, "://", true)
        or _CL_SafeFind(msg, "www%.", true)
        or _CL_SafeFind(msg, "@", true)
        or _CL_SafeFind(msg, "%d+%.%d+%.%d+%.%d+")
        or _CL_SafeFind(msg, ".", true)) -- bare domains like google.com
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


-------------------------------------------------
-- Chat Filtering: Register on all known chat events (cross-client safe)
-------------------------------------------------
local CHAT_EVENT_SUFFIXES = {
    "SAY","YELL","EMOTE",
    "WHISPER","WHISPER_INFORM",
    "GUILD","OFFICER",
    "PARTY","PARTY_LEADER",
    "RAID","RAID_LEADER","RAID_WARNING",
    "INSTANCE_CHAT","INSTANCE_CHAT_LEADER",
    "CHANNEL",
    "AFK","DND",
    "BATTLEGROUND","BATTLEGROUND_LEADER",
    "SYSTEM",
    "LOOT","MONEY","CURRENCY",
    "SKILL","TRADESKILLS",
    "COMBAT_XP_GAIN","COMBAT_HONOR_GAIN","COMBAT_FACTION_CHANGE",
    "ACHIEVEMENT","GUILD_ACHIEVEMENT",
    "BN_WHISPER","BN_WHISPER_INFORM",
    "BN_CONVERSATION","BN_CONVERSATION_NOTICE","BN_CONVERSATION_LIST",
    "BN_INLINE_TOAST_ALERT",
    "BN_INLINE_TOAST_BROADCAST","BN_INLINE_TOAST_BROADCAST_INFORM",
    "BN_INLINE_TOAST_CONVERSATION","BN_INLINE_TOAST_CONVERSATION_INFORM",
    "COMMUNITIES_CHANNEL",
    "CLUB",
    "CLUB_MEMBER_UPDATED","CLUB_MEMBER_ADDED","CLUB_MEMBER_REMOVED",
    "CLUB_STREAMS_LOADED","CLUB_STREAM_MESSAGE",
    "PET_BATTLE_INFO",
}

local function _CL_RegisterAllChatFilters()
    for _, suffix in ipairs(CHAT_EVENT_SUFFIXES) do
        local ev = "CHAT_MSG_" .. suffix
        pcall(ChatFrame_AddMessageEventFilter, ev, makeClickable)
    end
end

_CL_RegisterAllChatFilters()



-------------------------------------------------
-- Ensure system-style messages (e.g. GUILD_MOTD) also get clickable URLs
-------------------------------------------------
-- notes: Some messages (guild MOTD, addon prints, certain system lines) are written directly via ChatFrame:AddMessage
-- notes: and do NOT go through CHAT_MSG_* filters. We wrap AddMessage to catch those too.
-- notes: ElvUI replaces the ChatFrame system but correctly passes messages through CHAT_MSG_* filters,
-- notes: so the AddMessage hook is not needed (and causes triple-message display) when ElvUI is active.
local function _CL_IsElvUIActive()
    return _G.ElvUI ~= nil
end

local HookCommunitiesFramesForClickableURLs -- forward declare (used before definition)
local function HookChatFramesForClickableURLs()
    if _CL_IsElvUIActive() then return end
    if HookCommunitiesFramesForClickableURLs then
        HookCommunitiesFramesForClickableURLs()
    end
    if not _G.ChatFrame1 then return end

    for i = 1, (NUM_CHAT_WINDOWS or 0) do
        local cf = _G["ChatFrame" .. i]
        if cf and type(cf.AddMessage) == "function" then
            -- If another addon replaced AddMessage after our hook, re-hook safely.
            if cf.AddMessage ~= cf.__ClickLinks_WrappedAddMessage then
                cf.__ClickLinks_OrigAddMessage = cf.AddMessage
                cf.__ClickLinks_WrappedAddMessage = function(self, text, ...)
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
                    local orig = self.__ClickLinks_OrigAddMessage
                    return orig(self, text, ...)
                end

                cf.AddMessage = cf.__ClickLinks_WrappedAddMessage
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
    if _CL_IsElvUIActive() then return end
    if type(frame.AddMessage) ~= "function" then return end

    -- If another addon/UI code replaces AddMessage later, re-hook safely.
    if frame.AddMessage == frame.__ClickLinks_WrappedAddMessage then return end

    frame.__ClickLinks_OrigAddMessage = frame.AddMessage
    frame.__ClickLinks_WrappedAddMessage = function(self, msg, ...)
        if _CL_CanTreatAsString(msg) and not _CL_SafeFind(msg, "|H", true) then
            local ok, _, newMsg = _CL_SafeCall(makeClickable, self, "MESSAGE_FRAME_ADD_MESSAGE", msg, ...)
            if ok and newMsg then
                msg = newMsg
            end
        end
        local orig = self.__ClickLinks_OrigAddMessage
        return orig(self, msg, ...)
    end

    frame.AddMessage = frame.__ClickLinks_WrappedAddMessage
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

-- Re-hook safety: some UI mods replace ChatFrame:AddMessage after login.
-- We do a short-lived ticker after login to re-apply our hooks if needed.
local __clRehookTicker
local function _CL_StartRehookTicker()
    if __clRehookTicker then return end
    if not (C_Timer and C_Timer.NewTicker) then return end
    local ticks = 0
    __clRehookTicker = C_Timer.NewTicker(5, function()
        ticks = ticks + 1
        HookChatFramesForClickableURLs()
        HookCommunitiesFramesForClickableURLs()
        if _G.ClickLinks_EnsureSetItemRefHook then _G.ClickLinks_EnsureSetItemRefHook() end
        if ticks >= 12 then -- ~60 seconds
            __clRehookTicker:Cancel()
            __clRehookTicker = nil
        end
    end)
end
local __clHookFrame = CreateFrame("Frame")
__clHookFrame:RegisterEvent("PLAYER_LOGIN")
__clHookFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
__clHookFrame:RegisterEvent("ADDON_LOADED")
__clHookFrame:SetScript("OnEvent", function(_, event, addonName)
    HookChatFramesForClickableURLs()
	if event == "PLAYER_LOGIN" then _CL_StartRehookTicker() end
    if _G.ClickLinks_EnsureSetItemRefHook then _G.ClickLinks_EnsureSetItemRefHook() end
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
-- Copy popup
-------------------------------------------------
-- notes:
--   WoW addons cannot write to the OS clipboard. We show a small edit box with the URL
--   selected and focused so the user can press Ctrl+C.

local function _CL_EnsureCopyBox()
    ClickLinksDB = ClickLinksDB or {}
    if _G.ClickLinks_CopyBox and _G.ClickLinks_CopyBox.editBox then return _G.ClickLinks_CopyBox end

    local template = (BackdropTemplateMixin and "BackdropTemplate") or nil
    local f = CreateFrame("Frame", "ClickLinks_CopyBox", UIParent, template)
    f:SetFrameStrata("DIALOG")
    f:SetSize(420, 70)
    if ClickLinksDB.copyBoxPos and type(ClickLinksDB.copyBoxPos.x) == "number" then
        f:SetPoint(
            ClickLinksDB.copyBoxPos.point,
            UIParent,
            ClickLinksDB.copyBoxPos.relativePoint,
            ClickLinksDB.copyBoxPos.x,
            ClickLinksDB.copyBoxPos.y
        )
    else
        f:SetPoint("CENTER")
    end
    f:Hide()
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()

        local point, _, relativePoint, x, y = self:GetPoint()
        ClickLinksDB.copyBoxPos = {
            point = point,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end)

    if f.SetBackdrop then
        f:SetBackdrop({
			bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
		f:SetBackdropColor(0, 0, 0, 0.95)   -- solid dark background
		f:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    end

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOP", 0, -10)
    title:SetText(L["COPYBOX_TITLE"] or "Copy Link")

    local hint = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("BOTTOM", 0, 10)
    hint:SetText(L["COPYBOX_HINT"] or "Press Ctrl+C to copy link")
	
    -- Don't auto-hide on focus loss (dragging/clicking can steal focus)
    -- Don't re-highlight on every change (prevents cursor placement)
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)

    local eb = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    eb:SetAutoFocus(true)
    eb:SetSize(380, 24)
    eb:SetPoint("CENTER", 0, -2)
    eb:SetScript("OnEscapePressed", function() f:Hide() end)
    eb:SetScript("OnEnterPressed", function() f:Hide() end)
	
    f.editBox = eb
    return f
end

local function _CL_ShowCopyBox(text)
    local f = _CL_EnsureCopyBox()
    if not f or not f.editBox then return end
    f:Show()
    f.editBox:SetText(text or "")
    -- Slight delay ensures focus isn't stolen by other UI hooks
    C_Timer.After(0, function()
        if f:IsShown() and f.editBox then
            f.editBox:SetFocus()
            f.editBox:HighlightText()
        end
    end)
end

local _AddToJournal -- forward declared (used by URL hooks)

--[[-------------------------------------------------------------------------
ElvUI (and some other UI mods) may replace ItemRefTooltip:SetHyperlink after we
hook it, which can prevent our URL popup from firing. Hooking SetItemRef is
more reliable because it runs when a hyperlink is clicked.
---------------------------------------------------------------------------]]

-- Keep original for non-url links; we will re-capture if another addon replaces SetItemRef.
local _OriginalSetItemRef

-- Capture a base fallback the first time we ever run, before other addons start
-- swapping SetItemRef around.
_G.ClickLinks_OriginalSetItemRef_Base = _G.ClickLinks_OriginalSetItemRef_Base or _G.SetItemRef

-- Wrapper is defined once. We only swap _OriginalSetItemRef as other addons replace SetItemRef.
_G.ClickLinks_SetItemRef_Wrapper = _G.ClickLinks_SetItemRef_Wrapper or function(link, text, button, chatFrame)
    -- Prevent infinite recursion if load-order causes _OriginalSetItemRef to point back at us.
    if _G.__ClickLinks_InSetItemRef then
        local fallback = _G.ClickLinks_OriginalSetItemRef_Base
        if fallback and fallback ~= _G.ClickLinks_SetItemRef_Wrapper then
            return fallback(link, text, button, chatFrame)
        end
        return
    end

    if type(link) == "string" and link:match("^url:") then
        local u = link:sub(5):gsub("||", "|")
        _AddToJournal(u)
        _CL_ShowCopyBox(u)
        return
    end

    local orig = _OriginalSetItemRef or _G.ClickLinks_OriginalSetItemRef_Base
    if not orig or orig == _G.ClickLinks_SetItemRef_Wrapper then
        orig = _G.ClickLinks_OriginalSetItemRef_Base
    end

    _G.__ClickLinks_InSetItemRef = true
    local ok, r1, r2, r3, r4 = pcall(orig, link, text, button, chatFrame)
    _G.__ClickLinks_InSetItemRef = false

    if ok then
        return r1, r2, r3, r4
    end
end

_G.ClickLinks_EnsureSetItemRefHook = function()
    -- On modern clients, avoid overriding the global SetItemRef entirely.
    -- Overriding can taint the chat popup menu flow and break protected clipboard actions (Copy Character Name).
    if _G.hooksecurefunc then
        if _G.__ClickLinks_SetItemRefHooked then
            return
        end

        _G.__ClickLinks_SetItemRefHooked = true

        hooksecurefunc("SetItemRef", function(link, text, button, chatFrame)
            if type(link) == "string" and link:match("^url:") then
                local u = link:sub(5):gsub("||", "|")
                _AddToJournal(u)
                _CL_ShowCopyBox(u)
            end
        end)

        return
    end

    -- Legacy fallback (no hooksecurefunc): keep the previous wrapper swap logic.
    local current = _G.SetItemRef
    if current == _G.ClickLinks_SetItemRef_Wrapper then
        return
    end

    -- Don't allow "original" to ever be our wrapper.
    _OriginalSetItemRef = current
    if not _OriginalSetItemRef or _OriginalSetItemRef == _G.ClickLinks_SetItemRef_Wrapper then
        _OriginalSetItemRef = _G.ClickLinks_OriginalSetItemRef_Base
    end

    _G.SetItemRef = _G.ClickLinks_SetItemRef_Wrapper
end

-- Call once now, and again after other addons load (eg. ElvUI) to keep our hook active.
_G.ClickLinks_EnsureSetItemRefHook()

-- (Optional) Keep the ItemRefTooltip hook as a secondary path for clients that call it directly.
local OriginalSetHyperlink = ItemRefTooltip.SetHyperlink
function ItemRefTooltip:SetHyperlink(link)
    if type(link) == "string" and link:match("^url:") then
        local u = link:sub(5):gsub("||", "|")
        _AddToJournal(u)
        _CL_ShowCopyBox(u)
    else
        if type(OriginalSetHyperlink) == "function" then
            local ok = pcall(OriginalSetHyperlink, self, link)
            if ok then return end
        end
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
ClickLinksDB.copyBoxPos = ClickLinksDB.copyBoxPos or nil

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
    url = tostring(url or "")
    url = url:gsub("||", "|")
    url = url:gsub("%s+$", ""):gsub("^%s+", "")
    if url == "" then return end

    local j = ClickLinksDB.journal

    -- De-duplicate: if URL already exists anywhere, remove old entry(ies) and re-add as newest.
    for i = #j, 1, -1 do
        local e = j[i]
        if e and e.url == url then
            table.remove(j, i)
        end
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
                        local idxToRemove = self._journalIndex
                        local entry = idxToRemove and ClickLinksDB.journal[idxToRemove]
                        if entry and entry.url == self._url and entry.t == self._ts then
                            table.remove(ClickLinksDB.journal, idxToRemove)
                        else
                            -- fallback for legacy rows/state drift
                            for k = #ClickLinksDB.journal, 1, -1 do
                                local e = ClickLinksDB.journal[k]
                                if e and e.url == self._url and e.t == self._ts then
                                    table.remove(ClickLinksDB.journal, k)
                                    break
                                end
                            end
                        end
                        _UpdateJournalUI()
                    else
                        _CL_ShowCopyBox(url)
                    end
                end)

                JournalButtons[idx] = btn
            end

            local ts = _FormatTime(entry.t)
            local display = entry.url or ""
            if #display > 300 then display = display:sub(1, 300) .. "..." end

            btn._url = entry.url
            btn._ts = entry.t
            btn._journalIndex = i
            btn.text:SetText((ts ~= "" and ("|cffaaaaaa" .. ts .. "|r  ") or "") .. "|cff00ccff" .. display .. "|r")
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
    ver = tostring(ver or "")
    local a, b, c = ver:match("(%d+)%.(%d+)%.(%d+)")
    if not a then
        a, b = ver:match("(%d+)%.(%d+)")
        c = 0
    end
    if not a then return 0 end
    return tonumber(a) * 10000 + tonumber(b) * 100 + tonumber(c)
end

local localVerNum = VersionToNumber(localVersion)

local _CL_RegisterAddonMessagePrefix = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix
local _CL_SendAddonMessage = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage

-- notes: Must register prefix before sending/receiving addon messages.
if type(_CL_RegisterAddonMessagePrefix) == "function" then
    _CL_RegisterAddonMessagePrefix(PREFIX)
end

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
    if type(_CL_SendAddonMessage) ~= "function" then
        return
    end

    if IsInGuild() then
        _CL_SendAddonMessage(PREFIX, localVersion, "GUILD")
    end
    if IsInRaid() or IsInGroup() then
        if not sentVersionThisGroup then
            local channel = IsInRaid() and "RAID" or "PARTY"
            _CL_SendAddonMessage(PREFIX, localVersion, channel)
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

    -- /cl pvp removed: PvP auto-disable no longer needed in Retail 12.x

    else
        print("|cff149bfd" .. L["ADDON_NAME"] .. "|r")
        print("|cffffcc00" .. L["HELP_LINE_VERSION"] .. "|r")
        print("|cffffcc00" .. L["HELP_LINE_JOURNAL"] .. "|r")
        print("|cffffcc00" .. L["HELP_LINE_MINIMAP"] .. "|r")
    end
end
