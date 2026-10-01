local UI = KamiUI

UI.eventFrame = CreateFrame("Frame")
UI.events = {}

function UI:RegisterEvent(event, callback)
    if not self.events[event] then
        self.events[event] = {}
        self.eventFrame:RegisterEvent(event)
    end

    table.insert(self.events[event], callback)
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