local UI = KamiUI

local BLIZZARD_FRAMES = {
    "PlayerFrame",
    "TargetFrame",
    "TargetFrameToT",
    "FocusFrame",
    "FocusFrameToT",
}

local function DisableBlizzardFrame(frameName)
    local frame = _G[frameName]

    if not frame then
        return
    end

    frame:UnregisterAllEvents()
    frame:Hide()
end

local function DisableBlizzardUnitFrames()
    for _, frameName in ipairs(BLIZZARD_FRAMES) do
        DisableBlizzardFrame(frameName)
    end
end

UI:RegisterEvent("PLAYER_LOGIN", DisableBlizzardUnitFrames)
