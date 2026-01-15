-- Minimal AceLocale-3.0 implementation (vendored for ClickLinks)
-- Provides: LibStub("AceLocale-3.0"):NewLocale(), :GetLocale()
-- Supports enUS base/fallback and per-locale overrides.
-- Compatible with common AceLocale patterns: value == true => key.

local MAJOR, MINOR = "AceLocale-3.0", 1
local LibStub = LibStub
if not LibStub then error(MAJOR .. " requires LibStub.") end

local AceLocale, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not AceLocale then return end

AceLocale.apps = AceLocale.apps or {} -- appName -> { locales = { [locale] = tbl }, base = tbl, baseLocale = "enUS" }

local function normalize_value(key, val)
    if val == true then return key end
    return val
end

function AceLocale:NewLocale(appName, locale, isDefault)
    if type(appName) ~= "string" or appName == "" then error("NewLocale: appName must be a non-empty string") end
    if type(locale) ~= "string" or locale == "" then error("NewLocale: locale must be a non-empty string") end

    local app = self.apps[appName]
    if not app then
        app = { locales = {}, base = nil, baseLocale = nil }
        self.apps[appName] = app
    end

    -- If this locale already exists, return it (allow re-loading).
    if app.locales[locale] then
        return app.locales[locale]
    end

    local tbl = {}
    app.locales[locale] = tbl

    if isDefault then
        app.base = tbl
        app.baseLocale = locale
        setmetatable(tbl, {
            __newindex = function(t, k, v) rawset(t, k, normalize_value(k, v)) end
        })
    else
        setmetatable(tbl, {
            __newindex = function(t, k, v) rawset(t, k, normalize_value(k, v)) end
        })
    end

    return tbl
end

function AceLocale:GetLocale(appName, silent)
    local app = self.apps[appName]
    if not app or not app.base then
        if not silent then error("GetLocale: No base locale for " .. tostring(appName)) end
        return nil
    end

    local gameLocale = (GetLocale and GetLocale()) or app.baseLocale or "enUS"
    local loc = app.locales[gameLocale] or app.base

    -- Create a proxy that falls back to base.
    if loc == app.base then
        -- Ensure missing keys fall back to key itself (common AceLocale behavior).
        return setmetatable({}, {
            __index = function(_, k)
                local v = app.base[k]
                if v == nil then return tostring(k) end
                return v
            end
        })
    end

    return setmetatable({}, {
        __index = function(_, k)
            local v = loc[k]
            if v ~= nil then return v end
            v = app.base[k]
            if v ~= nil then return v end
            return tostring(k)
        end
    })
end
