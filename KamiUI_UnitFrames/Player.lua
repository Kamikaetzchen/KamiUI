local UI = KamiUI
local UF = UI:GetModule("UnitFrames")

local FRAME_WIDTH = 200
local FRAME_HEIGHT = 40
local BORDER_SIZE = 1
local CONTENT_WIDTH = FRAME_WIDTH - BORDER_SIZE * 2
local CONTENT_HEIGHT = FRAME_HEIGHT - BORDER_SIZE * 2
local PORTRAIT_SIZE = CONTENT_HEIGHT
local BAR_WIDTH = CONTENT_WIDTH - PORTRAIT_SIZE

local HEALTH_HEIGHT = 22
local POWER_HEIGHT = 15
local HEALTH_CAST_HEIGHT = 17
local POWER_CAST_HEIGHT = 11
local CAST_HEIGHT = 8
local SEPARATOR_SIZE = 1
local FRAME_Y = -250

local frame = CreateFrame(
    "Button",
    "KamiUIPlayerFrame",
    UIParent,
    "SecureUnitButtonTemplate"
)
frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
UF:ConfigureUnitButton(frame, "player")

local layoutPending = false

local function PositionFrame()
    if InCombatLockdown and InCombatLockdown() then
        layoutPending = true
        return
    end

    layoutPending = false
    frame:ClearAllPoints()
    frame:SetPoint(
        "RIGHT",
        UIParent,
        "CENTER",
        -1,
        FRAME_Y + UI:GetBottomInset()
    )
end

PositionFrame()

local background = frame:CreateTexture(nil, "BACKGROUND")
background:SetAllPoints()
background:SetColorTexture(0, 0, 0, 1)

local content = CreateFrame("Frame", nil, frame)
content:SetPoint("TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
content:SetPoint("BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)

local portrait = CreateFrame("PlayerModel", nil, content)
portrait:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
portrait:SetPoint("TOPLEFT")
portrait:EnableMouse(false)

if portrait.SetPortraitZoom then
    portrait:SetPortraitZoom(1)
end

if portrait.SetCamDistanceScale then
    portrait:SetCamDistanceScale(1)
end

local health = CreateFrame("StatusBar", nil, content)
health:SetSize(BAR_WIDTH, HEALTH_HEIGHT)
health:SetPoint("TOPLEFT", portrait, "TOPRIGHT")
health:SetStatusBarTexture(UF.flatTexture)

local healthBackground = health:CreateTexture(nil, "BACKGROUND")
healthBackground:SetAllPoints()
healthBackground:SetColorTexture(0.08, 0.08, 0.08, 1)

local power = CreateFrame("StatusBar", nil, content)
power:SetSize(BAR_WIDTH, POWER_HEIGHT)
power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -SEPARATOR_SIZE)
power:SetStatusBarTexture(UF.flatTexture)

local powerBackground = power:CreateTexture(nil, "BACKGROUND")
powerBackground:SetAllPoints()
powerBackground:SetColorTexture(0.08, 0.08, 0.08, 1)

local cast = CreateFrame("StatusBar", nil, content)
cast:SetSize(BAR_WIDTH, CAST_HEIGHT)
cast:SetPoint("TOPLEFT", power, "BOTTOMLEFT", 0, -SEPARATOR_SIZE)
cast:SetStatusBarTexture(UF.flatTexture)
cast:SetStatusBarColor(0.65, 0.45, 0.10)
cast:Hide()

local castBackground = cast:CreateTexture(nil, "BACKGROUND")
castBackground:SetAllPoints()
castBackground:SetColorTexture(0.08, 0.08, 0.08, 1)

local nameText = health:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nameText:SetPoint("LEFT", 3, 0)
nameText:SetJustifyH("LEFT")
nameText:SetTextColor(1, 1, 1)
nameText:SetShadowColor(0, 0, 0, 1)
nameText:SetShadowOffset(1, -1)
nameText:SetWidth(110)
UF:ConfigureNameText(nameText)

local healthText = health:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
healthText:SetPoint("RIGHT", -3, 0)
healthText:SetJustifyH("RIGHT")
healthText:SetTextColor(1, 1, 1)
healthText:SetShadowColor(0, 0, 0, 1)
healthText:SetShadowOffset(1, -1)

local powerText = power:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
powerText:SetPoint("RIGHT", -3, 0)
powerText:SetJustifyH("RIGHT")
powerText:SetTextColor(1, 1, 1)
powerText:SetShadowColor(0, 0, 0, 1)
powerText:SetShadowOffset(1, -1)

local fontPath, _, fontFlags = GameFontNormalSmall:GetFont()

nameText:SetFont(fontPath, UF:GetBarFontSize(HEALTH_HEIGHT), fontFlags)
healthText:SetFont(fontPath, UF:GetBarFontSize(HEALTH_HEIGHT), fontFlags)
powerText:SetFont(fontPath, UF:GetBarFontSize(POWER_HEIGHT), fontFlags)

local castNameText = cast:CreateFontString(nil, "OVERLAY")
castNameText:SetFont(fontPath, UF:GetBarFontSize(CAST_HEIGHT), "OUTLINE")
castNameText:SetPoint("LEFT", 2, 0)
castNameText:SetJustifyH("LEFT")
castNameText:SetTextColor(1, 1, 1)

local castProgressText = cast:CreateFontString(nil, "OVERLAY")
castProgressText:SetFont(fontPath, UF:GetBarFontSize(CAST_HEIGHT), "OUTLINE")
castProgressText:SetPoint("RIGHT", -2, 0)
castProgressText:SetJustifyH("RIGHT")
castProgressText:SetTextColor(1, 1, 1)

local castStart
local castEnd

local function GetCastInfo()
    local name, _, _, fourth, fifth, sixth = UnitCastingInfo("player")
    local startTime = fourth
    local endTime = fifth

    if name and (type(startTime) ~= "number" or type(endTime) ~= "number") then
        startTime = fifth
        endTime = sixth
    end

    if name then
        return name, startTime, endTime
    end

    name, _, _, fourth, fifth, sixth = UnitChannelInfo("player")
    startTime = fourth
    endTime = fifth

    if name and (type(startTime) ~= "number" or type(endTime) ~= "number") then
        startTime = fifth
        endTime = sixth
    end

    return name, startTime, endTime
end

local function SetCastingLayout(isCasting)
    if isCasting then
        health:SetHeight(HEALTH_CAST_HEIGHT)
        power:SetHeight(POWER_CAST_HEIGHT)
        nameText:SetFont(
            fontPath,
            UF:GetBarFontSize(HEALTH_CAST_HEIGHT),
            fontFlags
        )
        healthText:SetFont(
            fontPath,
            UF:GetBarFontSize(HEALTH_CAST_HEIGHT),
            fontFlags
        )
        powerText:SetFont(
            fontPath,
            UF:GetBarFontSize(POWER_CAST_HEIGHT),
            fontFlags
        )
        cast:Show()
    else
        health:SetHeight(HEALTH_HEIGHT)
        power:SetHeight(POWER_HEIGHT)
        nameText:SetFont(
            fontPath,
            UF:GetBarFontSize(HEALTH_HEIGHT),
            fontFlags
        )
        healthText:SetFont(
            fontPath,
            UF:GetBarFontSize(HEALTH_HEIGHT),
            fontFlags
        )
        powerText:SetFont(
            fontPath,
            UF:GetBarFontSize(POWER_HEIGHT),
            fontFlags
        )
        cast:Hide()
    end
end

local function UpdateCast()
    local spellName, startTime, endTime = GetCastInfo()

    if not spellName or not startTime or not endTime
        or not UF:CanAccessValue(spellName)
        or not UF:CanAccessValue(startTime)
        or not UF:CanAccessValue(endTime)
    then
        castStart = nil
        castEnd = nil
        SetCastingLayout(false)
        return
    end

    castStart = startTime / 1000
    castEnd = endTime / 1000

    local duration = math.max(castEnd - castStart, 0.001)
    cast:SetMinMaxValues(0, duration)
    castNameText:SetText(spellName)
    SetCastingLayout(true)
end

cast:SetScript("OnUpdate", function()
    if not castStart or not castEnd then
        return
    end

    local elapsed = math.max(GetTime() - castStart, 0)
    local duration = math.max(castEnd - castStart, 0.001)

    if elapsed >= duration then
        UpdateCast()
        return
    end

    cast:SetValue(elapsed)
    castProgressText:SetFormattedText("%.1fs", elapsed)
end)

local function UpdateHealth()
    local current = UnitHealth("player")
    local maximum = UnitHealthMax("player")

    health:SetMinMaxValues(0, maximum)
    health:SetValue(current)
    healthText:SetFormattedText("%d/%d", current, maximum)

    local r, g, b = UF:GetUnitColor("player")
    health:SetStatusBarColor(r, g, b)
end

local function UpdatePower()
    local current = UnitPower("player")
    local maximum = UnitPowerMax("player")

    power:SetMinMaxValues(0, maximum)
    power:SetValue(current)
    powerText:SetFormattedText("%d/%d", current, maximum)

    local r, g, b = UF:GetPowerColor("player")
    power:SetStatusBarColor(r, g, b)
end

local function UpdateIdentity()
    UF:SetUnitDisplayName(nameText, "player")
    portrait:SetUnit("player")
end

local function UpdateAll()
    UpdateIdentity()
    UpdateHealth()
    UpdatePower()
    UpdateCast()
end

local function OnPlayerEvent(event, unit)
    if event == "PLAYER_ENTERING_WORLD" or unit == "player" then
        UpdateAll()
    end
end

local function OnCastEvent(_, unit)
    if unit == "player" then
        UpdateCast()
    end
end

UI:RegisterBottomInsetCallback(PositionFrame)

UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if layoutPending then
        PositionFrame()
    end
end)

UI:RegisterEvent("PLAYER_ENTERING_WORLD", OnPlayerEvent)
UI:RegisterEvent("UNIT_HEALTH", OnPlayerEvent)
UI:RegisterEvent("UNIT_MAXHEALTH", OnPlayerEvent)
UI:RegisterEvent("UNIT_POWER_UPDATE", OnPlayerEvent)
UI:RegisterEvent("UNIT_POWER_FREQUENT", OnPlayerEvent)
UI:RegisterEvent("UNIT_MAXPOWER", OnPlayerEvent)
UI:RegisterEvent("UNIT_DISPLAYPOWER", OnPlayerEvent)
UI:RegisterEvent("UNIT_NAME_UPDATE", OnPlayerEvent)
UI:RegisterEvent("UNIT_PORTRAIT_UPDATE", OnPlayerEvent)
UI:RegisterEvent("UNIT_MODEL_CHANGED", OnPlayerEvent)

UI:RegisterEvent("UNIT_SPELLCAST_START", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_STOP", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_FAILED", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_DELAYED", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", OnCastEvent)

frame.health = health
frame.power = power
frame.portrait = portrait
frame.nameText = nameText
frame.healthText = healthText
frame.powerText = powerText

UF.playerFrame = frame
