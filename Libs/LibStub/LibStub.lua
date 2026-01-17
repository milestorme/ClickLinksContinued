-- LibStub.lua
-- Compatible with LibStub 2.0 style API.
-- This is a standard embedded copy used by many WoW addons.

local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2

local LibStub = _G[LIBSTUB_MAJOR]
if LibStub and LibStub.minor and LibStub.minor >= LIBSTUB_MINOR then
    return
end

LibStub = LibStub or { libs = {}, minors = {} }
LibStub.minor = LIBSTUB_MINOR

function LibStub:NewLibrary(major, minor)
    assert(type(major) == "string", "Bad argument #2 to `NewLibrary' (string expected)")
    minor = assert(tonumber(minor), "Bad argument #3 to `NewLibrary' (number expected)")
    local oldminor = self.minors[major]
    if oldminor and oldminor >= minor then
        return nil
    end
    self.minors[major] = minor
    self.libs[major] = self.libs[major] or {}
    return self.libs[major], oldminor
end

function LibStub:GetLibrary(major, silent)
    if not self.libs[major] then
        if silent then return nil end
        error(("Cannot find a library instance of %q."):format(tostring(major)), 2)
    end
    return self.libs[major], self.minors[major]
end

function LibStub:IterateLibraries()
    return pairs(self.libs)
end

_G[LIBSTUB_MAJOR] = LibStub
