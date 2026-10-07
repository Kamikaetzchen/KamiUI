local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles
local Components = UI.Components

local Module = UI:NewModule("Loot", "KamiUI_Loot")

local FRAME_WIDTH = 280
local HEADER_HEIGHT = 28
local FRAME_PADDING = 7
local ROW_HEIGHT = 36
local ROW_SPACING = 3
local ICON_SIZE = 32
local CURSOR_OFFSET_X = 12
local CURSOR_OFFSET_Y = -12
local SCREEN_PADDING = 8

local function CloseLootWindow()
    if CloseLoot then
        CloseLoot()
    elseif LootFrame and LootFrame.Hide then
        LootFrame:Hide()
    end
end

local function SuppressNativeLootFrame()
    local frame = _G.LootFrame

    if not frame then
        return
    end

    UI:SuppressFrame(frame, {
        children = true,
    })

    if frame.KamiUILootSuppressed or not frame.HookScript then
        return
    end

    frame.KamiUILootSuppressed = true
    frame:HookScript("OnShow", function(self)
        UI:SuppressFrame(self, {
            children = true,
        })
    end)
end

local function GetLootQualityColor(quality)
    local color = quality
        and ITEM_QUALITY_COLORS
        and ITEM_QUALITY_COLORS[quality]

    return color or Palette.text
end

local function CreateLootRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp")

    Styles:EnsureBackground(
        row,
        "KamiLootRowBackground",
        Palette.panel
    )
    Styles:CreateBorder(row, {
        key = "KamiLootRowBorder",
        color = Palette.border,
    })

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    Styles:SetColor(
        highlight,
        Palette.white,
        Styles.State.hoverAlpha
    )

    local icon = Components:CreateItemSlot(row, {
        frameType = "Frame",
        size = ICON_SIZE,
        count = true,
        highlight = false,
        corners = true,
    })
    icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.icon = icon

    local name = row:CreateFontString(nil, "OVERLAY")
    Styles:ApplyText(name, "normal")
    name:SetPoint("LEFT", icon, "RIGHT", 7, 0)
    name:SetPoint("RIGHT", row, "RIGHT", -7, 0)
    name:SetJustifyH("LEFT")

    if name.SetWordWrap then
        name:SetWordWrap(false)
    end

    if name.SetMaxLines then
        name:SetMaxLines(1)
    end

    row.nameText = name

    row:SetScript("OnClick", function(self)
        if self.locked or not self.lootSlot then
            return
        end

        LootSlot(self.lootSlot)
    end)

    row:SetScript("OnEnter", function(self)
        if not self.lootSlot or not GameTooltip then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

        if GameTooltip.SetLootItem then
            GameTooltip:SetLootItem(self.lootSlot)
        elseif self.itemLink then
            GameTooltip:SetHyperlink(self.itemLink)
        else
            GameTooltip:SetText(self.itemName or LOOT or "Loot")
        end

        GameTooltip:Show()
    end)

    row:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    return row
end

local function GetLootSlotData(slot)
    local texture,
        itemName,
        quantity,
        currencyID,
        quality,
        locked,
        isQuestItem,
        questID,
        isActive,
        isCoin = GetLootSlotInfo(slot)

    local slotType = GetLootSlotType and GetLootSlotType(slot)
    local link = GetLootSlotLink and GetLootSlotLink(slot)

    if not texture
        and not itemName
        and not link
        and (not slotType or slotType == 0)
    then
        return nil
    end

    return {
        slot = slot,
        texture = texture,
        itemName = itemName or link or LOOT or "Loot",
        quantity = quantity or 1,
        currencyID = currencyID,
        quality = quality,
        locked = locked == true,
        isQuestItem = isQuestItem == true,
        questID = questID,
        isActive = isActive,
        isCoin = isCoin == true,
        slotType = slotType,
        link = link,
    }
end

local function PositionAtCursor(frame)
    local scale = UIParent:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()

    cursorX = cursorX / scale
    cursorY = cursorY / scale

    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()
    local frameWidth = frame:GetWidth()
    local frameHeight = frame:GetHeight()

    local x = cursorX + CURSOR_OFFSET_X
    local y = cursorY - CURSOR_OFFSET_Y

    x = math.max(
        SCREEN_PADDING,
        math.min(
            x,
            screenWidth - frameWidth - SCREEN_PADDING
        )
    )
    y = math.max(
        SCREEN_PADDING,
        math.min(
            y,
            screenHeight - frameHeight - SCREEN_PADDING
        )
    )

    frame:ClearAllPoints()
    frame:SetPoint(
        "BOTTOMLEFT",
        UIParent,
        "BOTTOMLEFT",
        x,
        y
    )
end

function Module:Refresh()
    local frame = self.frame

    if not frame then
        return
    end

    local entries = {}

    for slot = 1, GetNumLootItems() do
        local data = GetLootSlotData(slot)

        if data then
            entries[#entries + 1] = data
        end
    end

    for index, data in ipairs(entries) do
        local row = frame.rows[index]

        if not row then
            row = CreateLootRow(frame.content)
            frame.rows[index] = row
        end

        row:ClearAllPoints()
        row:SetPoint(
            "TOPLEFT",
            frame.content,
            "TOPLEFT",
            0,
            -(index - 1) * (ROW_HEIGHT + ROW_SPACING)
        )
        row:SetPoint(
            "TOPRIGHT",
            frame.content,
            "TOPRIGHT",
            0,
            -(index - 1) * (ROW_HEIGHT + ROW_SPACING)
        )

        row.lootSlot = data.slot
        row.itemName = data.itemName
        row.itemLink = data.link
        row.locked = data.locked

        row.nameText:SetText(data.itemName)
        Styles:SetTextColor(
            row.nameText,
            data.locked
                and Palette.muted
                or GetLootQualityColor(data.quality)
        )

        Components:SetItemSlotData(row.icon, {
            link = data.link,
            icon = data.texture,
            count = data.quantity,
            quality = data.quality,
            alpha = data.locked and 0.45 or 1,
            desaturated = data.locked,
        })

        row:SetAlpha(data.locked and 0.70 or 1)
        row:Show()
    end

    for index = #entries + 1, #frame.rows do
        frame.rows[index]:Hide()
    end

    local rowCount = #entries
    local contentHeight = rowCount > 0
        and (
            rowCount * ROW_HEIGHT
            + (rowCount - 1) * ROW_SPACING
        )
        or 0

    frame.content:SetHeight(contentHeight)
    frame:SetHeight(
        HEADER_HEIGHT
        + FRAME_PADDING
        + contentHeight
        + FRAME_PADDING
    )

    if rowCount == 0 then
        frame:Hide()
    end
end

function Module:Show()
    if not self.frame then
        return
    end

    SuppressNativeLootFrame()
    self:Refresh()

    if #self.frame.rows == 0 then
        return
    end

    local hasVisibleRow = false

    for _, row in ipairs(self.frame.rows) do
        if row:IsShown() then
            hasVisibleRow = true
            break
        end
    end

    if not hasVisibleRow then
        return
    end

    PositionAtCursor(self.frame)
    self.frame:Show()
end

function Module:Hide()
    if self.frame then
        self.frame:Hide()
    end

    if GameTooltip then
        GameTooltip:Hide()
    end
end

function Module:CreateFrame()
    local frame, header = Components:CreateWindow(
        "KamiUILootFrame",
        {
            width = FRAME_WIDTH,
            height = HEADER_HEIGHT + FRAME_PADDING * 2,
            backgroundColor = Palette.window.neutral,
            borderColor = Palette.windowBorder.neutral,
            header = {
                height = HEADER_HEIGHT,
                title = LOOT or "Loot",
            },
        }
    )

    local close = Components:CreateWindowCloseButton(
        header.RightActions,
        {
            onClick = CloseLootWindow,
        }
    )
    frame.closeButton = close

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        FRAME_PADDING,
        -HEADER_HEIGHT - FRAME_PADDING
    )
    content:SetPoint(
        "TOPRIGHT",
        frame,
        "TOPRIGHT",
        -FRAME_PADDING,
        -HEADER_HEIGHT - FRAME_PADDING
    )
    content:SetHeight(1)

    frame.content = content
    frame.rows = {}

    frame:SetScript("OnHide", function()
        if Module.manualLootOpen then
            Module.manualLootOpen = false
            CloseLootWindow()
        end
    end)

    Components:RegisterEscapeClose(frame)

    self.frame = frame
end

function Module:Initialize()
    self:CreateFrame()
    SuppressNativeLootFrame()

    UI:RegisterEvent("LOOT_OPENED", function(_, autoLoot)
        if Module.ShouldAutoLoot
            and Module:ShouldAutoLoot(autoLoot)
        then
            Module.manualLootOpen = false
            Module:Hide()
            return
        end

        Module.manualLootOpen = true
        Module:Show()
    end)

    UI:RegisterEvent("LOOT_READY", function()
        if Module.frame and Module.frame:IsShown() then
            Module:Refresh()
        end
    end)

    UI:RegisterEvent("LOOT_SLOT_CLEARED", function()
        if Module.frame and Module.frame:IsShown() then
            Module:Refresh()
        end
    end)

    UI:RegisterEvent("LOOT_SLOT_CHANGED", function()
        if Module.frame and Module.frame:IsShown() then
            Module:Refresh()
        end
    end)

    UI:RegisterEvent("LOOT_CLOSED", function()
        Module.manualLootOpen = false
        Module:Hide()
    end)

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        SuppressNativeLootFrame()
    end)

    UI:RegisterEvent("ADDON_LOADED", function()
        SuppressNativeLootFrame()
    end)
end

Module:Initialize()
