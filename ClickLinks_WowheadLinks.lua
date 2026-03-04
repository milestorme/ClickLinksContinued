-- File: ClickLinks_WowheadLinks.lua
-- Description: Adds "Copy Wowhead URL" option when right-clicking item, spell, or quest links in chat.
-- Part of the ClickLinks addon.

local L = LibStub("AceLocale-3.0"):GetLocale("ClickLinks")

-------------------------------------------------
-- Wowhead URL bases
-------------------------------------------------
local WOWHEAD_URLS = {
    item    = "https://www.wowhead.com/item=",
    spell   = "https://www.wowhead.com/spell=",
    quest   = "https://www.wowhead.com/quest=",
    achievement = "https://www.wowhead.com/achievement=",
    currency = "https://www.wowhead.com/currency=",
}

-------------------------------------------------
-- Dropdown menu frame (created once, reused)
-------------------------------------------------
local dropdown = CreateFrame("Frame", "ClickLinks_WowheadDropdown", UIParent, "UIDropDownMenuTemplate")

-------------------------------------------------
-- Build and show the context menu
-------------------------------------------------
local function ShowWowheadMenu(wowheadURL)
    local function InitializeMenu(self, level)
        if not level then return end

        local info = UIDropDownMenu_CreateInfo()
        info.text = L["WOWHEAD_COPY_URL"] or "Copy Wowhead URL"
        info.notCheckable = true
        info.func = function()
            -- Save to journal and reuse ClickLinks' copy box
            if _G.ClickLinks_AddToJournal then
                _G.ClickLinks_AddToJournal(wowheadURL)
            end
            if _G.ClickLinks_ShowCopyBox then
                _G.ClickLinks_ShowCopyBox(wowheadURL)
            end
        end
        UIDropDownMenu_AddButton(info, level)

        info = UIDropDownMenu_CreateInfo()
        info.text = L["CANCEL"] or "Cancel"
        info.notCheckable = true
        info.func = function() end
        UIDropDownMenu_AddButton(info, level)
    end

    UIDropDownMenu_Initialize(dropdown, InitializeMenu, "MENU")
    ToggleDropDownMenu(1, nil, dropdown, "cursor", 0, 0)
end

-------------------------------------------------
-- Extract ID and build URL from a hyperlink string
-------------------------------------------------
local function GetWowheadURL(link)
    -- Standard link types: item:ID, spell:ID, quest:ID, etc.
    for linkType, baseURL in pairs(WOWHEAD_URLS) do
        local pattern = "^" .. linkType .. ":(%d+)"
        local id = tonumber(string.match(link, pattern))
        if id then
            return baseURL .. id
        end
    end

    -- Profession / tradeskill links: trade:SPELLID:... or trade:GUID:SPELLID:...
    -- The spell ID in trade links maps to wowhead.com/spell=
    if string.sub(link, 1, 6) == "trade:" then
        local rest = string.sub(link, 7)
        -- Try each colon-separated field for a valid spell ID (numeric, > 0)
        for field in string.gmatch(rest, "([^:]+)") do
            local id = tonumber(field)
            if id and id > 0 then
                return WOWHEAD_URLS.spell .. id
            end
        end
    end

    -- Enchant links: enchant:SPELLID (these are spells on Wowhead)
    if string.sub(link, 1, 8) == "enchant:" then
        local id = tonumber(string.match(link, "^enchant:(%d+)"))
        if id then
            return WOWHEAD_URLS.spell .. id
        end
    end

    return nil
end

-------------------------------------------------
-- Supported link prefixes for right-click detection
-------------------------------------------------
local SUPPORTED_PREFIXES = {
    "item:",
    "spell:",
    "quest:",
    "achievement:",
    "currency:",
    "trade:",
    "enchant:",
}

local function IsSupportedLink(link)
    for _, prefix in ipairs(SUPPORTED_PREFIXES) do
        if string.sub(link, 1, #prefix) == prefix then
            return true
        end
    end
    return false
end

-------------------------------------------------
-- Right-click handler (shared by all hooks)
-------------------------------------------------
-- Debug mode: set ClickLinks_WowheadDebug = true in chat with:
--   /run ClickLinks_WowheadDebug = true
-- to see which links are being detected on right-click.
local function HandleRightClick(link)
    if type(link) ~= "string" then return end

    if _G.ClickLinks_WowheadDebug then
        print("|cff00ff00[WowheadLinks Debug]|r Right-click detected: " .. link)
        print("|cff00ff00[WowheadLinks Debug]|r Supported: " .. tostring(IsSupportedLink(link)))
    end

    if not IsSupportedLink(link) then return end

    local wowheadURL = GetWowheadURL(link)

    if _G.ClickLinks_WowheadDebug then
        print("|cff00ff00[WowheadLinks Debug]|r URL: " .. tostring(wowheadURL))
    end

    if wowheadURL then
        -- Close any Blizzard context menus (quest share/track, etc.)
        -- then show ours after a short delay so it doesn't get clobbered.
        CloseDropDownMenus()
        C_Timer.After(0.0, function()
            CloseDropDownMenus()
            ShowWowheadMenu(wowheadURL)
        end)
    end
end

-------------------------------------------------
-- Primary hook: ChatFrame OnHyperlinkClick
-------------------------------------------------
-- This fires directly from the chat frame when any hyperlink is clicked,
-- before link-type-specific handling. More reliable than SetItemRef for
-- link types like trade: and enchant: which WoW may handle differently.

local hookedFrames = {}

local function HookChatFrame(chatFrame)
    if not chatFrame or hookedFrames[chatFrame] then return end
    hookedFrames[chatFrame] = true
    chatFrame:HookScript("OnHyperlinkClick", function(self, link, text, button)
        if _G.ClickLinks_WowheadDebug then
            print("|cff00ff00[WowheadLinks Debug]|r OnHyperlinkClick: button=" .. tostring(button) .. " link=" .. tostring(link))
        end
        if button == "RightButton" then
            HandleRightClick(link)
        end
    end)
end

local function HookAllChatFrames()
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame" .. i]
        if cf then
            HookChatFrame(cf)
        end
    end
end

-- Hook now (covers frames that already exist)
HookAllChatFrames()

-- Re-hook after login and when new frames may appear
local hookFrame = CreateFrame("Frame")
hookFrame:RegisterEvent("PLAYER_LOGIN")
hookFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
hookFrame:SetScript("OnEvent", function()
    HookAllChatFrames()
end)

-------------------------------------------------
-- Fallback hook: SetItemRef
-------------------------------------------------
-- Catches links clicked outside of standard chat frames (e.g. Communities UI)
hooksecurefunc("SetItemRef", function(link, text, button, chatFrame)
    if _G.ClickLinks_WowheadDebug then
        print("|cff00ff00[WowheadLinks Debug]|r SetItemRef: button=" .. tostring(button) .. " link=" .. tostring(link))
    end
    if button == "RightButton" then
        HandleRightClick(link)
    end
end)
