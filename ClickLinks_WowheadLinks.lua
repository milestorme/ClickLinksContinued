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
    -- Try each supported link type
    for linkType, baseURL in pairs(WOWHEAD_URLS) do
        local pattern = linkType .. ":(%d+)"
        local id = tonumber(string.match(link, pattern))
        if id then
            return baseURL .. id
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
-- Hook SetItemRef for right-click on supported links
-------------------------------------------------
hooksecurefunc("SetItemRef", function(link, text, button, chatFrame)
    if button ~= "RightButton" then return end
    if type(link) ~= "string" then return end
    if not IsSupportedLink(link) then return end

    local wowheadURL = GetWowheadURL(link)
    if wowheadURL then
        ShowWowheadMenu(wowheadURL)
    end
end)
