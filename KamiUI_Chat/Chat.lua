local UI = KamiUI

local Module = UI:NewModule("Chat")

Module.name = "KamiUI_Chat"
Module.version = "0.1.0"

local defaults = {
    width = 420,
    height = 180,
    fontSize = 14,
    background = { 0, 0, 0, 0.85 },
    border = { 0.2, 0.2, 0.2, 1 },
}

local function StyleFrame(frame)
    if not frame then
        return
    end

    frame:SetSize(defaults.width, defaults.height)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(defaults.background))
    frame.KamiBackground = bg

    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 1,
    })
    border:SetBackdropBorderColor(unpack(defaults.border))
    frame.KamiBorder = border
end

local function StyleFont(frame)
    if not frame then
        return
    end

    local font = frame:GetFont()

    if font then
        frame:SetFont(font, defaults.fontSize)
    end
end

function Module:SetupChat()
    for index = 1, NUM_CHAT_WINDOWS do
        local chat = _G["ChatFrame" .. index]

        if chat then
            StyleFrame(chat)
            StyleFont(chat)
        end
    end

    if ChatFrameMenuButton then
        ChatFrameMenuButton:Hide()
    end

    if QuickJoinToastButton then
        QuickJoinToastButton:Hide()
    end
end

function Module:Reset()
    KamiUIDB = KamiUIDB or {}
    KamiUIDB.chat = nil

    self:SetupChat()

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

    if KamiUIDB.chat.initialized then
        return
    end

    self:SetupChat()

    KamiUIDB.chat.initialized = true
end

Module:Initialize()
