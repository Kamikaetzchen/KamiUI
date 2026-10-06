local UI = KamiUI
local UF = UI:GetModule("UnitFrames")

local PARTY_WIDTH = 200
local PARTY_HEIGHT = 40
local PARTY_SPACING = 41
local PARTY_TOP_OFFSET = 145

local frames = {}

local function CreatePartyMember(index)
    local unit = "party" .. index

    local frame = UF:CreatePrimaryFrame({
        name = "KamiUIParty" .. index .. "Frame",
        unit = unit,
        width = PARTY_WIDTH,
        height = PARTY_HEIGHT,
        portraitSide = "LEFT",
        nameWidth = 112,
    })

    frame:SetPoint(
        "TOPLEFT",
        UIParent,
        "LEFT",
        0,
        PARTY_TOP_OFFSET - (index - 1) * (PARTY_HEIGHT + PARTY_SPACING)
    )

    return frame
end

local function CreatePartyPet(index, ownerFrame)
    local frame = UF:CreateCompactFrame({
        name = "KamiUIParty" .. index .. "PetFrame",
        unit = "partypet" .. index,
        width = 100,
        height = 25,
        healthHeight = 13,
        powerHeight = 9,
        nameWidth = 64,
    })

    frame:SetPoint("BOTTOMLEFT", ownerFrame, "BOTTOMRIGHT", 2, 0)

    return frame
end

local function CreatePartyTarget(index, petFrame, ownerFrame)
    local frame = UF:CreateHealthFrame({
        name = "KamiUIParty" .. index .. "TargetFrame",
        unit = "party" .. index .. "target",
        width = 100,
        height = 13,
        healthHeight = 11,
    })

    frame:SetPoint("BOTTOMLEFT", petFrame, "TOPLEFT", 0, 2)
    frame.ownerFrame = ownerFrame

    return frame
end

local function UpdateMain(frame)
    UF:UpdateUnitFrame(frame)
end

local function UpdatePet(frame)
    UF:UpdateUnitFrame(frame)
end

local function UpdateTarget(frame)
    UF:UpdateUnitFrame(frame)
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

    for _, group in ipairs(frames) do
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

local function OnCastEvent(_, unit)
    if not unit then
        return
    end

    for _, group in ipairs(frames) do
        if unit == group.main.unit then
            UF:UpdateCast(group.main)
            return
        end
    end
end

UI:RegisterEvent("PLAYER_ENTERING_WORLD", UpdateAll)
UI:RegisterEvent("GROUP_ROSTER_UPDATE", UpdateAll)
UI:RegisterEvent("UNIT_HEALTH", OnUnitEvent)
UI:RegisterEvent("UNIT_MAXHEALTH", OnUnitEvent)
UI:RegisterEvent("UNIT_FACTION", OnUnitEvent)
UI:RegisterEvent("UNIT_POWER_UPDATE", OnUnitEvent)
UI:RegisterEvent("UNIT_POWER_FREQUENT", OnUnitEvent)
UI:RegisterEvent("UNIT_MAXPOWER", OnUnitEvent)
UI:RegisterEvent("UNIT_DISPLAYPOWER", OnUnitEvent)
UI:RegisterEvent("UNIT_NAME_UPDATE", OnUnitEvent)
UI:RegisterEvent("UNIT_PORTRAIT_UPDATE", OnUnitEvent)
UI:RegisterEvent("UNIT_MODEL_CHANGED", OnUnitEvent)
UI:RegisterEvent("UNIT_TARGET", OnTargetEvent)
UI:RegisterEvent("UNIT_PET", function()
    UpdateAll()
end)

UI:RegisterEvent("UNIT_SPELLCAST_START", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_STOP", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_FAILED", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_DELAYED", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", OnCastEvent)

UF.partyFrames = frames
