local UI = KamiUI

local Module = UI:NewModule("Chat")

Module.name = "KamiUI_Chat"
Module.version = "0.1.0"

local SETUP_VERSION = 1

local defaults = {
    width = 800,
    height = 250,
    inputHeight = 24,
    tabAreaHeight = 32,
    fontSize = 14,
    position = {
        x = 0,
        y = 0,
    },
    background = { 0, 0, 0, 0.85 },
    border = { 0.2, 0.2, 0.2, 1 },
}

local function GetPositionY()
    return defaults.position.y + UI:GetBottomInset()
end

local managedWindows = {
    {
        name = "Guild",
        groups = {
            "GUILD",
            "OFFICER",
        },
    },
    {
        name = "Party",
        groups = {
            "PARTY",
            "PARTY_LEADER",
            "RAID",
            "RAID_LEADER",
            "RAID_WARNING",
            "INSTANCE_CHAT",
            "INSTANCE_CHAT_LEADER",
            "BATTLEGROUND",
            "BATTLEGROUND_LEADER",
        },
    },
    {
        name = "Whisper",
        groups = {
            "WHISPER",
            "BN_WHISPER",
        },
        privateMessages = true,
    },
}

local hiddenObjects = setmetatable({}, { __mode = "k" })

local function HideObject(object)
    if not object then
        return
    end

    object:SetAlpha(0)
    object:Hide()

    if object.EnableMouse then
        object:EnableMouse(false)
    end

    if not hiddenObjects[object] and object.HookScript then
        hiddenObjects[object] = true

        object:HookScript("OnShow", function(self)
            self:SetAlpha(0)
            self:Hide()
        end)
    end
end

local function CreatePanel(name, height, y)
    local panel = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    panel:SetFrameStrata("BACKGROUND")
    panel:SetSize(defaults.width, height)
    panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", defaults.position.x, y)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(unpack(defaults.background))
    panel:SetBackdropBorderColor(unpack(defaults.border))
    panel:EnableMouse(false)

    return panel
end

local function EnsurePanels()
    if not Module.chatPanel then
        Module.chatPanel = CreatePanel(
            "KamiUIChatPanel",
            defaults.height,
            GetPositionY()
        )
    end

    if not Module.inputPanel then
        Module.inputPanel = CreatePanel(
            "KamiUIChatInputPanel",
            defaults.inputHeight,
            GetPositionY() + defaults.height + defaults.tabAreaHeight
        )
        Module.inputPanel:Hide()
    end
end

local function PositionPanels()
    local y = GetPositionY()

    if Module.chatPanel then
        Module.chatPanel:SetSize(defaults.width, defaults.height)
        Module.chatPanel:ClearAllPoints()
        Module.chatPanel:SetPoint(
            "BOTTOMLEFT",
            UIParent,
            "BOTTOMLEFT",
            defaults.position.x,
            y
        )
    end

    if Module.inputPanel then
        Module.inputPanel:SetSize(defaults.width, defaults.inputHeight)
        Module.inputPanel:ClearAllPoints()
        Module.inputPanel:SetPoint(
            "BOTTOMLEFT",
            UIParent,
            "BOTTOMLEFT",
            defaults.position.x,
            y + defaults.height + defaults.tabAreaHeight
        )
    end
end

local function HideFrameTextures(frame)
    if not frame then
        return
    end

    -- Do not merely set these to alpha 0. Blizzard's FCF_FadeInChatFrame()
    -- animates the stock chat chrome back to DEFAULT_CHATFRAME_ALPHA whenever
    -- the mouse enters the chat. Hidden regions are skipped by that code.
    HideObject(frame.Background)

    local name = frame:GetName()

    if not name then
        return
    end

    for _, suffix in ipairs(CHAT_FRAME_TEXTURES or {}) do
        HideObject(_G[name .. suffix])
    end
end

local function HideFrameButtons(frame)
    if not frame then
        return
    end

    local name = frame:GetName()

    if name then
        HideObject(_G[name .. "ButtonFrame"])
    end

    -- The scrollbar is also faded back in by Blizzard on hover. We do not use
    -- any of the stock chat controls, so keep the whole lot permanently hidden.
    HideObject(frame.ScrollBar)
    HideObject(frame.ScrollToBottomButton)
    HideObject(frame.ResizeButton)
end

local function StyleFont(frame)
    if not frame or not frame.GetFont then
        return
    end

    local font, _, flags = frame:GetFont()

    if font then
        frame:SetFont(font, defaults.fontSize, flags)
    end
end

local function StyleEditBox(frame)
    if not frame then
        return
    end

    local editBox = frame.editBox or _G[frame:GetName() .. "EditBox"]

    if not editBox then
        return
    end

    editBox:ClearAllPoints()
    editBox:SetPoint(
        "BOTTOMLEFT",
        UIParent,
        "BOTTOMLEFT",
        defaults.position.x,
        GetPositionY() + defaults.height + defaults.tabAreaHeight
    )
    editBox:SetPoint(
        "BOTTOMRIGHT",
        UIParent,
        "BOTTOMLEFT",
        defaults.position.x + defaults.width,
        GetPositionY() + defaults.height + defaults.tabAreaHeight
    )
    editBox:SetHeight(defaults.inputHeight)

    if not editBox.KamiInputPanelHooked then
        editBox.KamiInputPanelHooked = true

        editBox:HookScript("OnEditFocusGained", function()
            if Module.inputPanel then
                Module.inputPanel:Show()
            end
        end)

        editBox:HookScript("OnEditFocusLost", function()
            C_Timer.After(0, function()
                if not Module.inputPanel then
                    return
                end

                for index = 1, NUM_CHAT_WINDOWS do
                    local chatFrame = _G["ChatFrame" .. index]
                    local otherEditBox = chatFrame and chatFrame.editBox

                    if otherEditBox
                        and otherEditBox.HasFocus
                        and otherEditBox:HasFocus()
                    then
                        return
                    end
                end

                Module.inputPanel:Hide()
            end)
        end)
    end

    local editName = editBox:GetName()

    if editName then
        for _, suffix in ipairs({
            "Left",
            "Right",
            "Mid",
            "FocusLeft",
            "FocusRight",
            "FocusMid",
        }) do
            local texture = _G[editName .. suffix]

            if texture then
                texture:SetAlpha(0)
            end
        end
    end

    local font, _, flags = editBox:GetFont()

    if font then
        editBox:SetFont(font, defaults.fontSize, flags)
    end

    if editBox.header then
        local headerFont, _, headerFlags = editBox.header:GetFont()

        if headerFont then
            editBox.header:SetFont(headerFont, defaults.fontSize, headerFlags)
        end
    end

    if editBox.headerSuffix then
        local suffixFont, _, suffixFlags = editBox.headerSuffix:GetFont()

        if suffixFont then
            editBox.headerSuffix:SetFont(
                suffixFont,
                defaults.fontSize,
                suffixFlags
            )
        end
    end
end

local function StyleFrame(frame)
    if not frame then
        return
    end

    frame:SetSize(defaults.width, defaults.height)
    frame:SetFading(false)

    HideFrameTextures(frame)
    HideFrameButtons(frame)
    StyleFont(frame)
    StyleEditBox(frame)
end

local function StyleTab(frame)
    if not frame then
        return
    end

    local tab = _G[frame:GetName() .. "Tab"]

    if not tab then
        return
    end

    if not tab.KamiUIStyled then
        tab.KamiUIStyled = true

        for _, key in ipairs({
            "Left",
            "Middle",
            "Right",
            "ActiveLeft",
            "ActiveMiddle",
            "ActiveRight",
            "HighlightLeft",
            "HighlightMiddle",
            "HighlightRight",
            "glow",
        }) do
            local texture = tab[key]

            if texture then
                texture:SetAlpha(0)
            end
        end

        local flash = _G[tab:GetName() .. "Flash"]

        if flash then
            flash:SetAlpha(0)
        end

        local background = tab:CreateTexture(nil, "BACKGROUND")
        background:SetPoint("TOPLEFT", tab, "TOPLEFT", 2, -6)
        background:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -2, 4)
        tab.KamiUIBackground = background

        local function CreateEdge(pointA, pointB, width, height)
            local edge = tab:CreateTexture(nil, "BORDER")
            edge:SetColorTexture(unpack(defaults.border))
            edge:SetPoint(pointA, background, pointA)
            edge:SetPoint(pointB, background, pointB)

            if width then
                edge:SetWidth(width)
            end

            if height then
                edge:SetHeight(height)
            end
        end

        CreateEdge("TOPLEFT", "TOPRIGHT", nil, 1)
        CreateEdge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
        CreateEdge("TOPLEFT", "BOTTOMLEFT", 1, nil)
        CreateEdge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)

        local font, _, flags = tab.Text:GetFont()

        if font then
            tab.Text:SetFont(font, defaults.fontSize - 2, flags)
        end
    end

    tab:SetAlpha(1)
end

local function UpdateTabStyles()
    local selected

    if GeneralDockManager then
        selected = FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)
    end

    for index = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. index]
        local tab = frame and _G[frame:GetName() .. "Tab"]

        if tab and tab.KamiUIBackground then
            if frame == selected then
                tab.KamiUIBackground:SetColorTexture(0.08, 0.08, 0.08, 0.95)
                tab.Text:SetTextColor(1, 1, 1)
            else
                tab.KamiUIBackground:SetColorTexture(0.02, 0.02, 0.02, 0.80)
                tab.Text:SetTextColor(0.72, 0.72, 0.72)
            end

            tab:SetAlpha(1)
        end
    end
end

local function DetachPrimaryFrame()
    if not ChatFrame1 then
        return
    end

    -- ChatFrame1 is the only Edit Mode managed chat frame. Detach it once and
    -- let PositionMessageFrames own the geometry for every docked tab equally.
    if ChatFrame1.BreakFromFrameManager then
        ChatFrame1:BreakFromFrameManager()
    end

    ChatFrame1.ignoreFramePositionManager = true
    ChatFrame1:SetUserPlaced(true)
end

local positioningMessageFrames = false

local function PositionMessageFrames()
    if not GeneralDockManager or not Module.chatPanel or positioningMessageFrames then
        return
    end

    positioningMessageFrames = true

    for _, frame in ipairs(FCFDock_GetChatFrames(GENERAL_CHAT_DOCK)) do
        local topInset = 4

        if frame == ChatFrame2 and _G.CombatLogQuickButtonFrame_Custom then
            topInset = _G.CombatLogQuickButtonFrame_Custom:GetHeight() + 4
        end

        frame:ClearAllPoints()
        frame:SetPoint(
            "TOPLEFT",
            Module.chatPanel,
            "TOPLEFT",
            4,
            -topInset
        )
        frame:SetPoint(
            "BOTTOMRIGHT",
            Module.chatPanel,
            "BOTTOMRIGHT",
            -4,
            4
        )
    end

    positioningMessageFrames = false
end

local positioningDock = false

local function PositionDock()
    if not GeneralDockManager or not Module.chatPanel or positioningDock then
        return
    end

    positioningDock = true

    -- Anchor the dock to our panel instead of ChatFrame1. Blizzard's default
    -- ChatFrame1 position carries a 32 px left offset, which otherwise also
    -- drags the two static tabs (General and Combat Log) to the right.
    GeneralDockManager:ClearAllPoints()
    GeneralDockManager:SetHeight(defaults.tabAreaHeight)
    GeneralDockManager:SetPoint(
        "BOTTOMLEFT",
        Module.chatPanel,
        "TOPLEFT",
        0,
        0
    )
    GeneralDockManager:SetPoint(
        "BOTTOMRIGHT",
        Module.chatPanel,
        "TOPRIGHT",
        0,
        0
    )

    positioningDock = false
end

local positioningCombatLogBar = false

local function PositionCombatLogBar()
    local bar = _G.CombatLogQuickButtonFrame_Custom

    if not bar or not Module.chatPanel or positioningCombatLogBar then
        return
    end

    positioningCombatLogBar = true
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", Module.chatPanel, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", Module.chatPanel, "TOPRIGHT", 0, 0)
    positioningCombatLogBar = false
end

local function HideGlobalButtons()
    HideObject(ChatFrameMenuButton)
    HideObject(ChatFrameChannelButton)
    HideObject(TextToSpeechButton)
    HideObject(QuickJoinToastButton)
end

local function FindChatWindow(name)
    for index = 3, NUM_CHAT_WINDOWS do
        local windowName = FCF_GetChatWindowInfo(index)

        if windowName == name then
            return _G["ChatFrame" .. index]
        end
    end
end

local function RemoveAllMessageGroups(frame)
    if frame.RemoveAllMessageGroups then
        frame:RemoveAllMessageGroups()
    else
        ChatFrame_RemoveAllMessageGroups(frame)
    end
end

local function RemoveAllChannels(frame)
    if frame.RemoveAllChannels then
        frame:RemoveAllChannels()
    else
        ChatFrame_RemoveAllChannels(frame)
    end
end

local function AddMessageGroup(frame, group)
    if ChatTypeGroup and not ChatTypeGroup[group] then
        return
    end

    if frame.AddMessageGroup then
        frame:AddMessageGroup(group)
    else
        ChatFrame_AddMessageGroup(frame, group)
    end
end

local function ConfigureWindow(frame, config)
    RemoveAllMessageGroups(frame)
    RemoveAllChannels(frame)

    for _, group in ipairs(config.groups) do
        AddMessageGroup(frame, group)
    end

    if config.privateMessages and frame.ReceiveAllPrivateMessages then
        frame:ReceiveAllPrivateMessages()
    elseif config.privateMessages and ChatFrame_ReceiveAllPrivateMessages then
        ChatFrame_ReceiveAllPrivateMessages(frame)
    end

    if not frame.isDocked then
        FCF_DockFrame(
            frame,
            #FCFDock_GetChatFrames(GENERAL_CHAT_DOCK) + 1,
            false
        )
    end

    FCF_SetLocked(frame, true)

    local tab = _G[frame:GetName() .. "Tab"]

    if tab then
        tab:Show()
    end
end

local function EnsureWindow(config)
    local frame = FindChatWindow(config.name)

    if not frame then
        frame = FCF_OpenNewWindow(config.name, true)
    end

    if not frame then
        return
    end

    ConfigureWindow(frame, config)

    return frame
end

local function EnsureCombatWindow()
    if not ChatFrame2 then
        return
    end

    FCF_SetWindowName(ChatFrame2, "Combat")

    if not ChatFrame2.isDocked then
        FCF_DockFrame(ChatFrame2, 2, false)
    end

    FCF_SetLocked(ChatFrame2, true)

    local tab = _G[ChatFrame2:GetName() .. "Tab"]

    if tab then
        tab:Show()
    end

    return ChatFrame2
end

function Module:SetupTabs()
    self.combatFrame = EnsureCombatWindow()
    self.guildFrame = EnsureWindow(managedWindows[1])
    self.partyFrame = EnsureWindow(managedWindows[2])
    self.whisperFrame = EnsureWindow(managedWindows[3])
end

function Module:FindTabs()
    self.combatFrame = ChatFrame2
    self.guildFrame = FindChatWindow(managedWindows[1].name)
    self.partyFrame = FindChatWindow(managedWindows[2].name)
    self.whisperFrame = FindChatWindow(managedWindows[3].name)
end

function Module:ApplyLayout()
    EnsurePanels()
    PositionPanels()
    DetachPrimaryFrame()
    PositionDock()
    PositionCombatLogBar()
    HideGlobalButtons()

    for index = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. index]

        StyleFrame(frame)
        StyleTab(frame)
    end

    PositionMessageFrames()
    UpdateTabStyles()
end

function Module:Apply()
    self:FindTabs()
    self:ApplyLayout()
end

function Module:Reset()
    KamiUIDB = KamiUIDB or {}
    KamiUIDB.chat = {}

    self:SetupTabs()
    self:ApplyLayout()

    KamiUIDB.chat.initialized = true
    KamiUIDB.chat.setupVersion = SETUP_VERSION

    UI:Print("Chat reset")
end

UI:RegisterCommand(
    "chat",
    "reset",
    function()
        Module:Reset()
    end,
    "Reset chat configuration"
)

function Module:Initialize()
    KamiUIDB = KamiUIDB or {}
    KamiUIDB.chat = KamiUIDB.chat or {}

    if (KamiUIDB.chat.setupVersion or 0) < SETUP_VERSION then
        self:SetupTabs()
        KamiUIDB.chat.initialized = true
        KamiUIDB.chat.setupVersion = SETUP_VERSION
    else
        self:FindTabs()
    end

    self:ApplyLayout()

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0, function()
            Module:ApplyLayout()
        end)
    end)

    UI:RegisterBottomInsetCallback(function()
        Module:ApplyLayout()
    end)

    UI:RegisterEvent("UPDATE_CHAT_WINDOWS", function()
        C_Timer.After(0, function()
            Module:ApplyLayout()
        end)
    end)

    UI:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS", function()
        C_Timer.After(0, function()
            Module:ApplyLayout()
        end)
    end)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_CombatLog" then
            C_Timer.After(0, function()
                PositionCombatLogBar()
                PositionMessageFrames()

                local bar = _G.CombatLogQuickButtonFrame_Custom

                if bar and not bar.KamiUIPositionHooked then
                    bar.KamiUIPositionHooked = true
                    hooksecurefunc(bar, "SetPoint", PositionCombatLogBar)
                end

                if ChatFrame2 and not ChatFrame2.KamiUIPositionHooked then
                    ChatFrame2.KamiUIPositionHooked = true
                    hooksecurefunc(ChatFrame2, "SetPoint", PositionMessageFrames)
                end
            end)
        end
    end)

    local combatLogBar = _G.CombatLogQuickButtonFrame_Custom

    if combatLogBar and not combatLogBar.KamiUIPositionHooked then
        combatLogBar.KamiUIPositionHooked = true
        hooksecurefunc(combatLogBar, "SetPoint", PositionCombatLogBar)
    end

    if ChatFrame2 and not ChatFrame2.KamiUIPositionHooked then
        ChatFrame2.KamiUIPositionHooked = true
        hooksecurefunc(ChatFrame2, "SetPoint", PositionMessageFrames)
    end

    -- Blizzard restores ChatFrame1 from several different paths. Reassert our
    -- anchors after every known restore path, and also after direct SetPoint
    -- calls. The positioning guards keep our own anchors from recursing.
    if FCF_RestorePositionAndDimensions then
        hooksecurefunc("FCF_RestorePositionAndDimensions", function(frame)
            if frame == ChatFrame1 then
                DetachPrimaryFrame()
                PositionDock()
                PositionMessageFrames()
            end
        end)
    end

    if ChatFrame1.ApplySystemAnchor then
        hooksecurefunc(ChatFrame1, "ApplySystemAnchor", function()
            DetachPrimaryFrame()
            PositionDock()
            PositionMessageFrames()
        end)
    end

    if EditModeManagerFrame and EditModeManagerFrame.UpdateLayoutInfo then
        hooksecurefunc(EditModeManagerFrame, "UpdateLayoutInfo", function()
            DetachPrimaryFrame()
            PositionDock()
            PositionMessageFrames()
        end)
    end

    UI:RegisterEvent("UI_SCALE_CHANGED", function()
        C_Timer.After(0, function()
            DetachPrimaryFrame()
            PositionDock()
            PositionMessageFrames()
        end)
    end)

    if FCFDock_SetPrimary then
        hooksecurefunc("FCFDock_SetPrimary", function(dock, frame)
            if dock == GENERAL_CHAT_DOCK and frame == ChatFrame1 then
                C_Timer.After(0, PositionDock)
            end
        end)
    end

    if FCFDock_UpdateTabs then
        hooksecurefunc("FCFDock_UpdateTabs", function(dock)
            if dock == GENERAL_CHAT_DOCK then
                PositionDock()
                PositionMessageFrames()
            end
        end)
    end

    if FCFTab_UpdateAlpha then
        hooksecurefunc("FCFTab_UpdateAlpha", function()
            C_Timer.After(0, UpdateTabStyles)
        end)
    end

    if FCFDock_SelectWindow then
        hooksecurefunc("FCFDock_SelectWindow", function(dock)
            if dock == GENERAL_CHAT_DOCK then
                C_Timer.After(0, function()
                    PositionMessageFrames()
                    UpdateTabStyles()
                end)
            end
        end)
    end
end

Module:Initialize()
