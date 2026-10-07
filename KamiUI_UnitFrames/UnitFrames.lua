local UI = KamiUI
local Palette = UI.Palette

local UF = UI:NewModule("UnitFrames", "KamiUI_UnitFrames")


UF.flatTexture = "Interface\\Buttons\\WHITE8X8"
UF.colorMultiplier = 0.60
UF.powerColorMultiplier = 0.85

UF.frames = {}
UF.framesByUnit = {}

local function CopyFeatures(features)
    local copy = {}

    for key, value in pairs(features or {}) do
        copy[key] = value
    end

    return copy
end

function UF:RegisterFrame(frame, features)
    if not frame or frame.KamiUIRegistered then
        return frame
    end

    frame.KamiUIRegistered = true
    frame.features = CopyFeatures(features)

    self.frames[#self.frames + 1] = frame

    local unit = frame.unit

    if unit then
        self.framesByUnit[unit] = self.framesByUnit[unit] or {}
        self.framesByUnit[unit][#self.framesByUnit[unit] + 1] = frame
    end

    return frame
end

function UF:HasFeature(frame, feature)
    return frame
        and frame.features
        and frame.features[feature] == true
end

function UF:ForEachFrame(callback, feature)
    if type(callback) ~= "function" then
        return
    end

    for _, frame in ipairs(self.frames) do
        if not feature or self:HasFeature(frame, feature) then
            callback(frame)
        end
    end
end

function UF:ForEachUnitFrame(unit, callback, feature)
    if not unit or type(callback) ~= "function" then
        return
    end

    for _, frame in ipairs(self.framesByUnit[unit] or {}) do
        if not feature or self:HasFeature(frame, feature) then
            callback(frame)
        end
    end
end

function UF:ForEachMatchingUnitFrame(unit, callback, feature)
    if not unit or type(callback) ~= "function" then
        return
    end

    for _, frame in ipairs(self.frames) do
        if not feature or self:HasFeature(frame, feature) then
            local matches = frame.unit == unit

            if not matches
                and UnitExists(frame.unit)
                and UnitExists(unit)
                and UnitIsUnit
            then
                matches = UnitIsUnit(frame.unit, unit)

                if not UI:CanAccessValue(matches) then
                    matches = false
                end
            end

            if matches then
                callback(frame)
            end
        end
    end
end

local HAPPINESS_COLORS = {
    [1] = { 0.85, 0.10, 0.10 },
    [2] = { 0.85, 0.65, 0.05 },
    [3] = { 0.10, 0.75, 0.20 },
}

local CLASSIFICATION_SUFFIX = {
    elite = "E",
    rare = "R",
    rareelite = "RE",
    worldboss = "B",
}

local function ToHexChannel(value)
    return math.floor(math.max(0, math.min(1, value)) * 255 + 0.5)
end

local function CreateFrameBackground(parent)
    local background = parent:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 1)
    return background
end

function UF:GetUnitColor(unit)
    local tapDenied = UnitIsTapDenied and UnitIsTapDenied(unit)

    if UI:CanAccessValue(tapDenied) and tapDenied then
        return 0.35, 0.35, 0.35
    end

    if unit == "pet" and C_PetInfo and C_PetInfo.GetPetHappiness then
        local happiness = C_PetInfo.GetPetHappiness()

        if happiness and UI:CanAccessValue(happiness) then
            local color = HAPPINESS_COLORS[happiness]

            if color then
                return self:DarkenColor(color[1], color[2], color[3])
            end
        end
    end

    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)

        if class and UI:CanAccessValue(class) then
            local color = Palette:GetClassColor(class)

            if color then
                return self:DarkenColor(
                    color.r or color[1],
                    color.g or color[2],
                    color.b or color[3]
                )
            end
        end
    end

    local reaction = UnitReaction(unit, "player")

    if reaction and UI:CanAccessValue(reaction) and FACTION_BAR_COLORS then
        local color = FACTION_BAR_COLORS[reaction]

        if color then
            return self:DarkenColor(color.r, color.g, color.b)
        end
    end

    return self:DarkenColor(0.2, 0.8, 0.2)
end

function UF:GetPowerColor(unit)
    local _, powerToken = UnitPowerType(unit)

    return Palette:GetReadablePowerColor(
        powerToken,
        self.powerColorMultiplier
    )
end

function UF:DarkenColor(r, g, b)
    return r * self.colorMultiplier,
        g * self.colorMultiplier,
        b * self.colorMultiplier
end

function UF:GetBarFontSize(height)
    return math.min(height, 10)
end

function UF:GetUnitDisplayName(unit)
    local name

    if GetUnitName then
        name = GetUnitName(unit)
    end

    name = name or UnitName(unit) or ""

    local status = ""

    local isAFK = UnitIsAFK and UnitIsAFK(unit)
    local isDND = UnitIsDND and UnitIsDND(unit)

    if UI:CanAccessValue(isAFK) and isAFK then
        status = "<AFK> "
    elseif UI:CanAccessValue(isDND) and isDND then
        status = "<DND> "
    end

    local level = UnitLevel(unit)
    local levelText = level and level > 0 and tostring(level) or "??"
    local classification = UnitClassification(unit)
    local suffix = CLASSIFICATION_SUFFIX[classification] or ""

    local color = Palette:GetLevelDifficultyColor(level)

    local levelColor = string.format(
        "|cff%02x%02x%02x",
        ToHexChannel(color.r or color[1]),
        ToHexChannel(color.g or color[2]),
        ToHexChannel(color.b or color[3])
    )

    return status .. levelColor .. levelText .. suffix .. "|r " .. name
end

function UF:GetUnitFirstName(unit)
    local firstName = UnitName(unit)

    if firstName and UI:CanAccessValue(firstName) then
        return firstName
    end

    return ""
end

function UF:SetUnitFirstName(fontString, unit)
    if not fontString then
        return
    end

    fontString:SetText(self:GetUnitFirstName(unit))
end

function UF:ConfigureNameText(fontString)
    if fontString.SetWordWrap then
        fontString:SetWordWrap(false)
    end

    if fontString.SetMaxLines then
        fontString:SetMaxLines(1)
    end
end

function UF:SetUnitDisplayName(fontString, unit)
    if not fontString then
        return
    end

    local display = self:GetUnitDisplayName(unit)
    fontString:SetText(display)

    if not UI:CanAccessValue(display) then
        return
    end

    local width = fontString:GetWidth()

    if not UI:CanAccessValue(width) or not width or width <= 0 then
        return
    end

    local stringWidth = fontString:GetStringWidth()

    if not UI:CanAccessValue(stringWidth) or stringWidth <= width then
        return
    end

    local prefix, name = string.match(display, "^(.-|r%s)(.*)$")

    if not prefix then
        prefix = ""
        name = display
    end

    local length = #name

    while length > 0 do
        length = length - 1
        fontString:SetText(
            prefix .. string.sub(name, 1, length) .. "..."
        )

        stringWidth = fontString:GetStringWidth()

        if not UI:CanAccessValue(stringWidth) then
            fontString:SetText(display)
            return
        end

        if stringWidth <= width then
            return
        end
    end

    fontString:SetText(prefix .. "...")
end

function UF:ConfigureUnitButton(frame, unit)
    frame.unit = unit
    frame:RegisterForClicks("AnyUp")
    frame:SetAttribute("unit", unit)
    frame:SetAttribute("*type1", "target")
    frame:SetAttribute("*type2", "togglemenu")

    if frame.HookScript
        and not frame.KamiUnitTooltipHooked
    then
        frame.KamiUnitTooltipHooked = true

        frame:HookScript("OnEnter", function(self)
            local tooltipUnit = self.unit

            if not GameTooltip
                or not tooltipUnit
                or not UnitExists(tooltipUnit)
            then
                return
            end

            GameTooltip:SetOwner(
                self,
                "ANCHOR_CURSOR_RIGHT"
            )
            GameTooltip:SetUnit(tooltipUnit)
        end)

        frame:HookScript("OnLeave", function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)
    end
end

function UF:CreateBar(parent, width, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(width, height)
    bar:SetStatusBarTexture(self.flatTexture)

    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.08, 0.08, 0.08, 1)

    bar.background = background

    return bar
end

function UF:CreateText(parent, barHeight, justify, fontOffset)
    local text = parent:CreateFontString(nil, "OVERLAY")
    local fontPath, _, fontFlags = GameFontNormalSmall:GetFont()
    local fontSize = math.max(
        1,
        self:GetBarFontSize(barHeight) + (fontOffset or 0)
    )

    text:SetFont(fontPath, fontSize, fontFlags)
    text:SetJustifyH(justify or "LEFT")
    text:SetTextColor(1, 1, 1)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)

    return text
end

function UF:CreatePortrait(parent, size)
    local portrait = CreateFrame("PlayerModel", nil, parent)
    portrait:SetSize(size, size)
    portrait:EnableMouse(false)

    if portrait.SetPortraitZoom then
        portrait:SetPortraitZoom(1)
    end

    if portrait.SetCamDistanceScale then
        portrait:SetCamDistanceScale(1)
    end

    return portrait
end

function UF:CreateUnitFrameBase(options)
    options = options or {}

    local frame = CreateFrame(
        "Button",
        options.name,
        options.parent or UIParent,
        "SecureUnitButtonTemplate"
    )

    frame:SetSize(options.width, options.height)
    self:ConfigureUnitButton(frame, options.unit)

    if options.watch ~= false and RegisterUnitWatch then
        RegisterUnitWatch(frame)
    end

    CreateFrameBackground(frame)

    return frame
end

function UF:CreatePrimaryFrame(options)
    options = options or {}

    local width = options.width or 200
    local height = options.height or 40
    local borderSize = options.borderSize or 1
    local separatorSize = options.separatorSize or 1
    local contentWidth = width - borderSize * 2
    local contentHeight = height - borderSize * 2
    local portraitSize = options.portraitSize or contentHeight
    local barWidth = contentWidth - portraitSize
    local healthHeight = options.healthHeight or 22
    local powerHeight = options.powerHeight or 15
    local healthCastHeight = options.healthCastHeight or 17
    local powerCastHeight = options.powerCastHeight or 11
    local castHeight = options.castHeight or 8
    local portraitSide = options.portraitSide == "RIGHT" and "RIGHT" or "LEFT"

    local frame = self:CreateUnitFrameBase({
        name = options.name,
        unit = options.unit,
        parent = options.parent,
        width = width,
        height = height,
        watch = options.watch,
    })

    local features = CopyFeatures(options.features)
    features.cast = true
    self:RegisterFrame(frame, features)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", borderSize, -borderSize)
    content:SetPoint("BOTTOMRIGHT", -borderSize, borderSize)

    local portrait = self:CreatePortrait(content, portraitSize)

    if portraitSide == "RIGHT" then
        portrait:SetPoint("TOPRIGHT")
    else
        portrait:SetPoint("TOPLEFT")
    end

    local health = self:CreateBar(content, barWidth, healthHeight)

    if portraitSide == "RIGHT" then
        health:SetPoint("TOPLEFT")
    else
        health:SetPoint("TOPLEFT", portrait, "TOPRIGHT")
    end

    local power = self:CreateBar(content, barWidth, powerHeight)
    power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -separatorSize)

    local cast = self:CreateBar(content, barWidth, castHeight)
    cast:SetPoint("TOPLEFT", power, "BOTTOMLEFT", 0, -separatorSize)
    cast:SetStatusBarColor(0.65, 0.45, 0.10)
    cast:Hide()

    local nameText = self:CreateText(health, healthHeight, "LEFT")
    nameText:SetPoint("LEFT", options.textInset or 3, 0)
    nameText:SetWidth(options.nameWidth or 110)
    self:ConfigureNameText(nameText)

    local healthText = self:CreateText(health, healthHeight, "RIGHT")
    healthText:SetPoint("RIGHT", -(options.textInset or 3), 0)

    local powerText = self:CreateText(power, powerHeight, "RIGHT")
    powerText:SetPoint("RIGHT", -(options.textInset or 3), 0)

    local fontPath, _, fontFlags = GameFontNormalSmall:GetFont()

    local castNameText = cast:CreateFontString(nil, "OVERLAY")
    castNameText:SetFont(
        fontPath,
        self:GetBarFontSize(castHeight),
        "OUTLINE"
    )
    castNameText:SetPoint("LEFT", 2, 0)
    castNameText:SetJustifyH("LEFT")
    castNameText:SetTextColor(1, 1, 1)

    local castProgressText = cast:CreateFontString(nil, "OVERLAY")
    castProgressText:SetFont(
        fontPath,
        self:GetBarFontSize(castHeight),
        "OUTLINE"
    )
    castProgressText:SetPoint("RIGHT", -2, 0)
    castProgressText:SetJustifyH("RIGHT")
    castProgressText:SetTextColor(1, 1, 1)

    frame.content = content
    frame.health = health
    frame.power = power
    frame.cast = cast
    frame.portrait = portrait
    frame.nameText = nameText
    frame.healthText = healthText
    frame.powerText = powerText
    frame.castNameText = castNameText
    frame.castProgressText = castProgressText
    frame.castLayout = {
        healthHeight = healthHeight,
        powerHeight = powerHeight,
        healthCastHeight = healthCastHeight,
        powerCastHeight = powerCastHeight,
        fontPath = fontPath,
        fontFlags = fontFlags,
    }

    cast:SetScript("OnUpdate", function()
        UF:UpdateCastProgress(frame)
    end)

    return frame
end

function UF:CreateCompactFrame(options)
    options = options or {}

    local width = options.width or 150
    local height = options.height or 25
    local borderSize = options.borderSize or 1
    local separatorSize = options.separatorSize or 1
    local healthHeight = options.healthHeight or 13
    local powerHeight = options.powerHeight or 9
    local contentWidth = width - borderSize * 2

    local frame = self:CreateUnitFrameBase({
        name = options.name,
        unit = options.unit,
        parent = options.parent,
        width = width,
        height = height,
        watch = options.watch,
    })

    self:RegisterFrame(frame, options.features)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", borderSize, -borderSize)
    content:SetPoint("BOTTOMRIGHT", -borderSize, borderSize)

    local health = self:CreateBar(content, contentWidth, healthHeight)
    health:SetPoint("TOPLEFT")

    local power = self:CreateBar(content, contentWidth, powerHeight)
    power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -separatorSize)

    local nameText = self:CreateText(
        health,
        healthHeight,
        "LEFT",
        options.nameFontOffset or 0
    )
    nameText:SetPoint("LEFT", options.textInset or 2, 0)
    nameText:SetWidth(options.nameWidth or (contentWidth - 42))
    self:ConfigureNameText(nameText)

    local healthText = self:CreateText(
        health,
        healthHeight,
        "RIGHT",
        options.healthFontOffset or 0
    )
    healthText:SetPoint("RIGHT", -(options.textInset or 2), 0)

    local powerText = self:CreateText(
        power,
        powerHeight,
        "RIGHT",
        options.powerFontOffset or 0
    )
    powerText:SetPoint("RIGHT", -(options.textInset or 2), 0)

    frame.content = content
    frame.health = health
    frame.power = power
    frame.nameText = nameText
    frame.healthText = healthText
    frame.powerText = powerText

    return frame
end

function UF:CreateHealthFrame(options)
    options = options or {}

    local width = options.width or 100
    local height = options.height or 13
    local borderSize = options.borderSize or 1
    local healthHeight = options.healthHeight or (height - borderSize * 2)

    local frame = self:CreateUnitFrameBase({
        name = options.name,
        unit = options.unit,
        parent = options.parent,
        width = width,
        height = height,
        watch = options.watch,
    })

    self:RegisterFrame(frame, options.features)

    local health = self:CreateBar(
        frame,
        width - borderSize * 2,
        healthHeight
    )
    health:SetPoint("TOPLEFT", borderSize, -borderSize)

    local nameText = self:CreateText(
        health,
        healthHeight,
        "LEFT",
        options.nameFontOffset or 0
    )
    nameText:SetPoint("LEFT", options.textInset or 2, 0)
    nameText:SetPoint("RIGHT", -(options.textInset or 2), 0)
    self:ConfigureNameText(nameText)

    frame.health = health
    frame.nameText = nameText

    return frame
end

function UF:CreateRaidFrame(options)
    options = options or {}

    local width = options.width or 75
    local height = options.height or 25
    local borderSize = options.borderSize or 1
    local separatorSize = options.separatorSize or 1
    local healthHeight = options.healthHeight or 13
    local powerHeight = options.powerHeight or 9
    local contentWidth = width - borderSize * 2

    local frame = self:CreateUnitFrameBase({
        name = options.name,
        unit = options.unit,
        parent = options.parent,
        width = width,
        height = height,
        watch = options.watch,
    })

    self:RegisterFrame(frame, options.features)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", borderSize, -borderSize)
    content:SetPoint("BOTTOMRIGHT", -borderSize, borderSize)

    local health = self:CreateBar(content, contentWidth, healthHeight)
    health:SetPoint("TOPLEFT")

    local power = self:CreateBar(content, contentWidth, powerHeight)
    power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -separatorSize)

    local nameText = self:CreateText(
        health,
        healthHeight,
        "CENTER",
        options.nameFontOffset or -1
    )
    nameText:SetPoint("CENTER", health, "CENTER", 0, 0)
    nameText:SetWidth(contentWidth - 38)
    self:ConfigureNameText(nameText)

    local deficitText = self:CreateText(
        power,
        powerHeight,
        "CENTER",
        options.healthFontOffset or -1
    )
    deficitText:SetPoint("CENTER", power, "CENTER", 0, 0)
    deficitText:SetWidth(contentWidth - 4)

    frame.frameType = "raid"
    frame.nameMode = "first"
    frame.healthTextMode = "deficit"
    frame.content = content
    frame.health = health
    frame.power = power
    frame.nameText = nameText
    frame.healthText = deficitText
    frame.deficitText = deficitText

    return frame
end

function UF:UpdateHealth(frame)
    if not frame or not frame.health or not UnitExists(frame.unit) then
        return
    end

    local current = UnitHealth(frame.unit)
    local maximum = UnitHealthMax(frame.unit)

    frame.health:SetMinMaxValues(0, maximum)
    frame.health:SetValue(current)

    if frame.healthText then
        if frame.healthTextMode == "deficit" then
            local deficit = current - maximum

            if deficit < 0 then
                frame.healthText:SetText(tostring(deficit))
            else
                frame.healthText:SetText("")
            end
        else
            frame.healthText:SetFormattedText("%d/%d", current, maximum)
        end
    end

    local r, g, b = self:GetUnitColor(frame.unit)
    frame.health:SetStatusBarColor(r, g, b)
end

function UF:UpdatePower(frame)
    if not frame or not frame.power or not UnitExists(frame.unit) then
        return
    end

    local current = UnitPower(frame.unit)
    local maximum = UnitPowerMax(frame.unit)

    frame.power:SetMinMaxValues(0, maximum)
    frame.power:SetValue(current)

    if frame.powerText then
        frame.powerText:SetFormattedText("%d/%d", current, maximum)
    end

    local r, g, b = self:GetPowerColor(frame.unit)
    frame.power:SetStatusBarColor(r, g, b)
end

function UF:UpdateIdentity(frame)
    if not frame or not UnitExists(frame.unit) then
        return
    end

    if frame.nameText then
        if frame.nameMode == "first" then
            self:SetUnitFirstName(frame.nameText, frame.unit)
        else
            self:SetUnitDisplayName(frame.nameText, frame.unit)
        end
    end

    if frame.portrait then
        frame.portrait:SetUnit(frame.unit)
    end
end

function UF:GetCastInfo(unit)
    local name, _, _, fourth, fifth, sixth = UnitCastingInfo(unit)
    local startTime = fourth
    local endTime = fifth

    if name and (type(startTime) ~= "number" or type(endTime) ~= "number") then
        startTime = fifth
        endTime = sixth
    end

    if name then
        return name, startTime, endTime
    end

    name, _, _, fourth, fifth, sixth = UnitChannelInfo(unit)
    startTime = fourth
    endTime = fifth

    if name and (type(startTime) ~= "number" or type(endTime) ~= "number") then
        startTime = fifth
        endTime = sixth
    end

    return name, startTime, endTime
end

function UF:SetCastingLayout(frame, isCasting)
    if not frame or not frame.cast or not frame.castLayout then
        return
    end

    local layout = frame.castLayout
    local healthHeight = isCasting
        and layout.healthCastHeight
        or layout.healthHeight
    local powerHeight = isCasting
        and layout.powerCastHeight
        or layout.powerHeight

    frame.health:SetHeight(healthHeight)
    frame.power:SetHeight(powerHeight)

    frame.nameText:SetFont(
        layout.fontPath,
        self:GetBarFontSize(healthHeight),
        layout.fontFlags
    )
    frame.healthText:SetFont(
        layout.fontPath,
        self:GetBarFontSize(healthHeight),
        layout.fontFlags
    )
    frame.powerText:SetFont(
        layout.fontPath,
        self:GetBarFontSize(powerHeight),
        layout.fontFlags
    )

    frame.cast:SetShown(isCasting)
end

function UF:UpdateCast(frame)
    if not frame or not frame.cast then
        return
    end

    if not UnitExists(frame.unit) then
        frame.castStart = nil
        frame.castEnd = nil
        self:SetCastingLayout(frame, false)
        return
    end

    local spellName, startTime, endTime = self:GetCastInfo(frame.unit)

    if not spellName or not startTime or not endTime
        or not UI:CanAccessValue(spellName)
        or not UI:CanAccessValue(startTime)
        or not UI:CanAccessValue(endTime)
    then
        frame.castStart = nil
        frame.castEnd = nil
        self:SetCastingLayout(frame, false)
        return
    end

    frame.castStart = startTime / 1000
    frame.castEnd = endTime / 1000

    local duration = math.max(frame.castEnd - frame.castStart, 0.001)

    frame.cast:SetMinMaxValues(0, duration)
    frame.castNameText:SetText(spellName)
    self:SetCastingLayout(frame, true)
end

function UF:UpdateCastProgress(frame)
    if not frame or not frame.castStart or not frame.castEnd then
        return
    end

    local elapsed = math.max(GetTime() - frame.castStart, 0)
    local duration = math.max(frame.castEnd - frame.castStart, 0.001)

    if elapsed >= duration then
        self:UpdateCast(frame)
        return
    end

    frame.cast:SetValue(elapsed)
    frame.castProgressText:SetFormattedText("%.1fs", elapsed)
end

function UF:UpdateUnitFrame(frame)
    if not frame or not UnitExists(frame.unit) then
        return
    end

    self:UpdateIdentity(frame)
    self:UpdateHealth(frame)
    self:UpdatePower(frame)
    self:UpdateCast(frame)
end

function UF:UpdateAllFrames()
    self:ForEachFrame(function(frame)
        self:UpdateUnitFrame(frame)
    end)
end

local function DispatchUnitUpdate(unit, updater)
    if not unit then
        return
    end

    UF:ForEachUnitFrame(unit, function(frame)
        updater(UF, frame)
    end)
end

local function DispatchHealth(_, unit)
    DispatchUnitUpdate(unit, UF.UpdateHealth)
end

local function DispatchPower(_, unit)
    DispatchUnitUpdate(unit, UF.UpdatePower)
end

local function DispatchIdentity(_, unit)
    DispatchUnitUpdate(unit, UF.UpdateIdentity)
end

local function DispatchCast(_, unit)
    DispatchUnitUpdate(unit, UF.UpdateCast)
end

UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    UF:UpdateAllFrames()
end)

UI:RegisterEvent("UNIT_HEALTH", DispatchHealth)
UI:RegisterEvent("UNIT_MAXHEALTH", DispatchHealth)
UI:RegisterEvent("UNIT_FACTION", DispatchHealth)

UI:RegisterEvent("UNIT_POWER_UPDATE", DispatchPower)
UI:RegisterEvent("UNIT_POWER_FREQUENT", DispatchPower)
UI:RegisterEvent("UNIT_MAXPOWER", DispatchPower)
UI:RegisterEvent("UNIT_DISPLAYPOWER", DispatchPower)

UI:RegisterEvent("UNIT_NAME_UPDATE", DispatchIdentity)
UI:RegisterEvent("UNIT_PORTRAIT_UPDATE", DispatchIdentity)
UI:RegisterEvent("UNIT_MODEL_CHANGED", DispatchIdentity)
UI:RegisterEvent("UNIT_FLAGS", DispatchIdentity)
UI:RegisterEvent("UNIT_LEVEL", DispatchIdentity)

UI:RegisterEvent("UNIT_SPELLCAST_START", DispatchCast)
UI:RegisterEvent("UNIT_SPELLCAST_STOP", DispatchCast)
UI:RegisterEvent("UNIT_SPELLCAST_FAILED", DispatchCast)
UI:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", DispatchCast)
UI:RegisterEvent("UNIT_SPELLCAST_DELAYED", DispatchCast)
UI:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", DispatchCast)
UI:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", DispatchCast)
UI:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", DispatchCast)
