local UI = KamiUI
local Module = UI:NewModule("ItemRating", "KamiUI_ItemRating")

Module.profiles = {}

function Module:RegisterProfile(classFile, spec, profile)
    if not classFile or not spec or type(profile) ~= "table" then
        return
    end

    self.profiles[classFile] = self.profiles[classFile] or {}
    self.profiles[classFile][spec] = profile
end

function Module:GetActiveProfile()
    local _, classFile = UnitClass("player")

    if not UI:CanAccessValue(classFile) or classFile ~= "DRUID" then
        return nil
    end

    -- V1 intentionally always rates Cat DPS, regardless of current form.
    -- Other classes/specs and talent-specific weighting come later.
    return self.profiles.DRUID and self.profiles.DRUID.cat
end
