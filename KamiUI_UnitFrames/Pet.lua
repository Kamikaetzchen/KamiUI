local UI = KamiUI
local UF = UI:GetModule("UnitFrames")
local Layout = UI.Layout.UnitFrames.Pet

local petFrame = UF:CreateCompactFrame({
    name = "KamiUIPetFrame",
    unit = "pet",
    width = Layout.WIDTH,
    height = Layout.HEIGHT,
    healthHeight = Layout.HEALTH_HEIGHT,
    powerHeight = Layout.POWER_HEIGHT,
    nameWidth = Layout.NAME_WIDTH,
    nameFontOffset = Layout.NAME_FONT_OFFSET,
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
    width = Layout.WIDTH,
    height = Layout.TARGET_HEIGHT,
    healthHeight = Layout.TARGET_HEALTH_HEIGHT,
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
