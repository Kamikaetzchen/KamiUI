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
    "CompactRaidFrameManager",
    "CompactRaidFrameContainer",
}

local function DisableBlizzardFrame(frameName)
    UI:DisableFrame(_G[frameName], {
        unregisterUnitWatch = true,
    })
end

local function DisableBlizzardUnitFrames()
    for _, frameName in ipairs(BLIZZARD_FRAMES) do
        DisableBlizzardFrame(frameName)
    end
end

UI:RegisterEvent("PLAYER_LOGIN", DisableBlizzardUnitFrames)

UI:RegisterEvent("PLAYER_ENTERING_WORLD", DisableBlizzardUnitFrames)
