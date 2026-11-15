local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles

local Module = UI:NewModule("Tooltips", "KamiUI_Tooltips")


local INSPECT_CACHE_SECONDS = 600
local INSPECT_MISS_CACHE_SECONDS = 10
local INSPECT_THROTTLE_SECONDS = 1.5
local INSPECT_TIMEOUT_SECONDS = 5
local INSPECT_READY_RETRY_SECONDS = 0.05
local INSPECT_READY_RETRY_COUNT = 20
local EXTERNAL_INSPECT_GRACE_SECONDS = 5

local GUILD_RANK_COLOR = Palette.gold

local SPEC_LABELS = {
    WARRIOR = {
        arms = "Arms",
        fury = "Fury",
        protection = "Prot",
    },
    PALADIN = {
        holy = "Holy",
        protection = "Prot",
        retribution = "Ret",
    },
    HUNTER = {
        ["beast mastery"] = "BM",
        beastmaster = "BM",
        marksmanship = "MM",
        survival = "SV",
    },
    ROGUE = {
        assassination = "Assa",
        combat = "Combat",
        subtlety = "Sub",
    },
    PRIEST = {
        discipline = "Disc",
        holy = "Holy",
        shadow = "Shadow",
        ["shadow magic"] = "Shadow",
    },
    SHAMAN = {
        elemental = "Ele",
        ["elemental combat"] = "Ele",
        enhancement = "Enh",
        restoration = "Resto",
    },
    MAGE = {
        arcane = "Arcane",
        fire = "Fire",
        frost = "Frost",
    },
    WARLOCK = {
        affliction = "DoT",
        demonology = "Demo",
        destruction = "Destro",
    },
    DRUID = {
        balance = "Balance",
        feral = "Feral",
        ["feral combat"] = "Feral",
        restoration = "Resto",
    },
}

local tooltipNames = {
    "GameTooltip",
    "ItemRefTooltip",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
    "ItemRefShoppingTooltip1",
    "ItemRefShoppingTooltip2",
}

local specCache = {}
local pendingInspect
local queuedInspect
local lastInspectRequest = 0
local externalInspectUntil = 0

-- Blizzard's View Talents and tooltip specialization inspection share
-- the same INSPECT_TRAIT_CONFIG_ID. A manual inspect must take priority
-- over our background tooltip requests.

local function GetClassInfo(unit)
    local className, classFile, classID = UnitClass(unit)

    if className and not UI:CanAccessValue(className) then
        className = nil
    end

    if classFile and not UI:CanAccessValue(classFile) then
        classFile = nil
    end

    if classID and not UI:CanAccessValue(classID) then
        classID = nil
    end

    return className, classFile, classID
end

local function GetClassColor(unit)
    local _, classFile = GetClassInfo(unit)

    return Palette:GetClassColor(classFile) or Palette.text
end

local function GetColorChannels(color)
    return Styles:GetColorChannels(color)
end

local function StyleTooltip(tooltip)
    if not tooltip then
        return
    end

    for _, region in ipairs({
        tooltip.NineSlice,
        tooltip.Background,
        tooltip.Bg,
    }) do
        if region and region.SetAlpha then
            region:SetAlpha(0)
        end
    end

    if not tooltip.KamiTooltipStyled then
        tooltip.KamiTooltipStyled = true

        Styles:EnsureBackground(
            tooltip,
            "KamiTooltipBackground",
            { 0.005, 0.008, 0.015, 0.60 },
            "BACKGROUND",
            -8
        )
        Styles:CreateBorder(tooltip, {
            key = "KamiTooltipBorder",
            color = Palette.border,
        })

        if tooltip.SetPadding then
            tooltip:SetPadding(7, 7, 7, 7)
        end

        if tooltip.SetClampedToScreen then
            tooltip:SetClampedToScreen(true)
        end

        if tooltip.SetClampRectInsets then
            tooltip:SetClampRectInsets(0, 0, 0, 0)
        end

        if tooltip.HookScript then
            tooltip:HookScript("OnShow", function(self)
                StyleTooltip(self)
            end)
        end
    end
end

local function StyleKnownTooltips()
    for _, name in ipairs(tooltipNames) do
        StyleTooltip(_G[name])
    end
end

local function IsValidPlayerUnit(unit)
    -- Tooltip:GetUnit() can return a secret unit token in combat,
    -- particularly for grouped players and world-cursor tooltips.
    -- Never pass it to protected unit APIs before checking access.
    if not UI:CanAccessValue(unit)
        or type(unit) ~= "string"
        or unit == ""
    then
        return false
    end

    local exists = UnitExists(unit)
    if not UI:CanAccessValue(exists) or not exists then
        return false
    end

    local isPlayer = UnitIsPlayer(unit)
    return UI:CanAccessValue(isPlayer) and isPlayer == true
end

local function GetLocalizedSpecName(
    classID,
    specIndex,
    sex,
    fallbackName
)
    if GetSpecializationInfoForClassID
        and classID
        and specIndex
    then
        local _id, name = UI:SafeCall(
            GetSpecializationInfoForClassID,
            classID,
            specIndex,
            sex
        )

        if name and UI:CanAccessValue(name) then
            return name
        end
    end

    return fallbackName
end

local function GetSpecFromTraitGroups(unit)
    if not IsValidPlayerUnit(unit) or UnitIsUnit(unit, "player")
        or not C_Traits or not C_Traits.GetConfigInfo
        or not C_Traits.GetGroupDisplayInfoByTreeID
        or not Constants or not Constants.TraitConsts
        or not Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID then
        return nil
    end

    if C_Traits.HasValidInspectData
        and UI:SafeCall(C_Traits.HasValidInspectData) ~= true then
        return nil
    end

    local configID = Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID
    local config = UI:SafeCall(C_Traits.GetConfigInfo, configID)
    if not config or not UI:CanAccessValue(config)
        or type(config.treeIDs) ~= "table"
        or not UI:CanAccessValue(config.treeIDs) then
        return nil
    end

    local groups = {}
    for _, treeID in ipairs(config.treeIDs) do
        if UI:CanAccessValue(treeID) then
            local display = UI:SafeCall(
                C_Traits.GetGroupDisplayInfoByTreeID, treeID
            )
            if type(display) == "table"
                and UI:CanAccessValue(display) then
                local groupIDs = {}

                for _, info in ipairs(display) do
                    local id = info and info.groupID
                    local name = info and info.displayName
                    if UI:CanAccessValue(id)
                        and UI:CanAccessValue(name)
                        and type(id) == "number"
                        and type(name) == "string" then
                        groupIDs[#groupIDs + 1] = id
                        groups[id] = groups[id] or {
                            name = name,
                            ranks = 0,
                            spent = 0,
                        }
                    end
                end

                -- Inspect currency values can be absent or identical
                -- across talent groups. Count actual learned node
                -- ranks in each group when the 1.60.1 API provides
                -- them, instead of relying solely on currency totals.
                if C_Traits.GetTreeNodes and C_Traits.GetNodeInfo then
                    local nodes = UI:SafeCall(
                        C_Traits.GetTreeNodes, treeID
                    )
                    if type(nodes) == "table"
                        and UI:CanAccessValue(nodes) then
                        for _, nodeID in ipairs(nodes) do
                            local node = UI:SafeCall(
                                C_Traits.GetNodeInfo,
                                configID, nodeID
                            )
                            if node and UI:CanAccessValue(node) then
                                local rank = node.activeRank
                                    or node.currentRank
                                local ids = node.groupIDs
                                if UI:CanAccessValue(rank)
                                    and type(rank) == "number"
                                    and rank > 0
                                    and type(ids) == "table"
                                    and UI:CanAccessValue(ids) then
                                    for _, id in ipairs(ids) do
                                        if groups[id] then
                                            groups[id].ranks =
                                                groups[id].ranks + rank
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                if C_Traits.GetGroupCurrencyInfo
                    and #groupIDs > 0 then
                    local currencies = UI:SafeCall(
                        C_Traits.GetGroupCurrencyInfo,
                        configID, groupIDs
                    )
                    if type(currencies) == "table"
                        and UI:CanAccessValue(currencies) then
                        for _, entry in ipairs(currencies) do
                            local group = entry
                                and groups[entry.traitNodeGroupID]
                            local currency = entry
                                and entry.currencyInfos
                                and entry.currencyInfos[1]
                            local spent = currency and (
                                currency.spentInTree or currency.spent
                            )
                            if group and UI:CanAccessValue(spent)
                                and type(spent) == "number" then
                                group.spent = math.max(
                                    group.spent, spent
                                )
                            end
                        end
                    end
                end
            end
        end
    end

    local hasRanks = false
    for _, group in pairs(groups) do
        if group.ranks > 0 then hasRanks = true end
    end

    local best, bestPoints, tied = nil, 0, false
    for _, group in pairs(groups) do
        local points = hasRanks and group.ranks or group.spent
        if points > bestPoints then
            best = group.name
            bestPoints = points
            tied = false
        elseif points == bestPoints and points > 0 then
            tied = true
        end
    end

    if best and not tied then
        local className = GetClassInfo(unit)
        return best .. " " .. (className or "")
    end
    return nil
end

local function GetSpecFromTalentPoints(unit)
    if not IsValidPlayerUnit(unit)
        or not C_SpecializationInfo
        or not C_SpecializationInfo.GetSpecialization
        or not C_SpecializationInfo.GetSpecializationInfo
    then
        return nil
    end

    local className, _, classID = GetClassInfo(unit)
    local isInspect = not UnitIsUnit(unit, "player")
    local inspectTarget = isInspect and unit or nil
    local sex = UnitSex and UI:SafeCall(UnitSex, unit) or nil
    local groupIndex

    if C_SpecializationInfo.GetActiveSpecGroup then
        groupIndex = UI:SafeCall(
            C_SpecializationInfo.GetActiveSpecGroup,
            isInspect,
            false
        )

        if groupIndex
            and not UI:CanAccessValue(groupIndex)
        then
            groupIndex = nil
        end
    end

    local specIndex = UI:SafeCall(
        C_SpecializationInfo.GetSpecialization,
        isInspect,
        false,
        groupIndex
    )

    if not specIndex
        or not UI:CanAccessValue(specIndex)
    then
        return nil
    end

    specIndex = tonumber(specIndex)

    if not specIndex or specIndex < 1 then
        return nil
    end

    local ok,
        _specID,
        specName,
        _description,
        _icon,
        _role,
        _primaryStat,
        pointsSpent,
        _background,
        previewPointsSpent,
        _isUnlocked =
        pcall(
            C_SpecializationInfo.GetSpecializationInfo,
            specIndex,
            isInspect,
            false,
            inspectTarget,
            sex,
            groupIndex,
            classID
        )

    if not ok then
        return nil
    end

    if specName
        and not UI:CanAccessValue(specName)
    then
        specName = nil
    end

    if not specName then
        return nil
    end

    if pointsSpent
        and UI:CanAccessValue(pointsSpent)
    then
        pointsSpent = tonumber(pointsSpent) or 0
    else
        pointsSpent = 0
    end

    if previewPointsSpent
        and UI:CanAccessValue(previewPointsSpent)
    then
        previewPointsSpent =
            tonumber(previewPointsSpent) or 0
    else
        previewPointsSpent = 0
    end

    local localizedName = GetLocalizedSpecName(
        classID,
        specIndex,
        nil,
        specName
    )

    if not localizedName then
        return nil
    end

    return localizedName .. " " .. (className or "")
end

local function GetSpecFromInspectSpecialization(unit)
    if not IsValidPlayerUnit(unit)
        or not C_SpecializationInfo
        or not C_SpecializationInfo.GetInspectSpecialization
    then
        return nil
    end

    local specID = UI:SafeCall(
        C_SpecializationInfo.GetInspectSpecialization,
        unit
    )

    if not specID
        or not UI:CanAccessValue(specID)
        or tonumber(specID) == 0
    then
        return nil
    end

    local specName

    if GetSpecializationNameForSpecID then
        specName = UI:SafeCall(
            GetSpecializationNameForSpecID,
            specID
        )
    elseif GetSpecializationInfoForSpecID then
        local _id
        _id, specName = UI:SafeCall(
            GetSpecializationInfoForSpecID,
            specID
        )
    elseif GetSpecializationInfoByID then
        local _id
        _id, specName = UI:SafeCall(
            GetSpecializationInfoByID,
            specID
        )
    end

    if not specName
        or not UI:CanAccessValue(specName)
    then
        return nil
    end

    local className = GetClassInfo(unit)

    if className and not UI:CanAccessValue(className) then
        className = nil
    end

    return specName .. " " .. (className or "")
end

local function GetSpecFromClassicTalentTabs(unit)
    if not IsValidPlayerUnit(unit)
        or not GetNumTalentTabs
        or not GetTalentTabInfo
    then
        return nil
    end

    local tabCount = UI:SafeCall(GetNumTalentTabs) or 0
    local bestName
    local bestPoints = -1
    local tied = false

    local isInspect = not UnitIsUnit(unit, "player")

    for index = 1, tabCount do
        local _id,
            name,
            _description,
            _icon,
            pointsSpent =
            UI:SafeCall(
                GetTalentTabInfo,
                index,
                isInspect,
                false
            )

        if pointsSpent
            and UI:CanAccessValue(pointsSpent)
        then
            pointsSpent = tonumber(pointsSpent)
        else
            pointsSpent = nil
        end

        if name
            and UI:CanAccessValue(name)
            and pointsSpent
        then
            if pointsSpent > bestPoints then
                bestName = name
                bestPoints = pointsSpent
                tied = false
            elseif pointsSpent == bestPoints then
                tied = true
            end
        end
    end

    if bestName and bestPoints > 0 and not tied then
        local className = GetClassInfo(unit)

        return bestName .. " " .. (className or "")
    end

    return nil
end

local function NormalizeSpecText(specText, unit)
    if not specText or not UI:CanAccessValue(specText) then
        return nil
    end

    local className, classFile = GetClassInfo(unit)

    if not className then
        return specText
    end

    local normalized = string.lower(specText)
    local normalizedClass = string.lower(className)

    if normalized == normalizedClass
        or normalized == normalizedClass .. " " .. normalizedClass
    then
        return nil
    end

    local suffix = " " .. normalizedClass
    local specName = normalized

    if string.sub(normalized, -#suffix) == suffix then
        specName = string.sub(
            normalized,
            1,
            #normalized - #suffix
        )
    end

    local classLabels = classFile
        and SPEC_LABELS[classFile]
    local label = classLabels
        and classLabels[specName]

    if label then
        return label .. " " .. className
    end

    if classLabels then
        -- Our cached shortened labels (e.g. "Ele Shaman") must remain
        -- valid when NormalizeSpecText is called a second time.
        for _, abbreviation in pairs(classLabels) do
            if string.lower(abbreviation) == specName then
                return abbreviation .. " " .. className
            end
        end

        -- A stale shared inspect config can otherwise turn a priest's
        -- "Discipline" talent data into "Discipline Shaman". Keep
        -- unfamiliar spec names, but reject known talents of other classes.
        for otherClass, otherLabels in pairs(SPEC_LABELS) do
            if otherClass ~= classFile and otherLabels[specName] then
                return nil
            end
        end
    end

    return specText
end

local function ResolveInspectedSpec(unit)
    -- Prefer Blizzard's explicit inspect specialization when present.
    -- Forever's talent group currencies may not expose spent points in
    -- every inspected config, so don't stop after one failed reader.
    local readers = {
        GetSpecFromInspectSpecialization,
        GetSpecFromTraitGroups,
        GetSpecFromTalentPoints,
        GetSpecFromClassicTalentTabs,
    }

    for _, reader in ipairs(readers) do
        local spec = NormalizeSpecText(reader(unit), unit)
        if spec then return spec end
    end

    return nil
end

local function CacheSpec(guid, specText, ttl)
    if not guid then
        return
    end

    local lifetime = ttl
        or (
            specText
            and INSPECT_CACHE_SECONDS
            or INSPECT_MISS_CACHE_SECONDS
        )

    specCache[guid] = {
        text = specText or false,
        expires = (GetTime and GetTime() or 0)
            + lifetime,
    }
end

local function GetCachedSpec(guid)
    local cached = guid and specCache[guid]

    if not cached then
        return false, nil
    end

    local now = GetTime and GetTime() or 0

    if cached.expires < now then
        specCache[guid] = nil
        return false, nil
    end

    return true, cached.text ~= false
        and cached.text
        or nil
end

local function GetBlizzardInspectUnit()
    -- Forever's context-menu "View Talents" opens PlayerSpellsFrame
    -- directly. The old InspectFrame may still retain a stale .unit
    -- after closing; only inspect the visible window's current unit.
    local talents = PlayerSpellsFrame
    if talents and talents.IsShown and talents:IsShown()
        and talents.IsInspecting and talents:IsInspecting()
        and talents.GetInspectUnit then
        local unit = talents:GetInspectUnit()
        if IsValidPlayerUnit(unit) then return unit end
    end

    local inspect = InspectFrame
    if inspect and inspect.IsShown and inspect:IsShown()
        and IsValidPlayerUnit(inspect.unit) then
        return inspect.unit
    end
end

local function IsBlizzardInspectActive()
    local talents = PlayerSpellsFrame
    if talents and talents.IsShown and talents:IsShown()
        and talents.IsInspecting and talents:IsInspecting() then
        return true
    end

    local inspect = InspectFrame
    return inspect and inspect.IsShown and inspect:IsShown()
        or false
end

local function CanRequestInspect(unit)
    if not IsValidPlayerUnit(unit)
        or UnitIsUnit(unit, "player")
        or IsBlizzardInspectActive()
        or (GetTime and GetTime() or 0) < externalInspectUntil
        or not NotifyInspect
        or not CanInspect
    then
        return false
    end

    return UI:SafeCall(CanInspect, unit) == true
end

local function StartSpecInspect(unit, guid)
    local now = GetTime and GetTime() or 0
    local cached = select(1, GetCachedSpec(guid))

    if cached
        or pendingInspect
        or not CanRequestInspect(unit)
        or not guid
    then
        return false
    end

    if now - lastInspectRequest < INSPECT_THROTTLE_SECONDS then
        return false
    end

    local request = {
        unit = unit,
        guid = guid,
        requestedAt = now,
    }

    pendingInspect = request
    lastInspectRequest = now

    -- Mark our own request so the NotifyInspect observer below does not
    -- mistake it for the player opening the native Inspect/Talents UI.
    Module.sendingSpecInspect = true
    NotifyInspect(unit)
    Module.sendingSpecInspect = nil

    if C_Timer and C_Timer.After then
        C_Timer.After(
            INSPECT_TIMEOUT_SECONDS,
            function()
                if pendingInspect ~= request then
                    return
                end

                pendingInspect = nil

                CacheSpec(
                    guid,
                    nil,
                    INSPECT_MISS_CACHE_SECONDS
                )

                if ClearInspectPlayer
                    and not IsBlizzardInspectActive()
                    and (GetTime and GetTime() or 0) >= externalInspectUntil
                then
                    ClearInspectPlayer()
                end
            end
        )
    end

    return true
end

local function GetVisibleTooltipUnit(guid)
    local tooltip = GameTooltip

    if not tooltip
        or not tooltip:IsShown()
        or not tooltip.GetUnit
    then
        return nil
    end

    local _name, unit = tooltip:GetUnit()

    if not IsValidPlayerUnit(unit) then
        return nil
    end

    local currentGuid = UnitGUID(unit)

    if not currentGuid
        or not UI:CanAccessValue(currentGuid)
        or currentGuid ~= guid
    then
        return nil
    end

    return unit
end

local function ScheduleSpecInspect(unit, guid)
    if not guid or not IsValidPlayerUnit(unit) then
        return
    end

    local cached = select(1, GetCachedSpec(guid))

    if cached
        or (pendingInspect and pendingInspect.guid == guid)
        or (queuedInspect and queuedInspect.guid == guid)
    then
        return
    end

    local request = {
        guid = guid,
    }

    queuedInspect = request

    local function TryStart()
        if queuedInspect ~= request then
            return
        end

        queuedInspect = nil

        local currentUnit =
            GetVisibleTooltipUnit(request.guid)

        if not currentUnit then
            return
        end

        local hasCached =
            select(1, GetCachedSpec(request.guid))

        if hasCached or pendingInspect then
            return
        end

        local now = GetTime and GetTime() or 0
        local throttleRemaining =
            INSPECT_THROTTLE_SECONDS
            - (now - lastInspectRequest)

        if throttleRemaining > 0
            and C_Timer
            and C_Timer.After
        then
            queuedInspect = request

            C_Timer.After(
                throttleRemaining,
                TryStart
            )
            return
        end

        StartSpecInspect(
            currentUnit,
            request.guid
        )
    end

    TryStart()
end

local function GetPlayerSpec(unit, guid)
    local hasCached, cached = GetCachedSpec(guid)

    if hasCached then
        return cached
    end

    if UnitIsUnit(unit, "player") then
        local specName

        if C_SpecializationInfo
            and C_SpecializationInfo.GetSpecialization
            and C_SpecializationInfo.GetSpecializationInfo
        then
            local index = UI:SafeCall(
                C_SpecializationInfo.GetSpecialization
            )

            if index and index > 0 then
                local _id
                _id, specName = UI:SafeCall(
                    C_SpecializationInfo.GetSpecializationInfo,
                    index
                )
            end
        end

        if specName
            and UI:CanAccessValue(specName)
        then
            local className = GetClassInfo(unit)

            specName = NormalizeSpecText(
                specName .. " " .. (className or ""),
                unit
            )
        else
            specName = nil
        end

        specName = specName
            or NormalizeSpecText(
                GetSpecFromClassicTalentTabs(unit),
                unit
            )

        if specName then
            CacheSpec(guid, specName)
        end

        return specName
    end

    ScheduleSpecInspect(unit, guid)

    return nil
end

local function GetTooltipLine(tooltip, side, index)
    local methodName = side == "right"
        and "GetRightLine"
        or "GetLeftLine"
    local getter = tooltip[methodName]

    if getter then
        local line = getter(tooltip, index)

        if line then
            return line
        end
    end

    if tooltip.GetName then
        local tooltipName = tooltip:GetName()

        if tooltipName then
            return _G[
                tooltipName
                .. (side == "right" and "TextRight" or "TextLeft")
                .. index
            ]
        end
    end
end

local function GetTextColor(line)
    if line and line.GetTextColor then
        local r, g, b = line:GetTextColor()

        return r or 1, g or 1, b or 1
    end

    return 1, 1, 1
end

local function StripColorCodes(text)
    if not text then
        return ""
    end

    return text
        :gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")
end

local function Colorize(text, color)
    local r, g, b = GetColorChannels(color)

    return string.format(
        "|cff%02x%02x%02x%s|r",
        math.floor(math.max(0, math.min(1, r)) * 255 + 0.5),
        math.floor(math.max(0, math.min(1, g)) * 255 + 0.5),
        math.floor(math.max(0, math.min(1, b)) * 255 + 0.5),
        tostring(text or "")
    )
end

local function GetLevelColor(level)
    -- Unit tooltip level colors must match mob difficulty, not
    -- quest-log difficulty. Share the palette logic with nameplates
    -- and unit frames.
    return Palette:GetLevelDifficultyColor(level)
end

local function CaptureTooltipLines(tooltip)
    local lines = {}
    local count = tooltip.NumLines and tooltip:NumLines() or 0

    for index = 1, count do
        local left = GetTooltipLine(tooltip, "left", index)
        local right = GetTooltipLine(tooltip, "right", index)
        local leftText = left and left.GetText and left:GetText()
        local rightText = right and right.GetText and right:GetText()

        if leftText and not UI:CanAccessValue(leftText) then
            leftText = nil
        end

        if rightText and not UI:CanAccessValue(rightText) then
            rightText = nil
        end

        local lr, lg, lb = GetTextColor(left)
        local rr, rg, rb = GetTextColor(right)

        lines[#lines + 1] = {
            leftText = leftText,
            rightText = rightText,
            leftColor = { lr, lg, lb },
            rightColor = { rr, rg, rb },
        }
    end

    return lines
end

local function AddCapturedLine(tooltip, line)
    if not line.leftText and not line.rightText then
        return
    end

    if line.rightText and line.rightText ~= "" then
        tooltip:AddDoubleLine(
            line.leftText or "",
            line.rightText,
            unpack(line.leftColor),
            unpack(line.rightColor)
        )
    else
        tooltip:AddLine(
            line.leftText or "",
            unpack(line.leftColor)
        )
    end
end

local function BuildGuildText(guildName, guildRankName)
    if not guildName
        or guildName == ""
        or not UI:CanAccessValue(guildName)
    then
        return nil
    end

    local text = Colorize(
        "<" .. guildName .. ">",
        Palette.guild
    )

    if guildRankName
        and UI:CanAccessValue(guildRankName)
        and guildRankName ~= ""
    then
        text = text
            .. "  "
            .. Colorize(guildRankName, GUILD_RANK_COLOR)
    end

    return text
end

local function BuildLevelLine(
    unit,
    className,
    classColor,
    specText
)
    local level = UnitLevel and UnitLevel(unit)
    local raceName = UnitRace and UnitRace(unit)

    if not level
        or not UI:CanAccessValue(level)
        or not raceName
        or not UI:CanAccessValue(raceName)
        or not className
    then
        return nil
    end

    level = tonumber(level)

    if not level then
        return nil
    end

    local classText = specText or className
    local normalizedRace = string.lower(raceName)

    if string.find(
        normalizedRace,
        "skyborn",
        1,
        true
    ) then
        raceName = "Smurf Elf"
    end

    return "Level "
        .. Colorize(level, GetLevelColor(level))
        .. " "
        .. raceName
        .. " "
        .. Colorize(classText, classColor)
end

local function AddPlayerDetails(tooltip)
    if tooltip ~= GameTooltip
        or tooltip.KamiAddingPlayerDetails
        or not tooltip.GetUnit
    then
        return
    end

    local _name, unit = tooltip:GetUnit()

    if not IsValidPlayerUnit(unit) then
        return
    end

    local guid = UnitGUID(unit)

    if not guid or not UI:CanAccessValue(guid) then
        return
    end

    local className = GetClassInfo(unit)

    if not className then
        return
    end

    local classColor = GetClassColor(unit)
    local guildName, guildRankName

    if GetGuildInfo then
        guildName, guildRankName = GetGuildInfo(unit)
    end

    local guildText = BuildGuildText(
        guildName,
        guildRankName
    )
    local specText = NormalizeSpecText(
        GetPlayerSpec(unit, guid),
        unit
    )
    local levelText = BuildLevelLine(
        unit,
        className,
        classColor,
        specText
    )

    tooltip.KamiAddingPlayerDetails = true

    local lines = CaptureTooltipLines(tooltip)
    local guildIndex
    local levelIndex

    for index, line in ipairs(lines) do
        local plain = StripColorCodes(line.leftText)

        if guildName
            and line.leftText
            and string.find(
                line.leftText,
                guildName,
                1,
                true
            )
        then
            guildIndex = guildIndex or index
        end

        if string.find(plain, "Level ", 1, true) == 1 then
            levelIndex = levelIndex or index
        end
    end

    tooltip:ClearLines()

    local addedGuild = false
    local addedLevel = false
    local duplicateClass =
        string.lower(className .. " " .. className)

    for index, line in ipairs(lines) do
        local plain = StripColorCodes(line.leftText)
        local normalizedPlain = string.lower(plain)

        if index == 1 then
            if line.leftText then
                local r, g, b =
                    GetColorChannels(classColor)

                tooltip:AddLine(
                    line.leftText,
                    r,
                    g,
                    b
                )
            end

            if guildText and not guildIndex then
                tooltip:AddLine(guildText, 1, 1, 1)
                addedGuild = true
            end
        elseif guildIndex and index == guildIndex then
            if guildText then
                tooltip:AddLine(guildText, 1, 1, 1)
                addedGuild = true
            end
        elseif levelIndex and index == levelIndex then
            if levelText then
                tooltip:AddLine(levelText, 1, 1, 1)
                addedLevel = true
            else
                AddCapturedLine(tooltip, line)
            end
        elseif plain == className
            or normalizedPlain == duplicateClass
            or (specText and plain == specText)
        then
            -- Class/spec is already part of the combined level line.
        elseif normalizedPlain == "horde"
            or normalizedPlain == "alliance"
        then
            -- Faction is already obvious from the player race.
        else
            AddCapturedLine(tooltip, line)
        end
    end

    if guildText and not addedGuild then
        tooltip:AddLine(guildText, 1, 1, 1)
    end

    if levelText and not addedLevel then
        tooltip:AddLine(levelText, 1, 1, 1)
    end

    tooltip.KamiAddingPlayerDetails = false
end

local function RefreshVisiblePlayerTooltip(guid)
    local tooltip = GameTooltip
    local unit = GetVisibleTooltipUnit(guid)

    if not tooltip or not unit then
        return
    end

    tooltip.KamiPendingRefreshGuid = guid

    local function Refresh()
        if tooltip.KamiPendingRefreshGuid ~= guid then
            return
        end

        local currentUnit = GetVisibleTooltipUnit(guid)

        if not currentUnit then
            tooltip.KamiPendingRefreshGuid = nil
            return
        end

        tooltip.KamiPendingRefreshGuid = nil
        tooltip:SetUnit(currentUnit)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, Refresh)
    else
        Refresh()
    end
end

local function GetMatchingInspectUnit(guid, preferredUnit)
    local function Matches(unit)
        if not IsValidPlayerUnit(unit) then
            return false
        end

        local unitGuid = UnitGUID(unit)

        return unitGuid
            and UI:CanAccessValue(unitGuid)
            and unitGuid == guid
    end

    local inspectUnit = GetBlizzardInspectUnit()

    if Matches(inspectUnit) then
        return inspectUnit
    end

    if Matches(preferredUnit) then
        return preferredUnit
    end

    local visibleUnit = GetVisibleTooltipUnit(guid)

    if Matches(visibleUnit) then
        return visibleUnit
    end

    return nil
end

local function FinishInspectRequest(request)
    -- Never clear Blizzard's inspection when INSPECT_READY belongs to its
    -- native talents/inspect window or another add-on.
    if not request or pendingInspect ~= request then
        return
    end

    pendingInspect = nil

    if ClearInspectPlayer
        and not IsBlizzardInspectActive()
        and (GetTime and GetTime() or 0) >= externalInspectUntil
    then
        ClearInspectPlayer()
    end
end

local function ResolveInspectReady(
    guid,
    request,
    preferredUnit
)
    local attempts = 0

    local function TryResolve()
        if request and pendingInspect ~= request then
            return
        end

        -- Manual Inspect/View Talents opened while our async inspect was
        -- pending: abandon our request without touching Blizzard's data.
        if IsBlizzardInspectActive() then
            if request and pendingInspect == request then
                pendingInspect = nil
            end
            return
        end

        attempts = attempts + 1

        local unit = GetMatchingInspectUnit(
            guid,
            preferredUnit
        )

        local hasValidInspectData = true
        if C_Traits and C_Traits.HasValidInspectData then
            hasValidInspectData =
                UI:SafeCall(C_Traits.HasValidInspectData)
                    == true
        end

        if not hasValidInspectData then
            if attempts < INSPECT_READY_RETRY_COUNT
                and C_Timer
                and C_Timer.After
            then
                C_Timer.After(
                    INSPECT_READY_RETRY_SECONDS,
                    TryResolve
                )
                return
            end

            if request then
                FinishInspectRequest(request)
            end
            return
        end

        local specText = unit
            and ResolveInspectedSpec(unit)
            or nil

        if specText then
            CacheSpec(guid, specText)
            FinishInspectRequest(request)
            RefreshVisiblePlayerTooltip(guid)
            return
        end

        if attempts < INSPECT_READY_RETRY_COUNT
            and C_Timer
            and C_Timer.After
        then
            C_Timer.After(
                INSPECT_READY_RETRY_SECONDS,
                TryResolve
            )
            return
        end

        if request then
            CacheSpec(
                guid,
                nil,
                INSPECT_MISS_CACHE_SECONDS
            )
            FinishInspectRequest(request)
            RefreshVisiblePlayerTooltip(guid)
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, TryResolve)
    else
        TryResolve()
    end
end

-- A manual right-click > View Talents can generate INSPECT_READY
-- without one of our tooltip requests. Read the already-loaded talent
-- groups, never issue another NotifyInspect or ClearInspectPlayer.
local function CacheManualInspectSpec(guid)
    local attempts = 0

    local function TryCache()
        local unit = GetBlizzardInspectUnit()
        if not unit then return end

        local unitGUID = UnitGUID(unit)
        if not UI:CanAccessValue(unitGUID)
            or unitGUID ~= guid then
            return
        end

        attempts = attempts + 1

        if C_Traits and C_Traits.HasValidInspectData
            and UI:SafeCall(C_Traits.HasValidInspectData) ~= true then
            if attempts < INSPECT_READY_RETRY_COUNT
                and C_Timer and C_Timer.After then
                C_Timer.After(
                    INSPECT_READY_RETRY_SECONDS, TryCache
                )
            end
            return
        end

        local spec = ResolveInspectedSpec(unit)
        if spec then
            CacheSpec(guid, spec)
            RefreshVisiblePlayerTooltip(guid)
            return
        end

        if attempts < INSPECT_READY_RETRY_COUNT
            and C_Timer and C_Timer.After then
            C_Timer.After(
                INSPECT_READY_RETRY_SECONDS, TryCache
            )
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, TryCache)
    else
        TryCache()
    end
end

-- Native "View Talents" can load INSPECT_READY before the
-- PlayerSpellsFrame becomes visible. Watch the frame lifecycle too.
local function InstallPlayerSpellsInspectHook()
    local frame = PlayerSpellsFrame
    if not frame or frame.KamiSpecInspectHooked
        or not frame.HookScript then
        return
    end

    frame.KamiSpecInspectHooked = true

    local function TryManualInspect()
        if not frame:IsShown() or not frame.IsInspecting
            or not frame:IsInspecting()
            or not frame.GetInspectUnit then
            return
        end

        local unit = frame:GetInspectUnit()
        if not IsValidPlayerUnit(unit) then return end

        local guid = UnitGUID(unit)
        if not guid or not UI:CanAccessValue(guid) then return end

        -- Blizzard now owns the shared inspect config. Cancel
        -- tooltip requests but never call ClearInspectPlayer here.
        pendingInspect = nil
        queuedInspect = nil
        externalInspectUntil = (GetTime and GetTime() or 0)
            + EXTERNAL_INSPECT_GRACE_SECONDS

        CacheManualInspectSpec(guid)
    end

    frame:HookScript("OnShow", TryManualInspect)
    if hooksecurefunc and type(frame.SetInspectUnit) == "function" then
        hooksecurefunc(frame, "SetInspectUnit", TryManualInspect)
    end
    if frame:IsShown() then TryManualInspect() end
end

local function HandleInspectReady(guid)
    if not guid or not UI:CanAccessValue(guid) then
        return
    end

    local request = pendingInspect
    if request and request.guid == guid then
        if IsBlizzardInspectActive() then
            -- Manual View Talents superseded our tooltip probe.
            pendingInspect = nil
            CacheManualInspectSpec(guid)
            return
        end

        ResolveInspectReady(guid, request, request.unit)
        return
    end

    -- Ignore unsolicited events unless Blizzard is displaying the
    -- player whose GUID fired INSPECT_READY. Prevents stale talent
    -- groups from being cached for another class or player.
    if IsBlizzardInspectActive() then
        -- A different manual inspect has superseded any older
        -- background request; its timeout must not clear this view.
        pendingInspect = nil
        queuedInspect = nil
        CacheManualInspectSpec(guid)
    end
end

local function InstallManualInspectPriority()
    if Module.manualInspectPriorityInstalled
        or not hooksecurefunc
        or not NotifyInspect
    then
        return
    end

    Module.manualInspectPriorityInstalled = true

    -- Observational secure hook only; never call NotifyInspect again or
    -- rewrite Blizzard's function. External/native requests supersede
    -- outstanding tooltip probes, preventing stale class talent displays.
    hooksecurefunc("NotifyInspect", function()
        if Module.sendingSpecInspect then
            return
        end

        queuedInspect = nil
        pendingInspect = nil
        externalInspectUntil = (GetTime and GetTime() or 0)
            + EXTERNAL_INSPECT_GRACE_SECONDS
    end)
end

-- Append item level without rebuilding Blizzard's tooltip contents.
-- KamiUI_Bags invokes this before its character counts, and this hook
-- keeps the feature available when the Bags module is disabled.
-- Pre-call edits would risk tainting secret tooltip data on Forever.
local function ResolveItemLevel(tooltip, data)
    local link
    local dataLink = data and data.hyperlink
    if UI:CanAccessValue(dataLink) and type(dataLink) == "string" then
        link = dataLink
    end

    if not link and tooltip.GetItem then
        local _, tooltipLink = UI:SafeCall(tooltip.GetItem, tooltip)
        if UI:CanAccessValue(tooltipLink)
            and type(tooltipLink) == "string" then
            link = tooltipLink
        end
    end

    local id = data and data.id
    if not UI:CanAccessValue(id) then id = nil end
    if not link and type(id) ~= "number" then return nil end

    local query = link or id
    local detailed = (C_Item and C_Item.GetDetailedItemLevelInfo)
        or GetDetailedItemLevelInfo
    if detailed then
        local level = UI:SafeCall(detailed, query)
        if UI:CanAccessValue(level)
            and type(level) == "number" and level > 0 then
            return level
        end
    end

    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if getInfo then
        local _, _, _, level = UI:SafeCall(getInfo, query)
        if UI:CanAccessValue(level)
            and type(level) == "number" and level > 0 then
            return level
        end
    end

    local override = data and data.overrideItemLevel
    if UI:CanAccessValue(override)
        and type(override) == "number" and override > 0 then
        return override
    end
end

local function AlreadyShowsItemLevel(tooltip)
    local count = tooltip.NumLines and tooltip:NumLines() or 0
    for index = 1, count do
        local line = GetTooltipLine(tooltip, "left", index)
        local text = line and line.GetText
            and UI:SafeCall(line.GetText, line)
        if UI:CanAccessValue(text) and type(text) == "string" then
            local clean = StripColorCodes(text)
            if clean:match("^Item Level%s*:?%s*%d")
                or clean:match("^Gegenstandsstufe%s*:?%s*%d") then
                return true
            end
        end
    end
    return false
end

function Module:AppendItemLevel(tooltip, data)
    if not tooltip or not tooltip.AddLine
        or AlreadyShowsItemLevel(tooltip) then
        return
    end
    local level = ResolveItemLevel(tooltip, data)
    if not level then return end
    tooltip:AddLine(
        string.format("Item Level %d", math.floor(level)),
        0.78, 0.78, 0.86
    )
end

local function InstallItemLevelHook()
    if Module.itemLevelHookInstalled then return end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        Module.itemLevelHookInstalled = true
        TooltipDataProcessor.AddTooltipPostCall(
            Enum.TooltipDataType.Item,
            function(tooltip, data)
                Module:AppendItemLevel(tooltip, data)
            end
        )
    elseif GameTooltip and GameTooltip.HookScript
        and GameTooltip.HasScript
        and GameTooltip:HasScript("OnTooltipSetItem") then
        Module.itemLevelHookInstalled = true
        GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
            Module:AppendItemLevel(tooltip)
        end)
    end
end

local function InstallUnitTooltipHook()
    if Module.unitTooltipHookInstalled then
        return
    end

    if TooltipDataProcessor
        and TooltipDataProcessor.AddTooltipPostCall
        and Enum
        and Enum.TooltipDataType
        and Enum.TooltipDataType.Unit
    then
        Module.unitTooltipHookInstalled = true

        TooltipDataProcessor.AddTooltipPostCall(
            Enum.TooltipDataType.Unit,
            function(tooltip)
                AddPlayerDetails(tooltip)
            end
        )

        return
    end

    if GameTooltip
        and GameTooltip.HookScript
        and GameTooltip.HasScript
        and GameTooltip:HasScript("OnTooltipSetUnit")
    then
        Module.unitTooltipHookInstalled = true
        GameTooltip:HookScript(
            "OnTooltipSetUnit",
            AddPlayerDetails
        )
    end
end

-- Do not re-enter GameTooltip:SetWorldCursor from a secure post-hook.
-- On modern Forever clients this can run Blizzard tooltip data processing in
-- a tainted context while tooltip lines still contain secret values.
-- Keep only the unrelated inspect cleanup on tooltip hide.
local function InstallTooltipHideCleanup()
    if Module.tooltipHideCleanupInstalled
        or not GameTooltip
        or not GameTooltip.HookScript
    then
        return
    end

    Module.tooltipHideCleanupInstalled = true
    GameTooltip:HookScript("OnHide", function(self)
        queuedInspect = nil
        self.KamiPendingRefreshGuid = nil
    end)
end

-- World units and gathering nodes are positioned through SetWorldCursor
-- rather than GameTooltip_SetDefaultAnchor. Re-anchor them after Blizzard
-- sets up the tooltip, without re-entering SetWorldCursor: invoking that
-- method from this hook runs its tooltip-data pipeline a second time in
-- an addon-tainted context (secret tooltip lines/colors may then error).
local function InstallWorldCursorAnchor()
    if Module.worldCursorAnchorInstalled
        or not GameTooltip
        or not GameTooltip.SetWorldCursor
        or not GameTooltip.SetAnchorType
        or not hooksecurefunc
        or not Enum
        or not Enum.WorldCursorAnchorType
    then
        return
    end

    Module.worldCursorAnchorInstalled = true

    hooksecurefunc(GameTooltip, "SetWorldCursor", function(self, anchorType)
        -- Override only Blizzard's default corner placement for world
        -- tooltips. Respect explicitly requested cursor/nameplate anchors.
        if anchorType ~= Enum.WorldCursorAnchorType.Default then
            return
        end

        -- Changes only the position; never calls SetWorldCursor, SetOwner,
        -- SetUnit, Show, or any tooltip data-processing method.
        self:SetAnchorType(Styles.Tooltip.anchor, 14, 12)
    end)
end

local function InstallInstantUnitTooltipHide()
    if Module.instantUnitTooltipHideInstalled
        or not hooksecurefunc
        or not UnitFrame_OnLeave
    then
        return
    end

    Module.instantUnitTooltipHideInstalled = true

    hooksecurefunc("UnitFrame_OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
end

local function InstallStatusBarSuppression()
    if Module.statusBarSuppressionInstalled
        or not GameTooltipStatusBar
    then
        return
    end

    Module.statusBarSuppressionInstalled = true
    GameTooltipStatusBar:SetAlpha(0)

    if GameTooltipStatusBar.HookScript then
        GameTooltipStatusBar:HookScript(
            "OnShow",
            function(self)
                self:SetAlpha(0)
            end
        )
    end
end

-- Read-only inspect diagnostics for the target or View Talents.
UI:RegisterCommand("tooltips", "inspect", function()
    if InCombatLockdown and InCombatLockdown() then
        UI:Print("Inspect diagnostics require leaving combat.")
        return
    end

    local unit = GetBlizzardInspectUnit()
    if not unit and IsValidPlayerUnit("target") then
        unit = "target"
    end
    if not unit then
        UI:Print("Target a player or open View Talents first.")
        return
    end

    local guid = UnitGUID(unit)
    local _, classFile = GetClassInfo(unit)
    local cached, name = GetCachedSpec(guid)
    local canInspect = CanInspect
        and UI:SafeCall(CanInspect, unit)
    local valid = C_Traits and C_Traits.HasValidInspectData
        and UI:SafeCall(C_Traits.HasValidInspectData)
    local configID = Constants and Constants.TraitConsts
        and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID
    local config = configID and C_Traits
        and C_Traits.GetConfigInfo
        and UI:SafeCall(C_Traits.GetConfigInfo, configID)
    local trees = config and config.treeIDs

    UI:Print(
        "Inspect:", unit, classFile or "?",
        "can=" .. tostring(canInspect),
        "ready=" .. tostring(valid),
        "trees=" .. tostring(type(trees) == "table" and #trees or 0)
    )
    UI:Print(
        "Blizzard inspect visible:", tostring(IsBlizzardInspectActive()),
        "pending:", tostring(pendingInspect ~= nil),
        "cached:", cached and (name or "miss") or "no"
    )
    UI:Print(
        "C_Traits groups:",
        tostring(GetSpecFromTraitGroups(unit))
    )
    UI:Print(
        "Inspect specialization:",
        tostring(GetSpecFromInspectSpecialization(unit))
    )
    UI:Print(
        "Specialization points:",
        tostring(GetSpecFromTalentPoints(unit)),
        "legacy tabs:",
        tostring(GetSpecFromClassicTalentTabs(unit))
    )
end, "Diagnose player talent inspect and spec cache")

function Module:Initialize()
    StyleKnownTooltips()
    InstallTooltipHideCleanup()
    InstallWorldCursorAnchor()
    InstallManualInspectPriority()
    InstallPlayerSpellsInspectHook()
    InstallStatusBarSuppression()
    InstallInstantUnitTooltipHide()
    InstallUnitTooltipHook()
    InstallItemLevelHook()

    UI:RegisterEvent("INSPECT_READY", function(_, guid)
        HandleInspectReady(guid)
    end)

    UI:RegisterEvent("ADDON_LOADED", function()
        StyleKnownTooltips()
        InstallTooltipHideCleanup()
        InstallWorldCursorAnchor()
        InstallManualInspectPriority()
        InstallPlayerSpellsInspectHook()
        InstallStatusBarSuppression()
        InstallInstantUnitTooltipHide()
        InstallUnitTooltipHook()
        InstallItemLevelHook()
    end)
end

Module:Initialize()
