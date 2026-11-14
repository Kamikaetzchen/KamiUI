local UI = KamiUI
local Module = UI:GetModule("Quests")
if not Module then return end

local Styles = UI.Styles
local Palette = UI.Palette
local hooks = {}
local detailFonts = {}

local function StyleDetailFont(name, role)
    local font = _G[name]
    if not font or not font.GetFont or not font.GetTextColor then
        return
    end

    if not detailFonts[font] then
        local fontPath, size, flags = font:GetFont()
        local r, g, b, a = font:GetTextColor()
        detailFonts[font] = {
            fontPath, size, flags, r, g, b, a,
        }
    end

    Styles:ApplyText(font, role)
end

-- QuestInfo FontStrings are shared with NPC quest dialogs. Restore
-- their exact previous font/color once the map's details pane hides.
local function RestoreDetailFonts()
    for font, saved in pairs(detailFonts) do
        if saved[1] and saved[2] then
            font:SetFont(saved[1], saved[2], saved[3])
        end
        font:SetTextColor(saved[4], saved[5], saved[6], saved[7])
        detailFonts[font] = nil
    end
end

-- Visual pass over Blizzard's pooled quest buttons. This must never
-- create quest rows, reorder data, change header collapse state, or
-- call QuestLogQuests_Update() itself.
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
        Styles:ApplyText(button.ButtonText, "sectionTitle")
    end

    -- The native collapse control and its click handlers are retained.
    -- Hide only the header button's decorative atlas.
    if button.GetNormalTexture then
        local texture = button:GetNormalTexture()
        if texture then texture:SetAlpha(0) end
    end
end

local function StyleQuest(button)
    if not button then return end

    local info = button.info
    local level = info and (
        info.difficultyLevel or info.level
    )
    local color = type(level) == "number" and level > 0
        and Palette:GetLevelDifficultyColor(level)
        or Palette.text

    -- Keep Blizzard's text, quest levels, tracking checkbox,
    -- selection, mouse handlers and tooltip behavior intact.
    if button.Text then
        Styles:ApplyText(
            button.Text, Styles.FontSize.ObjectiveTracker, color
        )
    end
    if button.ButtonText then
        Styles:ApplyText(
            button.ButtonText, Styles.FontSize.ObjectiveTracker,
            color
        )
    end
end

local function StyleQuestDetails()
    local details = QuestMapFrame
        and QuestMapFrame.DetailsFrame
    if not details then return end

    -- Only the QuestLog details pane. The separate NPC quest dialogs
    -- keep their own materials and colors.
    Styles:EnsureBackground(
        details, "KamiQuestDetailsBackground",
        Palette.window.neutral
    )
    Styles:CreateBorder(details, {
        color = Palette.windowBorder.neutral,
        size = 1,
        key = "KamiQuestDetailsBorder",
    })

    if details.Bg then details.Bg:SetAlpha(0) end
    if details.SealMaterialBG then
        details.SealMaterialBG:SetAlpha(0)
    end

    -- QuestInfo_Display applies Blizzard's parchment text colors
    -- again on selection. Reapply after that native update below.
    for _, name in ipairs({
        "QuestInfoTitleHeader",
        "QuestInfoDescriptionHeader",
        "QuestInfoObjectivesHeader",
    }) do
        StyleDetailFont(name, "panelTitle")
    end

    for _, name in ipairs({
        "QuestInfoDescriptionText",
        "QuestInfoObjectivesText",
        "QuestInfoGroupSize",
        "QuestInfoTimerText",
    }) do
        StyleDetailFont(name, "normal")
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

    if scroll.Background then
        scroll.Background:SetAlpha(0)
    end

    local contents = scroll.Contents
    local separator = contents and contents.Separator
    if separator and separator.Divider then
        separator.Divider:SetAlpha(0)
    end

    local story = contents and contents.StoryHeader
    if story then
        if story.Background then story.Background:SetAlpha(0) end
        if story.Text then
            Styles:ApplyText(story.Text, "sectionTitle")
        end
        if story.Progress then
            Styles:ApplyText(story.Progress, "muted")
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

    -- OpenMap can change the sidebar's width, so all backgrounds
    -- anchor to existing native frames, never fixed pixel sizes.
    StyleQuestDetails()
end

local function InstallSkin()
    local panel = QuestMapFrame

    if panel and not hooks.map then
        hooks.map = true
        panel:HookScript("OnShow", StyleQuestList)
        if panel:IsShown() then
            StyleQuestList()
        end
    end

    if not hooks.questUpdate and hooksecurefunc
        and type(QuestLogQuests_Update) == "function" then
        hooks.questUpdate = true
        hooksecurefunc("QuestLogQuests_Update", StyleQuestList)
    end

    if not hooks.detailShow and panel and panel.DetailsFrame then
        hooks.detailShow = true
        panel.DetailsFrame:HookScript(
            "OnShow", StyleQuestDetails
        )
        panel.DetailsFrame:HookScript(
            "OnHide", RestoreDetailFonts
        )
    end

    if not hooks.detailUpdate and hooksecurefunc
        and type(QuestInfo_Display) == "function" then
        hooks.detailUpdate = true
        hooksecurefunc("QuestInfo_Display", function()
            if QuestMapFrame and QuestMapFrame.DetailsFrame
                and QuestMapFrame.DetailsFrame:IsShown() then
                StyleQuestDetails()
            end
        end)
    end
end

InstallSkin()
UI:RegisterEvent("ADDON_LOADED", InstallSkin)
