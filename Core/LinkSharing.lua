-- Explicit opt-in sharing. Incoming messages are never saved automatically.
ClickLinks = ClickLinks or {}
local L = LibStub("AceLocale-3.0"):GetLocale("ClickLinks")
local S = {}
ClickLinks.Sharing = S
local PREFIX="CLKLNK23"
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
    if #entry.url>210 then return nil,"url_too_long" end
    if type(send)~="function" then return nil,"api_unavailable" end
    local ok=pcall(send,PREFIX,"1|"..entry.url,channel)
    return ok or nil,ok and nil or "send_failed"
end
function S.Receive(sender,payload)
    if not ClickLinksDB.settings.sharingEnabled then return nil,"sharing_disabled" end
    if type(payload)~="string" then return nil,"invalid_payload" end
    local ok,version,url=pcall(function() return payload:match("^(%d+)|(.+)$") end)
    if not ok or version~="1" or not url or #url>210 then return nil,"invalid_payload" end
    local check=ClickLinks.Security.Analyze(url)
    if not check.allowed then return nil,"unsafe_payload" end
    S.pending={sender=sender,url=url}
    print("|cff55b8ffClickLinks:|r "..string.format(L["RECEIVED_LINK"],tostring(sender)))
    return true
end
function S.Accept()
    if not S.pending then return nil,"no_pending_link" end
    local pending=S.pending
    S.pending=nil
    return ClickLinks.Journal.Add(pending.url)
end
function S.Reject() S.pending=nil end
