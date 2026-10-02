local UI = KamiUI

local Module = UI:NewModule("Bags")

Module.name = "KamiUI_Bags"
Module.version = "0.1.0"

local defaults = {
    background = { 0, 0, 0, 0.92 },
    border = { 0.2, 0.2, 0.2, 1 },
}

local function EnsureDatabase()
    KamiUIDB = KamiUIDB or {}
    KamiUIDB.bags = KamiUIDB.bags or {}

    return KamiUIDB.bags
end

local function EnableCombinedBags()
    if not GetCVar or not SetCVar then
        return
    end

    local ok, value = pcall(GetCVar, "combinedBags")

    if ok and value ~= nil and value ~= "" and value ~= "1" then
        SetCVar("combinedBags", "1")
    end
end

local function CreateBackdrop(frame)
    if frame.KamiBackdrop then
        return
    end

    local backdrop = CreateFrame(
        "Frame",
        nil,
        frame,
        "BackdropTemplate"
    )
    backdrop:SetAllPoints()
    backdrop:SetFrameLevel(frame:GetFrameLevel())
    backdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    backdrop:SetBackdropColor(unpack(defaults.background))
    backdrop:SetBackdropBorderColor(unpack(defaults.border))
    backdrop:EnableMouse(false)

    frame.KamiBackdrop = backdrop
end

local function StripBlizzardChrome(frame)
    if frame.NineSlice then
        frame.NineSlice:SetAlpha(0)
    end

    if frame.Bg then
        frame.Bg:SetAlpha(0)
    end

    if frame.PortraitContainer then
        frame.PortraitContainer:SetAlpha(0)
    end

    if frame.MoneyFrame and frame.MoneyFrame.Border then
        frame.MoneyFrame.Border:SetAlpha(0)
    end

    if frame.TitleContainer and frame.TitleContainer.TitleText then
        frame.TitleContainer.TitleText:SetTextColor(1, 1, 1)
    end
end

local function StyleBagMenuButton(frame)
    local button = frame.PortraitButton

    if not button then
        return
    end

    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -2)
    button:SetSize(22, 18)

    if button.Highlight then
        button.Highlight:SetAlpha(0)
    end

    if not button.KamiLabel then
        local label = button:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontNormalSmall"
        )
        label:SetPoint("CENTER", 0, 2)
        label:SetText("...")
        label:SetTextColor(0.75, 0.75, 0.75)

        button.KamiLabel = label
    end
end

local function ApplySavedPosition(frame)
    local db = EnsureDatabase()
    local position = db.position

    if not position then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(
        "CENTER",
        UIParent,
        "CENTER",
        position.x or 0,
        position.y or 0
    )
end

local function SavePosition(frame)
    local frameX, frameY = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()

    if not frameX or not frameY or not parentX or not parentY then
        return
    end

    local db = EnsureDatabase()

    db.position = {
        x = frameX - parentX,
        y = frameY - parentY,
    }

    ApplySavedPosition(frame)
end

local function SetupDragging(frame)
    if frame.KamiDraggingInitialized then
        return
    end

    frame.KamiDraggingInitialized = true
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    local dragHandle = frame.TitleContainer or frame
    dragHandle:EnableMouse(true)

    if frame.TitleContainer then
        frame.TitleContainer:ClearAllPoints()
        frame.TitleContainer:SetPoint(
            "TOPLEFT",
            frame,
            "TOPLEFT",
            30,
            -1
        )
        frame.TitleContainer:SetPoint(
            "TOPRIGHT",
            frame,
            "TOPRIGHT",
            -28,
            -1
        )
    end

    dragHandle:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            frame:StartMoving()
        end
    end)

    dragHandle:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" then
            return
        end

        frame:StopMovingOrSizing()
        frame:SetUserPlaced(true)
        SavePosition(frame)
    end)
end

local function StyleCombinedBags(frame)
    CreateBackdrop(frame)
    StripBlizzardChrome(frame)
    StyleBagMenuButton(frame)
    SetupDragging(frame)
end

function Module:Apply()
    EnableCombinedBags()

    local frame = ContainerFrameCombinedBags

    if not frame then
        return false
    end

    StyleCombinedBags(frame)
    ApplySavedPosition(frame)

    if not frame.KamiShowHook then
        frame.KamiShowHook = true

        frame:HookScript("OnShow", function(self)
            StyleCombinedBags(self)
            ApplySavedPosition(self)
        end)
    end

    return true
end

function Module:ResetPosition()
    local db = EnsureDatabase()
    db.position = nil

    local frame = ContainerFrameCombinedBags

    if frame then
        frame:SetUserPlaced(false)

        if UpdateContainerFrameAnchors then
            UpdateContainerFrameAnchors()
        end
    end

    UI:Print("Bag position reset")
end

UI:RegisterCommand(
    "bags",
    "reset",
    function()
        Module:ResetPosition()
    end,
    "Reset bag position"
)

function Module:Initialize()
    EnsureDatabase()
    EnableCombinedBags()
    self:Apply()

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0, function()
            Module:Apply()
        end)
    end)

    UI:RegisterEvent("ADDON_LOADED", function()
        if not Module.frameReady then
            Module.frameReady = Module:Apply()
        end
    end)

    if UpdateContainerFrameAnchors then
        hooksecurefunc("UpdateContainerFrameAnchors", function()
            local frame = ContainerFrameCombinedBags

            if frame and EnsureDatabase().position then
                C_Timer.After(0, function()
                    ApplySavedPosition(frame)
                end)
            end
        end)
    end
end

Module:Initialize()
