local UI = KamiUI

UI.Components = UI.Components or {}

local function NeutralizeTexture(texture)
    if not texture then
        return
    end

    if texture.SetColorTexture then
        pcall(
            texture.SetColorTexture,
            texture,
            0,
            0,
            0,
            0
        )
    end

    if texture.SetAlpha then
        texture:SetAlpha(0)
    end

    if texture.Hide then
        texture:Hide()
    end
end

function UI.Components:_NeutralizeTexture(texture)
    NeutralizeTexture(texture)
end
