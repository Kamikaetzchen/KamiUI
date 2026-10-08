local UI = KamiUI
local Styles = UI.Styles
local UF = UI:GetModule("UnitFrames")

local Layout = UI.Layout.UnitFrames.Indicators

local READY_CHECK_STAY_TIME = DEFAULT_READY_CHECK_STAY_TIME or 5
local readyCheckGeneration = 0


local function IsTruthy(value)
    return UI:CanAccessValue(value) and value and true or false
end

local function SetIndicatorAtlas(icon, atlas, fallbackTexture)
    if icon.SetAtlas and atlas then
        local ok = pcall(icon.SetAtlas, icon, atlas, false)

        if ok then
            return
        end
    end

    icon:SetTexture(fallbackTexture or atlas)
    icon:SetTexCoord(0, 1, 0, 1)
end

local function IsReadyCheckUnit(unit)
    if unit == "player" then
        return true
    end

    local inParty = UnitInParty and UnitInParty(unit)
    local inRaid = UnitInRaid and UnitInRaid(unit)

    return IsTruthy(inParty) or IsTruthy(inRaid)
end

local function CreateIcon(parent)
    local icon = parent:CreateTexture(nil, "OVERLAY")
    icon:SetSize(Layout.STATUS_ICON_SIZE, Layout.STATUS_ICON_SIZE)
    icon:SetAlpha(Styles.State.indicatorAlpha)
    icon:Hide()
    return icon
end

local function CreateCenterIndicators(frame)
    local row = CreateFrame("Frame", nil, frame)

    local level = frame:GetFrameLevel()

    if frame.health then
        level = math.max(level, frame.health:GetFrameLevel())
    end

    if frame.power then
        level = math.max(level, frame.power:GetFrameLevel())
    end

    row:SetFrameLevel(level + 20)

    -- Anchor the indicator area to the actual bars, not the whole unit frame.
    -- This automatically excludes portraits on player/target/party frames.
    if frame.health and frame.power then
        row:SetPoint("TOPLEFT", frame.health, "TOPLEFT", 0, 0)
        row:SetPoint("BOTTOMRIGHT", frame.power, "BOTTOMRIGHT", 0, 0)
    elseif frame.health then
        row:SetAllPoints(frame.health)
    else
        row:SetAllPoints(frame)
    end

    row.icons = {
        raid = CreateIcon(row),
        ready = CreateIcon(row),
        resurrect = CreateIcon(row),
        summon = CreateIcon(row),
        offline = CreateIcon(row),
        ghost = CreateIcon(row),
    }

    local indicatorSize = math.floor(frame:GetHeight() * 0.75 + 0.5)
    indicatorSize = math.max(12, math.min(30, indicatorSize))

    for _, icon in pairs(row.icons) do
        icon:SetSize(indicatorSize, indicatorSize)
        icon:SetAlpha(0.60)
    end

    frame.centerIndicators = row
end

local function LayoutCenterIndicators(frame)
    local row = frame.centerIndicators
    if not row then
        return
    end

    local visible = {}

    for _, key in ipairs({
        "raid",
        "ready",
        "resurrect",
        "summon",
        "offline",
        "ghost",
    }) do
        local icon = row.icons[key]

        if icon:IsShown() then
            visible[#visible + 1] = icon
        end
    end

    local count = #visible

    if count == 0 then
        return
    end

    local iconSize = visible[1]:GetWidth()
    local gap = 2
    local totalWidth = count * iconSize + (count - 1) * gap
    local x = -totalWidth / 2 + iconSize / 2

    for _, icon in ipairs(visible) do
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", row, "CENTER", x, 0)
        x = x + iconSize + gap
    end
end


local function UpdateRaidMarker(frame)
    local icon = frame.centerIndicators.icons.raid
    local index = GetRaidTargetIndex and GetRaidTargetIndex(frame.unit)

    if not index or not UI:CanAccessValue(index) then
        icon:Hide()
        return
    end

    icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")

    if SetRaidTargetIconTexture
        and pcall(SetRaidTargetIconTexture, icon, index)
    then
        icon:Show()
    else
        icon:Hide()
    end
end

local function UpdateReadyCheck(frame)
    local icon = frame.centerIndicators.icons.ready
    local status = frame.readyCheckStatus

    if status == "ready" then
        SetIndicatorAtlas(
            icon,
            READY_CHECK_READY_TEXTURE_RAID
                or "UI-LFG-ReadyMark-Raid",
            "Interface\\RaidFrame\\ReadyCheck-Ready"
        )
        icon:Show()
    elseif status == "notready" then
        SetIndicatorAtlas(
            icon,
            READY_CHECK_NOT_READY_TEXTURE_RAID
                or "UI-LFG-DeclineMark-Raid",
            "Interface\\RaidFrame\\ReadyCheck-NotReady"
        )
        icon:Show()
    elseif status == "waiting" then
        SetIndicatorAtlas(
            icon,
            READY_CHECK_WAITING_TEXTURE_RAID
                or "UI-LFG-PendingMark-Raid",
            "Interface\\RaidFrame\\ReadyCheck-Waiting"
        )
        icon:Show()
    else
        icon:Hide()
    end
end

local function UpdateResurrection(frame)
    local icon = frame.centerIndicators.icons.resurrect
    local incoming = UnitHasIncomingResurrection
        and UnitHasIncomingResurrection(frame.unit)

    if IsTruthy(incoming) then
        SetIndicatorAtlas(
            icon,
            "RaidFrame-Icon-Rez",
            "Interface\\RaidFrame\\Raid-Icon-Rez"
        )
        icon:Show()
    else
        icon:Hide()
    end
end

local function UpdateSummon(frame)
    local icon = frame.centerIndicators.icons.summon
    local incoming = C_IncomingSummon
        and C_IncomingSummon.HasIncomingSummon
        and C_IncomingSummon.HasIncomingSummon(frame.unit)

    if not IsTruthy(incoming) then
        icon:Hide()
        return
    end

    local status = C_IncomingSummon.IncomingSummonStatus
        and C_IncomingSummon.IncomingSummonStatus(frame.unit)

    local accepted = Enum
        and Enum.SummonStatus
        and Enum.SummonStatus.Accepted
        or 2
    local declined = Enum
        and Enum.SummonStatus
        and Enum.SummonStatus.Declined
        or 3

    if status == accepted then
        SetIndicatorAtlas(
            icon,
            "RaidFrame-Icon-SummonAccepted",
            "Interface\\RaidFrame\\Raid-Icon-SummonAccepted"
        )
    elseif status == declined then
        SetIndicatorAtlas(
            icon,
            "RaidFrame-Icon-SummonDeclined",
            "Interface\\RaidFrame\\Raid-Icon-SummonDeclined"
        )
    else
        SetIndicatorAtlas(
            icon,
            "RaidFrame-Icon-SummonPending",
            "Interface\\RaidFrame\\Raid-Icon-SummonPending"
        )
    end

    icon:Show()
end
local function UpdateConnection(frame)
    local offlineIcon = frame.centerIndicators.icons.offline
    local ghostIcon = frame.centerIndicators.icons.ghost

    local connected = UnitIsConnected and UnitIsConnected(frame.unit)
    if UI:CanAccessValue(connected) and connected == false then
        offlineIcon:SetTexture("Interface\\CharacterFrame\\Disconnect-Icon")
        offlineIcon:SetTexCoord(0, 1, 0, 1)
        offlineIcon:Show()
    else
        offlineIcon:Hide()
    end

    local ghost = UnitIsGhost and UnitIsGhost(frame.unit)
    if IsTruthy(ghost) then
        ghostIcon:SetTexture(
            "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
        )
        ghostIcon:SetTexCoord(0, 1, 0, 1)
        ghostIcon:Show()
    else
        ghostIcon:Hide()
    end
end

local function UpdateCenterIndicators(frame)
    if not frame.centerIndicators or not UnitExists(frame.unit) then
        return
    end

    UpdateRaidMarker(frame)
    UpdateReadyCheck(frame)
    UpdateResurrection(frame)
    UpdateSummon(frame)
    UpdateConnection(frame)
    LayoutCenterIndicators(frame)
end

local function CreatePortraitIndicators(frame)
    if not frame.portrait then
        return
    end

    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints(frame.portrait)
    overlay:SetFrameLevel(math.max(
        frame:GetFrameLevel(),
        frame.portrait:GetFrameLevel()
    ) + 20)
    overlay:EnableMouse(false)

    local leader = overlay:CreateTexture(nil, "OVERLAY")
    leader:SetSize(10, 10)
    leader:SetPoint("CENTER", frame.portrait, "TOPLEFT", 5, 0)
    leader:Hide()

    local role = overlay:CreateTexture(nil, "OVERLAY")
    role:SetSize(10, 10)
    role:SetPoint("CENTER", frame.portrait, "TOPRIGHT", -5, 0)
    role:Hide()

    local loot = overlay:CreateTexture(nil, "OVERLAY")
    loot:SetSize(10, 10)
    loot:SetPoint("CENTER", frame.portrait, "TOP", 0, 0)
    loot:Hide()

    frame.portraitIndicatorOverlay = overlay
    frame.leaderIndicator = leader
    frame.roleIndicator = role
    frame.lootIndicator = loot
end

local function IsMasterLooter(unit)
    if not C_PartyInfo or not C_PartyInfo.GetLootMethod then
        return false
    end

    local method, partyID, raidID = C_PartyInfo.GetLootMethod()
    if not UI:CanAccessValue(method) or method ~= 2 then
        return false
    end

    if raidID then
        return UnitIsUnit(unit, "raid" .. raidID)
    end

    if partyID ~= nil then
        if partyID == 0 then
            return UnitIsUnit(unit, "player")
        end

        return UnitIsUnit(unit, "party" .. partyID)
    end

    return false
end

local function UpdatePortraitIndicators(frame)
    if not frame.portrait
        or not frame.portraitIndicatorOverlay
        or not UnitExists(frame.unit)
    then
        return
    end

    local leader = UnitIsGroupLeader and UnitIsGroupLeader(frame.unit)
    local assistant = UnitIsGroupAssistant and UnitIsGroupAssistant(frame.unit)

    if IsTruthy(leader) then
        frame.leaderIndicator:SetTexture(
            "Interface\\GroupFrame\\UI-Group-LeaderIcon"
        )
        frame.leaderIndicator:Show()
    elseif IsTruthy(assistant) then
        frame.leaderIndicator:SetTexture(
            "Interface\\GroupFrame\\UI-Group-AssistantIcon"
        )
        frame.leaderIndicator:Show()
    else
        frame.leaderIndicator:Hide()
    end

    if IsMasterLooter(frame.unit) then
        frame.lootIndicator:SetTexture(
            "Interface\\GroupFrame\\UI-Group-MasterLooter"
        )
        frame.lootIndicator:Show()
    else
        frame.lootIndicator:Hide()
    end

    local role = UnitGroupRolesAssigned
        and UnitGroupRolesAssigned(frame.unit)

    if UI:CanAccessValue(role)
        and (role == "TANK" or role == "HEALER" or role == "DAMAGER")
    then
        frame.roleIndicator:SetTexture(
            "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
        )

        if GetTexCoordsForRoleSmallCircle then
            frame.roleIndicator:SetTexCoord(
                GetTexCoordsForRoleSmallCircle(role)
            )
        else
            frame.roleIndicator:SetTexCoord(0, 1, 0, 1)
        end

        frame.roleIndicator:Show()
    else
        frame.roleIndicator:Hide()
    end
end


local function UpdateUnitLabel(frame)
    if not frame.nameText or not UnitExists(frame.unit) then
        return
    end

    if frame.nameMode == "first" then
        UF:SetUnitFirstName(frame.nameText, frame.unit)
    else
        UF:SetUnitDisplayName(frame.nameText, frame.unit)
    end
end

local function CreateHealPrediction(frame)
    if not UF:HasFeature(frame, "healPrediction")
        or not frame.health
        or not CreateUnitHealPredictionCalculator
        or not UnitGetDetailedHealPrediction
    then
        return
    end

    if frame.health.SetClipsChildren then
        frame.health:SetClipsChildren(true)
    end

    local incoming = CreateFrame("StatusBar", nil, frame.health)
    incoming:SetPoint(
        "TOPLEFT",
        frame.health:GetStatusBarTexture(),
        "TOPRIGHT",
        0,
        0
    )
    incoming:SetPoint(
        "BOTTOMLEFT",
        frame.health:GetStatusBarTexture(),
        "BOTTOMRIGHT",
        0,
        0
    )
    incoming:SetWidth(frame.health:GetWidth())
    incoming:SetStatusBarTexture(UF.flatTexture)
    incoming:SetStatusBarColor(0.35, 0.80, 1.00, 0.70)

    local absorb = CreateFrame("StatusBar", nil, frame.health)
    absorb:SetPoint(
        "TOPLEFT",
        incoming:GetStatusBarTexture(),
        "TOPRIGHT",
        0,
        0
    )
    absorb:SetPoint(
        "BOTTOMLEFT",
        incoming:GetStatusBarTexture(),
        "BOTTOMRIGHT",
        0,
        0
    )
    absorb:SetWidth(frame.health:GetWidth())
    absorb:SetStatusBarTexture("Interface\\RaidFrame\\Shield-Fill")
    absorb:SetStatusBarColor(0.45, 0.70, 1.00, 0.80)

    frame.healPrediction = {
        calculator = CreateUnitHealPredictionCalculator(),
        incoming = incoming,
        absorb = absorb,
    }
end

local function UpdateHealPrediction(frame)
    local prediction = frame.healPrediction
    if not prediction or not UnitExists(frame.unit) then
        return
    end

    local calculator = prediction.calculator
    calculator:Reset()
    UnitGetDetailedHealPrediction(frame.unit, nil, calculator)

    local maximum = calculator:GetMaximumHealth()
    local incoming = calculator:GetIncomingHeals()
    local absorbs = calculator:GetDamageAbsorbs()

    prediction.incoming:SetMinMaxValues(0, maximum)
    prediction.incoming:SetValue(incoming)

    prediction.absorb:SetMinMaxValues(0, maximum)
    prediction.absorb:SetValue(absorbs)
end

local comboBars = {}

local function CreateComboPoints()
    local frame = UF.targetFrame
    if not frame or not frame.portrait then
        return
    end

    local _, class = UnitClass("player")
    if class ~= "ROGUE" and class ~= "DRUID" then
        return
    end

    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints(frame.portrait)
    overlay:SetFrameLevel(math.max(
        frame:GetFrameLevel(),
        frame.portrait:GetFrameLevel()
    ) + 20)
    overlay:EnableMouse(false)
    frame.comboPointOverlay = overlay

    for i = 1, 5 do
        local bar = overlay:CreateTexture(nil, "OVERLAY")
        bar:SetSize(6, 3)
        bar:SetPoint(
            "BOTTOMLEFT",
            overlay,
            "BOTTOMLEFT",
            2 + (i - 1) * 7,
            2
        )
        bar:SetColorTexture(0.12, 0.12, 0.12, 0.90)
        comboBars[i] = bar
    end
end

local function UpdateComboPoints()
    if #comboBars == 0 or not GetComboPoints then
        return
    end

    local points = GetComboPoints("player", "target")
    if not UI:CanAccessValue(points) then
        return
    end

    for i, bar in ipairs(comboBars) do
        if i <= points then
            bar:SetColorTexture(1.00, 0.80, 0.05, 0.95)
        else
            bar:SetColorTexture(0.12, 0.12, 0.12, 0.90)
        end
    end
end

local function UpdateFrame(frame)
    UpdateUnitLabel(frame)
    UpdatePortraitIndicators(frame)
    UpdateCenterIndicators(frame)
    UpdateHealPrediction(frame)
end


local function UpdateAll()
    UF:ForEachFrame(function(frame)
        if UF:HasFeature(frame, "indicators")
            or UF:HasFeature(frame, "healPrediction")
        then
            UpdateFrame(frame)
        end
    end)

    UpdateComboPoints()
end
local function UpdateUnit(_, unit)
    if not unit then
        UpdateAll()
        return
    end

    UF:ForEachMatchingUnitFrame(unit, function(frame)
        if UF:HasFeature(frame, "indicators")
            or UF:HasFeature(frame, "healPrediction")
        then
            UpdateFrame(frame)
        end
    end)

    if unit == "target" or unit == "player" then
        UpdateComboPoints()
    end
end

local function RefreshCenterIndicatorsForUnit(_, unit)
    local function Refresh()
        if unit then
            UF:ForEachMatchingUnitFrame(
                unit,
                UpdateCenterIndicators,
                "indicators"
            )
        else
            UF:ForEachFrame(UpdateCenterIndicators, "indicators")
        end
    end

    Refresh()

    if C_Timer and C_Timer.After then
        C_Timer.After(0, Refresh)
    end
end

local function SyncReadyCheckStatuses()
    UF:ForEachFrame(function(frame)
        if not UnitExists(frame.unit) or not IsReadyCheckUnit(frame.unit) then
            frame.readyCheckStatus = nil
            UpdateCenterIndicators(frame)
            return
        end

        local status = GetReadyCheckStatus
            and GetReadyCheckStatus(frame.unit)

        if UI:CanAccessValue(status)
            and (
                status == "ready"
                or status == "notready"
                or status == "waiting"
            )
        then
            frame.readyCheckStatus = status
        elseif not frame.readyCheckStatus then
            frame.readyCheckStatus = "waiting"
        end

        UpdateCenterIndicators(frame)
    end, "indicators")
end

local function BeginReadyCheck()
    readyCheckGeneration = readyCheckGeneration + 1

    UF:ForEachFrame(function(frame)
        frame.readyCheckStatus = IsReadyCheckUnit(frame.unit)
            and "waiting"
            or nil
        UpdateCenterIndicators(frame)
    end, "indicators")

    if C_Timer and C_Timer.After then
        local generation = readyCheckGeneration

        C_Timer.After(0, function()
            if generation == readyCheckGeneration then
                SyncReadyCheckStatuses()
            end
        end)
    else
        SyncReadyCheckStatuses()
    end
end

local function ConfirmReadyCheck(_, unit, isReady)
    if not unit then
        return
    end

    local status = (isReady == true or isReady == 1)
        and "ready"
        or "notready"

    UF:ForEachMatchingUnitFrame(unit, function(frame)
        frame.readyCheckStatus = status
        UpdateCenterIndicators(frame)
    end, "indicators")
end

local function FinishReadyCheck()
    local generation = readyCheckGeneration

    UF:ForEachFrame(function(frame)
        if frame.readyCheckStatus == "waiting" then
            frame.readyCheckStatus = "notready"
        end

        UpdateCenterIndicators(frame)
    end, "indicators")

    if not C_Timer or not C_Timer.After then
        return
    end

    C_Timer.After(READY_CHECK_STAY_TIME, function()
        if generation ~= readyCheckGeneration then
            return
        end

        UF:ForEachFrame(function(frame)
            frame.readyCheckStatus = nil
            UpdateCenterIndicators(frame)
        end, "indicators")
    end)
end

UF:ForEachFrame(function(frame)
    if UF:HasFeature(frame, "indicators") then
        CreateCenterIndicators(frame)
        CreatePortraitIndicators(frame)
    end

    if UF:HasFeature(frame, "healPrediction") then
        CreateHealPrediction(frame)
    end
end)

CreateComboPoints()
UpdateAll()

UI:RegisterEvent("PLAYER_ENTERING_WORLD", UpdateAll)
UI:RegisterEvent("GROUP_ROSTER_UPDATE", UpdateAll)
UI:RegisterEvent("PARTY_LEADER_CHANGED", UpdateAll)
UI:RegisterEvent("PARTY_LOOT_METHOD_CHANGED", UpdateAll)
UI:RegisterEvent("PLAYER_ROLES_ASSIGNED", UpdateAll)
UI:RegisterEvent("ROLE_CHANGED_INFORM", UpdateAll)
UI:RegisterEvent("RAID_TARGET_UPDATE", UpdateAll)

UI:RegisterEvent("READY_CHECK", BeginReadyCheck)
UI:RegisterEvent("READY_CHECK_CONFIRM", ConfirmReadyCheck)
UI:RegisterEvent("READY_CHECK_FINISHED", FinishReadyCheck)
UI:RegisterEvent(
    "INCOMING_RESURRECT_CHANGED",
    RefreshCenterIndicatorsForUnit
)
UI:RegisterEvent(
    "INCOMING_SUMMON_CHANGED",
    RefreshCenterIndicatorsForUnit
)

UI:RegisterEvent("UNIT_FLAGS", UpdateUnit)
UI:RegisterEvent("UNIT_CONNECTION", UpdateUnit)
UI:RegisterEvent("UNIT_NAME_UPDATE", UpdateUnit)
UI:RegisterEvent("UNIT_HEAL_PREDICTION", UpdateUnit)
UI:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED", UpdateUnit)
UI:RegisterEvent("UNIT_POWER_UPDATE", UpdateUnit)
UI:RegisterEvent("PLAYER_TARGET_CHANGED", UpdateAll)

local rangeElapsed = 0
local rangeUpdater = CreateFrame("Frame")

rangeUpdater:SetScript("OnUpdate", function(_, elapsed)
    rangeElapsed = rangeElapsed + elapsed
    if rangeElapsed < 0.20 then
        return
    end

    rangeElapsed = 0

    UF:ForEachFrame(function(frame)
        if not UnitExists(frame.unit) then
            return
        end

        local inRange, checkedRange = UnitInRange(frame.unit)

        if UI:CanAccessValue(checkedRange) and checkedRange
            and UI:CanAccessValue(inRange)
        then
            frame:SetAlpha(inRange and 1 or Styles.State.outOfRangeAlpha)
        else
            frame:SetAlpha(1)
        end
    end, "range")
end)
