-- File: ClickLinks.lua
-- Name: Click Links Continued
-- Original Author: tannerng
-- Updated by : Milestorme
-- Description: Makes URLs clickable
-- Version: 1.0.10 (Fully fixed working on all game versions)

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
    "%f[%S]([0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d%.[0-2]?%d?%d)%f[%D]",
    
    -- x.y.z shit disabled for now, probabaly forever
    --"^([-%w_%%]+%.[-%w_%%]+%.(%a%a+))",
    --"%f[%S]([-%w_%%]+%.[-%w_%%]+%.(%a%a+))",
    --"^([-%w_%%]+%.(%a%a+))",
    --"%f[%S]([-%w_%%]+%.(%a%a+))"
}

function formatURL(url)
    return "|cff149bfd|Hurl:" .. url .. "|h[" .. url .. "]|h|r "
end

-------------------------------------------------
-- Proper gsub capture handling
-------------------------------------------------
function makeClickable(self, event, msg, ...)
    for _, p in pairs(URL_PATTERNS) do
        msg = msg:gsub(p, function(url)
            return formatURL(url)
        end)
    end
    return false, msg, ...
end
-------------------------------------------------

-------------------------------------------------
-- StaticPopup handling
-------------------------------------------------
StaticPopupDialogs["CLICK_LINK_CLICKURL"] = {
    text = "Copy & Paste the link into your browser",
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
-------------------------------------------------

local OriginalSetHyperlink = ItemRefTooltip.SetHyperlink
function ItemRefTooltip:SetHyperlink(link)
    if link:sub(1, 3) == "url" then
        local url = link:sub(5)
        StaticPopup_Show("CLICK_LINK_CLICKURL", nil, nil, { url = url })
    else
        OriginalSetHyperlink(self, link)
    end
end

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
