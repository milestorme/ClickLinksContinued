-- CallbackHandler-1.0.lua
-- Minimal embedded CallbackHandler-1.0 implementation (Ace-compatible).

local MAJOR, MINOR = "CallbackHandler-1.0", 7
local CallbackHandler, oldMinor = LibStub:NewLibrary(MAJOR, MINOR)
if not CallbackHandler then return end

local meta = { __index = function(tbl, key)
    local method = tbl.__methods[key]
    if method then
        return function(_, ...)
            return method(tbl, ...)
        end
    end
end }

local function Dispatch(tbl, event, ...)
    local reg = tbl.__registry[event]
    if not reg then return end

    -- Copy keys to avoid issues if callbacks unregister during dispatch.
    local callList = {}
    for k in pairs(reg) do
        callList[#callList + 1] = k
    end

    for i = 1, #callList do
        local obj = callList[i]
        local callback = reg[obj]
        if callback then
            if type(callback) == "string" then
                local func = obj[callback]
                if func then
                    func(obj, event, ...)
                end
            else
                callback(event, ...)
            end
        end
    end
end

function CallbackHandler:New(target, callFunc, regFunc, unregFunc)
    target = target or {}
    local tbl = setmetatable({
        __registry = {},
        __methods = {},
        Fire = function(self, event, ...) Dispatch(self, event, ...) end,
    }, meta)

    tbl.__methods.RegisterCallback = function(self, obj, event, callback)
        assert(obj, "RegisterCallback: obj is required")
        assert(type(event) == "string", "RegisterCallback: event must be a string")
        if callback == nil then callback = event end

        local reg = self.__registry[event]
        if not reg then
            reg = {}
            self.__registry[event] = reg
            if regFunc then regFunc(target, event) end
        end

        reg[obj] = callback
        if regFunc and callFunc then
            -- no-op: kept for compatibility
        end
    end

    tbl.__methods.UnregisterCallback = function(self, obj, event)
        assert(obj, "UnregisterCallback: obj is required")
        assert(type(event) == "string", "UnregisterCallback: event must be a string")

        local reg = self.__registry[event]
        if not reg then return end
        reg[obj] = nil

        local empty = true
        for _ in pairs(reg) do empty = false break end
        if empty then
            self.__registry[event] = nil
            if unregFunc then unregFunc(target, event) end
        end
    end

    tbl.__methods.UnregisterAllCallbacks = function(self, obj)
        assert(obj, "UnregisterAllCallbacks: obj is required")
        for event, reg in pairs(self.__registry) do
            if reg[obj] then
                reg[obj] = nil
                local empty = true
                for _ in pairs(reg) do empty = false break end
                if empty then
                    self.__registry[event] = nil
                    if unregFunc then unregFunc(target, event) end
                end
            end
        end
    end

    if callFunc then
        tbl.__methods.Fire = function(self, event, ...)
            callFunc(target, Dispatch, event, ...)
        end
    end

    return tbl
end
