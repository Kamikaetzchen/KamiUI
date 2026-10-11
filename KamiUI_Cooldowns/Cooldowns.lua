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

    UI:RegisterEvent("PLAYER_LEVEL_UP", function()
        -- Edit Mode can restore viewer parents during the level-up layout pass.
        C_Timer.After(0, function() Module:Apply() end)
        C_Timer.After(0.2, function() Module:Apply() end)
    end)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_CooldownViewer" then
            Module:Apply()
        end
    end)
end

Module:Initialize()
