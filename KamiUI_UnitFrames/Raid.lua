local UI = KamiUI
local UF = UI:GetModule("UnitFrames")

local Layout = UI.Layout.UnitFrames.Raid

local frames = {}
local framesByUnit = {}
local layoutPending = false

local blockWidth =
    Layout.GROUP_COUNT * Layout.FRAME_WIDTH
    + (Layout.GROUP_COUNT - 1) * Layout.GROUP_SPACING
local blockHeight =
    Layout.GROUP_SIZE * Layout.FRAME_HEIGHT
    + (Layout.GROUP_SIZE - 1) * Layout.MEMBER_SPACING

local anchor = CreateFrame("Frame", "KamiUIRaidFrameAnchor", UIParent)
anchor:SetSize(blockWidth, blockHeight)

local partyAnchor = UF.partyFrames
    and UF.partyFrames[1]
    and UF.partyFrames[1].main

if partyAnchor then
    anchor:SetPoint(
        "BOTTOMLEFT",
        partyAnchor,
        "TOPLEFT",
        Layout.LEFT_OFFSET,
        Layout.PARTY_GAP
    )
else
    anchor:SetPoint("BOTTOMLEFT", UIParent, "LEFT", Layout.LEFT_OFFSET, 190)
end

local function CreateAuraSlot(parent)
    local slot = CreateFrame("Frame", nil, parent)
    slot:SetSize(Layout.AURA_SIZE, Layout.AURA_SIZE)
    slot:SetFrameLevel(parent:GetFrameLevel() + 10)
    slot:EnableMouse(false)

    local border = slot:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0, 0, 0, 1)

    local icon = slot:CreateTexture(nil, "OVERLAY")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    slot.icon = icon
    slot:Hide()

    return slot
end

local function CreateAuraSlots(frame)
    frame.raidBuffs = {}
    frame.raidDebuffs = {}

    for index = 1, Layout.MAX_BUFFS do
        local slot = CreateAuraSlot(frame.health)
        slot:SetPoint(
            "TOPLEFT",
            frame.health,
            "TOPLEFT",
            (index - 1) * Layout.AURA_SIZE,
            0
        )
        frame.raidBuffs[index] = slot
    end

    for index = 1, Layout.MAX_DEBUFFS do
        local slot = CreateAuraSlot(frame.health)
        slot:SetPoint(
            "TOPRIGHT",
            frame.health,
            "TOPRIGHT",
            -(index - 1) * Layout.AURA_SIZE,
            0
        )
        frame.raidDebuffs[index] = slot
    end
end

local function ClearAuraSlots(slots)
    for _, slot in ipairs(slots) do
        slot.icon:SetTexture(nil)
        slot:Hide()
    end
end

local function IsPlayerAura(auraData)
    local sourceUnit = auraData and auraData.sourceUnit

    if not sourceUnit then
        return false
    end

    if sourceUnit == "player" then
        return true
    end

    if not UnitIsUnit then
        return false
    end

    local isPlayer = UnitIsUnit(sourceUnit, "player")

    return UI:CanAccessValue(isPlayer) and isPlayer or false
end

local function ForEachAura(unit, filter, callback)
    if AuraUtil and AuraUtil.ForEachAura then
        AuraUtil.ForEachAura(unit, filter, nil, callback, true)
        return
    end

    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then
        return
    end

    for index = 1, 40 do
        local auraData = C_UnitAuras.GetAuraDataByIndex(
            unit,
            index,
            filter
        )

        if not auraData or callback(auraData) then
            return
        end
    end
end

local function FillAuraSlots(frame, slots, filter, playerOnly)
    ClearAuraSlots(slots)

    if not UnitExists(frame.unit) then
        return
    end

    local shown = 0

    ForEachAura(frame.unit, filter, function(auraData)
        if playerOnly and not IsPlayerAura(auraData) then
            return false
        end

        if not auraData or not auraData.icon then
            return false
        end

        shown = shown + 1

        local slot = slots[shown]
        slot.icon:SetTexture(auraData.icon)
        slot:Show()

        return shown >= #slots
    end)
end

local function UpdateAuras(frame)
    FillAuraSlots(frame, frame.raidBuffs, "HELPFUL", true)
    FillAuraSlots(frame, frame.raidDebuffs, "HARMFUL", false)
end

local function CreateRaidMember(index)
    local unit = "raid" .. index

    local frame = UF:CreateRaidFrame({
        name = "KamiUIRaid" .. index .. "Frame",
        unit = unit,
        width = Layout.FRAME_WIDTH,
        height = Layout.FRAME_HEIGHT,
        healthHeight = Layout.HEALTH_HEIGHT,
        powerHeight = Layout.POWER_HEIGHT,
        features = {
            indicators = true,
            healPrediction = true,
            range = true,
        },
    })

    CreateAuraSlots(frame)

    frames[index] = frame
    framesByUnit[unit] = frame

    return frame
end

for index = 1, Layout.GROUP_COUNT * Layout.GROUP_SIZE do
    CreateRaidMember(index)
end

local function GetLayoutPosition(index, groupCounts)
    local subgroup

    if GetRaidRosterInfo then
        subgroup = select(3, GetRaidRosterInfo(index))
    end

    if subgroup
        and UI:CanAccessValue(subgroup)
        and subgroup >= 1
        and subgroup <= Layout.GROUP_COUNT
    then
        groupCounts[subgroup] = (groupCounts[subgroup] or 0) + 1

        return subgroup, groupCounts[subgroup]
    end

    return math.floor((index - 1) / Layout.GROUP_SIZE) + 1,
        ((index - 1) % Layout.GROUP_SIZE) + 1
end

local function LayoutFrames()
    if InCombatLockdown and InCombatLockdown() then
        layoutPending = true
        return
    end

    layoutPending = false

    local groupCounts = {}

    for index, frame in ipairs(frames) do
        local group, slot = GetLayoutPosition(index, groupCounts)
        local x = (group - 1) * (Layout.FRAME_WIDTH + Layout.GROUP_SPACING)
        local y = -(slot - 1) * (Layout.FRAME_HEIGHT + Layout.MEMBER_SPACING)

        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, y)

        frame.raidGroup = group
        frame.raidSlot = slot
    end
end

local function UpdateAll()
    for _, frame in ipairs(frames) do
        UF:UpdateUnitFrame(frame)
        UpdateAuras(frame)
    end
end

LayoutFrames()
UpdateAll()

UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(0, function()
        LayoutFrames()
        UpdateAll()
    end)
end)

UI:RegisterEvent("GROUP_ROSTER_UPDATE", function()
    LayoutFrames()
    UpdateAll()
end)

UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if layoutPending then
        LayoutFrames()
        UpdateAll()
    end
end)

UI:RegisterEvent("UNIT_AURA", function(_, unit)
    local frame = unit and framesByUnit[unit]

    if frame then
        UpdateAuras(frame)
    end
end)

UF.raidFrames = frames
UF.raidFrameAnchor = anchor
