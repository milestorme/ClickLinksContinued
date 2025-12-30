-- File: ClickLinks.lua
-- Name: Click Links
-- Original Author: tannerng
-- Continued by : Milestorme
-- Description: Makes URLs clickable + automatic version checking
-- Version: 1.0.18

URL_PATTERNS = {
    -- X://Y most urls
    "^(%a[%w+.-]+://%S+)",
    "%f[%S](%a[%w+.-]+://%S+)",
    -- www.X.Y domain and path
    "^(www%.[-%w_%%]+%.(%a%a+)/%S+)",
    "%f[%S](www%.[-%w_%%]+%.(%a%a+)/%S+)",
    -- www.X.Y domain
    "^(www%.[-%w_%%]+%.(%a%a+))",
    "%f[%S](www%.[-%w_%%]+%.(%a%a+))",
    -- emaild
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
    return "|cff149bfd|Hurl:" .. url .. "|h[" .. url .. "]|h|r "
end

local function makeClickable(self, event, msg, ...)
    for _, pattern in pairs(URL_PATTERNS) do
        msg = msg:gsub(pattern, function(url)
            return formatURL(url)
        end)
    end
    return false, msg, ...
end

-------------------------------------------------
-- StaticPopup for copying URLs
-------------------------------------------------
StaticPopupDialogs["CLICK_LINK_CLICKURL"] = {
    text = "Press Ctrl+C to copy link",
    button1 = CLOSE,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    hasEditBox = true,

    OnShow = function(self)
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
    if link:sub(1, 3) == "url" then
        StaticPopup_Show("CLICK_LINK_CLICKURL", nil, nil, {
            url = link:sub(5)
        })
    else
        OriginalSetHyperlink(self, link)
    end
end

-------------------------------------------------
-- Chat Filters
-------------------------------------------------
local CHAT_TYPES = {
    "AFK",
    "BATTLEGROUND_LEADER",
    "BATTLEGROUND",
    "BN_WHISPER",
    "BN_WHISPER_INFORM",
    "CHANNEL",
    "COMMUNITIES_CHANNEL",
    "DND",
    "EMOTE",
    "GUILD",
    "OFFICER",
    "PARTY_LEADER",
    "PARTY",
    "RAID_LEADER",
    "RAID_WARNING",
    "RAID",
    "SAY",
    "WHISPER",
    "WHISPER_INFORM",
    "YELL",
    "SYSTEM"
}

for _, chatType in pairs(CHAT_TYPES) do
    ChatFrame_AddMessageEventFilter("CHAT_MSG_" .. chatType, makeClickable)
end

-------------------------------------------------
-- Automatic Version Check
-------------------------------------------------
local ADDON_NAME = ...
local PREFIX = "CLICKLINKS_VER"

ClickLinksDB = ClickLinksDB or {
    warned = false,
}

local L = {
    ADDON_NAME = "Click Links",
    UPDATE_AVAILABLE = "A newer version is available.",
    YOUR_VERSION = "Your version:",
    NEWER_VERSION = "Newer version detected:",
    UPDATE_HINT = "Please update via CurseForge.",
    VERSION_CMD = "Addon version:",
}

local localVersion = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "0"

local function VersionToNumber(ver)
    local a, b, c = ver:match("(%d+)%.(%d+)%.(%d+)")
    if not a then return 0 end
    return a * 10000 + b * 100 + c
end

local localVerNum = VersionToNumber(localVersion)
C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_ADDON")

f:SetScript("OnEvent", function(_, event, prefix, message)
    if event == "PLAYER_LOGIN" then
        if IsInGuild() then
            C_ChatInfo.SendAddonMessage(PREFIX, localVersion, "GUILD")
        end
        if IsInGroup() then
            C_ChatInfo.SendAddonMessage(PREFIX, localVersion, "PARTY")
        end
		if IsInRaid() then
			C_ChatInfo.SendAddonMessage(PREFIX, localVersion, "RAID")
		end
    elseif event == "CHAT_MSG_ADDON" and prefix == PREFIX then
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
    msg = msg and msg:lower() or ""

    if msg == "version" or msg == "ver" then
        print("|cff149bfd" .. L.ADDON_NAME .. "|r")
        print("|cffffcc00" .. L.VERSION_CMD .. "|r", localVersion)
    else
        print("|cff149bfd" .. L.ADDON_NAME .. "|r")
        print("|cffffcc00/clicklinks version|r - Show addon version")
    end
end
