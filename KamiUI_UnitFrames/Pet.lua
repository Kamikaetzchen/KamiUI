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
    features = {
        indicators = true,
        healPrediction = true,
        range = true,
    },
})

petFrame:SetPoint("BOTTOMRIGHT", UF.playerFrame, "BOTTOMLEFT", -2, 0)

local petTargetFrame = UF:CreateHealthFrame({
    name = "KamiUIPetTargetFrame",
    unit = "pettarget",
    width = 100,
    height = 13,
    healthHeight = 11,
    features = {
        indicators = true,
        range = true,
    },
})

petTargetFrame:SetPoint("BOTTOMRIGHT", petFrame, "TOPRIGHT", 0, 2)

local function UpdatePet()
    UF:UpdateUnitFrame(petFrame)
    UF:UpdateUnitFrame(petTargetFrame)
end

UI:RegisterEvent("UNIT_PET", function(_, unit)
    if not unit or unit == "player" then
        UpdatePet()
    end
end)

UI:RegisterEvent("UNIT_TARGET", function(_, unit)
    if unit == "pet" then
        UF:UpdateUnitFrame(petTargetFrame)
    end
end)

UI:RegisterEvent("UNIT_HAPPINESS", function()
    UF:UpdateHealth(petFrame)
end)

UF.petFrame = petFrame
UF.petTargetFrame = petTargetFrame
