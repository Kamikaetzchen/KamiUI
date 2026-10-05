local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles

local Module = UI:NewModule("Tooltips", "KamiUI_Tooltips")

Module.version = "0.2.1"

local INSPECT_CACHE_SECONDS = 300
local INSPECT_THROTTLE_SECONDS = 1.5
local INSPECT_TIMEOUT_SECONDS = 5

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
            { 0.005, 0.008, 0.015, 0.96 },
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
        GetSpecFromTalentPoints(unit),
        unit
    )
        or NormalizeSpecText(
            GetSpecFromInspectSpecialization(unit),
            unit
        )
        or NormalizeSpecText(
            GetSpecFromClassicTalentTabs(unit),
            unit
        )
end

local function CacheSpec(guid, specText)
    if not guid or not specText then
        return
    end

    specCache[guid] = {
        text = specText,
        expires = (GetTime and GetTime() or 0)
            + INSPECT_CACHE_SECONDS,
    }
end

local function GetCachedSpec(guid)
    local cached = guid and specCache[guid]

    if not cached then
        return nil
    end

    local now = GetTime and GetTime() or 0

    if cached.expires < now then
        specCache[guid] = nil
        return nil
    end

    return cached.text
end

local function IsBlizzardInspectActive()
    if InspectFrame then
        if InspectFrame.unit then
            return true
        end

        if InspectFrame.IsShown
            and InspectFrame:IsShown()
        then
            return true
        end
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
    if not IsValidPlayerUnit(unit)
        or UnitIsUnit(unit, "player")
        or IsBlizzardInspectActive()
        or not NotifyInspect
        or not CanInspect
    then
        return false
    end

    local canInspect = UI:SafeCall(CanInspect, unit)

    return canInspect == true
end

local function RequestSpecInspect(unit, guid)
    local now = GetTime and GetTime() or 0

    if pendingInspect
        and now - (pendingInspect.requestedAt or 0)
            >= INSPECT_TIMEOUT_SECONDS
    then
        pendingInspect = nil
    end

    if pendingInspect
        or not CanRequestInspect(unit)
        or not guid
    then
        return
    end

    if now - lastInspectRequest < INSPECT_THROTTLE_SECONDS then
        return
    end

    pendingInspect = {
        unit = unit,
        guid = guid,
        requestedAt = now,
    }
    lastInspectRequest = now

    NotifyInspect(unit)
end

local function GetPlayerSpec(unit, guid)
    local cached = GetCachedSpec(guid)

    if cached then
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

    RequestSpecInspect(unit, guid)

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

    if not tooltip
        or not tooltip:IsShown()
        or not tooltip.GetUnit
    then
        return
    end

    local _name, unit = tooltip:GetUnit()

    if not IsValidPlayerUnit(unit) then
        return
    end

    local currentGuid = UnitGUID(unit)

    if not currentGuid
        or not UI:CanAccessValue(currentGuid)
        or currentGuid ~= guid
    then
        return
    end

    tooltip:SetUnit(unit)
end

local function HandleInspectReady(guid)
    local request = pendingInspect

    if not request or request.guid ~= guid then
        return
    end

    if IsBlizzardInspectActive() then
        pendingInspect = nil
        return
    end

    pendingInspect = nil

    local unit = request.unit

    if IsValidPlayerUnit(unit) then
        local currentGuid = UnitGUID(unit)

        if currentGuid
            and UI:CanAccessValue(currentGuid)
            and currentGuid == guid
        then
            local specText = ResolveInspectedSpec(unit)

            if specText then
                CacheSpec(guid, specText)
            end
        end
    end

    if ClearInspectPlayer
        and not IsBlizzardInspectActive()
    then
        ClearInspectPlayer()
    end

    RefreshVisiblePlayerTooltip(guid)
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
