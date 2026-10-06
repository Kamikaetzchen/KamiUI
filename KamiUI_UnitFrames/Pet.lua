local UI = KamiUI
local UF = UI:GetModule("UnitFrames")

local petFrame = UF:CreateCompactFrame({
    name = "KamiUIPetFrame",
    unit = "pet",
    width = 100,
    height = 25,
    healthHeight = 13,
    powerHeight = 9,
    nameWidth = 64,
    nameFontOffset = -1,
})

petFrame:SetPoint("BOTTOMRIGHT", UF.playerFrame, "BOTTOMLEFT", -2, 0)

local petTargetFrame = UF:CreateHealthFrame({
    name = "KamiUIPetTargetFrame",
    unit = "pettarget",
    width = 100,
    height = 13,
    healthHeight = 11,
})

petTargetFrame:SetPoint("BOTTOMRIGHT", petFrame, "TOPRIGHT", 0, 2)

local function UpdatePet()
    UF:UpdateUnitFrame(petFrame)
end

local function UpdatePetTarget()
    UF:UpdateUnitFrame(petTargetFrame)
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
UI:RegisterEvent("UNIT_FACTION", OnUnitEvent)
UI:RegisterEvent("UNIT_POWER_UPDATE", OnUnitEvent)
UI:RegisterEvent("UNIT_POWER_FREQUENT", OnUnitEvent)
UI:RegisterEvent("UNIT_MAXPOWER", OnUnitEvent)
UI:RegisterEvent("UNIT_DISPLAYPOWER", OnUnitEvent)
UI:RegisterEvent("UNIT_NAME_UPDATE", OnUnitEvent)
UI:RegisterEvent("UNIT_HAPPINESS", UpdateAll)

UF.petFrame = petFrame
UF.petTargetFrame = petTargetFrame
