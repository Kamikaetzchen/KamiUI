local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles

local Module = UI:NewModule("Tooltips", "KamiUI_Tooltips")

Module.version = "0.2.0"

local INSPECT_CACHE_SECONDS = 300
local INSPECT_THROTTLE_SECONDS = 1.5

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
    if not tooltip or tooltip.KamiTooltipStyled then
        return
    end

    tooltip.KamiTooltipStyled = true

    for _, region in ipairs({
        tooltip.NineSlice,
        tooltip.Background,
        tooltip.Bg,
    }) do
        if region and region.SetAlpha then
            region:SetAlpha(0)
        end
    end

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
end

local function StyleKnownTooltips()
    for _, name in ipairs(tooltipNames) do
        StyleTooltip(_G[name])
    end
end

local function AnchorGameTooltipToCursor(tooltip)
    if tooltip ~= GameTooltip or not tooltip.SetAnchorType then
        return
    end

    tooltip:SetAnchorType("ANCHOR_CURSOR_RIGHT", 14, 12)
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
            pointsSpent =
            UI:SafeCall(
                C_SpecializationInfo.GetSpecializationInfo,
                index,
                true,
                false,
                unit,
                sex,
                nil,
                classID
            )

        pointsSpent = tonumber(pointsSpent)

        if specName and pointsSpent then
            if pointsSpent > bestPoints then
                bestName = specName
                bestPoints = pointsSpent
                tied = false
            elseif pointsSpent == bestPoints then
                tied = true
            end
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

    if GetSpecializationInfoByID then
        local _id
        _id, specName = UI:SafeCall(
            GetSpecializationInfoByID,
            specID,
            UnitSex and UnitSex(unit) or nil
        )
    elseif GetSpecializationInfoForSpecID then
        local _id
        _id, specName = UI:SafeCall(
            GetSpecializationInfoForSpecID,
            specID,
            UnitSex and UnitSex(unit) or nil
        )
    end

    if not specName then
        return nil
    end

    local className = GetClassInfo(unit)

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

    for index = 1, tabCount do
        local _id,
            name,
            _description,
            _icon,
            pointsSpent =
            UI:SafeCall(
                GetTalentTabInfo,
                index,
                true,
                false
            )

        pointsSpent = tonumber(pointsSpent)

        if name and pointsSpent then
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

local function ResolveInspectedSpec(unit)
    return GetSpecFromTalentPoints(unit)
        or GetSpecFromInspectSpecialization(unit)
        or GetSpecFromClassicTalentTabs(unit)
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

local function CanRequestInspect(unit)
    if not IsValidPlayerUnit(unit)
        or UnitIsUnit(unit, "player")
        or not NotifyInspect
        or not CanInspect
    then
        return false
    end

    local canInspect = UI:SafeCall(CanInspect, unit, false)

    return canInspect == true
end

local function RequestSpecInspect(unit, guid)
    if pendingInspect
        or not CanRequestInspect(unit)
        or not guid
    then
        return
    end

    local now = GetTime and GetTime() or 0

    if now - lastInspectRequest < INSPECT_THROTTLE_SECONDS then
        return
    end

    pendingInspect = {
        unit = unit,
        guid = guid,
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

        if not specName then
            specName = GetSpecFromClassicTalentTabs(unit)
        else
            local className = GetClassInfo(unit)
            specName = specName .. " " .. (className or "")
        end

        if specName then
            CacheSpec(guid, specName)
        end

        return specName
    end

    RequestSpecInspect(unit, guid)

    return nil
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

    tooltip.KamiAddingPlayerDetails = true

    local guildName, guildRankName

    if GetGuildInfo then
        guildName, guildRankName = GetGuildInfo(unit)
    end

    if guildName and guildName ~= "" then
        local guildText = "<" .. guildName .. ">"

        if guildRankName and guildRankName ~= "" then
            guildText = guildText .. "  " .. guildRankName
        end

        local r, g, b = GetColorChannels(Palette.muted)
        tooltip:AddLine(guildText, r, g, b)
    end

    local specText = GetPlayerSpec(unit, guid)

    if specText then
        local color = GetClassColor(unit)
        local r, g, b = GetColorChannels(color)

        tooltip:AddLine(specText, r, g, b)
    end

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

    if not IsValidPlayerUnit(unit)
        or UnitGUID(unit) ~= guid
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

    pendingInspect = nil

    local unit = request.unit

    if IsValidPlayerUnit(unit)
        and UnitGUID(unit) == guid
    then
        local specText = ResolveInspectedSpec(unit)

        if specText then
            CacheSpec(guid, specText)
        end
    end

    if ClearInspectPlayer
        and not (
            InspectFrame
            and InspectFrame.IsShown
            and InspectFrame:IsShown()
        )
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
