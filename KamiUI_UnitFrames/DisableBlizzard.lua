local UI = KamiUI

local BLIZZARD_FRAMES = {
    "PlayerFrame",
    "PetFrame",
    "TargetFrame",
    "TargetFrameToT",
    "FocusFrame",
    "FocusFrameToT",
    "CastingBarFrame",
    "PlayerCastingBarFrame",
    "TargetFrameSpellBar",
    "PartyFrame",
    "CompactPartyFrame",
}

local function DisableBlizzardFrame(frameName)
    local frame = _G[frameName]

    if not frame then
        return
    end

    if UnregisterUnitWatch then
        pcall(UnregisterUnitWatch, frame)
    end

    frame:UnregisterAllEvents()

    if frame.EnableMouse then
        frame:EnableMouse(false)
    end

    frame:Hide()
end

local function DisableBlizzardUnitFrames()
    for _, frameName in ipairs(BLIZZARD_FRAMES) do
        DisableBlizzardFrame(frameName)
    end
end

UI:RegisterEvent("PLAYER_LOGIN", DisableBlizzardUnitFrames)

UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(0, DisableBlizzardUnitFrames)
end)
