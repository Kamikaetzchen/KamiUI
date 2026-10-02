local UI = KamiUI

local Module = UI:NewModule("Auras")

Module.name = "KamiUI_Auras"
Module.version = "0.1.0"

local defaults = {
    width = 300,
    height = 25,
    iconSize = 25,
    groupGap = 4,
    x = 0,
    y = 300,
    fontSize = 11,
    updateInterval = 0.05,
    barAlpha = 0.40,
    backgroundAlpha = 0.60,
    backgroundTint = 0.28,
    helpfulColor = { 0.20, 0.55, 0.90 },
    neutralColor = { 0.03, 0.03, 0.03 },
}

local auraRows = {}
local activeRows = {}
local hiddenObjects = setmetatable({}, { __mode = "k" })
local groupFrames = {}

local function HideObject(object)
    if not object then
        return
    end

    object:Hide()

    if not hiddenObjects[object] and object.HookScript then
        hiddenObjects[object] = true

        object:HookScript("OnShow", function(self)
            self:Hide()
        end)
    end
end

local function HideBlizzardAuras()
    HideObject(BuffFrame)
    HideObject(DebuffFrame)
end

local function GetColorComponents(color, fallback)
    if color then
        if color.GetRGB then
            return color:GetRGB()
        end

        if color.r and color.g and color.b then
            return color.r, color.g, color.b
        end
    end

    return unpack(fallback)
end

local function CreateBorder(parent, top, bottom, left, right)
    local function CreateEdge(pointA, pointB, width, height)
        local edge = parent:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(0, 0, 0, 1)
        edge:SetPoint(pointA, parent, pointA)
        edge:SetPoint(pointB, parent, pointB)

        if width then
            edge:SetWidth(width)
        end

        if height then
            edge:SetHeight(height)
        end
    end

    if top then
        CreateEdge("TOPLEFT", "TOPRIGHT", nil, 1)
    end

    if bottom then
        CreateEdge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    end

    if left then
        CreateEdge("TOPLEFT", "BOTTOMLEFT", 1, nil)
    end

    if right then
        CreateEdge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
    end
end

local function GetAuraColor(aura)
    local dispelColors = {
        Magic = DEBUFF_TYPE_MAGIC_COLOR,
        Curse = DEBUFF_TYPE_CURSE_COLOR,
        Disease = DEBUFF_TYPE_DISEASE_COLOR,
        Poison = DEBUFF_TYPE_POISON_COLOR,
        Bleed = DEBUFF_TYPE_BLEED_COLOR,
    }

    if aura.dispelName and dispelColors[aura.dispelName] then
        return GetColorComponents(
            dispelColors[aura.dispelName],
            defaults.helpfulColor
        )
    end

    if aura.isHarmful then
        return GetColorComponents(
            DEBUFF_TYPE_NONE_COLOR,
            { 0.80, 0.20, 0.20 }
        )
    end

    return unpack(defaults.neutralColor)
end

local function GetAuraBackgroundColor(r, g, b)
    local tint = defaults.backgroundTint
    local nr, ng, nb = unpack(defaults.neutralColor)

    return nr + (r - nr) * tint,
        ng + (g - ng) * tint,
        nb + (b - nb) * tint
end

local function FormatTime(seconds)
    if not seconds or seconds <= 0 then
        return ""
    end

    if seconds >= 3600 then
        return string.format("%dh", math.ceil(seconds / 3600))
    end

    if seconds >= 60 then
        return string.format("%dm", math.ceil(seconds / 60))
    end

    if seconds >= 10 then
        return string.format("%ds", math.ceil(seconds))
    end

    return string.format("%.1f", seconds)
end

local function CreateAuraRow(index)
    local row = CreateFrame(
        "Button",
        "KamiUIAuraRow" .. index,
        UIParent
    )
    row:SetSize(defaults.width, defaults.height)

    -- Rows only draw their bottom separator. The group frame provides the
    -- shared outer border, so adjacent rows never stack two 1px borders.
    CreateBorder(row, false, true, false, false)

    row:RegisterForClicks("RightButtonUp")

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(defaults.iconSize, defaults.iconSize)
    icon:SetPoint("LEFT")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local bar = CreateFrame("StatusBar", nil, row)
    bar:SetSize(defaults.width - defaults.iconSize, defaults.height)
    bar:SetPoint("LEFT", icon, "RIGHT", 0, 0)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetMinMaxValues(0, 1)

    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(
        defaults.neutralColor[1],
        defaults.neutralColor[2],
        defaults.neutralColor[3],
        defaults.backgroundAlpha
    )

    local nameText = bar:CreateFontString(nil, "OVERLAY")
    nameText:SetPoint("LEFT", 4, 0)
    nameText:SetPoint("RIGHT", bar, "RIGHT", -42, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetTextColor(1, 1, 1)
    nameText:SetShadowColor(0, 0, 0, 1)
    nameText:SetShadowOffset(1, -1)

    local timeText = bar:CreateFontString(nil, "OVERLAY")
    timeText:SetPoint("RIGHT", -4, 0)
    timeText:SetJustifyH("RIGHT")
    timeText:SetTextColor(1, 1, 1)
    timeText:SetShadowColor(0, 0, 0, 1)
    timeText:SetShadowOffset(1, -1)

    local fontPath, _, fontFlags = GameFontNormalSmall:GetFont()
    nameText:SetFont(fontPath, defaults.fontSize, fontFlags)
    timeText:SetFont(fontPath, defaults.fontSize, fontFlags)

    row:SetScript("OnClick", function(self, button)
        if button ~= "RightButton" then
            return
        end

        if not self.aura or not self.aura.isHelpful then
            return
        end

        if C_UnitAuras
            and C_UnitAuras.CancelAuraByInstanceID
            and self.aura.auraInstanceID
        then
            C_UnitAuras.CancelAuraByInstanceID(
                "player",
                self.aura.auraInstanceID
            )
        elseif self.aura.index then
            CancelUnitBuff(
                "player",
                self.aura.index,
                self.aura.filter
            )
        end
    end)

    row:SetScript("OnEnter", function(self)
        if not self.aura or not self.aura.index then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_LEFT")

        if GameTooltip.SetUnitAura then
            GameTooltip:SetUnitAura(
                "player",
                self.aura.index,
                self.aura.filter
            )
        end

        GameTooltip:Show()
    end)

    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    row.icon = icon
    row.bar = bar
    row.background = background
    row.nameText = nameText
    row.timeText = timeText

    auraRows[index] = row

    return row
end

local function GetAuraRow(index)
    return auraRows[index] or CreateAuraRow(index)
end

local function CollectAurasForFilter(auras, filter, isHelpful)
    local auraIndex = 0

    local function AddAura(auraData)
        auraIndex = auraIndex + 1

        table.insert(auras, {
            name = auraData.name,
            icon = auraData.icon,
            applications = auraData.applications,
            dispelName = auraData.dispelName,
            duration = auraData.duration or 0,
            expirationTime = auraData.expirationTime or 0,
            isHelpful = isHelpful,
            isHarmful = not isHelpful,
            index = auraIndex,
            filter = filter,
            auraInstanceID = auraData.auraInstanceID,
        })
    end

    if AuraUtil and AuraUtil.ForEachAura then
        AuraUtil.ForEachAura(
            "player",
            filter,
            nil,
            AddAura,
            true
        )
        return
    end

    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for index = 1, 255 do
            local auraData = C_UnitAuras.GetAuraDataByIndex(
                "player",
                index,
                filter
            )

            if not auraData then
                break
            end

            AddAura(auraData)
        end
    end
end

local function SortAuras(auras)
    table.sort(auras, function(a, b)
        local aPermanent = not a.duration or a.duration <= 0
        local bPermanent = not b.duration or b.duration <= 0

        if aPermanent ~= bPermanent then
            return aPermanent
        end

        if aPermanent and bPermanent then
            return (a.name or "") < (b.name or "")
        end

        if a.expirationTime == b.expirationTime then
            return (a.name or "") < (b.name or "")
        end

        return a.expirationTime > b.expirationTime
    end)
end

local function CollectAuras()
    local helpful = {}
    local harmful = {}

    CollectAurasForFilter(helpful, "HELPFUL", true)
    CollectAurasForFilter(harmful, "HARMFUL", false)

    SortAuras(helpful)
    SortAuras(harmful)

    return helpful, harmful
end

local function UpdateRow(row, aura)
    row.aura = aura
    row.icon:SetTexture(aura.icon)
    row.nameText:SetText(aura.name or "")

    local r, g, b = GetAuraColor(aura)
    row.bar:SetStatusBarColor(r, g, b, defaults.barAlpha)

    local br, bg, bb = GetAuraBackgroundColor(r, g, b)
    row.background:SetColorTexture(
        br,
        bg,
        bb,
        defaults.backgroundAlpha
    )

    if aura.duration and aura.duration > 0 then
        local remaining = math.max(
            aura.expirationTime - GetTime(),
            0
        )

        row.bar:SetMinMaxValues(0, aura.duration)
        row.bar:SetValue(remaining)
        row.timeText:SetText(FormatTime(remaining))
    else
        row.bar:SetMinMaxValues(0, 1)
        row.bar:SetValue(0)
        row.timeText:SetText("")
    end

    row:Show()
end

local function GetGroupFrame(key)
    local group = groupFrames[key]
    if group then
        return group
    end

    group = CreateFrame("Frame", nil, UIParent)
    group:SetWidth(defaults.width)
    group:SetFrameLevel(50)
    group:EnableMouse(false)
    CreateBorder(group, true, true, true, true)
    group:Hide()

    groupFrames[key] = group
    return group
end

local function LayoutGroupBorder(key, count, baseY)
    local group = GetGroupFrame(key)

    if count <= 0 then
        group:Hide()
        return
    end

    group:ClearAllPoints()
    group:SetPoint(
        "BOTTOMRIGHT",
        UIParent,
        "BOTTOMRIGHT",
        defaults.x,
        baseY
    )
    group:SetSize(defaults.width, count * defaults.height)
    group:Show()
end

local function LayoutAuraGroup(auras, startRow, baseY)
    for index, aura in ipairs(auras) do
        local rowIndex = startRow + index - 1
        local row = GetAuraRow(rowIndex)

        row:ClearAllPoints()
        row:SetPoint(
            "BOTTOMRIGHT",
            UIParent,
            "BOTTOMRIGHT",
            defaults.x,
            baseY + ((index - 1) * defaults.height)
        )

        UpdateRow(row, aura)
        table.insert(activeRows, row)
    end

    return startRow + #auras
end

local function LayoutRows(helpful, harmful)
    wipe(activeRows)

    local baseY = defaults.y + UI:GetBottomInset()

    local nextRow = LayoutAuraGroup(
        helpful,
        1,
        baseY
    )
    LayoutGroupBorder("helpful", #helpful, baseY)

    local harmfulY = baseY + (#helpful * defaults.height)

    if #helpful > 0 and #harmful > 0 then
        harmfulY = harmfulY + defaults.groupGap
    end

    nextRow = LayoutAuraGroup(
        harmful,
        nextRow,
        harmfulY
    )
    LayoutGroupBorder("harmful", #harmful, harmfulY)

    for index = nextRow, #auraRows do
        local row = auraRows[index]

        row.aura = nil
        row:Hide()
    end
end

function Module:Refresh()
    HideBlizzardAuras()

    local helpful, harmful = CollectAuras()
    LayoutRows(helpful, harmful)
end

local elapsedSinceUpdate = 0

local updater = CreateFrame("Frame")
updater:SetScript("OnUpdate", function(_, elapsed)
    elapsedSinceUpdate = elapsedSinceUpdate + elapsed

    if elapsedSinceUpdate < defaults.updateInterval then
        return
    end

    elapsedSinceUpdate = 0
    local now = GetTime()

    for _, row in ipairs(activeRows) do
        local aura = row.aura

        if aura and aura.duration and aura.duration > 0 then
            local remaining = math.max(
                aura.expirationTime - now,
                0
            )

            row.bar:SetValue(remaining)
            row.timeText:SetText(FormatTime(remaining))
        end
    end
end)

function Module:Initialize()
    self:Refresh()

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0, function()
            Module:Refresh()
        end)
    end)

    UI:RegisterBottomInsetCallback(function()
        Module:Refresh()
    end)

    UI:RegisterEvent("UNIT_AURA", function(_, unit)
        if unit == "player" then
            Module:Refresh()
        end
    end)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_BuffFrame" then
            C_Timer.After(0, function()
                Module:Refresh()
            end)
        end
    end)
end

Module:Initialize()
