local UI = KamiUI

local Module = UI:NewModule("Cooldowns")

Module.name = "KamiUI_Cooldowns"
Module.version = "0.1.0"

local viewerNames = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
    "BuffBarCooldownViewer",
}

local hiddenViewers = setmetatable({}, { __mode = "k" })

local function HideViewer(viewer)
    if not viewer then
        return
    end

    viewer:Hide()

    if viewer.EnableMouse then
        viewer:EnableMouse(false)
    end

    if not hiddenViewers[viewer] and viewer.HookScript then
        hiddenViewers[viewer] = true

        viewer:HookScript("OnShow", function(self)
            self:Hide()
        end)
    end
end

function Module:Apply()
    for _, name in ipairs(viewerNames) do
        HideViewer(_G[name])
    end
end

function Module:Initialize()
    self:Apply()

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0, function()
            Module:Apply()
        end)
    end)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_CooldownViewer" then
            C_Timer.After(0, function()
                Module:Apply()
            end)
        end
    end)
end

Module:Initialize()
