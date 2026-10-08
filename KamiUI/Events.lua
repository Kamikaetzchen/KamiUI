local UI = KamiUI

UI.eventFrame = CreateFrame("Frame")
UI.events = {}
UI.bottomInsetCallbacks = {}

function UI:RegisterEvent(event, callback)
    if not self.events[event] then
        self.events[event] = {}
        self.eventFrame:RegisterEvent(event)
    end

    table.insert(self.events[event], callback)
end

function UI:RegisterBottomInsetCallback(callback)
    table.insert(self.bottomInsetCallbacks, callback)
end

local function NotifyBottomInsetChanged()
    local inset = UI:GetBottomInset()

    if UI.currentBottomInset == inset then
        return
    end

    UI.currentBottomInset = inset

    for _, callback in ipairs(UI.bottomInsetCallbacks) do
        callback(inset)
    end
end

UI.eventFrame:SetScript("OnEvent", function(_, event, ...)
    local callbacks = UI.events[event]

    if not callbacks then
        return
    end

    for _, callback in ipairs(callbacks) do
        callback(event, ...)
    end
end)

UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(0, NotifyBottomInsetChanged)
end)

UI:RegisterEvent("UNIT_LEVEL", function(_, unit)
    if unit == "player" then
        C_Timer.After(0, NotifyBottomInsetChanged)
    end
end)

UI:RegisterEvent("PLAYER_MAX_LEVEL_UPDATE", function()
    C_Timer.After(0, NotifyBottomInsetChanged)
end)

-- Watching/unwatching a faction changes the reserved bar height at max level.
UI:RegisterEvent("UPDATE_FACTION", NotifyBottomInsetChanged)
