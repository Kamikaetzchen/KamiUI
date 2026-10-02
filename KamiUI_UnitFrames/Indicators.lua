local UI = KamiUI
local UF = UI:GetModule("UnitFrames")

local STATUS_ICON_SIZE = 12
local STATUS_ICON_GAP = 2
local STATUS_ALPHA = 0.75
local OUT_OF_RANGE_ALPHA = 0.45

local RAID_MARKER_COORDS = {
    [1] = { 0.00, 0.25, 0.00, 0.25 },
    [2] = { 0.25, 0.50, 0.00, 0.25 },
    [3] = { 0.50, 0.75, 0.00, 0.25 },
    [4] = { 0.75, 1.00, 0.00, 0.25 },
    [5] = { 0.00, 0.25, 0.25, 0.50 },
    [6] = { 0.25, 0.50, 0.25, 0.50 },
    [7] = { 0.50, 0.75, 0.25, 0.50 },
    [8] = { 0.75, 1.00, 0.25, 0.50 },
}

local frames = {
    UF.playerFrame,
    UF.targetFrame,
    UF.targetTargetFrame,
    UF.targetTargetTargetFrame,
    UF.focusFrame,
    UF.focusTargetFrame,
    UF.petFrame,
    UF.petTargetFrame,
}

local function IsTruthy(value)
    return UF:CanAccessValue(value) and value and true or false
end

local function CreateIcon(parent)
    local icon = parent:CreateTexture(nil, "OVERLAY")
    icon:SetSize(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
    icon:SetAlpha(STATUS_ALPHA)
    icon:Hide()
    return icon
end

local function CreateCenterIndicators(frame)
    local row = CreateFrame("Frame", nil, frame)
    row:SetSize(90, STATUS_ICON_SIZE)

    if frame.portrait and frame.health then
        row:SetPoint("CENTER", frame.health, "BOTTOM", 0, -2)
    else
        row:SetPoint("CENTER", frame, "CENTER", 0, 0)
    end

    row.icons = {
        raid = CreateIcon(row),
        ready = CreateIcon(row),
        resurrect = CreateIcon(row),
        summon = CreateIcon(row),
        offline = CreateIcon(row),
        ghost = CreateIcon(row),
    }

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
            table.insert(visible, icon)
        end
    end

    local count = #visible
    if count == 0 then
        return
    end

    local totalWidth =
        count * STATUS_ICON_SIZE + (count - 1) * STATUS_ICON_GAP
    local x = -totalWidth / 2

    for _, icon in ipairs(visible) do
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", row, "CENTER", x, 0)
        x = x + STATUS_ICON_SIZE + STATUS_ICON_GAP
    end
end

local function UpdateRaidMarker(frame)
    local icon = frame.centerIndicators.icons.raid
    local index = GetRaidTargetIndex and GetRaidTargetIndex(frame.unit)

    if UF:CanAccessValue(index) and index and RAID_MARKER_COORDS[index] then
        icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        icon:SetTexCoord(unpack(RAID_MARKER_COORDS[index]))
        icon:Show()
    else
        icon:Hide()
    end
end

local function UpdateReadyCheck(frame)
    local icon = frame.centerIndicators.icons.ready
    local status = GetReadyCheckStatus and GetReadyCheckStatus(frame.unit)

    if not UF:CanAccessValue(status) then
        icon:Hide()
        return
    end

    if status == "ready" then
        icon:SetTexture(
            READY_CHECK_READY_TEXTURE
                or "Interface\\RaidFrame\\ReadyCheck-Ready"
        )
        icon:SetTexCoord(0, 1, 0, 1)
        icon:Show()
    elseif status == "notready" then
        icon:SetTexture(
            READY_CHECK_NOT_READY_TEXTURE
                or "Interface\\RaidFrame\\ReadyCheck-NotReady"
        )
        icon:SetTexCoord(0, 1, 0, 1)
        icon:Show()
    elseif status == "waiting" then
        icon:SetTexture(
            READY_CHECK_WAITING_TEXTURE
                or "Interface\\RaidFrame\\ReadyCheck-Waiting"
        )
        icon:SetTexCoord(0, 1, 0, 1)
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
        icon:SetTexture("Interface\\RaidFrame\\Raid-Icon-Rez")
        icon:SetTexCoord(0, 1, 0, 1)
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

    if IsTruthy(incoming) then
        local status = C_IncomingSummon.IncomingSummonStatus
            and C_IncomingSummon.IncomingSummonStatus(frame.unit)

        if status == 2 then
            icon:SetTexture("Interface\\RaidFrame\\Raid-Icon-SummonAccepted")
        elseif status == 3 then
            icon:SetTexture("Interface\\RaidFrame\\Raid-Icon-SummonDeclined")
        else
            icon:SetTexture("Interface\\RaidFrame\\Raid-Icon-SummonPending")
        end

        icon:SetTexCoord(0, 1, 0, 1)
        icon:Show()
    else
        icon:Hide()
    end
end

local function UpdateConnection(frame)
    local offlineIcon = frame.centerIndicators.icons.offline
    local ghostIcon = frame.centerIndicators.icons.ghost

    local connected = UnitIsConnected and UnitIsConnected(frame.unit)
    if UF:CanAccessValue(connected) and connected == false then
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
    if not UF:CanAccessValue(method) or method ~= 2 then
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
    if not frame.portrait or not UnitExists(frame.unit) then
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

    if UF:CanAccessValue(role)
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
    if frame.nameText and UnitExists(frame.unit) then
        frame.nameText:SetText(UF:GetUnitDisplayName(frame.unit))
    end
end

local function CreateHealPrediction(frame)
    if not frame.health
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
    if not UF:CanAccessValue(points) then
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
    for _, frame in ipairs(frames) do
        if frame then
            UpdateFrame(frame)
        end
    end

    UpdateComboPoints()
end

local function UpdateUnit(_, unit)
    if not unit then
        UpdateAll()
        return
    end

    for _, frame in ipairs(frames) do
        if frame and frame.unit == unit then
            UpdateFrame(frame)
        end
    end

    if unit == "target" or unit == "player" then
        UpdateComboPoints()
    end
end

for _, frame in ipairs(frames) do
    if frame then
        CreateCenterIndicators(frame)
        CreatePortraitIndicators(frame)
        CreateHealPrediction(frame)
    end
end

CreateComboPoints()
UpdateAll()

UI:RegisterEvent("PLAYER_ENTERING_WORLD", UpdateAll)
UI:RegisterEvent("GROUP_ROSTER_UPDATE", UpdateAll)
UI:RegisterEvent("PARTY_LEADER_CHANGED", UpdateAll)
UI:RegisterEvent("PARTY_LOOT_METHOD_CHANGED", UpdateAll)
UI:RegisterEvent("PLAYER_ROLES_ASSIGNED", UpdateAll)
UI:RegisterEvent("ROLE_CHANGED_INFORM", UpdateAll)
UI:RegisterEvent("RAID_TARGET_UPDATE", UpdateAll)

UI:RegisterEvent("READY_CHECK", UpdateAll)
UI:RegisterEvent("READY_CHECK_CONFIRM", UpdateAll)
UI:RegisterEvent("READY_CHECK_FINISHED", UpdateAll)
UI:RegisterEvent("INCOMING_RESURRECT_CHANGED", UpdateAll)
UI:RegisterEvent("INCOMING_SUMMON_CHANGED", UpdateAll)

UI:RegisterEvent("UNIT_FLAGS", UpdateUnit)
UI:RegisterEvent("UNIT_CONNECTION", UpdateUnit)
UI:RegisterEvent("UNIT_NAME_UPDATE", UpdateUnit)
UI:RegisterEvent("UNIT_HEAL_PREDICTION", UpdateUnit)
UI:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED", UpdateUnit)
UI:RegisterEvent("UNIT_COMBO_POINTS", UpdateAll)
UI:RegisterEvent("PLAYER_TARGET_CHANGED", UpdateAll)

local rangeElapsed = 0
local rangeUpdater = CreateFrame("Frame")

rangeUpdater:SetScript("OnUpdate", function(_, elapsed)
    rangeElapsed = rangeElapsed + elapsed
    if rangeElapsed < 0.20 then
        return
    end

    rangeElapsed = 0

    for _, frame in ipairs(frames) do
        if frame and UnitExists(frame.unit) then
            local inRange, checkedRange = UnitInRange(frame.unit)

            if UF:CanAccessValue(checkedRange) and checkedRange
                and UF:CanAccessValue(inRange)
            then
                frame:SetAlpha(inRange and 1 or OUT_OF_RANGE_ALPHA)
            else
                frame:SetAlpha(1)
            end
        end
    end
end)
