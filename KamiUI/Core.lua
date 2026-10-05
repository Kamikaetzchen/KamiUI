KamiUI = KamiUI or {}

local UI = KamiUI

UI.name = "KamiUI"
UI.version = "0.1.0"

function UI:Print(...)
    print("|cff66ccffKamiUI:|r", ...)
end

function UI:CanAccessValue(value)
    if canaccessvalue then
        return canaccessvalue(value)
    end

    if issecretvalue then
        return not issecretvalue(value)
    end

    return true
end

UI:Print("Core loaded")