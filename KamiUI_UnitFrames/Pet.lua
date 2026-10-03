local UI = KamiUI
local UF = UI:GetModule("UnitFrames")

local PET_WIDTH = 100
local PET_HEIGHT = 25
local PET_TARGET_WIDTH = 100
local PET_TARGET_HEIGHT = 13

local BORDER_SIZE = 1
local SEPARATOR_SIZE = 1

local PET_HEALTH_HEIGHT = 13
local PET_POWER_HEIGHT = 9
local PET_TARGET_HEALTH_HEIGHT = 11

local fontPath, _, fontFlags = GameFontNormalSmall:GetFont()

local function CreatePetFrame()
    local frame = CreateFrame(
        "Button",
        "KamiUIPetFrame",
        UIParent,
        "SecureUnitButtonTemplate"
    )
    frame:SetSize(PET_WIDTH, PET_HEIGHT)
    frame:SetPoint("BOTTOMRIGHT", UF.playerFrame, "BOTTOMLEFT", -2, 0)
    UF:ConfigureUnitButton(frame, "pet")
    RegisterUnitWatch(frame)

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 1)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
    content:SetPoint("BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)

    local health = CreateFrame("StatusBar", nil, content)
    health:SetSize(PET_WIDTH - BORDER_SIZE * 2, PET_HEALTH_HEIGHT)
    health:SetPoint("TOPLEFT")
    health:SetStatusBarTexture(UF.flatTexture)

    local healthBackground = health:CreateTexture(nil, "BACKGROUND")
    healthBackground:SetAllPoints()
    healthBackground:SetColorTexture(0.08, 0.08, 0.08, 1)

    local power = CreateFrame("StatusBar", nil, content)
    power:SetSize(PET_WIDTH - BORDER_SIZE * 2, PET_POWER_HEIGHT)
    power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -SEPARATOR_SIZE)
    power:SetStatusBarTexture(UF.flatTexture)

    local powerBackground = power:CreateTexture(nil, "BACKGROUND")
    powerBackground:SetAllPoints()
    powerBackground:SetColorTexture(0.08, 0.08, 0.08, 1)

    local nameText = health:CreateFontString(nil, "OVERLAY")
    nameText:SetFont(
        fontPath,
        UF:GetBarFontSize(PET_HEALTH_HEIGHT),
        fontFlags
    )
    nameText:SetPoint("LEFT", 2, 0)
    nameText:SetWidth(54)
    nameText:SetJustifyH("LEFT")
    UF:ConfigureNameText(nameText)
    nameText:SetTextColor(1, 1, 1)
    nameText:SetShadowColor(0, 0, 0, 1)
    nameText:SetShadowOffset(1, -1)

    local healthText = health:CreateFontString(nil, "OVERLAY")
    healthText:SetFont(
        fontPath,
        UF:GetBarFontSize(PET_HEALTH_HEIGHT),
        fontFlags
    )
    healthText:SetPoint("RIGHT", -2, 0)
    healthText:SetJustifyH("RIGHT")
    healthText:SetTextColor(1, 1, 1)
    healthText:SetShadowColor(0, 0, 0, 1)
    healthText:SetShadowOffset(1, -1)

    local powerText = power:CreateFontString(nil, "OVERLAY")
    powerText:SetFont(
        fontPath,
        UF:GetBarFontSize(PET_POWER_HEIGHT),
        fontFlags
    )
    powerText:SetPoint("RIGHT", -2, 0)
    powerText:SetJustifyH("RIGHT")
    powerText:SetTextColor(1, 1, 1)
    powerText:SetShadowColor(0, 0, 0, 1)
    powerText:SetShadowOffset(1, -1)

    frame.health = health
    frame.power = power
    frame.nameText = nameText
    frame.healthText = healthText
    frame.powerText = powerText

    return frame
end

local function CreatePetTargetFrame(petFrame)
    local frame = CreateFrame(
        "Button",
        "KamiUIPetTargetFrame",
        UIParent,
        "SecureUnitButtonTemplate"
    )
    frame:SetSize(PET_TARGET_WIDTH, PET_TARGET_HEIGHT)
    frame:SetPoint("BOTTOMRIGHT", petFrame, "TOPRIGHT", 0, 2)
    UF:ConfigureUnitButton(frame, "pettarget")
    RegisterUnitWatch(frame)

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 1)

    local health = CreateFrame("StatusBar", nil, frame)
    health:SetSize(
        PET_TARGET_WIDTH - BORDER_SIZE * 2,
        PET_TARGET_HEALTH_HEIGHT
    )
    health:SetPoint("TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
    health:SetStatusBarTexture(UF.flatTexture)

    local healthBackground = health:CreateTexture(nil, "BACKGROUND")
    healthBackground:SetAllPoints()
    healthBackground:SetColorTexture(0.08, 0.08, 0.08, 1)

    local nameText = health:CreateFontString(nil, "OVERLAY")
    nameText:SetFont(
        fontPath,
        UF:GetBarFontSize(PET_TARGET_HEALTH_HEIGHT),
        fontFlags
    )
    nameText:SetPoint("LEFT", 2, 0)
    nameText:SetPoint("RIGHT", -2, 0)
    nameText:SetJustifyH("LEFT")
    UF:ConfigureNameText(nameText)
    nameText:SetTextColor(1, 1, 1)
    nameText:SetShadowColor(0, 0, 0, 1)
    nameText:SetShadowOffset(1, -1)

    frame.health = health
    frame.nameText = nameText

    return frame
end

local petFrame = CreatePetFrame()
local petTargetFrame = CreatePetTargetFrame(petFrame)

local function UpdatePet()
    if not UnitExists("pet") then
        return
    end

    local healthCurrent = UnitHealth("pet")
    local healthMaximum = UnitHealthMax("pet")
    petFrame.health:SetMinMaxValues(0, healthMaximum)
    petFrame.health:SetValue(healthCurrent)
    petFrame.healthText:SetFormattedText(
        "%d/%d",
        healthCurrent,
        healthMaximum
    )

    local r, g, b = UF:GetUnitColor("pet")
    petFrame.health:SetStatusBarColor(r, g, b)

    local powerCurrent = UnitPower("pet")
    local powerMaximum = UnitPowerMax("pet")
    petFrame.power:SetMinMaxValues(0, powerMaximum)
    petFrame.power:SetValue(powerCurrent)
    petFrame.powerText:SetFormattedText(
        "%d/%d",
        powerCurrent,
        powerMaximum
    )

    r, g, b = UF:GetPowerColor("pet")
    petFrame.power:SetStatusBarColor(r, g, b)

    UF:SetUnitDisplayName(petFrame.nameText, "pet")
end

local function UpdatePetTarget()
    if not UnitExists("pettarget") then
        return
    end

    local healthCurrent = UnitHealth("pettarget")
    local healthMaximum = UnitHealthMax("pettarget")
    petTargetFrame.health:SetMinMaxValues(0, healthMaximum)
    petTargetFrame.health:SetValue(healthCurrent)

    local r, g, b = UF:GetUnitColor("pettarget")
    petTargetFrame.health:SetStatusBarColor(r, g, b)
    UF:SetUnitDisplayName(petTargetFrame.nameText, "pettarget")
end

local function UpdateAll()
    UpdatePet()
    UpdatePetTarget()
end

local function OnUnitEvent(_, unit)
    if not unit then
        UpdateAll()
        return
    end

    if unit == "pet" then
        UpdatePet()
        UpdatePetTarget()
    elseif unit == "pettarget" then
        UpdatePetTarget()
    end
end

UI:RegisterEvent("PLAYER_ENTERING_WORLD", UpdateAll)
UI:RegisterEvent("UNIT_PET", UpdateAll)
UI:RegisterEvent("UNIT_TARGET", OnUnitEvent)
UI:RegisterEvent("UNIT_HEALTH", OnUnitEvent)
UI:RegisterEvent("UNIT_MAXHEALTH", OnUnitEvent)
UI:RegisterEvent("UNIT_POWER_UPDATE", OnUnitEvent)
UI:RegisterEvent("UNIT_MAXPOWER", OnUnitEvent)
UI:RegisterEvent("UNIT_DISPLAYPOWER", OnUnitEvent)
UI:RegisterEvent("UNIT_NAME_UPDATE", OnUnitEvent)
UI:RegisterEvent("UNIT_HAPPINESS", UpdateAll)

UF.petFrame = petFrame
UF.petTargetFrame = petTargetFrame
