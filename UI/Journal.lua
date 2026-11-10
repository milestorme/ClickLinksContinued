-- Modern dark Journal: native WoW frames, no external UI dependency.
ClickLinks = ClickLinks or {}
ClickLinks.UI = ClickLinks.UI or {}
local UI=ClickLinks.UI
local L=LibStub("AceLocale-3.0"):GetLocale("ClickLinks")
local frame, scroll, content, search, rows, status
local tab="all"
local sort="recent"
local ROW_H=39
local function panel(f,r,g,b,a)
    local t=f:CreateTexture(nil,"BACKGROUND")
    t:SetAllPoints();t:SetColorTexture(r,g,b,a or 1)
    return t
end
local function button(parent,label,width,height,handler)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(width,height);b:SetText(label);b:SetScript("OnClick",handler)
    return b
end
local function copyURL(e)
    if type(_G.ClickLinks_ShowCopyBox)=="function" then _G.ClickLinks_ShowCopyBox(e.url)
    elseif ChatEdit_InsertLink then ChatEdit_InsertLink(e.url)
    else print("ClickLinks: "..e.url) end
    ClickLinks.Journal.RecordCopy(e.id)
end
local function makeRow(i)
    local b=CreateFrame("Frame",nil,content)
    b:SetHeight(ROW_H);panel(b,0.10,0.13,0.18,0.96)
    b.label=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    b.label:SetPoint("LEFT",8,0);b.label:SetWidth(330);b.label:SetJustifyH("LEFT")
    b.label:SetWordWrap(false)
    b.copy=button(b,L["COPY"],48,23,function() if b.entry then copyURL(b.entry) end end)
    b.copy:SetPoint("RIGHT",-7,0)
    b.star=button(b,"",28,23,function()
        if b.entry then ClickLinks.Journal.SetFavorite(b.entry.id,not b.entry.favorite) end
    end)
    b.star:SetPoint("RIGHT",b.copy,"LEFT",-4,0)
    -- Use WoW's native raid-target star texture instead of font glyphs,
    -- which render as rectangles in some client fonts.
    b.star.icon=b.star:CreateTexture(nil,"OVERLAY")
    b.star.icon:SetSize(17,17)
    b.star.icon:SetPoint("CENTER",0,0)
    b.star.icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
    b.star:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetText(self.entry and self.entry.favorite
            and L["FAVORITE_REMOVE"] or L["FAVORITE_ADD"])
        GameTooltip:Show()
    end)
    b.star:SetScript("OnLeave",function() GameTooltip:Hide() end)
    b.pin=button(b,"P",26,23,function()
        if b.entry then ClickLinks.Journal.SetPinned(b.entry.id,not b.entry.pinned) end
    end)
    b.pin:SetPoint("RIGHT",b.star,"LEFT",-4,0)
    b.remove=button(b,"X",25,23,function()
        if b.entry then ClickLinks.Journal.Delete(b.entry.id) end
    end)
    b.remove:SetPoint("RIGHT",b.pin,"LEFT",-4,0)
    rows[i]=b
    return b
end
local function getFilters()
    return {query=search and search:GetText() or "",category=(tab=="favorites" or tab=="history") and "all" or tab,
        favoritesOnly=tab=="favorites",historyOnly=tab=="history",sort=sort}
end
function UI.RefreshJournal()
    if not frame or not frame:IsShown() then return end
    local found=ClickLinks.Journal.Search(getFilters())
    local viewHeight=scroll:GetHeight()
    local offset=scroll:GetVerticalScroll() or 0
    local first=math.max(1,math.floor(offset/ROW_H)+1)
    local visible=math.min(18,math.ceil(viewHeight/ROW_H)+2)
    for i=1,visible do
        local row=rows[i] or makeRow(i)
        local entry=found[first+i-1]
        if entry then
            row.entry=entry
            row:SetWidth(math.max(440,scroll:GetWidth()-6))
            row:ClearAllPoints();row:SetPoint("TOPLEFT",content,"TOPLEFT",0,-((first+i-2)*ROW_H))
            local label=(entry.pinned and "|cff62aaff[P]|r " or "")..
                (entry.favorite and "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14:14:0:0|t " or "")..
                "|cff77c9ff"..(entry.title or entry.url).."|r"
            row.label:SetText(label)
            row.star.entry=entry
            row.star.icon:SetDesaturated(not entry.favorite)
            row.star.icon:SetAlpha(entry.favorite and 1 or 0.55)
            row.pin:SetText(entry.pinned and "●" or "P")
            row:Show()
        else row.entry=nil;row:Hide() end
    end
    for i=visible+1,#rows do rows[i]:Hide() end
    content:SetHeight(math.max(1,#found*ROW_H))
    status:SetText(#found.." "..L["STATUS_LINKS"].."  •  "..L["STATUS_CLICKED"])
end
local function makeUI()
    if frame then return end
    frame=CreateFrame("Frame","ClickLinks_JournalFrame",UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(680,500);frame:SetPoint("CENTER");frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true);frame:EnableMouse(true);frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart",function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
    panel(frame,0.055,0.075,0.11,0.98)
    local title=frame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    title:SetPoint("TOPLEFT",frame,"TOPLEFT",22,-18)
    title:SetText("|cffffd100ClickLinks • "..L["JOURNAL_TITLE"].."|r")
    local close=button(frame,"X",28,24,function() frame:Hide() end)
    close:SetPoint("TOPRIGHT",-12,-12)
    search=CreateFrame("EditBox",nil,frame,"InputBoxTemplate")
    search:SetSize(410,25);search:SetPoint("TOPLEFT",22,-52)
    search:SetAutoFocus(false);search:SetMaxLetters(150)
    search:SetScript("OnTextChanged",function() if UI.RefreshJournal then UI.RefreshJournal() end end)
    search:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    local tabs={{L["TAB_ALL"],"all"},{L["TAB_FAVORITES"],"favorites"},{L["TAB_WOWHEAD"],"wowhead"},
        {L["TAB_WEBSITES"],"websites"},{L["TAB_DISCORD"],"discord"},{L["TAB_HISTORY"],"history"}}
    for i,t in ipairs(tabs) do
        local b=button(frame,t[1],i==2 and 93 or 83,24,function()
            tab=t[2];scroll:SetVerticalScroll(0);UI.RefreshJournal()
        end)
        b:SetPoint("TOPLEFT",18+(i-1)*101,-90)
    end
    local sortBtn=button(frame,L["SORT_LABEL"].." "..L["SORT_RECENT"],125,24,function(self)
        if sort=="recent" then sort="title"
        elseif sort=="title" then sort="oldest"
        elseif sort=="oldest" then sort="copies"
        else sort="recent" end
        self:SetText(L["SORT_LABEL"].." "..L[({recent="SORT_RECENT",title="SORT_TITLE",oldest="SORT_OLDEST",copies="SORT_COPIES"})[sort]]);UI.RefreshJournal()
    end)
    sortBtn:SetPoint("TOPRIGHT",-20,-51)
    scroll=CreateFrame("ScrollFrame",nil,frame,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",18,-129);scroll:SetPoint("BOTTOMRIGHT",-34,54)
    content=CreateFrame("Frame",nil,scroll);content:SetSize(610,1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnVerticalScroll",function(self,offset)
        UI.RefreshJournal()
    end)
    rows={}
    status=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    status:SetPoint("BOTTOMLEFT",20,20)
    local export=button(frame,L["EXPORT"],75,24,function()
        local text=ClickLinks.Journal.Export(getFilters())
        if type(_G.ClickLinks_ShowCopyBox)=="function" then _G.ClickLinks_ShowCopyBox(text)
        else print("ClickLinks: "..L["EXPORT_UNAVAILABLE"]) end
    end)
    export:SetPoint("BOTTOMRIGHT",-18,14)
    local clear=button(frame,L["CLEAR_UNPINNED"],120,24,function()
        StaticPopupDialogs["CLICKLINKS23_CLEAR"]={
            text=L["CLEAR_UNPINNED_CONFIRM"],
            button1=YES or "Yes",button2=NO or "No",
            OnAccept=function() ClickLinks.Journal.Clear(false) end,
            timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3
        }
        StaticPopup_Show("CLICKLINKS23_CLEAR")
    end)
    clear:SetPoint("RIGHT",export,"LEFT",-8,0)
    frame:Hide()
end
function UI.OpenJournal()
    makeUI();frame:Show();UI.RefreshJournal()
end
function UI.ToggleJournal()
    makeUI()
    if frame:IsShown() then frame:Hide() else UI.OpenJournal() end
end
