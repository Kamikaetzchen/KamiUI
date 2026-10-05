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

local function ApplyDefaults(target, defaults)
    if type(defaults) ~= "table" then
        return target
    end

    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end

            ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end

    return target
end

function UI:GetDatabase(key, defaults)
    KamiUIDB = KamiUIDB or {}

    if key == nil then
        return ApplyDefaults(KamiUIDB, defaults)
    end

    if type(KamiUIDB[key]) ~= "table" then
        KamiUIDB[key] = {}
    end

    return ApplyDefaults(KamiUIDB[key], defaults)
end

function UI:SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local ok, a, b, c, d, e, f, g, h = pcall(func, ...)

    if not ok then
        return nil
    end

    return a, b, c, d, e, f, g, h
end

function UI:GetCurrentCharacterNames()
    local first, surname = UnitName("player")

    first = first or "Player"

    if surname and surname ~= "" then
        return first, surname, first .. " " .. surname
    end

    return first, nil, first
end

function UI:GetCurrentCharacterKey()
    local _, _, fullName = self:GetCurrentCharacterNames()
    local realm = GetRealmName and GetRealmName() or ""

    return realm .. "::" .. fullName
end

function UI:GetCurrentCharacterName()
    local _, _, fullName = self:GetCurrentCharacterNames()

    return fullName
end

function UI:ParseCharacterKey(key)
    local realm, name = string.match(key or "", "^(.-)::(.*)$")

    return realm or "", name or "Unknown"
end

function UI:FormatNumber(value)
    if BreakUpLargeNumbers then
        return BreakUpLargeNumbers(value or 0)
    end

    return tostring(value or 0)
end

function UI:FormatMoney(copper, options)
    options = options or {}
    copper = math.max(0, copper or 0)

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local bronze = copper % 100
    local iconSize = options.iconSize or 14
    local iconYOffset = options.iconYOffset or 0
    local showAll = options.showAll == true
    local parts = {}

    local function AddPart(value, icon)
        parts[#parts + 1] = string.format(
            "%d |TInterface\\MoneyFrame\\%s:%d:%d:0:%d|t",
            value,
            icon,
            iconSize,
            iconSize,
            iconYOffset
        )
    end

    if showAll or gold > 0 then
        AddPart(gold, "UI-GoldIcon")
    end

    if showAll or silver > 0 or gold > 0 then
        AddPart(silver, "UI-SilverIcon")
    end

    AddPart(bronze, "UI-CopperIcon")

    return table.concat(parts, " ")
end

function UI:SaveFramePosition(
    frame,
    database,
    key,
    relativeTo,
    reanchor
)
    if type(database) ~= "table" then
        return nil
    end

    local position = self:GetFrameCenterOffset(frame, relativeTo)

    if not position then
        return nil
    end

    key = key or "position"
    database[key] = position

    if reanchor then
        self:SetFrameCenterOffset(frame, position, nil, nil, relativeTo)
    end

    return position
end

function UI:ApplyFramePosition(
    frame,
    database,
    key,
    fallbackX,
    fallbackY,
    relativeTo,
    onlyIfSaved
)
    key = key or "position"
    local position = type(database) == "table" and database[key] or nil

    if onlyIfSaved and not position then
        return false
    end

    self:SetFrameCenterOffset(
        frame,
        position,
        fallbackX,
        fallbackY,
        relativeTo
    )

    return position ~= nil
end

UI:Print("Core loaded")