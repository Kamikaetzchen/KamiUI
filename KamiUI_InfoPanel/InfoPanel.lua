local UI = KamiUI

local Module = UI:NewModule("InfoPanel")

Module.name = "KamiUI_InfoPanel"
Module.version = "0.1.0"

local defaults = {
    height = 20,
    padding = 6,
    spacing = 18,
    fontSize = 12,
    background = { 0.005, 0.008, 0.015, 0.95 },
    border = { 0.2, 0.2, 0.2, 1 },
    text = { 0.82, 0.82, 0.82, 1 },
    value = { 1, 1, 1, 1 },
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

    if gold > 0 then
        return string.format("%dg %ds %dc", gold, silver, bronze)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, bronze)
    end

    return string.format("%dc", bronze)
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

local function SetTextColor(fontString, color)
    fontString:SetTextColor(color[1], color[2], color[3], color[4])
end

local function CreateText(parent, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local font, _, flags = GameFontNormal:GetFont()

    if font then
        text:SetFont(font, defaults.fontSize, flags)
    end

    text:SetJustifyH(justify or "LEFT")
    SetTextColor(text, defaults.text)

    return text
end

local function CreatePanel()
    if Module.frame then
        return
    end

    local frame = CreateFrame(
        "Frame",
        "KamiUIInfoPanel",
        UIParent,
        "BackdropTemplate"
    )

    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
    frame:SetHeight(defaults.height)
    frame:SetFrameStrata("HIGH")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(unpack(defaults.background))
    frame:SetBackdropBorderColor(unpack(defaults.border))
    frame:EnableMouse(false)

    local left = CreateFrame("Frame", nil, frame)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", defaults.padding, 0)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", defaults.padding, 0)

    local right = CreateFrame("Frame", nil, frame)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -defaults.padding, 0)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -defaults.padding, 0)

    local location = CreateText(left, "LEFT")
    location:SetPoint("LEFT", left, "LEFT", 0, 0)

    local speed = CreateText(left, "LEFT")
    speed:SetPoint("LEFT", location, "RIGHT", defaults.spacing, 0)

    local xp = CreateText(left, "LEFT")
    xp:SetPoint("LEFT", speed, "RIGHT", defaults.spacing, 0)

    local bags = CreateText(left, "LEFT")
    bags:SetPoint("LEFT", xp, "RIGHT", defaults.spacing, 0)

    local durability = CreateText(left, "LEFT")
    durability:SetPoint("LEFT", bags, "RIGHT", defaults.spacing, 0)

    local gold = CreateText(left, "LEFT")
    gold:SetPoint("LEFT", durability, "RIGHT", defaults.spacing, 0)

    local clock = CreateText(right, "RIGHT")
    clock:SetPoint("RIGHT", right, "RIGHT", 0, 0)

    local latency = CreateText(right, "RIGHT")
    latency:SetPoint("RIGHT", clock, "LEFT", -defaults.spacing, 0)

    local fps = CreateText(right, "RIGHT")
    fps:SetPoint("RIGHT", latency, "LEFT", -defaults.spacing, 0)

    Module.frame = frame
    Module.texts = {
        location = location,
        speed = speed,
        xp = xp,
        bags = bags,
        durability = durability,
        gold = gold,
        fps = fps,
        latency = latency,
        clock = clock,
    }
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
    local fps = GetFramerate and math.floor(GetFramerate() + 0.5) or 0
    local latency = GetLatency()
    local xpPerHour = GetXPPerHour()

    self.texts.location:SetText(GetLocation())
    self.texts.speed:SetText(string.format("Speed %d%%", movement))
    self.texts.xp:SetText(string.format("XP/h %s", FormatNumber(xpPerHour)))
    self.texts.bags:SetText(string.format("Bags %d/%d", used, total))
    self.texts.durability:SetText(string.format("Dur %d%%", durability))
    self.texts.gold:SetText(FormatMoney(GetMoney and GetMoney() or 0))
    self.texts.fps:SetText(string.format("%d FPS", fps))
    self.texts.latency:SetText(string.format("%d ms", latency))
    self.texts.clock:SetText(date("%H:%M"))
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

    local ticker = C_Timer.NewTicker(1, function()
        Module:Refresh()
    end)

    self.ticker = ticker
end

Module:Initialize()
