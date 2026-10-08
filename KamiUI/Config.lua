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

-- Shared with XPBar and the layout offsets. Keep the same watched-faction
-- detection everywhere so the bar and its reserved space cannot diverge.
function UI:GetWatchedReputationData()
    if C_Reputation and C_Reputation.GetWatchedFactionData then
        local data = self:SafeCall(C_Reputation.GetWatchedFactionData)

        if type(data) == "table" and data.name then
            return data
        end
    end

    if GetWatchedFactionInfo then
        local name,
            reaction,
            lower,
            upper,
            standing,
            factionID = self:SafeCall(GetWatchedFactionInfo)

        if name then
            return {
                name = name,
                reaction = reaction,
                currentReactionThreshold = lower,
                nextReactionThreshold = upper,
                currentStanding = standing,
                factionID = factionID,
            }
        end
    end

    return nil
end

function UI:GetBottomInset()
    if not self:IsPlayerAtMaxLevel()
        or self:GetWatchedReputationData()
    then
        return self.defaults.layout.xpBarHeight
    end

    return 0
end
