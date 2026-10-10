local UI = KamiUI
local Styles = UI.Styles
local Palette = UI.Palette
local RestedXP = UI.RestedXP

local Module = UI:NewModule("InfoPanel", "KamiUI_InfoPanel")


local Layout = UI.Layout.InfoPanel

local slotOrder = {
    "location",
    "speed",
    "xp",
    "rested",
    "levelup",
    "bags",
    "durability",
    "gold",
    "latency",
    "clock",
}


local function FormatXPPerHour(value)
    value = math.max(0, value or 0)

    if value >= 1000 then
        return string.format("%.1fk", value / 1000)
    end

    return tostring(value)
end

local function GetLinenBagIcon()
    if C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(4238)
    elseif GetItemIcon then
        return GetItemIcon(4238)
    end

    return "Interface\\Icons\\INV_Misc_Bag_07"
end

local function IsContainerSlotUsed(bag, slot)
    return UI:GetContainerItemInfo(bag, slot) ~= nil
end

local function GetBagSlotUsage(bag)
    local total = UI:GetContainerNumSlots(bag)
    local used = 0

    for slot = 1, total do
        if IsContainerSlotUsed(bag, slot) then
            used = used + 1
        end
    end

    return used, total
end

local function GetBagUsage()
    local used = 0
    local total = 0

    for bag = 0, NUM_BAG_SLOTS or 4 do
        local bagUsed, bagTotal = GetBagSlotUsage(bag)
        used = used + bagUsed
        total = total + bagTotal
    end

    return used, total
end

local function GetBagName(bag)
    if bag == 0 then
        return BACKPACK_TOOLTIP or "Backpack"
    end

    local inventoryID

    if C_Container and C_Container.ContainerIDToInventoryID then
        inventoryID = C_Container.ContainerIDToInventoryID(bag)
    elseif ContainerIDToInventoryID then
        inventoryID = ContainerIDToInventoryID(bag)
    end

    if inventoryID and GetInventoryItemLink then
        local link = GetInventoryItemLink("player", inventoryID)

        if link then
            return link
        end
    end

    return string.format("Bag %d", bag)
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

    if canaccessvalue and not canaccessvalue(speed) then
        Module.speedSecretCount = (Module.speedSecretCount or 0) + 1

        if Module.speedSecretCount >= 5 then
            return nil, true
        end

        return nil, false
    end

    Module.speedSecretCount = 0

    if speed <= 0 then
        return 0, false
    end

    return math.floor((speed / 7) * 100 + 0.5), false
end

local function GetLatencies()
    if not GetNetStats then
        return 0, 0
    end

    local _, _, home, world = GetNetStats()

    return home or 0, world or 0
end

local function GetLatency()
    local home, world = GetLatencies()

    return math.max(home, world)
end

local function GetMoneyCharacters()
    local characters = UI:GetCharactersModule()

    if characters then
        if characters.UpdateCurrentCharacter then
            characters:UpdateCurrentCharacter()
        end

        return characters:GetSortedCharacters()
    end

    local key = UI:GetCurrentCharacterKey()

    return {
        {
            key = key,
            character = UI:GetCharacterProfile(key),
        },
    }
end

local function PrepareTooltip(owner, title)
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(title, 1, 0.82, 0)
end

local function HideTooltip(owner)
    if GameTooltip:IsOwned(owner) then
        GameTooltip:Hide()
    end
end

local function ShowBagsTooltip(owner)
    PrepareTooltip(owner, "Bags")

    local totalUsed = 0
    local totalSlots = 0

    for bag = 0, NUM_BAG_SLOTS or 4 do
        local used, total = GetBagSlotUsage(bag)

        if total > 0 then
            GameTooltip:AddDoubleLine(
                GetBagName(bag),
                string.format("%d / %d", used, total),
                1, 1, 1,
                0.82, 0.82, 0.82
            )

            totalUsed = totalUsed + used
            totalSlots = totalSlots + total
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(
        "Total",
        string.format("%d / %d", totalUsed, totalSlots),
        1, 0.82, 0,
        1, 1, 1
    )
    GameTooltip:Show()
end

local function GetDurabilityColor(percent)
    if percent >= 75 then
        return 0.2, 1.0, 0.2
    elseif percent >= 40 then
        return 1.0, 0.82, 0
    end

    return 1.0, 0.2, 0.2
end

local function ShowDurabilityTooltip(owner)
    PrepareTooltip(owner, "Durability")

    local currentTotal = 0
    local maximumTotal = 0

    for slot = 1, 18 do
        local current, maximum = GetInventoryItemDurability(slot)

        if current and maximum and maximum > 0 then
            local percent = math.floor((current / maximum) * 100 + 0.5)
            local r, g, b = GetDurabilityColor(percent)
            local item = GetInventoryItemLink("player", slot)
                or string.format("Slot %d", slot)

            GameTooltip:AddDoubleLine(
                item,
                string.format("%d%%", percent),
                1, 1, 1,
                r, g, b
            )

            currentTotal = currentTotal + current
            maximumTotal = maximumTotal + maximum
        end
    end

    if maximumTotal > 0 then
        local totalPercent = math.floor(
            (currentTotal / maximumTotal) * 100 + 0.5
        )
        local r, g, b = GetDurabilityColor(totalPercent)

        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(
            "Total",
            string.format("%d%%", totalPercent),
            1, 0.82, 0,
            r, g, b
        )
    end

    GameTooltip:Show()
end

local function ShowRestedTooltip(owner)
    PrepareTooltip(owner, "Rested XP")
    GameTooltip:AddLine(
        "Percent of the XP needed for one level (maximum 150%).",
        0.74, 0.74, 0.79, true
    )
    GameTooltip:AddLine(" ")

    local currentRealm = GetRealmName and GetRealmName() or ""
    local hasEstimates = false

    for _, entry in ipairs(RestedXP:GetCharacterEntries()) do
        local profile = entry.character or {}
        local name = profile.name or select(2, UI:ParseCharacterKey(entry.key))
        local classColor = Palette:GetClassColor(profile.classFile)
        local r = classColor and (classColor.r or classColor[1]) or 1
        local g = classColor and (classColor.g or classColor[2]) or 1
        local b = classColor and (classColor.b or classColor[3]) or 1
        local value

        if entry.maxLevel then
            value = "Max level"
        elseif entry.percent ~= nil then
            value = string.format("%s%.1f%%",
                entry.estimated and "~" or "", entry.percent)
            hasEstimates = hasEstimates or entry.estimated
        else
            value = "Log in once"
        end

        if profile.realm and profile.realm ~= ""
            and profile.realm ~= currentRealm then
            name = string.format("%s - %s", name, profile.realm)
        end

        GameTooltip:AddDoubleLine(
            name,
            value,
            r, g, b,
            0.80, 0.88, 1
        )
    end

    if hasEstimates then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(
            "~ = estimated offline gain (5% per 8h rested / 32h elsewhere).",
            0.67, 0.69, 0.75, true
        )
        GameTooltip:AddLine(
            "Values are measured again when you log into each character.",
            0.67, 0.69, 0.75, true
        )
    end
    GameTooltip:Show()
end

local function ShowGoldTooltip(owner)
    PrepareTooltip(owner, "Gold")

    local currentRealm = GetRealmName and GetRealmName() or ""
    local total = 0

    for _, entry in ipairs(GetMoneyCharacters()) do
        local character = entry.character
        local name = character.name or "Unknown"
        local amount = character.money or 0
        local color = Palette:GetClassColor(character.classFile)
        local r = color and color.r or 1
        local g = color and color.g or 1
        local b = color and color.b or 1

        total = total + amount

        if character.realm and character.realm ~= ""
            and character.realm ~= currentRealm then
            name = string.format("%s - %s", name, character.realm)
        end

        GameTooltip:AddDoubleLine(
            name,
            UI:FormatMoney(amount, { iconSize = 12, iconYOffset = 2, showAll = true }),
            r, g, b,
            1, 1, 1
        )
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(
        "Total",
        UI:FormatMoney(total, { iconSize = 12, iconYOffset = 2, showAll = true }),
        1, 0.82, 0,
        1, 1, 1
    )
    GameTooltip:Show()
end

local function ShowLatencyTooltip(owner)
    PrepareTooltip(owner, "Latency")

    local home, world = GetLatencies()

    GameTooltip:AddDoubleLine(
        "Home",
        string.format("%d ms", home),
        1, 1, 1,
        0.82, 0.82, 0.82
    )
    GameTooltip:AddDoubleLine(
        "World",
        string.format("%d ms", world),
        1, 1, 1,
        0.82, 0.82, 0.82
    )
    GameTooltip:Show()
end

local function ShowClockTooltip(owner)
    PrepareTooltip(owner, "Time")

    local serverHour = 0
    local serverMinute = 0

    if GetGameTime then
        serverHour, serverMinute = GetGameTime()
    end

    GameTooltip:AddDoubleLine(
        "Local",
        date("%H:%M"),
        1, 1, 1,
        0.82, 0.82, 0.82
    )
    GameTooltip:AddDoubleLine(
        "Server",
        string.format("%02d:%02d", serverHour, serverMinute),
        1, 1, 1,
        0.82, 0.82, 0.82
    )
    GameTooltip:Show()
end

local tooltipHandlers = {
    rested = ShowRestedTooltip,
    bags = ShowBagsTooltip,
    durability = ShowDurabilityTooltip,
    gold = ShowGoldTooltip,
    latency = ShowLatencyTooltip,
    clock = ShowClockTooltip,
}

local function CreateText(parent, width)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local font, _, flags = GameFontNormal:GetFont()

    if font then
        text:SetFont(font, Styles.FontSize.InfoPanel, flags)
    end

    text:SetWidth(width)
    text:SetJustifyH("LEFT")
    text:SetTextColor(unpack(Palette.infoPanel.text))

    if text.SetWordWrap then
        text:SetWordWrap(false)
    end

    return text
end

local function CreatePanel()
    if Module.frame then
        return
    end

    local totalWidth = Layout.SPACING * (#slotOrder - 1)

    for _, key in ipairs(slotOrder) do
        totalWidth = totalWidth + Layout.SLOT_WIDTHS[key]
    end

    local edgePadding = 12
    local sideAngle = 60
    local sideRun = math.floor(
        Layout.HEIGHT / math.tan(math.rad(sideAngle)) + 0.5
    )
    local bodyWidth = totalWidth + (edgePadding * 2)
    local frameWidth = bodyWidth + (sideRun * 2)

    local frame = CreateFrame("Frame", "KamiUIInfoPanel", UIParent)
    frame:SetSize(frameWidth, Layout.HEIGHT)
    frame:SetPoint("TOP", UIParent, "TOP", 0, 0)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(false)

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPLEFT", frame, "TOPLEFT", sideRun, 0)
    background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -sideRun, 0)
    background:SetColorTexture(unpack(Palette.infoPanel.background))

    for index = 1, sideRun do
        local stripHeight = math.ceil(
            Layout.HEIGHT * index / sideRun
        )

        local leftStrip = frame:CreateTexture(nil, "BACKGROUND")
        leftStrip:SetSize(1, stripHeight)
        leftStrip:SetPoint(
            "TOPLEFT",
            frame,
            "TOPLEFT",
            index - 1,
            0
        )
        leftStrip:SetColorTexture(unpack(Palette.infoPanel.background))

        local rightStrip = frame:CreateTexture(nil, "BACKGROUND")
        rightStrip:SetSize(1, stripHeight)
        rightStrip:SetPoint(
            "TOPRIGHT",
            frame,
            "TOPRIGHT",
            -(index - 1),
            0
        )
        rightStrip:SetColorTexture(unpack(Palette.infoPanel.background))
    end

    local bottomBorder = frame:CreateTexture(nil, "ARTWORK")
    bottomBorder:SetPoint(
        "BOTTOMLEFT",
        frame,
        "BOTTOMLEFT",
        sideRun,
        0
    )
    bottomBorder:SetPoint(
        "BOTTOMRIGHT",
        frame,
        "BOTTOMRIGHT",
        -sideRun,
        0
    )
    bottomBorder:SetHeight(3)
    bottomBorder:SetColorTexture(unpack(Palette.infoPanel.bottomBorder))

    local leftBorder = frame:CreateLine(nil, "ARTWORK")
    leftBorder:SetThickness(3)
    leftBorder:SetColorTexture(unpack(Palette.infoPanel.bottomBorder))
    leftBorder:SetStartPoint("TOPLEFT", frame, 0, 0)
    leftBorder:SetEndPoint("BOTTOMLEFT", frame, sideRun, 0)

    local rightBorder = frame:CreateLine(nil, "ARTWORK")
    rightBorder:SetThickness(3)
    rightBorder:SetColorTexture(unpack(Palette.infoPanel.bottomBorder))
    rightBorder:SetStartPoint("TOPRIGHT", frame, 0, 0)
    rightBorder:SetEndPoint("BOTTOMRIGHT", frame, -sideRun, 0)

    local content = CreateFrame("Frame", nil, frame)
    content:SetSize(totalWidth, Layout.HEIGHT)
    content:SetPoint("CENTER", frame, "CENTER", 0, 0)

    local texts = {}
    local previous

    for _, key in ipairs(slotOrder) do
        local text = CreateText(content, Layout.SLOT_WIDTHS[key])

        if previous then
            text:SetPoint("LEFT", previous, "RIGHT", Layout.SPACING, 0)
        else
            text:SetPoint("LEFT", content, "LEFT", 0, 0)
        end

        texts[key] = text
        previous = text
    end

    texts.location:SetJustifyH("CENTER")

    local levelupArrow = CreateFrame("Frame", nil, content)
    levelupArrow:SetSize(12, 12)
    levelupArrow:SetPoint("LEFT", texts.levelup, "LEFT", 0, 1)

    local arrowColor = { 0.2, 0.9, 0.3, 1 }

    local arrowStem = levelupArrow:CreateLine(nil, "OVERLAY")
    arrowStem:SetThickness(2)
    arrowStem:SetColorTexture(unpack(arrowColor))
    arrowStem:SetStartPoint("BOTTOM", levelupArrow, 0, 1)
    arrowStem:SetEndPoint("TOP", levelupArrow, 0, -2)

    local arrowLeft = levelupArrow:CreateLine(nil, "OVERLAY")
    arrowLeft:SetThickness(2)
    arrowLeft:SetColorTexture(unpack(arrowColor))
    arrowLeft:SetStartPoint("TOP", levelupArrow, 0, -2)
    arrowLeft:SetEndPoint("LEFT", levelupArrow, 2, -1)

    local arrowRight = levelupArrow:CreateLine(nil, "OVERLAY")
    arrowRight:SetThickness(2)
    arrowRight:SetColorTexture(unpack(arrowColor))
    arrowRight:SetStartPoint("TOP", levelupArrow, 0, -2)
    arrowRight:SetEndPoint("RIGHT", levelupArrow, -2, -1)

    local signal = CreateFrame("Frame", nil, content)
    signal:SetSize(12, 12)
    signal:SetPoint("LEFT", texts.latency, "LEFT", 0, 2)

    local signalHeights = { 4, 7, 10 }

    for index, height in ipairs(signalHeights) do
        local bar = signal:CreateTexture(nil, "OVERLAY")
        bar:SetSize(2, height)
        bar:SetPoint(
            "BOTTOMLEFT",
            signal,
            "BOTTOMLEFT",
            (index - 1) * 4,
            0
        )
        bar:SetColorTexture(unpack(Palette.infoPanel.text))
    end

    local hoverFrames = {}

    for key, showTooltip in pairs(tooltipHandlers) do
        local hover = CreateFrame("Frame", nil, content)
        hover:SetSize(Layout.SLOT_WIDTHS[key], Layout.HEIGHT)
        hover:SetPoint("CENTER", texts[key], "CENTER", 0, 0)
        hover:SetFrameLevel(content:GetFrameLevel() + 10)
        hover:EnableMouse(true)
        hover:SetScript("OnEnter", showTooltip)
        hover:SetScript("OnLeave", HideTooltip)
        hoverFrames[key] = hover
    end

    Module.frame = frame
    Module.content = content
    Module.texts = texts
    Module.levelupArrow = levelupArrow
    Module.latencySignal = signal
    Module.hoverFrames = hoverFrames
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

local function GetTimeToLevel(xpPerHour)
    if not xpPerHour or xpPerHour <= 0 then
        return "--"
    end

    local currentXP = UnitXP("player") or 0
    local maxXP = UnitXPMax("player") or 0

    if maxXP <= 0 or currentXP >= maxXP then
        return "--"
    end

    local remainingXP = maxXP - currentXP
    local seconds = math.floor((remainingXP / xpPerHour) * 3600 + 0.5)

    if seconds < 60 then
        return "<1m"
    end

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)

    if hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    end

    return string.format("%dm", minutes)
end

function Module:Refresh()
    CreatePanel()

    local used, total = GetBagUsage()
    local durability = GetDurabilityPercent()
    local movement, movementUnavailable = GetMovementSpeed()
    local latency = GetLatency()
    local xpPerHour = GetXPPerHour()
    local timeToLevel = GetTimeToLevel(xpPerHour)

    self.texts.location:SetText(string.format(
        "|TInterface\\Icons\\icon_treasuremap:13:13:0:2:64:64:4:60:4:60|t %s",
        GetLocation()
    ))
    if movement ~= nil then
        self.texts.speed:SetText(string.format(
            "|TInterface\\Icons\\Ability_Rogue_Sprint:13:13:0:2:64:64:4:60:4:60|t %d%%",
            movement
        ))
    elseif movementUnavailable then
        self.texts.speed:SetText(
            "|TInterface\\Icons\\Ability_Rogue_Sprint:13:13:0:2:64:64:4:60:4:60|t N/A"
        )
    end
    self.texts.xp:SetText(string.format(
        "|TInterface\\Icons\\xp_icon:13:13:0:2:64:64:4:60:4:60|t %s/h",
        FormatXPPerHour(xpPerHour)
    ))
    local restedPercent, atMaxLevel = RestedXP:GetCurrentPercent()
    if atMaxLevel then
        self.texts.rested:SetText(
            "|TInterface\\Icons\\Spell_Nature_Sleep:13:13:0:2|t Max"
        )
    elseif restedPercent then
        self.texts.rested:SetText(string.format(
            "|TInterface\\Icons\\Spell_Nature_Sleep:13:13:0:2|t %.0f%%",
            restedPercent
        ))
    else
        self.texts.rested:SetText(
            "|TInterface\\Icons\\Spell_Nature_Sleep:13:13:0:2|t --"
        )
    end
    self.texts.levelup:SetText(string.format("     %s", timeToLevel))

    local bagIcon = GetLinenBagIcon()
        or "Interface\\Icons\\INV_Misc_Bag_07"

    self.texts.bags:SetText(string.format(
        "|T%s:13:13:0:2:64:64:4:60:4:60|t %d/%d",
        bagIcon,
        used,
        total
    ))
    self.texts.durability:SetText(string.format(
        "|TInterface\\Minimap\\Tracking\\Repair:13:13:0:2|t %d%%",
        durability
    ))
    self.texts.gold:SetText(UI:FormatMoney(
        GetMoney and GetMoney() or 0,
        {
            iconSize = 12,
            iconYOffset = 2,
            showAll = true,
        }
    ))
    self.texts.latency:SetText(string.format("     %d ms", latency))
    self.texts.clock:SetText(string.format(
        "|TInterface\\Icons\\INV_Misc_PocketWatch_01:13:13:0:2:64:64:4:60:4:60|t %s",
        date("%H:%M")
    ))
end

function Module:Initialize()
    ResetSession()
    RestedXP:CaptureCurrent()
    CreatePanel()
    self:Refresh()

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0, function()
            RestedXP:CaptureCurrent()
            Module:Refresh()
        end)
    end)
    UI:RegisterEvent("UPDATE_EXHAUSTION", function()
        RestedXP:CaptureCurrent()
        Module:Refresh()
    end)
    UI:RegisterEvent("PLAYER_UPDATE_RESTING", function()
        RestedXP:CaptureCurrent()
    end)
    UI:RegisterEvent("PLAYER_LOGOUT", function()
        RestedXP:CaptureCurrent()
    end)

    UI:RegisterEvent("PLAYER_XP_UPDATE", function()
        UpdateXPTracking()
        RestedXP:CaptureCurrent()
        Module:Refresh()
    end)

    UI:RegisterEvent("PLAYER_LEVEL_UP", function()
        Module.levelStart = GetTime()
        Module.levelXP = 0
        Module.lastXP = 0

        C_Timer.After(0, function()
            RestedXP:CaptureCurrent()
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

    self.lastRestedSnapshot = GetTime()
    self.ticker = C_Timer.NewTicker(1, function()
        Module:Refresh()
        -- Record occasional fresh snapshots without updating SavedVariables
        -- every frame/second. Login, logout, XP and rest changes save instantly.
        if GetTime() - Module.lastRestedSnapshot >= 60 then
            Module.lastRestedSnapshot = GetTime()
            RestedXP:CaptureCurrent()
        end
    end)
end

Module:Initialize()
