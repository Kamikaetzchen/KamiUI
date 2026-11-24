local UI = KamiUI

-- Keep the last readable player GUID across temporary API restrictions.
local cachedGUID

function UI:GetCharacterGUIDKey()
    local guid = UnitGUID and self:SafeCall(UnitGUID, "player")
    if self:CanAccessValue(guid)
        and type(guid) == "string"
        and guid:match("^Player%-%d+%-%x+$") then
        cachedGUID = guid
    end
    -- Never fall back to an empty-realm key if the GUID becomes
    -- temporarily inaccessible during combat or a zone transition.
    return cachedGUID
end
