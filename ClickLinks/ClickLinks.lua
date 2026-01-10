-- File: ClickLinks.lua
-- Name: Click Links
-- Original Author: tannerng
-- Continued by : Milestorme
-- Description: Makes URLs clickable + automatic version checking
-- notes: Adds clickable URL links to chat, plus in-game version announcement + one-time update warning.

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

-------------------------------------------------
-- Chat message filter
-------------------------------------------------
local function makeClickable(self, event, msg, ...)
    -- notes: ChatFrame_AddMessageEventFilter callback.
    -- notes: Performs a cheap pre-check, then gsubs all URL patterns into clickable links.
    -- notes: Returns (false, msg, ...) so the message continues through normal rendering.

    -- If the line already contains hyperlinks (items/spells/etc), don't touch it.
    -- This avoids edge-case corruption and plays nicer with other chat addons.
    if msg and msg:find("|H") then
        return false, msg, ...
    end

    -- Quick pre-check to avoid unnecessary gsub
    -- Note: include IP-only links like 123.45.67.89:28015 which don't contain "://", "www.", or "@".
    if not msg
        or (not msg:find("://")
            and not msg:find("www%.")
            and not msg:find("@")
            and not msg:find("%d+%.%d+%.%d+%.%d+"))
    then
        return false, msg, ...
    end

    for _, pattern in ipairs(URL_PATTERNS) do
        msg = msg:gsub(pattern, formatURL)
    end
    return false, msg, ...
end

local CHAT_TYPES = {
    -- notes: Chat event suffixes to attach the filter to. "SYSTEM" included for system messages too.
    "AFK","BATTLEGROUND_LEADER","BATTLEGROUND","BN_WHISPER","BN_WHISPER_INFORM",
    "CHANNEL","COMMUNITIES_CHANNEL","DND","EMOTE","GUILD","OFFICER","PARTY_LEADER",
    "PARTY","RAID_LEADER","RAID_WARNING","RAID","SAY","WHISPER","WHISPER_INFORM","YELL","SYSTEM"
}

for _, chatType in ipairs(CHAT_TYPES) do
    -- notes: Registers message filter for each chat channel/event type.
    ChatFrame_AddMessageEventFilter("CHAT_MSG_" .. chatType, makeClickable)
end

-------------------------------------------------
-- StaticPopup for copying URLs
-------------------------------------------------
-- notes: Popup with editbox: user can Ctrl+C the URL.
StaticPopupDialogs["CLICK_LINK_CLICKURL"] = {
    text = "Press Ctrl+C to copy link",
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

local OriginalSetHyperlink = ItemRefTooltip.SetHyperlink
function ItemRefTooltip:SetHyperlink(link)
    -- notes: Hook ItemRefTooltip hyperlink handler.
    -- notes: Intercepts our custom "url:" hyperlinks and shows copy popup; otherwise passes through.
    if link:match("^url:") then
        StaticPopup_Show("CLICK_LINK_CLICKURL", nil, nil, { url = link:sub(5) })
    else
        OriginalSetHyperlink(self, link)
    end
end

-------------------------------------------------
-- Automatic Version Check
-------------------------------------------------
local ADDON_NAME = ...
local PREFIX = "CLICKLINKS_VER"

-- notes: SavedVariables: stores a one-time warning flag so users don't get spammed repeatedly.
ClickLinksDB = ClickLinksDB or { warned = false }

-- notes: Localization-ready strings (single table).
local L = {
    ADDON_NAME = "Click Links",
    UPDATE_AVAILABLE = "A newer version is available.",
    YOUR_VERSION = "Your version:",
    NEWER_VERSION = "Newer version detected:",
    UPDATE_HINT = "Please update via CurseForge.",
    VERSION_CMD = "Addon version:",
}

-- notes: Reads the addon Version field from the TOC metadata.
local localVersion = ((C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata)(ADDON_NAME, "Version") or "0"

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
            print("|cffff0000" .. L.ADDON_NAME .. ":|r " .. L.UPDATE_AVAILABLE)
            print("|cffffcc00" .. L.YOUR_VERSION .. "|r", localVersion)
            print("|cffffcc00" .. L.NEWER_VERSION .. "|r", message)
            print("|cffffcc00" .. L.UPDATE_HINT .. "|r")
        end
    end
end)

-------------------------------------------------
-- Slash Commands
-------------------------------------------------
SLASH_CLICKLINKS1 = "/clicklinks"
SLASH_CLICKLINKS2 = "/cl"

SlashCmdList["CLICKLINKS"] = function(msg)
    -- notes: Slash handler. Supports: "version" and "ver" (short alias).
    msg = msg and msg:lower() or ""

    if msg == "version" or msg == "ver" then
        print("|cff149bfd" .. L.ADDON_NAME .. "|r")
        print("|cffffcc00" .. L.VERSION_CMD .. "|r", localVersion)
    else
        print("|cff149bfd" .. L.ADDON_NAME .. "|r")
        print("|cffffcc00/clicklinks version|r - Show addon version")
    end
end
