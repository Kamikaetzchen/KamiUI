local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles

local Module = UI:NewModule("RareAlert", "KamiUI_RareAlert")

-- Nameplates, target and mouseover are the only discovery sources.
-- UnitClassification supplies the rare status; no NPC-ID database needed.
local ALERT_SECONDS = 5
local FADE_SECONDS = 1
local MAX_QUEUED = 5

local seenGUIDs = {}
local queued = {}
local alertFrame

local function PositionAlert(frame)
    -- Anchor the top of the banner at 10% of the UI height.
    -- Recalculate when the UI dimensions or scale change.
    local height = UIParent:GetHeight() or 0
    frame:ClearAllPoints()
    frame:SetPoint("TOP", UIParent, "TOP", 0, -height * 0.10)
end

local function CreateAlertFrame()
    local frame = CreateFrame("Frame", "KamiUIRareAlertFrame",
        UIParent, "BackdropTemplate")
    frame:SetSize(390, 74)
    PositionAlert(frame)
    UIParent:HookScript("OnSizeChanged", function()
        PositionAlert(frame)
    end)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(false)
    Styles:ApplyBackdrop(frame, {0, 0, 0, 0.15},
        {0.18, 0.18, 0.18, 0.20})

    local heading = frame:CreateFontString(nil, "OVERLAY")
    heading:SetPoint("TOP", frame, "TOP", 0, -10)
    heading:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    heading:SetJustifyH("CENTER")
    heading:SetTextColor(unpack(Palette.gold))
    frame.heading = heading

    local name = frame:CreateFontString(nil, "OVERLAY")
    name:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -31)
    name:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -31)
    name:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
    name:SetJustifyH("CENTER")
    name:SetWordWrap(false)
    name:SetTextColor(unpack(Palette.text))
    frame.name = name

    frame:SetScript("OnUpdate", function(self, elapsed)
        self.remaining = (self.remaining or 0) - elapsed
        if self.remaining <= 0 then
            self:Hide()
            Module:ShowNextAlert()
        elseif self.remaining < FADE_SECONDS then
            self:SetAlpha(self.remaining / FADE_SECONDS)
        end
    end)
    frame:Hide()
    return frame
end

local function PlayAlertSound()
    local sound = SOUNDKIT
        and (SOUNDKIT.TELL_MESSAGE or SOUNDKIT.RAID_WARNING)
    if sound and PlaySound then
        PlaySound(sound, "Master")
    end
end

function Module:ShowNextAlert()
    local nextAlert = table.remove(queued, 1)
    if not nextAlert then return end

    if not alertFrame then alertFrame = CreateAlertFrame() end

    local elite = nextAlert.classification == "rareelite"
    local r, g, b
    if elite then
        r, g, b = 1, 0.32, 0.25
    else
        r, g, b = unpack(Palette.gold)
    end

    alertFrame.heading:SetText(elite and "RARE ELITE ENTDECKT"
        or "RARE ENTDECKT")
    alertFrame.heading:SetTextColor(r, g, b)
    alertFrame.name:SetText(nextAlert.name)
    alertFrame.remaining = ALERT_SECONDS
    alertFrame:SetAlpha(1)
    alertFrame:Show()
    PlayAlertSound()
end

local function QueueAlert(name, classification)
    if #queued >= MAX_QUEUED then return end

    queued[#queued + 1] = {
        name = name,
        classification = classification,
    }
    if not alertFrame or not alertFrame:IsShown() then
        Module:ShowNextAlert()
    end
end

local function CheckUnit(unit)
    if not unit or not UnitExists or not UnitClassification
        or not UnitGUID or not UnitName then
        return
    end

    local exists = UnitExists(unit)
    if not UI:CanAccessValue(exists) or not exists then return end

    local classification = UnitClassification(unit)
    if not UI:CanAccessValue(classification)
        or (classification ~= "rare" and classification ~= "rareelite") then
        return
    end

    local player = UnitIsPlayer and UnitIsPlayer(unit)
    if not UI:CanAccessValue(player) or player then return end

    local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)
    if not UI:CanAccessValue(dead) or dead then return end

    local guid = UnitGUID(unit)
    local name = UnitName(unit)
    if not guid or not name
        or not UI:CanAccessValue(guid)
        or not UI:CanAccessValue(name)
        or seenGUIDs[guid] then
        return
    end

    seenGUIDs[guid] = true
    QueueAlert(name, classification)
end

local function IsRelevantUnit(unit)
    return type(unit) == "string"
        and (unit == "target" or unit == "mouseover"
            or string.match(unit, "^nameplate%d+$") ~= nil)
end

local function CheckExistingUnits()
    CheckUnit("target")
    CheckUnit("mouseover")
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
            if plate.namePlateUnitToken then
                CheckUnit(plate.namePlateUnitToken)
            end
        end
    end
end

function Module:Initialize()
    UI:RegisterEvent("NAME_PLATE_UNIT_ADDED", function(_, unit)
        CheckUnit(unit)
        -- Some clients populate a new nameplate's GUID a frame later.
        if C_Timer and C_Timer.After then
            C_Timer.After(0.15, function()
                CheckUnit(unit)
            end)
        end
    end)

    UI:RegisterEvent("PLAYER_TARGET_CHANGED", function()
        CheckUnit("target")
    end)
    UI:RegisterEvent("UPDATE_MOUSEOVER_UNIT", function()
        CheckUnit("mouseover")
    end)
    UI:RegisterEvent("UNIT_NAME_UPDATE", function(_, unit)
        if IsRelevantUnit(unit) then CheckUnit(unit) end
    end)

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, CheckExistingUnits)
        else
            CheckExistingUnits()
        end
    end)

    UI:RegisterCommand("rarealert", "test", function()
        QueueAlert("Test Rare", "rare")
    end, "Test the rare alert banner and sound")
end

Module:Initialize()
