local UI = KamiUI

-- Shared artwork paths for all KamiUI modules.
UI.Media = UI.Media or {}
UI.Media.KamiFacet = "Interface\\AddOns\\KamiUI\\Media\\KamiFacet"
UI.Media.HealthFade = "Interface\\AddOns\\KamiUI\\Media\\HealthFade"

-- Native StatusBars use a flat translucent fill over this cropped material.
-- A constant source-pixel/UI-pixel ratio keeps pebble size consistent.
UI.Media.KamiPebble = "Interface\\AddOns\\KamiUI\\Media\\KamiPebbleAlpha_512x64_morealpha.tga"
UI.Media.FlatBar = "Interface\\Buttons\\WHITE8X8"

-- Separately scalable, non-glowing combat HUD parts.
UI.Media.CombatPortraitMask = "Interface\\AddOns\\KamiUI\\Media\\CombatPortraitMask.tga"
UI.Media.CombatPortraitFrame = "Interface\\AddOns\\KamiUI\\Media\\CombatPortraitFrame.tga"
UI.Media.CombatPowerTriangle = "Interface\\AddOns\\KamiUI\\Media\\CombatPowerTriangle.tga"
UI.Media.CombatButtonFrames = "Interface\\AddOns\\KamiUI\\Media\\CombatButtonFrames.tga"

local PEBBLE_WIDTH = 512
local PEBBLE_HEIGHT = 64
local SOURCE_PIXELS_PER_UI_PIXEL = 2
local PEBBLE_BRIGHTNESS = 0.90

function UI.Media:SetPebbleCrop(texture, width, height)
    texture:SetTexCoord(
        0, math.min(1, width * SOURCE_PIXELS_PER_UI_PIXEL / PEBBLE_WIDTH),
        0, math.min(1, height * SOURCE_PIXELS_PER_UI_PIXEL / PEBBLE_HEIGHT)
    )
end

function UI.Media:ApplyPebble(texture, width, height, opacity)
    texture:SetTexture(self.KamiPebble)
    self:SetPebbleCrop(texture, width, height)
    texture:SetVertexColor(
        PEBBLE_BRIGHTNESS, PEBBLE_BRIGHTNESS, PEBBLE_BRIGHTNESS,
        opacity or 1
    )
end
