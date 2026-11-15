local UI = KamiUI
local Module = UI:GetModule("Quests")
if not Module then return end

local Styles = UI.Styles
local Palette = UI.Palette
local Components = UI.Components
local hooks = {}
local savedFonts = {}

local BODY_SIZE = 11
local HEADING_SIZE = 12
local LIST_SIZE = 11
local FRAME_BACKGROUND = { 0, 0, 0, 0.94 }

-- QuestInfo uses the very same FontStrings for the map and NPC
-- dialogs. Save their original appearance once and restore it after
-- both dialogs close; never leave global quest fonts modified.
local function StyleFont(font, size, color)
    if not font or not font.GetFont or not font.GetTextColor then
        return
    end
    if not savedFonts[font] then
        local path, originalSize, flags = font:GetFont()
        local r, g, b, a = font:GetTextColor()
        savedFonts[font] = {
            path, originalSize, flags, r, g, b, a,
        }
    end
    if size then
        Styles:ApplyText(font, size, color)
    else
        Styles:SetTextColor(font, color)
    end
end

local function StyleNamedFont(name, size, color)
    StyleFont(_G[name], size, color)
end

local function QuestDetailsVisible()
    return QuestMapFrame and QuestMapFrame.DetailsFrame
        and QuestMapFrame.DetailsFrame:IsShown()
end

local function NPCQuestVisible()
    return QuestFrame and QuestFrame:IsShown()
end

local function RestoreQuestFonts()
    if QuestDetailsVisible() or NPCQuestVisible() then return end
    for font, saved in pairs(savedFonts) do
        if saved[1] and saved[2] then
            font:SetFont(saved[1], saved[2], saved[3])
        end
        font:SetTextColor(saved[4], saved[5], saved[6], saved[7])
        savedFonts[font] = nil
    end
end

-- Individual quest objectives are NOT QuestInfoObjectivesText:
-- Blizzard creates QuestInfoObjective1, Objective2, ... as needed.
-- QuestInfo_Display recolors them dark for parchment on every update.
local function StyleSharedQuestText()
    if not QuestDetailsVisible() and not NPCQuestVisible() then
        return
    end

    -- Preserve the large native quest title, only recolor it.
    StyleNamedFont("QuestInfoTitleHeader", nil, Palette.gold)

    for _, name in ipairs({
        "QuestInfoDescriptionHeader",
        "QuestInfoObjectivesHeader",
    }) do
        StyleNamedFont(name, HEADING_SIZE, Palette.gold)
    end

    for _, name in ipairs({
        "QuestInfoDescriptionText",
        "QuestInfoObjectivesText",
        "QuestInfoGroupSize",
        "QuestInfoTimerText",
        "QuestInfoRewardText",
        "QuestInfoQuestType",
        "QuestInfoSpellObjectiveLearnLabel",
        "QuestInfoRequiredMoneyText",
    }) do
        StyleNamedFont(name, BODY_SIZE, Palette.text)
    end

    local objectives = QuestInfoObjectivesFrame
        and QuestInfoObjectivesFrame.Objectives
    if type(objectives) == "table" then
        for _, font in ipairs(objectives) do
            StyleFont(font, BODY_SIZE, Palette.text)
        end
    end

    local rewards = QuestInfoRewardsFrame
    if rewards then
        StyleFont(rewards.Header, HEADING_SIZE, Palette.gold)
        for _, key in ipairs({
            "ItemChooseText", "ItemReceiveText",
            "PlayerTitleText", "QuestSessionBonusReward",
        }) do
            StyleFont(rewards[key], BODY_SIZE, Palette.text)
        end
        if rewards.XPFrame then
            StyleFont(
                rewards.XPFrame.ReceiveText,
                BODY_SIZE, Palette.text
            )
        end
    end
end

local function StylePanelBackground(frame, key)
    if not frame then return end
    Styles:EnsureBackground(frame, key, FRAME_BACKGROUND)
    Styles:CreateBorder(frame, {
        color = Palette.windowBorder.neutral,
        size = 1,
        key = key .. "Border",
    })

    -- Blizzard's QuestFramePanelTemplate puts parchment textures on
    -- BORDER, above custom BACKGROUND textures. All must be hidden.
    for _, name in ipairs({
        "Bg", "MaterialTopLeft", "MaterialTopRight",
        "MaterialBotLeft", "MaterialBotRight",
        "SealMaterialBG",
    }) do
        local region = frame[name]
        if region and region.SetAlpha then
            region:SetAlpha(0)
        end
    end
end

-- Blizzard's QuestFramePanelTemplate defaults to 384 px wide, while
-- QuestFrame itself is only 338 px. Creating a separate black backdrop
-- on every panel extended it 46 px past the actual right frame edge.
-- Keep ONE backdrop on QuestFrame; remove only the panels' parchment.
local function HideNPCPanelParchment(panel)
    if not panel then return end
    for _, name in ipairs({
        "Bg", "MaterialTopLeft", "MaterialTopRight",
        "MaterialBotLeft", "MaterialBotRight",
        "SealMaterialBG",
    }) do
        local region = panel[name]
        if region and region.SetAlpha then
            region:SetAlpha(0)
        end
    end
end

local function CreateNPCPortrait(frame)
    if frame.KamiNPCPortrait then return end

    local holder = CreateFrame("Frame", nil, frame)
    holder:SetSize(44, 44)
    holder:SetPoint("TOPLEFT", frame, "TOPLEFT", 9, -7)
    Styles:EnsureBackground(
        holder, "KamiPortraitBackground", Palette.panelStrong
    )
    Styles:CreateBorder(holder, {
        color = Palette.windowBorder.neutral,
        size = 1,
        key = "KamiPortraitBorder",
    })

    -- Same square 3D portrait as KamiUI_UnitFrames, without forcing
    -- a dependency on that optional module.
    local portrait = CreateFrame("PlayerModel", nil, holder)
    portrait:SetPoint("TOPLEFT", holder, "TOPLEFT", 2, -2)
    portrait:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -2, 2)
    portrait:EnableMouse(false)
    if portrait.SetPortraitZoom then
        portrait:SetPortraitZoom(1)
    end
    if portrait.SetCamDistanceScale then
        portrait:SetCamDistanceScale(1)
    end

    -- Keep Blizzard's static quest icon as fallback for quests
    -- without a visible questnpc unit.
    local texture = _G.QuestFramePortrait
    if texture then
        texture:SetParent(holder)
        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT", holder, "TOPLEFT", 2, -2)
        texture:SetPoint(
            "BOTTOMRIGHT", holder, "BOTTOMRIGHT", -2, 2
        )
    end

    if frame.PortraitContainer then
        frame.PortraitContainer:SetAlpha(0)
    end

    frame.KamiNPCPortrait = portrait
    frame.KamiNPCPortraitFallback = texture
end

local function RefreshNPCPortrait(frame)
    local portrait = frame and frame.KamiNPCPortrait
    if not portrait then return end

    local hasNPC = UnitExists and UnitExists("questnpc")
    if UI:CanAccessValue(hasNPC) and hasNPC then
        portrait:SetUnit("questnpc")
        portrait:Show()
        if frame.KamiNPCPortraitFallback then
            frame.KamiNPCPortraitFallback:Hide()
        end
    else
        portrait:Hide()
        if frame.KamiNPCPortraitFallback then
            frame.KamiNPCPortraitFallback:Show()
        end
    end
end

local function StyleNPCChrome(frame)
    if frame.KamiNPCChromeStyled then return end
    frame.KamiNPCChromeStyled = true

    local close = frame.CloseButton
    if close then
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -7, -7)
        close:SetSize(20, 20)
        Components:StyleCloseButton(close, {
            artSize = 18,
            crossSize = 9,
            crossColor = Palette.text,
        })
    end

    -- The scrollbars were actually close to the native right edge;
    -- the over-wide 384 px panel background made them appear inset.
    -- Keep Blizzard's scroll anchors and scrolling functionality.
    for _, name in ipairs({
        "QuestDetailScrollFrame",
        "QuestProgressScrollFrame",
        "QuestRewardScrollFrame",
        "QuestGreetingScrollFrame",
    }) do
        local scroll = _G[name]
        if scroll and scroll.ScrollBar then
            Components:StyleScrollBar(scroll.ScrollBar, {
                width = 6,
            })
        end
    end

    for _, name in ipairs({
        "QuestFrameAcceptButton", "QuestFrameDeclineButton",
        "QuestFrameCompleteButton", "QuestFrameGoodbyeButton",
        "QuestFrameCompleteQuestButton",
        "QuestFrameGreetingGoodbyeButton",
    }) do
        local button = _G[name]
        if button then
            Components:StyleButton(button, {
                textColor = Palette.text,
                borderColor = Palette.windowBorder.neutral,
            })
        end
    end

    if frame.TitleContainer and frame.TitleContainer.TitleText then
        Styles:ApplyText(
            frame.TitleContainer.TitleText, 13, Palette.gold
        )
    end

    CreateNPCPortrait(frame)
end

local function StyleNPCQuest()
    local frame = QuestFrame
    if not frame then return end

    StylePanelBackground(frame, "KamiNPCQuestBackground")
    if frame.NineSlice then frame.NineSlice:SetAlpha(0) end
    if frame.TopTileStreaks then
        frame.TopTileStreaks:SetAlpha(0)
    end
    if frame.Inset then frame.Inset:SetAlpha(0) end

    for _, name in ipairs({
        "QuestFrameDetailPanel",
        "QuestFrameProgressPanel",
        "QuestFrameRewardPanel",
        "QuestFrameGreetingPanel",
    }) do
        HideNPCPanelParchment(_G[name])
    end

    StyleNPCChrome(frame)
    RefreshNPCPortrait(frame)
    StyleSharedQuestText()
    for _, name in ipairs({
        "QuestProgressTitleText",
        "QuestProgressRequiredItemsText",
        "CurrentQuestsText",
        "AvailableQuestsText",
    }) do
        StyleNamedFont(name, HEADING_SIZE, Palette.gold)
    end
    for _, name in ipairs({
        "QuestProgressText",
        "QuestProgressRequiredMoneyText",
        "GreetingText",
    }) do
        StyleNamedFont(name, BODY_SIZE, Palette.text)
    end
end

local function StyleQuestDetails()
    local details = QuestMapFrame and QuestMapFrame.DetailsFrame
    if not details or not details:IsShown() then return end
    StylePanelBackground(details, "KamiQuestDetailsBackground")
    StyleSharedQuestText()
end

-- Visual pass over Blizzard's pooled quest buttons. Never change
-- the native list, sort, collapse state or mouse click handlers.
local function StyleHeader(button)
    if not button then return end

    Styles:EnsureBackground(
        button, "KamiQuestHeaderBackground", Palette.header
    )
    Styles:CreateBorder(button, {
        color = Palette.windowBorder.neutral,
        size = 1,
        key = "KamiQuestHeaderBorder",
        top = false,
        left = false,
        right = false,
    })

    if button.ButtonText then
        Styles:ApplyText(button.ButtonText, HEADING_SIZE - 1,
            Palette.gold)
    end

    if button.GetNormalTexture then
        local texture = button:GetNormalTexture()
        if texture then texture:SetAlpha(0) end
    end
end

local function StyleQuest(button)
    if not button then return end

    local info = button.info
    if info and not UI:CanAccessValue(info) then
        info = nil
    end
    local level = info and (
        info.difficultyLevel or info.level
    )
    local color = UI:CanAccessValue(level)
        and type(level) == "number" and level > 0
        and Palette:GetLevelDifficultyColor(level)
        or Palette.text

    if button.Text then
        Styles:ApplyText(button.Text, LIST_SIZE, color)
    end
    if button.ButtonText then
        Styles:ApplyText(button.ButtonText, LIST_SIZE, color)
    end
end

local function StyleQuestList()
    local panel = QuestMapFrame
    local quests = panel and panel.QuestsFrame
    local scroll = quests and quests.ScrollFrame
    if not scroll then return end

    Styles:EnsureBackground(
        panel, "KamiQuestPanelBackground", Palette.window.neutral
    )
    Styles:EnsureBackground(
        scroll, "KamiQuestScrollBackground", Palette.panel
    )
    Styles:CreateBorder(scroll, {
        color = Palette.windowBorder.neutral,
        size = 1,
        key = "KamiQuestScrollBorder",
    })

    if scroll.Background then scroll.Background:SetAlpha(0) end

    local contents = scroll.Contents
    local separator = contents and contents.Separator
    if separator and separator.Divider then
        separator.Divider:SetAlpha(0)
    end

    local story = contents and contents.StoryHeader
    if story then
        if story.Background then story.Background:SetAlpha(0) end
        if story.Text then
            Styles:ApplyText(story.Text, HEADING_SIZE - 1,
                Palette.gold)
        end
        if story.Progress then
            Styles:ApplyText(story.Progress, 10, Palette.muted)
        end
    end

    local headerPool = scroll.headerFramePool
    if headerPool and headerPool.EnumerateActive then
        for button in headerPool:EnumerateActive() do
            StyleHeader(button)
        end
    end

    local questPool = scroll.titleFramePool
    if questPool and questPool.EnumerateActive then
        for button in questPool:EnumerateActive() do
            StyleQuest(button)
        end
    end

    -- Only touch shared QuestInfo fonts when the details actually show.
    if QuestDetailsVisible() then StyleQuestDetails() end
end

local function InstallSkin()
    local map = QuestMapFrame

    if map and not hooks.map then
        hooks.map = true
        map:HookScript("OnShow", StyleQuestList)
        if map:IsShown() then StyleQuestList() end
    end

    if not hooks.questUpdate and hooksecurefunc
        and type(QuestLogQuests_Update) == "function" then
        hooks.questUpdate = true
        hooksecurefunc("QuestLogQuests_Update", StyleQuestList)
    end

    if not hooks.details and map and map.DetailsFrame then
        hooks.details = true
        map.DetailsFrame:HookScript("OnShow", StyleQuestDetails)
        map.DetailsFrame:HookScript("OnHide", RestoreQuestFonts)
    end

    if not hooks.npc and QuestFrame then
        hooks.npc = true
        QuestFrame:HookScript("OnShow", StyleNPCQuest)
        QuestFrame:HookScript("OnHide", RestoreQuestFonts)
        for _, name in ipairs({
            "QuestFrameDetailPanel",
            "QuestFrameProgressPanel",
            "QuestFrameRewardPanel",
            "QuestFrameGreetingPanel",
        }) do
            local panel = _G[name]
            if panel then
                panel:HookScript("OnShow", StyleNPCQuest)
            end
        end
        if QuestFrame:IsShown() then StyleNPCQuest() end
    end

    -- Blizzard resets quest font colors every time it renders a
    -- new quest. Reapply after its rendering, never before it.
    if not hooks.questInfo and hooksecurefunc
        and type(QuestInfo_Display) == "function" then
        hooks.questInfo = true
        hooksecurefunc("QuestInfo_Display", function()
            if NPCQuestVisible() then
                StyleNPCQuest()
            elseif QuestDetailsVisible() then
                StyleQuestDetails()
            end
        end)
    end
end

InstallSkin()
UI:RegisterEvent("ADDON_LOADED", InstallSkin)
