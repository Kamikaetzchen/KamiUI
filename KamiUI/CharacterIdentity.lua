local UI = KamiUI

-- Character GUIDs survive realm-name API restrictions and relogs.
-- Migrate the logged-in character only: offline characters do not have
-- a readable GUID until they are logged in themselves.
local checkedIdentity
local cachedGUID

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do
        result[key] = Copy(item)
    end
    return result
end

local function AddMap(maps, id, value)
    if type(value) == "table" then
        maps[#maps + 1] = { id = id, data = value }
    end
end

local function CharacterMaps(db)
    local maps = {}
    local characters = db.characters
    local bags = db.bags
    local rested = db.restedXP
    local quests = db.quests
    local radial = db.radialMenu

    AddMap(maps, "characters", characters and characters.data)
    AddMap(maps, "bags", bags and bags.characters)
    AddMap(maps, "restedXP", rested and rested.characters)
    AddMap(maps, "questHeaders",
        quests and quests.questLogHeaders)
    AddMap(maps, "targetMacro",
        quests and quests.targetMacro
            and quests.targetMacro.characters)
    AddMap(maps, "radialMenu", radial and radial.characters)
    return maps
end

local function LegacyKeys(maps, name)
    local found = {}
    local realms = {}
    local realmCount = 0

    for _, map in ipairs(maps) do
        for key in pairs(map.data) do
            if type(key) == "string" then
                local realm, legacyName =
                    key:match("^(.-)::(.*)$")
                if realm and legacyName == name then
                    found[key] = true
                    if realm ~= "" and not realms[realm] then
                        realms[realm] = true
                        realmCount = realmCount + 1
                    end
                end
            end
        end
    end

    local keys = {}
    for key in pairs(found) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        -- Prefer an explicitly named realm on tied/undated snapshots.
        local aRealm = a:match("^(.-)::") or ""
        local bRealm = b:match("^(.-)::") or ""
        if (aRealm == "") ~= (bRealm == "") then
            return aRealm ~= ""
        end
        return a < b
    end)
    return keys, realmCount
end

local function Newest(records)
    local newest = records[1]
    for index = 2, #records do
        local candidate = records[index]
        local candidateTime = tonumber(candidate.data.updated) or 0
        local newestTime = tonumber(newest.data.updated) or 0
        if candidateTime >= newestTime then
            newest = candidate
        end
    end
    return newest
end

local function MergeMissing(target, source, deep)
    for key, value in pairs(source) do
        local existing = target[key]
        if existing == nil then
            target[key] = Copy(value)
        elseif deep and type(existing) == "table"
            and type(value) == "table" then
            MergeMissing(existing, value, true)
        elseif key == "realm" and existing == ""
            and type(value) == "string" and value ~= "" then
            target[key] = value
        end
    end
end

local function MergeCharacter(records)
    local result = Copy(Newest(records).data)
    for _, record in ipairs(records) do
        local data = record.data
        for key, value in pairs(data) do
            if result[key] == nil then
                result[key] = Copy(value)
            elseif (key == "professions" or key == "autoEquipment")
                and type(result[key]) == "table"
                and type(value) == "table" then
                MergeMissing(result[key], value, true)
            elseif key == "realm" and result.realm == ""
                and type(value) == "string" and value ~= "" then
                result.realm = value
            end
        end
    end
    return result
end

local function HasBagSnapshot(data)
    return type(data.bags) == "table" and #data.bags > 0
end

local function HasBankSnapshot(data)
    return type(data.bank) == "table"
        and type(data.bank.tabs) == "table"
        and #data.bank.tabs > 0
end

local function BestSnapshot(records, predicate, timestamp)
    local best
    local bestTime
    for _, record in ipairs(records) do
        local data = record.data
        if predicate(data) then
            local timeValue = tonumber(timestamp(data)) or 0
            if not best or timeValue >= bestTime then
                best = data
                bestTime = timeValue
            end
        end
    end
    return best
end

local function MergeBags(records)
    -- Bag contents and bank contents are independent snapshots. Never
    -- allow a newer empty bag record to erase an older valid bank.
    local bag = BestSnapshot(records, HasBagSnapshot,
        function(data) return data.updated end)
    local bank = BestSnapshot(records, HasBankSnapshot,
        function(data) return data.bank.updated end)
    local result = Copy(bag or Newest(records).data)

    for _, record in ipairs(records) do
        for key, value in pairs(record.data) do
            if key ~= "bags" and key ~= "items"
                and key ~= "equippedBags"
                and key ~= "bank" and key ~= "bankItems"
                and result[key] == nil then
                result[key] = Copy(value)
            end
        end
    end
    if bank then
        result.bank = Copy(bank.bank)
        result.bankItems = Copy(bank.bankItems)
    end
    return result
end

local function MergeSettings(records)
    local result = Copy(Newest(records).data)
    for _, record in ipairs(records) do
        MergeMissing(result, record.data, true)
    end

    -- The newer TargetMacro defaults contain empty marker names. Do
    -- not let those placeholders hide older manually configured names.
    if type(result.names) == "table" then
        for _, record in ipairs(records) do
            local names = record.data.names
            if type(names) == "table" then
                for index, value in pairs(names) do
                    if result.names[index] == "" and
                        type(value) == "string" and value ~= "" then
                        result.names[index] = value
                    end
                end
            end
        end
    end
    return result
end

local function MergeRecords(id, records)
    if id == "characters" then return MergeCharacter(records) end
    if id == "bags" then return MergeBags(records) end
    return MergeSettings(records)
end

function UI:TryMigrateCharacterIdentity(guid, name)
    local db = KamiUIDB
    if type(db) ~= "table" then return end
    if not name or name == "" or name == "Player" then return end
    -- Surnames can arrive after the first player identity read.
    -- Retry if the full display name changes during initial loading.
    local identityKey = guid .. "::" .. name
    if checkedIdentity == identityKey then return end
    checkedIdentity = identityKey

    local maps = CharacterMaps(db)
    local legacyKeys, realmCount = LegacyKeys(maps, name)
    if realmCount > 1 then
        self:Print("GUID migration skipped for " .. name
            .. ": multiple old realms have this name.")
        return
    end
    if #legacyKeys == 0 then return end

    local identity = db.characterIdentity or {}
    identity.legacyBackup = identity.legacyBackup or {}
    identity.aliases = identity.aliases or {}

    for _, map in ipairs(maps) do
        local records = {}
        for _, key in ipairs(legacyKeys) do
            local data = map.data[key]
            if type(data) == "table" then
                records[#records + 1] = { key = key, data = data }
            end
        end
        local current = map.data[guid]
        if type(current) == "table" then
            records[#records + 1] = { key = guid, data = current }
        end

        if #records > 0 then
            -- Store immutable copies before overwriting/removing aliases.
            local backup = identity.legacyBackup[map.id] or {}
            for _, record in ipairs(records) do
                if record.key ~= guid
                    and backup[record.key] == nil then
                    backup[record.key] = Copy(record.data)
                end
            end
            identity.legacyBackup[map.id] = backup

            map.data[guid] = MergeRecords(map.id, records)
            for _, key in ipairs(legacyKeys) do
                map.data[key] = nil
            end
        end
    end

    for _, key in ipairs(legacyKeys) do
        identity.aliases[key] = guid
    end
    db.characterIdentity = identity
    self:Print("Migrated " .. name .. " cache to Player GUID ("
        .. #legacyKeys .. " old key(s)).")
end

function UI:GetCharacterGUIDKey()
    local guid = UnitGUID and self:SafeCall(UnitGUID, "player")
    if self:CanAccessValue(guid)
        and type(guid) == "string"
        and guid:match("^Player%-%d+%-%x+$") then
        cachedGUID = guid
    end
    -- Never fall back to an empty-realm key if the GUID becomes
    -- temporarily inaccessible during combat or a zone transition.
    if not cachedGUID then return nil end

    local _, _, name = self:GetCurrentCharacterNames()
    self:TryMigrateCharacterIdentity(cachedGUID, name)
    return cachedGUID
end
