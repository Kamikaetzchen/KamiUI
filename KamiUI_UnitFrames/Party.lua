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
        features = {
            indicators = true,
            healPrediction = true,
            range = true,
        },
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

local function UpdateGroup(index)
    local group = frames[index]

    if not group then
        return
    end

    UF:UpdateUnitFrame(group.main)
    UF:UpdateUnitFrame(group.pet)
    UF:UpdateUnitFrame(group.target)
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

UI:RegisterEvent("GROUP_ROSTER_UPDATE", UpdateAll)

UI:RegisterEvent("UNIT_TARGET", function(_, unit)
    if not unit then
        return
    end

    for _, group in ipairs(frames) do
        if unit == group.main.unit then
            UF:UpdateUnitFrame(group.target)
            return
        end
    end
end)

UI:RegisterEvent("UNIT_PET", function()
    UpdateAll()
end)

UF.partyFrames = frames
