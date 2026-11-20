-- Explicit opt-in sharing. Incoming messages are never saved automatically.
ClickLinks = ClickLinks or {}
local L = LibStub("AceLocale-3.0"):GetLocale("ClickLinks")
local S = {}
ClickLinks.Sharing = S
local PREFIX="CLKLNK23"
local MAX_PENDING = 10
local pendingQueue = {}
local senderLast = {}
local function clock() return (type(time) == "function" and time()) or 0 end
local function refreshPending() S.pending = pendingQueue[1] end
local register=(C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix
local send=(C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
function S.Initialize()
    if type(register)=="function" then pcall(register,PREFIX) end
end
function S.Send(id,channel)
    if not ClickLinksDB.settings.sharingEnabled then return nil,"sharing_disabled" end
    if channel~="PARTY" and channel~="RAID" and channel~="GUILD" then return nil,"unsupported_channel" end
    local entry=ClickLinks.Journal.Get(id)
    if not entry then return nil,"not_found" end
    if type(entry.url) ~= "string" or #entry.url>210 then return nil,"url_too_long" end
    if not ClickLinks.Security.Analyze(entry.url).allowed then return nil,"unsafe_payload" end
    if type(send)~="function" then return nil,"api_unavailable" end
    local ok=pcall(send,PREFIX,"1|"..entry.url,channel)
    return ok or nil,ok and nil or "send_failed"
end
function S.Receive(sender,payload,channel)
    if not ClickLinksDB.settings.sharingEnabled then return nil,"sharing_disabled" end
    if channel ~= nil and channel ~= "PARTY" and channel ~= "RAID" and channel ~= "GUILD" and channel ~= "INSTANCE_CHAT" then return nil,"unsupported_channel" end
    if type(sender) ~= "string" or sender == "" then return nil,"invalid_sender" end
    if type(payload)~="string" then return nil,"invalid_payload" end
    local ok,version,url=pcall(function() return payload:match("^(%d+)|(.+)$") end)
    if not ok or version~="1" or not url or #url>210 then return nil,"invalid_payload" end
    local check=ClickLinks.Security.Analyze(url)
    if not check.allowed then return nil,"unsafe_payload" end
    local t = clock()
    if t > 0 and senderLast[sender] and t - senderLast[sender] < 3 then return nil,"rate_limited" end
    for _, item in ipairs(pendingQueue) do
        if item.sender == sender and item.url == url then return nil,"duplicate_pending" end
    end
    if #pendingQueue >= MAX_PENDING then return nil,"pending_full" end
    senderLast[sender] = t
    pendingQueue[#pendingQueue+1] = {sender=sender,url=url,receivedAt=t}
    refreshPending()
    print("|cff55b8ffClickLinks:|r "..string.format(L["RECEIVED_LINK"],tostring(sender)))
    return true
end
function S.Accept()
    if not S.pending then return nil,"no_pending_link" end
    local pending=table.remove(pendingQueue,1)
    refreshPending()
    return ClickLinks.Journal.Add(pending.url)
end
function S.Reject() table.remove(pendingQueue,1); refreshPending() end
