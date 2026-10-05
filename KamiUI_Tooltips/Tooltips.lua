local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles

local Module = UI:NewModule("Tooltips", "KamiUI_Tooltips")

Module.version = "0.2.4"

local INSPECT_CACHE_SECONDS = 600
local INSPECT_MISS_CACHE_SECONDS = 60
local INSPECT_HOVER_DELAY_SECONDS = 0.30
local INSPECT_THROTTLE_SECONDS = 1.5
local INSPECT_TIMEOUT_SECONDS = 10
local INSPECT_READY_RETRY_SECONDS = 0.05
local INSPECT_READY_RETRY_COUNT = 20
local INSPECT_DEBUG = true

local function DebugInspect(...)
    if not INSPECT_DEBUG then
        return
    end

    UI:Print("|cffffcc00Tooltip Inspect:|r", ...)
end

local function DebugValue(value)
    if value == nil then
        return "nil"
    end

    if not UI:CanAccessValue(value) then
        return "<secret>"
    end

    return tostring(value)
end

local GUILD_COLOR = { 0.50, 1.00, 0.50, 1.00 }
local GUILD_RANK_COLOR = Palette.gold

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

local function AnchorGameTooltipToCursor(tooltip)
    if tooltip ~= GameTooltip
        or not tooltip.SetAnchorType
        or not GetCursorPosition
        or not UIParent
    then
        return
    end

    local scale = UIParent:GetEffectiveScale() or 1
    local cursorX, cursorY = GetCursorPosition()

    tooltip:SetAnchorType("ANCHOR_NONE")
    tooltip:ClearAllPoints()
    tooltip:SetPoint(
        "TOPLEFT",
        UIParent,
        "BOTTOMLEFT",
        cursorX / scale + 14,
        cursorY / scale - 12
    )
end

local function IsValidPlayerUnit(unit)
    if not unit
        or not UnitExists(unit)
        or not UnitIsPlayer(unit)
    then
        return false
    end

    return true
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

local function GetSpecFromTalentPoints(unit)
    if not IsValidPlayerUnit(unit) then
        return nil
    end

    local className, _, classID = GetClassInfo(unit)

    if not classID
        or not C_SpecializationInfo
        or not C_SpecializationInfo.GetNumSpecializationsForClassID
        or not C_SpecializationInfo.GetSpecializationInfo
    then
        return nil
    end

    local specializationCount = UI:SafeCall(
        C_SpecializationInfo.GetNumSpecializationsForClassID,
        classID
    )

    if not specializationCount or specializationCount <= 0 then
        return nil
    end

    local isInspect = not UnitIsUnit(unit, "player")
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

    local bestName
    local bestPoints = -1
    local tied = false
    local sex = UnitSex and UnitSex(unit) or nil

    for index = 1, specializationCount do
        local _specID,
            specName,
            _description,
            _icon,
            _role,
            _primaryStat,
            pointsSpent,
            _background,
            previewPointsSpent =
            UI:SafeCall(
                C_SpecializationInfo.GetSpecializationInfo,
                index,
                isInspect,
                false,
                isInspect and unit or nil,
                sex,
                groupIndex,
                classID
            )

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

        local totalPoints =
            pointsSpent + previewPointsSpent

        if specName
            and not UI:CanAccessValue(specName)
        then
            specName = nil
        end

        specName = GetLocalizedSpecName(
            classID,
            index,
            sex,
            specName
        )

        if specName and totalPoints > bestPoints then
            bestName = specName
            bestPoints = totalPoints
            tied = false
        elseif specName
            and totalPoints == bestPoints
        then
            tied = true
        end
    end

    if bestName and bestPoints > 0 and not tied then
        return bestName .. " " .. (className or "")
    end

    return nil
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
    local sex = UnitSex and UnitSex(unit) or nil

    if GetSpecializationInfoForSpecID then
        local _id
        _id, specName = UI:SafeCall(
            GetSpecializationInfoForSpecID,
            specID,
            sex
        )
    elseif GetSpecializationInfoByID then
        local _id
        _id, specName = UI:SafeCall(
            GetSpecializationInfoByID,
            specID,
            sex
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

    local className = GetClassInfo(unit)

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

    return specText
end

local function ResolveInspectedSpec(unit)
    return NormalizeSpecText(
        GetSpecFromInspectSpecialization(unit),
        unit
    )
        or NormalizeSpecText(
            GetSpecFromTalentPoints(unit),
            unit
        )
        or NormalizeSpecText(
            GetSpecFromClassicTalentTabs(unit),
            unit
        )
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
    if InspectFrame and InspectFrame.unit then
        return InspectFrame.unit
    end

    if PlayerSpellsFrame
        and PlayerSpellsFrame.IsInspecting
        and PlayerSpellsFrame:IsInspecting()
        and PlayerSpellsFrame.GetInspectUnit
    then
        return PlayerSpellsFrame:GetInspectUnit()
    end

    return nil
end

local function IsBlizzardInspectActive()
    if GetBlizzardInspectUnit() then
        return true
    end

    if InspectFrame
        and InspectFrame.IsShown
        and InspectFrame:IsShown()
    then
        return true
    end

    if PlayerSpellsFrame
        and PlayerSpellsFrame.IsInspecting
        and PlayerSpellsFrame:IsInspecting()
    then
        return true
    end

    return false
end

local function CanRequestInspect(unit)
    if not IsValidPlayerUnit(unit) then
        DebugInspect(
            "blocked: invalid unit",
            DebugValue(unit)
        )
        return false
    end

    if UnitIsUnit(unit, "player") then
        DebugInspect("blocked: player unit")
        return false
    end

    if IsBlizzardInspectActive() then
        DebugInspect("blocked: Blizzard inspect active")
        return false
    end

    if not NotifyInspect or not CanInspect then
        DebugInspect(
            "blocked: inspect API missing",
            "NotifyInspect=" .. DebugValue(NotifyInspect),
            "CanInspect=" .. DebugValue(CanInspect)
        )
        return false
    end

    local canInspect = UI:SafeCall(CanInspect, unit)

    DebugInspect(
        "CanInspect",
        "unit=" .. DebugValue(unit),
        "result=" .. DebugValue(canInspect)
    )

    return canInspect == true
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

    DebugInspect(
        "request",
        "unit=" .. DebugValue(unit),
        "guid=" .. DebugValue(guid)
    )

    NotifyInspect(unit)

    DebugInspect("NotifyInspect called")

    if C_Timer and C_Timer.After then
        C_Timer.After(
            INSPECT_TIMEOUT_SECONDS,
            function()
                if pendingInspect ~= request then
                    return
                end

                pendingInspect = nil

                DebugInspect(
                    "timeout",
                    "guid=" .. DebugValue(guid)
                )

                CacheSpec(
                    guid,
                    nil,
                    INSPECT_MISS_CACHE_SECONDS
                )

                if ClearInspectPlayer
                    and not IsBlizzardInspectActive()
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

    if C_Timer and C_Timer.After then
        C_Timer.After(
            INSPECT_HOVER_DELAY_SECONDS,
            TryStart
        )
    else
        queuedInspect = nil
        StartSpecInspect(unit, guid)
    end
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
    if GetQuestDifficultyColor then
        local color = UI:SafeCall(
            GetQuestDifficultyColor,
            level
        )

        if color then
            return color
        end
    end

    return Palette.difficulty.normal
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
        GUILD_COLOR
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

local function BuildLevelLine(unit, className, classColor)
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

    return "Level "
        .. Colorize(level, GetLevelColor(level))
        .. " "
        .. raceName
        .. " "
        .. Colorize(className, classColor)
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
    local levelText = BuildLevelLine(
        unit,
        className,
        classColor
    )
    local specText = NormalizeSpecText(
        GetPlayerSpec(unit, guid),
        unit
    )

    tooltip.KamiAddingPlayerDetails = true

    local lines = CaptureTooltipLines(tooltip)
    local guildIndex
    local levelIndex
    local classIndex

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

        if plain == className then
            classIndex = classIndex or index
        end
    end

    tooltip:ClearLines()

    local addedGuild = false
    local addedLevel = false
    local addedSpec = false
    local duplicateSpec =
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

            if specText and not classIndex then
                local r, g, b =
                    GetColorChannels(classColor)
                tooltip:AddLine(specText, r, g, b)
                addedSpec = true
            end
        elseif classIndex and index == classIndex then
            if specText then
                local r, g, b =
                    GetColorChannels(classColor)
                tooltip:AddLine(specText, r, g, b)
                addedSpec = true
            end
        elseif normalizedPlain == duplicateSpec then
            -- Drop the old "Hunter Hunter"-style duplicate.
        elseif specText
            and plain == specText
            and addedSpec
        then
            -- Drop duplicate spec lines on refresh.
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

    if specText and not addedSpec then
        local r, g, b = GetColorChannels(classColor)
        tooltip:AddLine(specText, r, g, b)
    end

    AnchorGameTooltipToCursor(tooltip)
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

        if tooltip:IsShown() then
            AnchorGameTooltipToCursor(tooltip)
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, Refresh)
    else
        Refresh()
    end
end

local function GetMatchingInspectUnit(guid, preferredUnit)
    local candidates = {
        GetBlizzardInspectUnit(),
        preferredUnit,
        GetVisibleTooltipUnit(guid),
    }

    for _, unit in ipairs(candidates) do
        if IsValidPlayerUnit(unit) then
            local unitGuid = UnitGUID(unit)

            if unitGuid
                and UI:CanAccessValue(unitGuid)
                and unitGuid == guid
            then
                return unit
            end
        end
    end

    return nil
end

local function FinishInspectRequest(request)
    if request
        and pendingInspect == request
    then
        pendingInspect = nil
    end

    if ClearInspectPlayer
        and not IsBlizzardInspectActive()
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
        if request
            and pendingInspect ~= request
        then
            return
        end

        attempts = attempts + 1

        local unit = GetMatchingInspectUnit(
            guid,
            preferredUnit
        )

        local inspectSpecID
        if unit
            and C_SpecializationInfo
            and C_SpecializationInfo.GetInspectSpecialization
        then
            inspectSpecID = UI:SafeCall(
                C_SpecializationInfo.GetInspectSpecialization,
                unit
            )
        end

        local specText = unit
            and ResolveInspectedSpec(unit)
            or nil

        DebugInspect(
            "ready attempt " .. tostring(attempts),
            "unit=" .. DebugValue(unit),
            "specID=" .. DebugValue(inspectSpecID),
            "resolved=" .. DebugValue(specText)
        )

        if specText then
            DebugInspect(
                "success",
                "guid=" .. DebugValue(guid),
                "spec=" .. DebugValue(specText)
            )

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
            DebugInspect(
                "ready but unresolved",
                "guid=" .. DebugValue(guid)
            )

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

local function DebugInspectUnitToken(label, unit)
    local exists
    local isPlayer
    local unitGuid

    if unit then
        exists = UI:SafeCall(UnitExists, unit)
        isPlayer = UI:SafeCall(UnitIsPlayer, unit)
        unitGuid = UI:SafeCall(UnitGUID, unit)
    end

    DebugInspect(
        "unit probe",
        label .. "=" .. DebugValue(unit),
        "exists=" .. DebugValue(exists),
        "player=" .. DebugValue(isPlayer),
        "guid=" .. DebugValue(unitGuid)
    )
end

local function DebugInspectUnitState()
    local tooltipUnit

    if GameTooltip
        and GameTooltip.GetUnit
        and GameTooltip:IsShown()
    then
        local _name
        _name, tooltipUnit = GameTooltip:GetUnit()
    end

    DebugInspectUnitToken(
        "pendingUnit",
        pendingInspect and pendingInspect.unit
    )
    DebugInspectUnitToken("tooltipUnit", tooltipUnit)
    DebugInspectUnitToken("mouseover", "mouseover")
    DebugInspectUnitToken("target", "target")
end

local function HandleInspectReady(guid)
    DebugInspect(
        "INSPECT_READY",
        "guid=" .. DebugValue(guid),
        "pending=" .. DebugValue(
            pendingInspect and pendingInspect.guid
        )
    )

    DebugInspectUnitState()

    if not guid or not UI:CanAccessValue(guid) then
        DebugInspect("ignored: invalid INSPECT_READY guid")
        return
    end

    local inspectUnit = GetBlizzardInspectUnit()
    local inspectGuid = inspectUnit
        and UnitGUID(inspectUnit)
        or nil
    local request = pendingInspect
    local requestMatches = request
        and request.guid == guid

    if inspectGuid
        and UI:CanAccessValue(inspectGuid)
        and inspectGuid == guid
    then
        ResolveInspectReady(
            guid,
            requestMatches and request or nil,
            inspectUnit
        )
        return
    end

    if not requestMatches then
        return
    end

    ResolveInspectReady(
        guid,
        request,
        request.unit
    )
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

local function InstallCursorAnchor()
    if Module.cursorAnchorInstalled or not GameTooltip then
        return
    end

    Module.cursorAnchorInstalled = true

    GameTooltip:HookScript("OnShow", function(self)
        AnchorGameTooltipToCursor(self)
        StyleTooltip(self)
    end)

    GameTooltip:HookScript("OnHide", function(self)
        queuedInspect = nil
        self.KamiPendingRefreshGuid = nil
    end)

    if hooksecurefunc and GameTooltip_SetDefaultAnchor then
        hooksecurefunc(
            "GameTooltip_SetDefaultAnchor",
            function(tooltip)
                AnchorGameTooltipToCursor(tooltip)
            end
        )
    end
end

function Module:Initialize()
    StyleKnownTooltips()
    InstallCursorAnchor()
    InstallUnitTooltipHook()

    UI:RegisterEvent("INSPECT_READY", function(_, guid)
        HandleInspectReady(guid)
    end)

    UI:RegisterEvent("ADDON_LOADED", function()
        StyleKnownTooltips()
        InstallCursorAnchor()
        InstallUnitTooltipHook()
    end)
end

Module:Initialize()
