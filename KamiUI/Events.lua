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

function UI:SetBottomInset(inset)
    if self.currentBottomInset == inset then
        return
    end

    self.currentBottomInset = inset

    for _, callback in ipairs(self.bottomInsetCallbacks) do
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
