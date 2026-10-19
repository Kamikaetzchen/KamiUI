local UI = KamiUI
local Styles = UI.Styles
local Palette = UI.Palette
local Components = UI.Components
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

-- Read the current bag slot and the item database independently. Only
-- poor-quality, unlocked items with known stack sizes/prices are candidates.
-- The item database's stack count is the maximum, not the amount in the bag.
local function GetJunkStack(bag, slot)
    local info = UI:SafeCall(UI.GetContainerItemInfo, UI, bag, slot)
    if not info or not UI:CanAccessValue(info)
        or (issecrettable and issecrettable(info)) then
        return nil
    end

    local itemID, count = info.itemID, info.stackCount
    if type(itemID) ~= "number" or type(count) ~= "number"
        or not UI:CanAccessValue(itemID)
        or not UI:CanAccessValue(count)
        or count < 1 or info.isLocked or info.hasLoot
        or (info.quality ~= nil and info.quality ~= 0) then
        return nil
    end

    local itemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
    if type(itemInfo) ~= "function" then return nil end

    local ok, name, link, quality, _, _, _, _, maxStack,
        _, icon, unitPrice = pcall(itemInfo, itemID)
    if not ok or type(name) ~= "string" or quality ~= 0
        or type(maxStack) ~= "number" or maxStack < count
        or type(unitPrice) ~= "number" or unitPrice < 0
        or not UI:CanAccessValue(maxStack)
        or not UI:CanAccessValue(unitPrice) then
        return nil
    end

    -- Exclude quest items and items that start quests, if the API supplies
    -- this information. Never rely on an item's gray color alone for those.
    if C_Container and C_Container.GetContainerItemQuestInfo then
        local questInfo = UI:SafeCall(
            C_Container.GetContainerItemQuestInfo, bag, slot)
        if questInfo and (questInfo.isQuestItem or questInfo.questID) then
            return nil
        end
    end

    return {
        bag = bag,
        slot = slot,
        itemID = itemID,
        name = name,
        link = link,
        icon = icon,
        count = count,
        maxStack = maxStack,
        unitPrice = unitPrice,
        currentValue = count * unitPrice,
        fullValue = maxStack * unitPrice,
    }
end

local function IsCheaperJunkStack(candidate, best, metric)
    if not best then return true end
    if candidate[metric] ~= best[metric] then
        return candidate[metric] < best[metric]
    end

    -- On equal estimates, keep the cheaper current stack as a tiebreaker.
    if candidate.currentValue ~= best.currentValue then
        return candidate.currentValue < best.currentValue
    end
    return candidate.fullValue < best.fullValue
end

local function GetCheapestJunkStacks()
    if InCombatLockdown and InCombatLockdown() then
        return nil, nil
    end

    local cheapestCurrent, cheapestFull
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, UI:GetContainerNumSlots(bag) do
            local candidate = GetJunkStack(bag, slot)
            if candidate then
                if IsCheaperJunkStack(
                    candidate, cheapestCurrent, "currentValue") then
                    cheapestCurrent = candidate
                end
                if IsCheaperJunkStack(
                    candidate, cheapestFull, "fullValue") then
                    cheapestFull = candidate
                end
            end
        end
    end

    return cheapestCurrent, cheapestFull
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

-- Three independently aligned numeric columns for the rested tooltip,
-- kept in sync with Blizzard's tooltip rows. Hide them when another
-- tooltip is shown.
local restedTooltipColumns = {}
local function HideRestedTooltipColumns()
    for _, columns in ipairs(restedTooltipColumns) do
        columns.level:Hide()
        columns.time:Hide()
        columns.percent:Hide()
        if columns.spacer then
            columns.spacer:SetTextColor(1, 1, 1, 1)
        end
    end
end
GameTooltip:HookScript("OnHide", HideRestedTooltipColumns)

-- Reuse the exact KamiUI item-slot artwork for the junk candidates.
-- These slots are visuals only: the InfoPanel's bag counter owns the clicks.
local junkTooltipColumns
local function HideJunkTooltipColumns()
    if not junkTooltipColumns then return end
    for _, column in ipairs(junkTooltipColumns) do
        column.slot:Hide()
        column.name:Hide()
        column.current:Hide()
        column.full:Hide()
    end
end
GameTooltip:HookScript("OnHide", HideJunkTooltipColumns)

local function GetJunkTooltipColumns()
    if junkTooltipColumns then return junkTooltipColumns end
    junkTooltipColumns = {}

    for index = 1, 2 do
        local slot = Components:CreateItemDisplayButton(GameTooltip, {
            size = 30,
            corners = true,
            count = true,
            countFontSize = 9,
            rarityGlow = false,
            highlight = false,
        })
        slot:EnableMouse(false)
        slot:SetFrameLevel(GameTooltip:GetFrameLevel() + 2)
        slot:Hide()

        local function NewLabel()
            local label = GameTooltip:CreateFontString(
                nil, "OVERLAY", "GameFontHighlightSmall")
            label:SetWidth(170)
            label:SetJustifyH(index == 2 and "RIGHT" or "LEFT")
            label:SetWordWrap(false)
            label:Hide()
            return label
        end

        local name = NewLabel()
        local current = NewLabel()
        local full = NewLabel()
        name:SetTextColor(1, 1, 1)
        current:SetTextColor(0.76, 0.76, 0.76)
        full:SetTextColor(0.76, 0.76, 0.76)

        if index == 1 then
            name:SetPoint("TOPLEFT", slot, "TOPRIGHT", 6, 0)
            current:SetPoint("TOPLEFT", name, "TOPLEFT", 0, -14)
            full:SetPoint("TOPLEFT", name, "TOPLEFT", 0, -28)
        else
            -- Mirror the right preview: text first, item icon on the edge.
            name:SetPoint("TOPRIGHT", slot, "TOPLEFT", -6, 0)
            current:SetPoint("TOPRIGHT", name, "TOPRIGHT", 0, -14)
            full:SetPoint("TOPRIGHT", name, "TOPRIGHT", 0, -28)
        end

        junkTooltipColumns[index] = {
            slot = slot,
            name = name,
            current = current,
            full = full,
        }
    end

    return junkTooltipColumns
end

local function ShowJunkTooltipColumn(index, anchor, candidate)
    local column = GetJunkTooltipColumns()[index]
    local slot = column.slot
    slot:ClearAllPoints()
    if index == 1 then
        slot:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    else
        slot:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
    end

    Components:SetItemSlotData(slot, {
        itemID = candidate.itemID,
        link = candidate.link,
        icon = candidate.icon,
        quality = 0,
        count = candidate.count,
        countText = tostring(candidate.count),
    })
    slot:Show()

    column.name:SetText(candidate.name)
    column.name:Show()
    column.current:SetText("Now: " ..
        UI:FormatMoney(candidate.currentValue, { iconSize = 10 }))
    column.current:Show()

    column.full:SetText("Full x" .. candidate.maxStack .. ": " ..
        UI:FormatMoney(candidate.fullValue, { iconSize = 10 }))
    column.full:Show()
end

local function PrepareTooltip(owner, title)
    HideRestedTooltipColumns()
    HideJunkTooltipColumns()
    GameTooltip:SetOwner(owner, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("TOP", owner, "BOTTOM", 0, -6)
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

    -- Top section: left and right mouse actions occupy matching columns.
    local current, full = GetCheapestJunkStacks()
    if InCombatLockdown and InCombatLockdown() then
        GameTooltip:AddLine("Junk deletion unavailable in combat",
            0.75, 0.75, 0.75)
    elseif current and full then
        GameTooltip:AddDoubleLine(
            "Shift + Left Click", "Shift + Right Click",
            1, 0.82, 0, 1, 0.82, 0
        )

        -- Invisible native text reserves both column widths and the row
        -- height. Overlay real KamiUI item slots rather than inline icons.
        local spacer = string.rep("W", 10)
        GameTooltip:AddDoubleLine(spacer, spacer, 1, 1, 1, 1, 1, 1)
        local index = GameTooltip:NumLines()
        local left = _G["GameTooltipTextLeft" .. index]
        local right = _G["GameTooltipTextRight" .. index]
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(" ")

        if left and right then
            left:SetTextColor(1, 1, 1, 0)
            right:SetTextColor(1, 1, 1, 0)
            ShowJunkTooltipColumn(1, left, current)
            ShowJunkTooltipColumn(2, right, full)
        end
    else
        GameTooltip:AddLine("No gray items to delete",
            0.75, 0.75, 0.75)
    end

    GameTooltip:AddLine(" ")
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

local function DeleteCheapestJunkStack(mode)
    -- The actual deletion must happen within one deliberate hardware click.
    if not IsShiftKeyDown or not IsShiftKeyDown()
        or (InCombatLockdown and InCombatLockdown())
        or type(DeleteCursorItem) ~= "function"
        or type(GetCursorInfo) ~= "function" then
        return
    end

    -- Never replace or delete anything already held on the cursor.
    if GetCursorInfo() ~= nil then return end

    local pickup = C_Container and C_Container.PickupContainerItem
        or PickupContainerItem
    if type(pickup) ~= "function" then return end

    -- Rescan and revalidate immediately before picking up the stack.
    local cheapestCurrent, cheapestFull = GetCheapestJunkStacks()
    local candidate = mode == "full" and cheapestFull or cheapestCurrent
    if not candidate then return end

    local verified = GetJunkStack(candidate.bag, candidate.slot)
    if not verified or verified.itemID ~= candidate.itemID
        or verified.count ~= candidate.count
        or verified.unitPrice ~= candidate.unitPrice
        or verified.maxStack ~= candidate.maxStack then
        return
    end

    pickup(candidate.bag, candidate.slot)

    local cursorType, cursorItemID = GetCursorInfo()
    if cursorType == "item" and cursorItemID == candidate.itemID then
        DeleteCursorItem()
    elseif cursorType == "item" and ClearCursor then
        -- An unexpected cursor item should not be destroyed.
        ClearCursor()
    end
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

local RESTED_LEVEL_WIDTH = 32
local RESTED_TIME_WIDTH = 95
local RESTED_PERCENT_WIDTH = 62
local RESTED_COLUMN_GAP = 12
-- The native right-hand text is only a sizing placeholder. Keeping it
-- short avoids a large empty gap after the character names; the separately
-- anchored time and percent labels still retain their fixed alignment.
local RESTED_COLUMN_SPACER = string.rep("W", 16)

local function AddRestedTooltipRow(index, name, level, remaining, value,
    nr, ng, nb, vr, vg, vb, header)
    -- Reserve room with the native tooltip layout, but draw three separately
    -- right-aligned fields rather than padding proportional-font text.
    GameTooltip:AddDoubleLine(name, RESTED_COLUMN_SPACER,
        nr, ng, nb, 1, 1, 1)
    local right = _G["GameTooltipTextRight" .. GameTooltip:NumLines()]
    if not right then return end

    local columns = restedTooltipColumns[index]
    if not columns then
        columns = {
            level = GameTooltip:CreateFontString(
                nil, "OVERLAY", "GameFontHighlightSmall"),
            time = GameTooltip:CreateFontString(
                nil, "OVERLAY", "GameFontHighlightSmall"),
            percent = GameTooltip:CreateFontString(
                nil, "OVERLAY", "GameFontHighlightSmall"),
        }
        restedTooltipColumns[index] = columns
    end

    columns.spacer = right
    right:SetTextColor(1, 1, 1, 0)
    for _, label in ipairs({
        columns.level, columns.time, columns.percent
    }) do
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
    local textColor = header and 0.65 or 0.85
    columns.time:SetTextColor(textColor, textColor, textColor)
    columns.time:Show()

    columns.level:SetWidth(RESTED_LEVEL_WIDTH)
    columns.level:SetPoint("RIGHT", columns.time, "LEFT",
        -RESTED_COLUMN_GAP, 0)
    columns.level:SetText(level)
    columns.level:SetTextColor(textColor, textColor, textColor)
    columns.level:Show()

    columns.percent:SetWidth(RESTED_PERCENT_WIDTH)
    columns.percent:SetPoint("RIGHT", right, "RIGHT", 0, 0)
    columns.percent:SetText(value)
    columns.percent:SetTextColor(vr, vg, vb)
    columns.percent:Show()
end

local function ShowRestedTooltip(owner)
    PrepareTooltip(owner, "Rested XP")
    local row = 1
    AddRestedTooltipRow(row, "Character (Legacy)", "Lvl", "To cap",
        "Rested", 0.65, 0.65, 0.65, 0.65, 0.65, 0.65, true)
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

        local level = profile.level
        local levelText = UI:CanAccessValue(level)
            and type(level) == "number"
            and level > 0 and tostring(level) or "--"

        row = row + 1
        AddRestedTooltipRow(row, name, levelText,
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

-- The native game-menu tooltip already knows how to display latency,
-- protocol, FPS, bandwidth, downloads, CPU and the largest addons.
-- Add the total for all KamiUI modules, which might not appear in its top 3.
local function FormatAddonMemory(kilobytes)
    if kilobytes >= 1024 then
        return string.format("%.2f MB", kilobytes / 1024)
    end

    return string.format("%.1f KB", kilobytes)
end

local function GetAddonCount()
    if C_AddOns and C_AddOns.GetNumAddOns then
        return C_AddOns.GetNumAddOns() or 0
    end

    return GetNumAddOns and GetNumAddOns() or 0
end

local function GetAddonName(index)
    local info

    if C_AddOns and C_AddOns.GetAddOnInfo then
        info = UI:SafeCall(C_AddOns.GetAddOnInfo, index)
    elseif GetAddOnInfo then
        info = UI:SafeCall(GetAddOnInfo, index)
    end

    return type(info) == "table" and info.name or info
end

local function GetKamiUIMemory(alreadyUpdated)
    if not GetAddOnMemoryUsage then
        return nil
    end

    -- The native performance tooltip already refreshed the cache. Avoid
    -- making an additional, potentially expensive full addon memory scan.
    if not alreadyUpdated and UpdateAddOnMemoryUsage then
        UI:SafeCall(UpdateAddOnMemoryUsage)
    end

    local total = 0
    local modules = {}

    for index = 1, GetAddonCount() do
        local name = GetAddonName(index)

        if type(name) == "string"
            and (name == "KamiUI" or string.find(name, "^KamiUI_"))
        then
            -- A few protected Blizzard addons reject memory queries;
            -- do not let any such failure break the performance tooltip.
            local usage = UI:SafeCall(GetAddOnMemoryUsage, index)

            if type(usage) == "number"
                and UI:CanAccessValue(usage)
                and usage >= 0
            then
                total = total + usage
                modules[#modules + 1] = {
                    name = name,
                    usage = usage,
                }
            end
        end
    end

    table.sort(modules, function(a, b)
        return a.usage > b.usage
    end)

    return total, modules
end

local function ShowLatencyTooltip(owner)
    HideRestedTooltipColumns()

    -- Reuse Blizzard's full game-menu performance tooltip when available.
    -- The original microbutton may be hidden by KamiUI, so use our hover
    -- frame as the tooltip owner rather than its original button.
    local shown = false
    if MainMenuBarPerformanceBarFrame_OnEnter then
        owner.tooltipText = "Performance"
        owner.newbieText = nil
        shown = pcall(MainMenuBarPerformanceBarFrame_OnEnter, owner)
            and GameTooltip:IsOwned(owner)
    end

    if not shown then
        -- Safe fallback for clients that do not load Blizzard_PerformanceBar.
        PrepareTooltip(owner, "Performance")
        local home, world = GetLatencies()
        GameTooltip:AddDoubleLine("Home latency",
            string.format("%d ms", home), 1, 1, 1, 0.82, 0.82, 0.82)
        GameTooltip:AddDoubleLine("World latency",
            string.format("%d ms", world), 1, 1, 1, 0.82, 0.82, 0.82)

        if GetFramerate then
            GameTooltip:AddDoubleLine("Framerate",
                string.format("%.0f fps", GetFramerate()),
                1, 1, 1, 0.82, 0.82, 0.82)
        end

        if GetAvailableBandwidth then
            local bandwidth = UI:SafeCall(GetAvailableBandwidth)
            if type(bandwidth) == "number" then
                GameTooltip:AddDoubleLine("Bandwidth",
                    string.format("%.2f Mbps", bandwidth),
                    1, 1, 1, 0.82, 0.82, 0.82)
            end
        end
    end

    local total, modules = GetKamiUIMemory(shown)
    if total and #modules > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(
            "KamiUI (all modules)",
            FormatAddonMemory(total),
            1, 0.82, 0, 1, 1, 1
        )

        -- Show the largest contributors without making the tooltip huge.
        for index = 1, math.min(3, #modules) do
            local module = modules[index]
            GameTooltip:AddDoubleLine(
                "  " .. module.name,
                FormatAddonMemory(module.usage),
                0.72, 0.72, 0.72, 0.82, 0.82, 0.82
            )
        end
    end

    GameTooltip:Show()

    if GameTooltip:IsShown() then
        -- Keep the native performance tooltip fixed below its panel slot,
        -- using the same anchoring as every other InfoPanel tooltip.
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("TOP", owner, "BOTTOM", 0, -6)
    end
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
        local hover = CreateFrame(
            key == "bags" and "Button" or "Frame", nil, content)
        hover:SetSize(Layout.SLOT_WIDTHS[key], Layout.HEIGHT)
        hover:SetPoint("CENTER", texts[key], "CENTER", 0, 0)
        hover:SetFrameLevel(content:GetFrameLevel() + 10)
        hover:EnableMouse(true)
        hover:SetScript("OnEnter", showTooltip)
        hover:SetScript("OnLeave", HideTooltip)
        if key == "bags" then
            hover:RegisterForClicks("AnyUp")
            hover:SetScript("OnClick", function(_, mouseButton)
                if mouseButton == "LeftButton" then
                    DeleteCheapestJunkStack("current")
                elseif mouseButton == "RightButton" then
                    DeleteCheapestJunkStack("full")
                end
            end)
        end
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

-- Forever currently uses the Classic XP curve. Historical XP is not
-- exposed by the API, so calculate it from the level requirements.
local function GetXPToNextLevel(level)
    if level < 1 or level >= 60 then return nil end

    local difficulty = 0
    if level == 29 then
        difficulty = 1
    elseif level == 30 then
        difficulty = 3
    elseif level == 31 then
        difficulty = 6
    elseif level >= 32 then
        difficulty = 5 * (level - 30)
    end

    local xp = (8 * level + difficulty) * (45 + 5 * level)
    return math.floor((xp + 50) / 100) * 100
end

local CUMULATIVE_XP = { [1] = 0 }
for level = 2, 60 do
    CUMULATIVE_XP[level] = CUMULATIVE_XP[level - 1]
        + GetXPToNextLevel(level - 1)
end

local function GetXPValues()
    if not UnitLevel or not UnitXP or not UnitXPMax then return nil end
    local level, xp, maxXP = UnitLevel("player"),
        UnitXP("player"), UnitXPMax("player")

    if type(level) ~= "number" or type(xp) ~= "number"
        or type(maxXP) ~= "number"
        or not UI:CanAccessValue(level)
        or not UI:CanAccessValue(xp)
        or not UI:CanAccessValue(maxXP)
        or level < 1 then
        return nil
    end

    return level, xp, maxXP
end

local function GetLifetimeXP()
    local level, xp, maxXP = GetXPValues()
    if not level then return nil end

    -- Avoid claiming a precise lifetime result if a future Forever patch
    -- changes the leveling curve.
    if level > 60 or not CUMULATIVE_XP[level]
        or (level < 60 and maxXP ~= GetXPToNextLevel(level)) then
        return nil
    end

    return CUMULATIVE_XP[level] + xp
end

local function RestorePlayedChatEvents()
    local frames = Module.mutedPlayedChatFrames
    Module.mutedPlayedChatFrames = nil
    if not frames then return end
    for _, frame in ipairs(frames) do
        frame:RegisterEvent("TIME_PLAYED_MSG")
    end
end

local function RequestPlayedTime()
    if type(RequestTimePlayed) ~= "function"
        or Module.playedRequestPending then return end
    local now = GetTime()
    if Module.lastPlayedRequest
        and now - Module.lastPlayedRequest < 10 then return end

    Module.lastPlayedRequest = now
    Module.playedRequestPending = true

    -- RequestTimePlayed also prints a /played line in chat. Temporarily
    -- unhook only frames already registered for that specific event.
    local frames = {}
    for index = 1, NUM_CHAT_WINDOWS or 10 do
        local frame = _G["ChatFrame" .. index]
        if frame and frame.IsEventRegistered
            and frame:IsEventRegistered("TIME_PLAYED_MSG") then
            frames[#frames + 1] = frame
            frame:UnregisterEvent("TIME_PLAYED_MSG")
        end
    end
    Module.mutedPlayedChatFrames = frames

    local ok = pcall(RequestTimePlayed)
    if not ok then
        Module.playedRequestPending = false
        RestorePlayedChatEvents()
        return
    end

    -- Always restore chat events if the server fails to answer.
    C_Timer.After(8, function()
        if Module.playedRequestPending then
            Module.playedRequestPending = false
            RestorePlayedChatEvents()
        end
    end)
end

local function GetPlayedTimes()
    if not Module.playedSnapshotAt then return nil, nil end
    local delta = math.max(0, GetTime() - Module.playedSnapshotAt)
    local total = (Module.playedTotal or 0) + delta
    local level = UnitLevel("player") == Module.playedLevelNumber
        and (Module.playedLevelSeconds or 0) + delta or nil
    return level, total
end

local function ResetSession()
    Module.sessionStart = GetTime()
    Module.sessionXP = 0
    Module.lastLevel, Module.lastXP, Module.lastMaxXP = GetXPValues()
end

local function UpdateXPTracking()
    if Module.levelUpPending then return end
    local level, xp, maxXP = GetXPValues()
    if not level then return end

    local oldLevel, oldXP = Module.lastLevel, Module.lastXP
    if not oldLevel then
        Module.lastLevel, Module.lastXP, Module.lastMaxXP =
            level, xp, maxXP
        return
    end

    local gained = 0
    if level > oldLevel then
        -- Count the remainder of the previous level plus any overflow
        -- into the next level. This fixes the lost-XP-at-level-up bug.
        gained = math.max(0,
            (Module.lastMaxXP or 0) - (oldXP or 0)) + xp
    elseif level == oldLevel and xp >= (oldXP or 0) then
        gained = xp - (oldXP or 0)
    end

    Module.sessionXP = (Module.sessionXP or 0) + math.max(0, gained)
    Module.lastLevel, Module.lastXP, Module.lastMaxXP =
        level, xp, maxXP
end

local function CalculateXPPerHour(xp, seconds)
    if not seconds or seconds <= 0 then return nil end
    return math.floor(math.max(0, xp or 0) * 3600 / seconds + 0.5)
end

local function GetXPPerHour()
    local elapsed = GetTime() - (Module.sessionStart or GetTime())
    return CalculateXPPerHour(Module.sessionXP or 0, elapsed) or 0
end

local function FormatXPDuration(seconds)
    if not seconds then return "--" end
    seconds = math.max(0, math.floor(seconds))
    local days = math.floor(seconds / 86400)
    local hours = math.floor(seconds % 86400 / 3600)
    local minutes = math.floor(seconds % 3600 / 60)

    if days > 0 then
        return string.format("%dd %dh", days, hours)
    elseif hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    elseif minutes > 0 then
        return string.format("%dm %ds", minutes, seconds % 60)
    end
    return string.format("%ds", seconds)
end

-- A common snapshot keeps XP/h and time-to-level tooltips in sync.
local function GetXPRateSnapshots()
    local sessionSeconds = math.max(0,
        GetTime() - (Module.sessionStart or GetTime()))
    local levelSeconds, totalSeconds = GetPlayedTimes()
    local _, levelXP = GetXPValues()
    local totalXP = GetLifetimeXP()

    local snapshots = {
        { label = "Session", xp = Module.sessionXP or 0,
            seconds = sessionSeconds },
        { label = "Current level", xp = levelXP,
            seconds = levelSeconds },
        { label = "Overall", xp = totalXP,
            seconds = totalSeconds },
    }

    for _, snapshot in ipairs(snapshots) do
        if snapshot.xp ~= nil then
            snapshot.rate = CalculateXPPerHour(
                snapshot.xp, snapshot.seconds)
        end
    end

    return snapshots
end

local function EnsurePlayedTime(snapshots)
    if not snapshots[2].seconds or not snapshots[3].seconds then
        RequestPlayedTime()
    end
end

local function ShowXPTooltip(owner)
    PrepareTooltip(owner, "Experience per Hour")
    local snapshots = GetXPRateSnapshots()

    for _, snapshot in ipairs(snapshots) do
        GameTooltip:AddDoubleLine(
            snapshot.label,
            snapshot.rate
                and (FormatXPPerHour(snapshot.rate) .. " XP/h") or "--",
            1, 1, 1, 1, 0.82, 0
        )
        GameTooltip:AddDoubleLine(
            "  " .. (snapshot.xp
                and (UI:FormatNumber(snapshot.xp) .. " XP") or "--"),
            FormatXPDuration(snapshot.seconds),
            0.65, 0.65, 0.65, 0.65, 0.65, 0.65
        )
    end

    GameTooltip:Show()
    EnsurePlayedTime(snapshots)
end

tooltipHandlers.xp = ShowXPTooltip

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

local function ShowTimeToLevelTooltip(owner)
    PrepareTooltip(owner, "Time to Level")
    local snapshots = GetXPRateSnapshots()

    for _, snapshot in ipairs(snapshots) do
        GameTooltip:AddDoubleLine(
            snapshot.label, GetTimeToLevel(snapshot.rate),
            1, 1, 1, 1, 0.82, 0
        )
    end

    GameTooltip:Show()
    EnsurePlayedTime(snapshots)
end

tooltipHandlers.levelup = ShowTimeToLevelTooltip

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
            RequestPlayedTime()
            RestedXP:CaptureCurrent()
            Module:Refresh()
        end)
    end)

    UI:RegisterEvent("TIME_PLAYED_MSG", function(_, total, levelSeconds)
        Module.playedRequestPending = false
        RestorePlayedChatEvents()
        if type(total) == "number" and type(levelSeconds) == "number"
            and UI:CanAccessValue(total)
            and UI:CanAccessValue(levelSeconds) then
            Module.playedTotal = total
            Module.playedLevelSeconds = levelSeconds
            Module.playedLevelNumber = UnitLevel("player")
            Module.playedSnapshotAt = GetTime()

            local hoverFrames = Module.hoverFrames or {}
            if hoverFrames.xp and GameTooltip:IsOwned(hoverFrames.xp) then
                ShowXPTooltip(hoverFrames.xp)
            elseif hoverFrames.levelup
                and GameTooltip:IsOwned(hoverFrames.levelup) then
                ShowTimeToLevelTooltip(hoverFrames.levelup)
            end
        end
    end)
    UI:RegisterEvent("UPDATE_EXHAUSTION", function()
        RestedXP:CaptureCurrent()
        Module:Refresh()
    end)
    UI:RegisterEvent("PLAYER_UPDATE_RESTING", function()
        RestedXP:CaptureCurrent()
    end)
    UI:RegisterEvent("PLAYER_LOGOUT", function()
        RestorePlayedChatEvents()
        RestedXP:CaptureCurrent()
    end)

    UI:RegisterEvent("PLAYER_XP_UPDATE", function()
        UpdateXPTracking()
        RestedXP:CaptureCurrent()
        Module:Refresh()
    end)

    UI:RegisterEvent("PLAYER_LEVEL_UP", function()
        Module.levelUpPending = true

        C_Timer.After(0, function()
            Module.levelUpPending = false
            UpdateXPTracking()
            Module.playedLevelNumber = nil
            RequestPlayedTime()
            RestedXP:CaptureCurrent()
            Module:Refresh()
        end)
    end)

    UI:RegisterEvent("BAG_UPDATE_DELAYED", function()
        Module:Refresh()
        local bagHover = Module.hoverFrames and Module.hoverFrames.bags
        if bagHover and GameTooltip:IsOwned(bagHover) then
            ShowBagsTooltip(bagHover)
        end
    end)

    UI:RegisterEvent("GET_ITEM_INFO_RECEIVED", function()
        local bagHover = Module.hoverFrames and Module.hoverFrames.bags
        if bagHover and GameTooltip:IsOwned(bagHover) then
            ShowBagsTooltip(bagHover)
        end
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
