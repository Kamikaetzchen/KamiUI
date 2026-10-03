local UI = KamiUI
local UF = UI:GetModule("UnitFrames")

local PARTY_WIDTH = 200
local PARTY_HEIGHT = 40
local PORTRAIT_SIZE = 38
local BORDER_SIZE = 1
local SEPARATOR_SIZE = 1

local HEALTH_HEIGHT = 22
local POWER_HEIGHT = 15

local PET_WIDTH = 100
local PET_HEIGHT = 25
local PET_HEALTH_HEIGHT = 13
local PET_POWER_HEIGHT = 9

local TARGET_WIDTH = 100
local TARGET_HEIGHT = 13
local TARGET_HEALTH_HEIGHT = 11

local PARTY_SPACING = 31
local PARTY_TOP_OFFSET = 145

local fontPath, _, fontFlags = GameFontNormalSmall:GetFont()
local frames = {}

local function CreateBackground(parent)
    local background = parent:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 1)

    return background
end

local function CreateBar(parent, width, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(width, height)
    bar:SetStatusBarTexture(UF.flatTexture)

    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.08, 0.08, 0.08, 1)

    return bar
end

local function CreateText(parent, size, justify)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(fontPath, UF:GetBarFontSize(size), fontFlags)
    text:SetJustifyH(justify or "LEFT")
    text:SetTextColor(1, 1, 1)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)

    return text
end

local function CreatePartyMember(index)
    local unit = "party" .. index

    local frame = CreateFrame(
        "Button",
        "KamiUIParty" .. index .. "Frame",
        UIParent,
        "SecureUnitButtonTemplate"
    )
    frame:SetSize(PARTY_WIDTH, PARTY_HEIGHT)
    frame:SetPoint(
        "TOPLEFT",
        UIParent,
        "LEFT",
        0,
        PARTY_TOP_OFFSET - (index - 1) * (PARTY_HEIGHT + PARTY_SPACING)
    )
    UF:ConfigureUnitButton(frame, unit)
    RegisterUnitWatch(frame)
    CreateBackground(frame)

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

    local barWidth = PARTY_WIDTH - BORDER_SIZE * 2 - PORTRAIT_SIZE

    local health = CreateBar(content, barWidth, HEALTH_HEIGHT)
    health:SetPoint("TOPLEFT", portrait, "TOPRIGHT")

    local power = CreateBar(content, barWidth, POWER_HEIGHT)
    power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -SEPARATOR_SIZE)

    local nameText = CreateText(health, HEALTH_HEIGHT, "LEFT")
    nameText:SetPoint("LEFT", 3, 0)
    nameText:SetWidth(92)

    local healthText = CreateText(health, HEALTH_HEIGHT, "RIGHT")
    healthText:SetPoint("RIGHT", -3, 0)

    local powerText = CreateText(power, POWER_HEIGHT, "RIGHT")
    powerText:SetPoint("RIGHT", -3, 0)

    frame.health = health
    frame.power = power
    frame.portrait = portrait
    frame.nameText = nameText
    frame.healthText = healthText
    frame.powerText = powerText

    return frame
end

local function CreatePartyPet(index, ownerFrame)
    local unit = "partypet" .. index

    local frame = CreateFrame(
        "Button",
        "KamiUIParty" .. index .. "PetFrame",
        UIParent,
        "SecureUnitButtonTemplate"
    )
    frame:SetSize(PET_WIDTH, PET_HEIGHT)
    frame:SetPoint("BOTTOMLEFT", ownerFrame, "BOTTOMRIGHT", 2, 0)
    UF:ConfigureUnitButton(frame, unit)
    RegisterUnitWatch(frame)
    CreateBackground(frame)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
    content:SetPoint("BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)

    local health = CreateBar(
        content,
        PET_WIDTH - BORDER_SIZE * 2,
        PET_HEALTH_HEIGHT
    )
    health:SetPoint("TOPLEFT")

    local power = CreateBar(
        content,
        PET_WIDTH - BORDER_SIZE * 2,
        PET_POWER_HEIGHT
    )
    power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -SEPARATOR_SIZE)

    local nameText = CreateText(health, PET_HEALTH_HEIGHT, "LEFT")
    nameText:SetPoint("LEFT", 2, 0)
    nameText:SetWidth(54)

    local healthText = CreateText(health, PET_HEALTH_HEIGHT, "RIGHT")
    healthText:SetPoint("RIGHT", -2, 0)

    local powerText = CreateText(power, PET_POWER_HEIGHT, "RIGHT")
    powerText:SetPoint("RIGHT", -2, 0)

    frame.health = health
    frame.power = power
    frame.nameText = nameText
    frame.healthText = healthText
    frame.powerText = powerText

    return frame
end

local function CreatePartyTarget(index, petFrame, ownerFrame)
    local unit = "party" .. index .. "target"

    local frame = CreateFrame(
        "Button",
        "KamiUIParty" .. index .. "TargetFrame",
        UIParent,
        "SecureUnitButtonTemplate"
    )
    frame:SetSize(TARGET_WIDTH, TARGET_HEIGHT)
    frame:SetPoint("BOTTOMLEFT", petFrame, "TOPLEFT", 0, 2)
    UF:ConfigureUnitButton(frame, unit)
    RegisterUnitWatch(frame)
    CreateBackground(frame)

    local health = CreateBar(
        frame,
        TARGET_WIDTH - BORDER_SIZE * 2,
        TARGET_HEALTH_HEIGHT
    )
    health:SetPoint("TOPLEFT", BORDER_SIZE, -BORDER_SIZE)

    local nameText = CreateText(health, TARGET_HEALTH_HEIGHT, "LEFT")
    nameText:SetPoint("LEFT", 2, 0)
    nameText:SetPoint("RIGHT", -2, 0)

    frame.health = health
    frame.nameText = nameText
    frame.ownerFrame = ownerFrame

    return frame
end

local function UpdateMain(frame)
    local unit = frame.unit

    if not UnitExists(unit) then
        return
    end

    local current = UnitHealth(unit)
    local maximum = UnitHealthMax(unit)

    frame.health:SetMinMaxValues(0, maximum)
    frame.health:SetValue(current)
    frame.healthText:SetFormattedText("%d/%d", current, maximum)

    local r, g, b = UF:GetUnitColor(unit)
    frame.health:SetStatusBarColor(r, g, b)

    current = UnitPower(unit)
    maximum = UnitPowerMax(unit)

    frame.power:SetMinMaxValues(0, maximum)
    frame.power:SetValue(current)
    frame.powerText:SetFormattedText("%d/%d", current, maximum)

    r, g, b = UF:GetPowerColor(unit)
    frame.power:SetStatusBarColor(r, g, b)

    frame.nameText:SetText(UF:GetUnitDisplayName(unit))
    frame.portrait:SetUnit(unit)
end

local function UpdatePet(frame)
    local unit = frame.unit

    if not UnitExists(unit) then
        return
    end

    local current = UnitHealth(unit)
    local maximum = UnitHealthMax(unit)

    frame.health:SetMinMaxValues(0, maximum)
    frame.health:SetValue(current)
    frame.healthText:SetFormattedText("%d/%d", current, maximum)

    local r, g, b = UF:GetUnitColor(unit)
    frame.health:SetStatusBarColor(r, g, b)

    current = UnitPower(unit)
    maximum = UnitPowerMax(unit)

    frame.power:SetMinMaxValues(0, maximum)
    frame.power:SetValue(current)
    frame.powerText:SetFormattedText("%d/%d", current, maximum)

    r, g, b = UF:GetPowerColor(unit)
    frame.power:SetStatusBarColor(r, g, b)

    frame.nameText:SetText(UF:GetUnitDisplayName(unit))
end

local function UpdateTarget(frame)
    local unit = frame.unit

    if not UnitExists(unit) then
        return
    end

    local current = UnitHealth(unit)
    local maximum = UnitHealthMax(unit)

    frame.health:SetMinMaxValues(0, maximum)
    frame.health:SetValue(current)

    local r, g, b = UF:GetUnitColor(unit)
    frame.health:SetStatusBarColor(r, g, b)
    frame.nameText:SetText(UF:GetUnitDisplayName(unit))
end

local function UpdateGroup(index)
    local group = frames[index]

    if not group then
        return
    end

    UpdateMain(group.main)
    UpdatePet(group.pet)
    UpdateTarget(group.target)
end

local function UpdateAll()
    for index = 1, 4 do
        UpdateGroup(index)
    end
end

for index = 1, 4 do
    local main = CreatePartyMember(index)
    local pet = CreatePartyPet(index, main)
    local target = CreatePartyTarget(index, pet, main)

    frames[index] = {
        main = main,
        pet = pet,
        target = target,
    }
end

local function OnUnitEvent(_, unit)
    if not unit then
        UpdateAll()
        return
    end

    for index, group in ipairs(frames) do
        if unit == group.main.unit then
            UpdateMain(group.main)
            UpdateTarget(group.target)
            return
        elseif unit == group.pet.unit then
            UpdatePet(group.pet)
            return
        elseif unit == group.target.unit then
            UpdateTarget(group.target)
            return
        end
    end
end

local function OnTargetEvent(_, unit)
    if not unit then
        return
    end

    for _, group in ipairs(frames) do
        if unit == group.main.unit then
            UpdateTarget(group.target)
            return
        end
    end
end

UI:RegisterEvent("PLAYER_ENTERING_WORLD", UpdateAll)
UI:RegisterEvent("GROUP_ROSTER_UPDATE", UpdateAll)
UI:RegisterEvent("UNIT_HEALTH", OnUnitEvent)
UI:RegisterEvent("UNIT_MAXHEALTH", OnUnitEvent)
UI:RegisterEvent("UNIT_POWER_UPDATE", OnUnitEvent)
UI:RegisterEvent("UNIT_MAXPOWER", OnUnitEvent)
UI:RegisterEvent("UNIT_DISPLAYPOWER", OnUnitEvent)
UI:RegisterEvent("UNIT_NAME_UPDATE", OnUnitEvent)
UI:RegisterEvent("UNIT_PORTRAIT_UPDATE", OnUnitEvent)
UI:RegisterEvent("UNIT_MODEL_CHANGED", OnUnitEvent)
UI:RegisterEvent("UNIT_TARGET", OnTargetEvent)
UI:RegisterEvent("UNIT_PET", function()
    UpdateAll()
end)

UF.partyFrames = frames
