local UI = KamiUI

local Module = UI:NewModule("Cooldowns", "KamiUI_Cooldowns")


local viewerNames = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
    "BuffBarCooldownViewer",
}

function Module:Apply()
    for _, name in ipairs(viewerNames) do
        UI:KeepFrameHidden(_G[name])
    end
end

function Module:Initialize()
    self:Apply()

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        Module:Apply()
    end)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_CooldownViewer" then
            Module:Apply()
        end
    end)
end

Module:Initialize()
