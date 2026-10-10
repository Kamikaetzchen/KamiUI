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
    "levelup",
    "bags",
    "durability",
    "gold",
    "rested",
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

-- Three independent columns for the rested tooltip, kept in sync with
-- Blizzard's tooltip rows. Hide them when a different tooltip is shown.
local restedTooltipColumns = {}
local function HideRestedTooltipColumns()
    for _, columns in ipairs(restedTooltipColumns) do
        columns.time:Hide()
        columns.percent:Hide()
        if columns.spacer then
            columns.spacer:SetTextColor(1, 1, 1, 1)
        end
    end
end
GameTooltip:HookScript("OnHide", HideRestedTooltipColumns)

local function PrepareTooltip(owner, title)
    HideRestedTooltipColumns()
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

-- A linear five-stop gradient using the shared WoW difficulty palette:
-- 0% gray, 25% green, 50% yellow, 75% orange, 100% red.
-- Scale each stop to the character's Well Rested-adjusted XP cap.
local RESTED_COLOR_STOPS = {
    Palette:GetDifficultyColor("trivial"),
    Palette:GetDifficultyColor("easy"),
    Palette:GetDifficultyColor("normal"),
    Palette:GetDifficultyColor("hard"),
    Palette:GetDifficultyColor("veryHard"),
}

local function GetRestedColor(percent, rank)
    local cap = RestedXP:GetCapPercent(rank)
    -- With an unknown talent rank there is no confirmed maximum, so
    -- project across the highest possible rank's cap without claiming full red.
    local scaleCap = cap or RestedXP:GetCapPercent(5)
    local progress = math.max(0, math.min(1, percent / scaleCap))
    if not cap then progress = math.min(progress, 0.999) end

    local pos = progress * (#RESTED_COLOR_STOPS - 1)
    local index = math.min(#RESTED_COLOR_STOPS - 1,
        math.floor(pos) + 1)
    local fraction = pos - (index - 1)
    local first = RESTED_COLOR_STOPS[index]
    local second = RESTED_COLOR_STOPS[index + 1]

    local function channel(color, number, field)
        return color[field] or color[number]
    end

    local function mix(number, field)
        local a = channel(first, number, field)
        local b = channel(second, number, field)
        return a + (b - a) * fraction
    end

    return mix(1, "r"), mix(2, "g"), mix(3, "b")
end

local function FormatRestedPercent(percent, rank)
    local r, g, b = GetRestedColor(percent, rank)
    return string.format("|cff%02x%02x%02x%.1f%%|r",
        math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5), percent)
end

local function FormatRestedTime(seconds)
    if seconds == nil then return "--" end

    -- Round upwards: 0m must mean that the cap is actually reached.
    local minutes = math.ceil(math.max(0, seconds) / 60)
    local days = math.floor(minutes / 1440)
    local hours = math.floor(minutes % 1440 / 60)
    local remainingMinutes = minutes % 60
    if days > 0 then
        return string.format("%dd%02dh%02dm", days, hours, remainingMinutes)
    elseif hours > 0 then
        return string.format("%dh%02dm", hours, remainingMinutes)
    end
    return string.format("%dm", remainingMinutes)
end

local RESTED_TIME_WIDTH = 95
local RESTED_PERCENT_WIDTH = 62
local RESTED_COLUMN_GAP = 12
-- The native right-hand text is only a sizing placeholder. Keeping it
-- short avoids a large empty gap after the character names; the separately
-- anchored time and percent labels still retain their fixed alignment.
local RESTED_COLUMN_SPACER = string.rep("W", 10)

local function AddRestedTooltipRow(index, name, remaining, value,
    nr, ng, nb, vr, vg, vb, header)
    -- Reserve room with the native tooltip layout, but draw two separately
    -- right-aligned fields rather than padding proportional-font text.
    GameTooltip:AddDoubleLine(name, RESTED_COLUMN_SPACER,
        nr, ng, nb, 1, 1, 1)
    local right = _G["GameTooltipTextRight" .. GameTooltip:NumLines()]
    if not right then return end

    local columns = restedTooltipColumns[index]
    if not columns then
        columns = {
            time = GameTooltip:CreateFontString(
                nil, "OVERLAY", "GameFontHighlightSmall"),
            percent = GameTooltip:CreateFontString(
                nil, "OVERLAY", "GameFontHighlightSmall"),
        }
        restedTooltipColumns[index] = columns
    end

    columns.spacer = right
    right:SetTextColor(1, 1, 1, 0)
    for _, label in ipairs({columns.time, columns.percent}) do
        label:ClearAllPoints()
        label:SetJustifyH("RIGHT")
        if label.SetWordWrap then label:SetWordWrap(false) end
        if right.GetFontObject and right:GetFontObject() then
            label:SetFontObject(right:GetFontObject())
        end
    end

    columns.time:SetWidth(RESTED_TIME_WIDTH)
    columns.time:SetPoint("RIGHT", right, "RIGHT",
        -(RESTED_PERCENT_WIDTH + RESTED_COLUMN_GAP), 0)
    columns.time:SetText(remaining)
    local timeColor = header and 0.65 or 0.85
    columns.time:SetTextColor(timeColor, timeColor, timeColor)
    columns.time:Show()

    columns.percent:SetWidth(RESTED_PERCENT_WIDTH)
    columns.percent:SetPoint("RIGHT", right, "RIGHT", 0, 0)
    columns.percent:SetText(value)
    columns.percent:SetTextColor(vr, vg, vb)
    columns.percent:Show()
end

local function ShowRestedTooltip(owner)
    PrepareTooltip(owner, "Rested XP")
    local row = 1
    AddRestedTooltipRow(row, "Character (Legacy)", "To cap", "Rested",
        0.65, 0.65, 0.65, 0.65, 0.65, 0.65, true)
    local currentRealm = GetRealmName and GetRealmName() or ""

    for _, entry in ipairs(RestedXP:GetCharacterEntries()) do
        local profile = entry.character or {}
        local name = profile.name or select(2, UI:ParseCharacterKey(entry.key))
        local classColor = Palette:GetClassColor(profile.classFile)
        local r = classColor and (classColor.r or classColor[1]) or 1
        local g = classColor and (classColor.g or classColor[2]) or 1
        local b = classColor and (classColor.b or classColor[3]) or 1
        local value
        local vr, vg, vb = 0.72, 0.72, 0.76

        if entry.maxLevel then
            value = "Max level"
        elseif entry.percent ~= nil then
            local outsideRestingArea = not entry.isCurrent
                and entry.restingOnLogout == false
            value = string.format("%s%.1f%%",
                outsideRestingArea and "*" or "", entry.percent)
            vr, vg, vb = GetRestedColor(entry.percent, entry.legacyRank)
        else
            value = "N/A"
        end

        if profile.realm and profile.realm ~= ""
            and profile.realm ~= currentRealm then
            name = string.format("%s - %s", name, profile.realm)
        end

        -- Do not imply that an unknown Legacy talent rank equals 0.
        local rankText = entry.legacyRank == nil
            and "?" or tostring(entry.legacyRank)
        name = string.format("%s (%s/5)", name, rankText)

        row = row + 1
        AddRestedTooltipRow(row, name,
            entry.maxLevel and "--" or FormatRestedTime(entry.timeToCap),
            value, r, g, b, vr, vg, vb)
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

    -- Refresh the time estimates every 30 seconds while hovered.
    local restedHover = hoverFrames.rested
    restedHover:HookScript("OnEnter", function(self)
        self.restedTooltipElapsed = 0
        self:SetScript("OnUpdate", function(frame, elapsed)
            frame.restedTooltipElapsed = frame.restedTooltipElapsed + elapsed
            if frame.restedTooltipElapsed >= 30 then
                frame.restedTooltipElapsed = 0
                if GameTooltip:IsOwned(frame) then
                    ShowRestedTooltip(frame)
                end
            end
        end)
    end)
    restedHover:HookScript("OnLeave", function(self)
        self:SetScript("OnUpdate", nil)
    end)

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
            "|TInterface\\Icons\\Spell_Nature_Sleep:13:13:0:2|t %s",
            FormatRestedPercent(restedPercent,
                RestedXP:GetCurrentLegacyRank())
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
