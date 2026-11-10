ClickLinks = ClickLinks or {}
ClickLinks.Security = {}
local S=ClickLinks.Security
local function domainMatches(host,domain)
    return host==domain or host:sub(-#domain-1)=="."..domain
end
function S.Analyze(url)
    local normalized,err=ClickLinks.Journal.Normalize(url)
    if not normalized then return {allowed=false,severity="blocked",reasons={err}} end
    local host=ClickLinks.Journal.Host(normalized)
    if not host then return {allowed=false,severity="blocked",reasons={"invalid_host"}} end
    for domain,enabled in pairs(ClickLinksDB.blockedDomains or {}) do
        if enabled and domainMatches(host,domain:lower()) then
            return {allowed=false,severity="blocked",reasons={"blocked_domain"}}
        end
    end
    local reasons={}
    if normalized:match("^https?://[^/]*@") then reasons[#reasons+1]="embedded_credentials" end
    if host:match("^%d+%.%d+%.%d+%.%d+$") then reasons[#reasons+1]="numeric_ip_host" end
    local trusted=false
    for domain,enabled in pairs(ClickLinksDB.trustedDomains or {}) do
        if enabled and domainMatches(host,domain:lower()) then trusted=true;break end
    end
    return {allowed=true,severity=(#reasons>0 and not trusted) and "warning" or "none",
            reasons=(trusted and {}) or reasons}
end
function S.IsBlocked(host)
    if type(host)~="string" then return false end
    for domain,enabled in pairs(ClickLinksDB.blockedDomains or {}) do
        if enabled and domainMatches(host:lower(),domain:lower()) then return true end
    end
    return false
end
