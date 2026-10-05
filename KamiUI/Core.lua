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

function UI:GetFrameCenterOffset(frame, relativeTo)
    relativeTo = relativeTo or UIParent

    if not frame
        or not relativeTo
        or not frame.GetCenter
        or not relativeTo.GetCenter
    then
        return nil
    end

    local frameX, frameY = frame:GetCenter()
    local relativeX, relativeY = relativeTo:GetCenter()

    if not frameX
        or not frameY
        or not relativeX
        or not relativeY
    then
        return nil
    end

    return {
        x = frameX - relativeX,
        y = frameY - relativeY,
    }
end

function UI:SetFrameCenterOffset(
    frame,
    position,
    fallbackX,
    fallbackY,
    relativeTo
)
    if not frame then
        return
    end

    relativeTo = relativeTo or UIParent

    local x = fallbackX or 0
    local y = fallbackY or 0

    if position then
        x = position.x or x
        y = position.y or y
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", relativeTo, "CENTER", x, y)
end

UI:Print("Core loaded")