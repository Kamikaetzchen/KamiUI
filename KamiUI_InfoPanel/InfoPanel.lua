local UI = KamiUI

local Module = UI:NewModule("InfoPanel")

Module.name = "KamiUI_InfoPanel"
Module.version = "0.1.0"

local defaults = {
    height = 20,
    padding = 6,
    spacing = 12,
    fontSize = 12,
    background = { 0.005, 0.008, 0.015, 0.80 },
    bottomBorder = { 0.55, 0.42, 0.16, 1 },
    text = { 0.82, 0.82, 0.82, 1 },
}

local slotOrder = {
    "location",
    "speed",
    "xp",
    "bags",
    "durability",
    "gold",
    "latency",
    "clock",
}

local slotWidths = {
    location = 220,
    speed = 100,
    xp = 120,
    bags = 90,
    durability = 90,
    gold = 130,
    latency = 80,
    clock = 70,
}

local function FormatNumber(value)
    if BreakUpLargeNumbers then
        return BreakUpLargeNumbers(value)
    end

    return tostring(value or 0)
end

local function FormatMoney(copper)
    copper = math.max(0, copper or 0)

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local bronze = copper % 100

    return string.format(
        "%d |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t "
            .. "%d |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t "
            .. "%d |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t",
        gold,
        silver,
        bronze
    )
end

local function GetLinenBagIcon()
    if C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(4238)
    elseif GetItemIcon then
        return GetItemIcon(4238)
    end

    return "Interface\\Icons\\INV_Misc_Bag_07"
end

local function GetBagUsage()
    local used = 0
    local total = 0

    for bag = 0, NUM_BAG_SLOTS or 4 do
        local slots

        if C_Container and C_Container.GetContainerNumSlots then
            slots = C_Container.GetContainerNumSlots(bag)
        elseif GetContainerNumSlots then
            slots = GetContainerNumSlots(bag)
        end

        slots = slots or 0
        total = total + slots

        for slot = 1, slots do
            local info

            if C_Container and C_Container.GetContainerItemInfo then
                info = C_Container.GetContainerItemInfo(bag, slot)
            elseif GetContainerItemInfo then
                local texture = GetContainerItemInfo(bag, slot)
                info = texture and true or nil
            end

            if info then
                used = used + 1
            end
        end
    end

    return used, total
end

local function GetDurabilityPercent()
    local current = 0
    local maximum = 0

    for slot = 1, 18 do
        local value, maxValue = GetInventoryItemDurability(slot)

        if value and maxValue and maxValue > 0 then
            current = current + value
            maximum = maximum + maxValue
        end
    end

    if maximum <= 0 then
        return 100
    end

    return math.floor((current / maximum) * 100 + 0.5)
end

local function GetLocation()
    local zone = GetMinimapZoneText and GetMinimapZoneText() or ""
    local x
    local y

    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
        local mapID = C_Map.GetBestMapForUnit("player")

        if mapID then
            local position = C_Map.GetPlayerMapPosition(mapID, "player")

            if position then
                x, y = position:GetXY()
            end
        end
    end

    if x and y then
        return string.format("%s %.1f, %.1f", zone, x * 100, y * 100)
    end

    return zone ~= "" and zone or "Unknown"
end

local function GetMovementSpeed()
    local speed = GetUnitSpeed and GetUnitSpeed("player") or 0

    if speed <= 0 then
        return 0
    end

    return math.floor((speed / 7) * 100 + 0.5)
end

local function GetLatency()
    if not GetNetStats then
        return 0
    end

    local _, _, home, world = GetNetStats()

    return math.max(home or 0, world or 0)
end

local function CreateText(parent, width)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local font, _, flags = GameFontNormal:GetFont()

    if font then
        text:SetFont(font, defaults.fontSize, flags)
    end

    text:SetWidth(width)
    text:SetJustifyH("CENTER")
    text:SetTextColor(unpack(defaults.text))

    if text.SetWordWrap then
        text:SetWordWrap(false)
    end

    return text
end

local function CreatePanel()
    if Module.frame then
        return
    end

    local frame = CreateFrame("Frame", "KamiUIInfoPanel", UIParent)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
    frame:SetHeight(defaults.height)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(false)

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(frame)
    background:SetColorTexture(unpack(defaults.background))

    local bottomBorder = frame:CreateTexture(nil, "ARTWORK")
    bottomBorder:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    bottomBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    bottomBorder:SetHeight(2)
    bottomBorder:SetColorTexture(unpack(defaults.bottomBorder))

    local totalWidth = defaults.spacing * (#slotOrder - 1)

    for _, key in ipairs(slotOrder) do
        totalWidth = totalWidth + slotWidths[key]
    end

    local content = CreateFrame("Frame", nil, frame)
    content:SetSize(totalWidth, defaults.height)
    content:SetPoint("CENTER", frame, "CENTER", 0, 0)

    local texts = {}
    local previous

    for _, key in ipairs(slotOrder) do
        local text = CreateText(content, slotWidths[key])

        if previous then
            text:SetPoint("LEFT", previous, "RIGHT", defaults.spacing, 0)
        else
            text:SetPoint("LEFT", content, "LEFT", 0, 0)
        end

        texts[key] = text
        previous = text
    end

    Module.frame = frame
    Module.content = content
    Module.texts = texts
end

local function ResetSession()
    Module.sessionStart = GetTime()
    Module.sessionXP = 0
    Module.levelStart = GetTime()
    Module.levelXP = UnitXP("player") or 0
    Module.lastXP = UnitXP("player") or 0
end

local function UpdateXPTracking()
    local currentXP = UnitXP("player") or 0

    if not Module.lastXP then
        Module.lastXP = currentXP
        return
    end

    local gained = currentXP - Module.lastXP

    if gained > 0 then
        Module.sessionXP = (Module.sessionXP or 0) + gained
    end

    Module.lastXP = currentXP
end

local function GetXPPerHour()
    local elapsed = math.max(1, GetTime() - (Module.sessionStart or GetTime()))
    local xp = Module.sessionXP or 0

    return math.floor((xp / elapsed) * 3600 + 0.5)
end

function Module:Refresh()
    CreatePanel()

    local used, total = GetBagUsage()
    local durability = GetDurabilityPercent()
    local movement = GetMovementSpeed()
    local latency = GetLatency()
    local xpPerHour = GetXPPerHour()

    self.texts.location:SetText(GetLocation())
    self.texts.speed:SetText(string.format("Speed %d%%", movement))
    self.texts.xp:SetText(string.format("XP/h %s", FormatNumber(xpPerHour)))
    local bagIcon = GetLinenBagIcon()
        or "Interface\\Icons\\INV_Misc_Bag_07"

    self.texts.bags:SetText(string.format(
        "|T%s:13:13:0:0|t %d/%d",
        bagIcon,
        used,
        total
    ))
    self.texts.durability:SetText(string.format(
        "|TInterface\\Minimap\\Tracking\\Repair:13:13:0:0|t %d%%",
        durability
    ))
    self.texts.gold:SetText(FormatMoney(GetMoney and GetMoney() or 0))
    self.texts.latency:SetText(string.format(
        "|A:ui-mainmenubar-performancebar-screen:14:9:0:0|a %d ms",
        latency
    ))
    self.texts.clock:SetText(string.format(
        "|TInterface\\Icons\\INV_Misc_PocketWatch_01:13:13:0:0|t %s",
        date("%H:%M")
    ))
end

function Module:Initialize()
    ResetSession()
    CreatePanel()
    self:Refresh()

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0, function()
            Module:Refresh()
        end)
    end)

    UI:RegisterEvent("PLAYER_XP_UPDATE", function()
        UpdateXPTracking()
        Module:Refresh()
    end)

    UI:RegisterEvent("PLAYER_LEVEL_UP", function()
        Module.levelStart = GetTime()
        Module.levelXP = 0
        Module.lastXP = 0

        C_Timer.After(0, function()
            Module:Refresh()
        end)
    end)

    UI:RegisterEvent("BAG_UPDATE_DELAYED", function()
        Module:Refresh()
    end)

    UI:RegisterEvent("PLAYER_MONEY", function()
        Module:Refresh()
    end)

    UI:RegisterEvent("UPDATE_INVENTORY_DURABILITY", function()
        Module:Refresh()
    end)

    UI:RegisterEvent("ZONE_CHANGED", function()
        Module:Refresh()
    end)

    UI:RegisterEvent("ZONE_CHANGED_INDOORS", function()
        Module:Refresh()
    end)

    UI:RegisterEvent("ZONE_CHANGED_NEW_AREA", function()
        Module:Refresh()
    end)

    self.ticker = C_Timer.NewTicker(1, function()
        Module:Refresh()
    end)
end

Module:Initialize()
