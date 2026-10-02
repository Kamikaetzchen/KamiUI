local UI = KamiUI

local Module = UI:NewModule("Chat")

Module.name = "KamiUI_Chat"
Module.version = "0.1.0"

local defaults = {
    width = 420,
    height = 180,
    inputHeight = 24,
    tabAreaHeight = 32,
    fontSize = 14,
    position = {
        x = 0,
        y = 22,
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

    if frame.Background then
        frame.Background:SetAlpha(0)
    end

    local name = frame:GetName()

    if not name then
        return
    end

    for _, suffix in ipairs(CHAT_FRAME_TEXTURES or {}) do
        local texture = _G[name .. suffix]

        if texture then
            texture:SetAlpha(0)
        end
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

        editBox:HookScript("OnShow", function()
            if Module.inputPanel then
                Module.inputPanel:Show()
            end
        end)

        editBox:HookScript("OnHide", function()
            if Module.inputPanel then
                Module.inputPanel:Hide()
            end
        end)
    end

    if editBox:IsShown() and Module.inputPanel then
        Module.inputPanel:Show()
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

local function PositionPrimaryFrame()
    if not ChatFrame1 then
        return
    end

    ChatFrame1:ClearAllPoints()
    ChatFrame1:SetPoint(
        "BOTTOMLEFT",
        UIParent,
        "BOTTOMLEFT",
        defaults.position.x,
        GetPositionY()
    )
    ChatFrame1:SetSize(defaults.width, defaults.height)
end

local function PositionDock()
    if not GeneralDockManager or not ChatFrame1 then
        return
    end

    GeneralDockManager:ClearAllPoints()
    GeneralDockManager:SetHeight(defaults.tabAreaHeight)
    GeneralDockManager:SetPoint(
        "BOTTOMLEFT",
        ChatFrame1,
        "TOPLEFT",
        0,
        0
    )
    GeneralDockManager:SetPoint(
        "BOTTOMRIGHT",
        ChatFrame1,
        "TOPRIGHT",
        0,
        0
    )
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

function Module:SetupTabs()
    self.guildFrame = EnsureWindow(managedWindows[1])
    self.partyFrame = EnsureWindow(managedWindows[2])
    self.whisperFrame = EnsureWindow(managedWindows[3])

    if ChatFrame1 and ChatFrame1.isDocked then
        FCF_SelectDockFrame(ChatFrame1)
    end
end

function Module:ApplyLayout()
    EnsurePanels()
    PositionPanels()
    PositionPrimaryFrame()
    PositionDock()
    HideGlobalButtons()

    for index = 1, NUM_CHAT_WINDOWS do
        StyleFrame(_G["ChatFrame" .. index])
    end
end

function Module:Apply()
    self:SetupTabs()
    self:ApplyLayout()
end

function Module:Reset()
    KamiUIDB = KamiUIDB or {}
    KamiUIDB.chat = {}

    self:Apply()

    KamiUIDB.chat.initialized = true

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

    self:Apply()

    KamiUIDB.chat.initialized = true

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0, function()
            Module:Apply()
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

    if FCFDock_SetPrimary then
        hooksecurefunc("FCFDock_SetPrimary", function(dock, frame)
            if dock == GENERAL_CHAT_DOCK and frame == ChatFrame1 then
                C_Timer.After(0, PositionDock)
            end
        end)
    end
end

Module:Initialize()
