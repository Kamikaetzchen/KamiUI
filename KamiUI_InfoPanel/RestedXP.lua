local UI = KamiUI

-- Account-wide cache: the WoW API only exposes rested XP for the currently
-- logged-in character. Other characters are estimates based on their last
-- snapshot and whether they were in a resting area when they logged off.
local RestedXP = {}
UI.RestedXP = RestedXP

local MAX_PERCENT = 150
local RESTED_RATE_PERCENT = 5
local INN_RATE_SECONDS = 8 * 60 * 60
local WORLD_RATE_SECONDS = 32 * 60 * 60

local function GetDB()
    return UI:GetDatabase("restedXP", { characters = {} })
end

local function Now()
    return time and time() or 0
end

local function GetCurrentValues()
    if not UnitXPMax then
        return nil
    end

    local maxXP = UnitXPMax("player")
    if maxXP == nil or not UI:CanAccessValue(maxXP) then
        return nil
    end

    local atMaxLevel = IsPlayerAtMaxLevel
        and IsPlayerAtMaxLevel() == true

    if atMaxLevel or maxXP <= 0 then
        return nil, true, maxXP
    end

    local rested = GetXPExhaustion and GetXPExhaustion() or 0
    if not UI:CanAccessValue(rested) then
        return nil
    end

    return math.max(0, math.min(rested or 0, maxXP * 1.5))
        / maxXP * 100, false, maxXP, rested or 0
end

function RestedXP:GetCurrentPercent()
    local percent, atMaxLevel = GetCurrentValues()
    return percent, atMaxLevel
end

function RestedXP:CaptureCurrent()
    local percent, atMaxLevel, maxXP, restedXP = GetCurrentValues()
    if percent == nil and not atMaxLevel then
        return
    end

    local key = UI:GetCurrentCharacterKey()
    local snapshots = GetDB().characters
    local firstName, surname, name = UI:GetCurrentCharacterNames()
    local _, classFile = UnitClass("player")
    local snapshot = snapshots[key] or {}

    snapshot.name = name
    snapshot.firstName = firstName
    snapshot.surname = surname
    snapshot.realm = GetRealmName and GetRealmName() or ""
    snapshot.classFile = classFile
    snapshot.level = UnitLevel and UnitLevel("player") or snapshot.level
    snapshot.maxLevel = atMaxLevel == true
    snapshot.maxXP = maxXP or 0
    snapshot.restedXP = atMaxLevel and 0
        or math.max(0, math.min(restedXP, maxXP * 1.5))
    snapshot.resting = IsResting and IsResting() == true or false
    snapshot.updated = Now()

    snapshots[key] = snapshot
end

local function GetEstimatedPercent(snapshot, isCurrent)
    if snapshot.maxLevel then
        return nil, false, true
    end

    local maxXP = snapshot.maxXP
    local restedXP = snapshot.restedXP
    if type(maxXP) ~= "number" or maxXP <= 0
        or type(restedXP) ~= "number"
    then
        return nil, false, false
    end

    local percent = math.min(MAX_PERCENT,
        math.max(0, restedXP / maxXP * 100))

    if isCurrent then
        -- The displayed current-character value always comes from the API.
        return percent, false, false
    end

    local elapsed = math.max(0, Now() - (snapshot.updated or Now()))
    local rate = snapshot.resting and INN_RATE_SECONDS
        or WORLD_RATE_SECONDS
    percent = math.min(MAX_PERCENT,
        percent + (elapsed / rate) * RESTED_RATE_PERCENT)

    return percent, elapsed > 0, false
end

function RestedXP:GetCharacterEntries()
    self:CaptureCurrent()

    local snapshots = GetDB().characters
    local records = {}
    local keys = {}

    local characters = UI:GetCharactersModule()
    if characters and characters.GetSortedCharacters then
        for _, entry in ipairs(characters:GetSortedCharacters()) do
            if not keys[entry.key] then
                records[#records + 1] = {
                    key = entry.key,
                    character = entry.character,
                }
                keys[entry.key] = true
            end
        end
    end

    for key, snapshot in pairs(snapshots) do
        if not keys[key] then
            records[#records + 1] = {
                key = key,
                character = UI:GetCharacterProfile(key, snapshot),
            }
            keys[key] = true
        end
    end

    local currentKey = UI:GetCurrentCharacterKey()
    if not keys[currentKey] then
        records[#records + 1] = {
            key = currentKey,
            character = UI:GetCharacterProfile(currentKey),
        }
    end
    UI:SortCharacterEntries(records)

    for _, entry in ipairs(records) do
        local isCurrent = entry.key == currentKey
        local snapshot = snapshots[entry.key]
        entry.isCurrent = isCurrent

        if snapshot then
            entry.percent, entry.estimated, entry.maxLevel =
                GetEstimatedPercent(snapshot, isCurrent)
        end
    end

    return records
end
