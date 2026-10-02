local UI = KamiUI

UI.defaults = {
    general = {
        scale = 1.0,
    },

    layout = {
        xpBarHeight = 10,
    },

    media = {
        fontSize = 12,
    },
}

function UI:GetEffectiveMaxLevel()
    if GameRulesUtil and GameRulesUtil.GetEffectiveMaxLevelForPlayer then
        return GameRulesUtil.GetEffectiveMaxLevelForPlayer()
    end

    if GetMaxPlayerLevel then
        return GetMaxPlayerLevel()
    end
end

function UI:IsPlayerAtMaxLevel()
    local level = UnitLevel("player")
    local maxLevel = self:GetEffectiveMaxLevel()

    return level and level > 0 and maxLevel and level >= maxLevel
end

function UI:GetBottomInset()
    if self:IsPlayerAtMaxLevel() then
        return 0
    end

    return self.defaults.layout.xpBarHeight
end
