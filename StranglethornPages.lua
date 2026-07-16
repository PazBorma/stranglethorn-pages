local addonName = ...

local debug = false

local frameWidth = 200
local frameBaseHeight = 148
local frameLegendExtraHeight = 12
local minimapButtonSize = 32

local defaultSettings = {
    frameVisible = true,
    minimap = {
        angle = 225,
        hide = false,
        minimapPos = 225,
    },
}

local chapters = {
    [1] = {
        questID = 339,
        pages = {
            { itemID = 2725, pageNumber = 1 },
            { itemID = 2728, pageNumber = 4 },
            { itemID = 2730, pageNumber = 6 },
            { itemID = 2732, pageNumber = 8 },
        },
    },
    [2] = {
        questID = 340,
        pages = {
            { itemID = 2734, pageNumber = 10 },
            { itemID = 2735, pageNumber = 11 },
            { itemID = 2738, pageNumber = 14 },
            { itemID = 2740, pageNumber = 16 },
        },
    },
    [3] = {
        questID = 341,
        pages = {
            { itemID = 2742, pageNumber = 18 },
            { itemID = 2744, pageNumber = 20 },
            { itemID = 2745, pageNumber = 21 },
            { itemID = 2748, pageNumber = 24 },
        },
    },
    [4] = {
        questID = 342,
        pages = {
            { itemID = 2749, pageNumber = 25 },
            { itemID = 2750, pageNumber = 26 },
            { itemID = 2751, pageNumber = 27 },
        },
    },
}

local colors = {
    neonGreen = "cff00ff00",
    androidGreen = "cff3ddc84",
    cyan = "cff00ffff",
    skyBlue = "cff6cb7ff",
    yellow = "cffffff00",
    red = "cffff5555",
    creamCanGold = "cfff0c75e",
    grey = "cff9aa3ad",
}

local chapterStatusColors = {
    DONE = colors.neonGreen,
    READY = colors.cyan,
    PARTIAL = colors.yellow,
    NONE = colors.red,
}

local pageColors = {
    OWNED = colors.androidGreen,
    BANK = colors.skyBlue,
    MISSING = colors.creamCanGold,
}

local tooltipStatusColors = {
    NEEDED = colors.cyan,
    NOT_NEEDED = colors.neonGreen,
}

local headerTextColor = colors.grey

local trackedPageIDs = {}

for chapterNumber, chapterData in pairs(chapters) do
    for _, pageData in ipairs(chapterData.pages) do
        trackedPageIDs[pageData.itemID] = {
            chapter = chapterNumber,
            pageNumber = pageData.pageNumber,
        }
    end
end

local function ensureSettings()
    StranglethornPagesDB = StranglethornPagesDB or {}

    if StranglethornPagesDB.frameVisible == nil then
        StranglethornPagesDB.frameVisible = defaultSettings.frameVisible
    end

    StranglethornPagesDB.minimap = StranglethornPagesDB.minimap or {}
    if StranglethornPagesDB.minimap.angle == nil then
        StranglethornPagesDB.minimap.angle = defaultSettings.minimap.angle
    end

    return StranglethornPagesDB
end

local function getSettings()
    return StranglethornPagesDB or ensureSettings()
end

local function minimapLibraries()
    if not LibStub then
        return nil, nil
    end

    local launcher = LibStub:GetLibrary("LibDataBroker-1.1", true)
    local icon = LibStub:GetLibrary("LibDBIcon-1.0", true)

    return launcher, icon
end

local function createMainFrame()
    local frame = CreateFrame("Frame", "StranglethornPagesFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")

    frame:SetSize(frameWidth, frameBaseHeight)
    frame:SetPoint("CENTER")
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("Stranglethorn Pages")

    local closeButton = CreateFrame("Button", nil, frame)
    closeButton:SetSize(14, 14)
    closeButton:SetPoint("TOPRIGHT", -8, -8)
    closeButton:SetScript("OnClick", function()
        StvPages.setFrameVisible(false)
    end)

    local closeText = closeButton:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    closeText:SetPoint("CENTER")
    closeText:SetText("X")
    closeText:SetTextColor(1, 1, 1, 0.8)
    closeButton.text = closeText

    closeButton:SetScript("OnEnter", function(self)
        self.text:SetTextColor(1, 1, 1, 1)
    end)

    closeButton:SetScript("OnLeave", function(self)
        self.text:SetTextColor(1, 1, 1, 0.8)
    end)

    frame.closeButton = closeButton

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.08)
    divider:SetPoint("TOPLEFT", 8, -24)
    divider:SetPoint("TOPRIGHT", -8, -24)
    divider:SetHeight(1)

    local headerChapter = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerChapter:SetPoint("TOPLEFT", 12, -31)
    headerChapter:SetText(colored("C", headerTextColor))

    local headerPages = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerPages:SetPoint("TOPLEFT", 36, -31)
    headerPages:SetText(colored("Pages", headerTextColor))

    local headerStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerStatus:SetPoint("TOPLEFT", frame, "TOPRIGHT", -47, -31)
    headerStatus:SetText(colored("Status", headerTextColor))

    frame.rows = {}

    for chapterNumber = 1, 4 do
        local row = CreateFrame("Frame", nil, frame)
        row:SetHeight(24)
        row:SetPoint("TOPLEFT", 8, -43 - ((chapterNumber - 1) * 24))
        row:SetPoint("TOPRIGHT", -6, -43 - ((chapterNumber - 1) * 24))

        local background = row:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        if chapterNumber % 2 == 1 then
            background:SetColorTexture(1, 1, 1, 0.04)
        else
            background:SetColorTexture(1, 1, 1, 0.02)
        end

        local chapterText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        chapterText:SetPoint("LEFT", 4, 0)
        chapterText:SetWidth(20)
        chapterText:SetJustifyH("LEFT")

        local pagesText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        pagesText:SetPoint("LEFT", 28, 0)
        pagesText:SetPoint("RIGHT", -44, 0)
        pagesText:SetJustifyH("LEFT")

        local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        statusText:SetPoint("RIGHT", -2, 0)
        statusText:SetWidth(38)
        statusText:SetJustifyH("LEFT")

        row.background = background
        row.chapterText = chapterText
        row.pagesText = pagesText
        row.statusText = statusText

        frame.rows[chapterNumber] = row
    end

    local legendText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    legendText:SetPoint("BOTTOMLEFT", 12, 4)
    legendText:SetPoint("BOTTOMRIGHT", -12, 4)
    legendText:SetJustifyH("CENTER")
    legendText:SetText(colored("-", headerTextColor) .. " " .. colored("bag", pageColors.OWNED) .. "   " .. colored("-", headerTextColor) .. " " .. colored("bank", pageColors.BANK))
    legendText:Hide()

    frame.legendText = legendText

    return frame
end

local function updateMinimapButtonPosition(button)
    local settings = getSettings()
    local angle = math.rad(settings.minimap.angle or defaultSettings.minimap.angle)
    local radius = 80
    local xOffset = math.cos(angle) * radius
    local yOffset = math.sin(angle) * radius

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", xOffset, yOffset)
end

local function createLauncher()
    local launcher = StvPages.launcher
    if launcher then
        return launcher
    end

    local dataBroker = minimapLibraries()
    if not dataBroker then
        return nil
    end

    launcher = dataBroker:NewDataObject("StranglethornPages", {
        type = "launcher",
        text = "Stranglethorn Pages",
        icon = "Interface\\Icons\\INV_Misc_Book_03",
        OnClick = function()
            StvPages.toggleFrame()
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("Stranglethorn Pages")
            tooltip:AddLine("Left-click to toggle the tracker.", 1, 1, 1)
        end,
    })

    StvPages.launcher = launcher
    return launcher
end

local function createMinimapLauncher()
    local launcher, icon = minimapLibraries()
    if not launcher or not icon then
        return nil
    end

    local settings = getSettings()
    settings.minimap.hide = settings.minimap.hide or false
    if settings.minimap.minimapPos == nil then
        settings.minimap.minimapPos = settings.minimap.angle or defaultSettings.minimap.minimapPos
    end

    icon:Register("StranglethornPages", createLauncher(), settings.minimap)
    return icon
end

local function createMinimapButton()
    local button = CreateFrame("Button", "StranglethornPagesMinimapButton", Minimap)
    button:SetSize(minimapButtonSize, minimapButtonSize)
    button:SetFrameStrata("MEDIUM")
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_03")
    button.icon = icon

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetPoint("TOPLEFT")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetBlendMode("ADD")
    highlight:SetSize(31, 31)
    highlight:SetPoint("CENTER", 0.5, -0.5)
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Stranglethorn Pages")
        GameTooltip:AddLine("Left-click to toggle the tracker.", 1, 1, 1)
        GameTooltip:AddLine("Drag to move around the minimap.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self:SetScript("OnUpdate", function(currentButton)
            local cursorX, cursorY = GetCursorPosition()
            local minimapScale = Minimap:GetEffectiveScale()
            local minimapCenterX, minimapCenterY = Minimap:GetCenter()
            local offsetX = (cursorX / minimapScale) - minimapCenterX
            local offsetY = (cursorY / minimapScale) - minimapCenterY
            local angle = math.deg(math.atan2(offsetY, offsetX))

            getSettings().minimap.angle = angle
            getSettings().minimap.minimapPos = angle
            updateMinimapButtonPosition(currentButton)
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self:UnlockHighlight()
        self:SetScript("OnUpdate", nil)
    end)

    updateMinimapButtonPosition(button)

    return button
end

local function getChapterInfo(chapterNumber)
    local chapterData = chapters[chapterNumber]
    local info = {
        chapter = chapterNumber,
        state = "NONE",
        ownedPages = {},
        missingPages = {},
    }

    if C_QuestLog.IsQuestFlaggedCompleted(chapterData.questID) then
        info.state = "DONE"
        return info
    end

    for _, pageData in ipairs(chapterData.pages) do
        if StvPages.hasItem(pageData.itemID) then
            table.insert(info.ownedPages, pageData)
        else
            table.insert(info.missingPages, pageData)
        end
    end

    if #info.missingPages == 0 then
        info.state = "READY"
    elseif #info.ownedPages > 0 then
        info.state = "PARTIAL"
    end

    return info
end

local function buildPagesText(chapterNumber, chapterQuestCompleted)
    local labels = {}

    for _, pageData in ipairs(chapters[chapterNumber].pages) do
        local color = pageColors.MISSING
        if chapterQuestCompleted or StvPages.hasItemInBags(pageData.itemID) then
            color = pageColors.OWNED
        elseif StvPages.hasItemInBank(pageData.itemID) then
            color = pageColors.BANK
        end

        table.insert(labels, colored(pageData.pageNumber, color))
    end

    return table.concat(labels, "   ")
end

local function getStatusLabel(state)
    if state == "DONE" then
        return colored("Done", chapterStatusColors.DONE)
    elseif state == "READY" then
        return colored("Ready", chapterStatusColors.READY)
    elseif state == "PARTIAL" then
        return colored("Partial", chapterStatusColors.PARTIAL)
    end

    return colored("None", chapterStatusColors.NONE)
end

local function applyRowStyle(row, state, chapterNumber)
    local baseAlpha = chapterNumber % 2 == 1 and 0.04 or 0.02

    if state == "DONE" then
        row.background:SetColorTexture(0.24, 0.65, 0.38, 0.16)
        row.chapterText:SetTextColor(0.85, 1.0, 0.88)
    elseif state == "READY" then
        row.background:SetColorTexture(0.12, 0.55, 0.65, 0.16)
        row.chapterText:SetTextColor(0.86, 0.98, 1.0)
    elseif state == "PARTIAL" then
        row.background:SetColorTexture(0.72, 0.56, 0.16, 0.14)
        row.chapterText:SetTextColor(1.0, 0.94, 0.76)
    else
        row.background:SetColorTexture(1, 1, 1, baseAlpha)
        row.chapterText:SetTextColor(0.82, 0.82, 0.82)
    end
end

local function refreshDisplay()
    if not StvPages.frame then
        return
    end

    local hasAnyBankOnlyPage = false

    for chapterNumber = 1, 4 do
        local info = getChapterInfo(chapterNumber)
        local row = StvPages.frame.rows[chapterNumber]
        local chapterQuestCompleted = info.state == "DONE"

        row.chapterText:SetText(tostring(chapterNumber))
        row.pagesText:SetText(buildPagesText(chapterNumber, chapterQuestCompleted))
        row.statusText:SetText(getStatusLabel(info.state))
        applyRowStyle(row, info.state, chapterNumber)

        if not hasAnyBankOnlyPage and not chapterQuestCompleted then
            for _, pageData in ipairs(chapters[chapterNumber].pages) do
                if StvPages.hasItemInBank(pageData.itemID) and not StvPages.hasItemInBags(pageData.itemID) then
                    hasAnyBankOnlyPage = true
                    break
                end
            end
        end
    end

    if StvPages.frame.legendText then
        if hasAnyBankOnlyPage then
            StvPages.frame.legendText:Show()
            StvPages.frame:SetHeight(frameBaseHeight + frameLegendExtraHeight)
        else
            StvPages.frame.legendText:Hide()
            StvPages.frame:SetHeight(frameBaseHeight)
        end
    end
end

local function isBankAccessible()
    if type(C_Bank) == "table" and type(C_Bank.IsBankOpen) == "function" then
        return C_Bank.IsBankOpen()
    end

    return BankFrame and BankFrame:IsShown()
end

local function refreshAllData()
    StvPages.updateAllBags()
    if isBankAccessible() then
        StvPages.updateAllBankBags()
    end
    refreshDisplay()
end

function StvPages.setFrameVisible(isVisible)
    local settings = getSettings()
    settings.frameVisible = not not isVisible

    if settings.frameVisible then
        refreshAllData()
        StvPages.frame:Show()
    else
        StvPages.frame:Hide()
    end
end

function StvPages.toggleFrame()
    StvPages.setFrameVisible(not getSettings().frameVisible)
end

local eventActions = {
    ["ADDON_LOADED"] = function(loadedAddonName)
        if loadedAddonName ~= addonName then
            return
        end

        ensureSettings()

        if not StvPages.minimapButton then
            StvPages.minimapButton = createMinimapLauncher()

            if not StvPages.minimapButton then
                StvPages.minimapButton = createMinimapButton()
                StvPages.minimapButton:SetScript("OnClick", function()
                    StvPages.toggleFrame()
                end)
            end
        else
            local _launcher, icon = minimapLibraries()
            if not icon then
                updateMinimapButtonPosition(StvPages.minimapButton)
            end
        end

        StvPages.setFrameVisible(getSettings().frameVisible)

        StvPages.frame:RegisterEvent("BAG_UPDATE_DELAYED")
        StvPages.frame:RegisterEvent("BANKFRAME_OPENED")
        StvPages.frame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
        StvPages.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        StvPages.frame:RegisterEvent("QUEST_LOG_UPDATE")

        StvPages.frame:UnregisterEvent("ADDON_LOADED")
    end,
    ["BAG_UPDATE_DELAYED"] = function()
        StvPages.updateAllBags()
        refreshDisplay()
    end,
    ["BANKFRAME_OPENED"] = function()
        StvPages.updateAllBankBags()
        refreshDisplay()
    end,
    ["PLAYERBANKSLOTS_CHANGED"] = function()
        StvPages.updateAllBankBags()
        refreshDisplay()
    end,
    ["PLAYER_ENTERING_WORLD"] = function()
        refreshAllData()
    end,
    ["QUEST_LOG_UPDATE"] = function()
        refreshDisplay()
    end,
}

local function HandleEvent(_frame, event, ...)
    if debug then
        print(event)
    end

    if event == "ADDON_LOADED" then
        eventActions[event](...)
    elseif getSettings().frameVisible then
        eventActions[event](...)
    end
end

local function tooltip(tooltip)
    local _itemName, itemLink = tooltip:GetItem()
    if not itemLink then
        return
    end

    local itemID = tonumber(itemLink:match("item:(%d+)"))
    if not itemID then
        return
    end

    local pageInfo = trackedPageIDs[itemID]
    if not pageInfo then
        return
    end

    local owner = tooltip:GetOwner()
    if not owner or not owner.GetName then
        return
    end

    local ownerName = owner:GetName()
    if not ownerName or not ownerName:match("^LootButton") then
        return
    end

    local chapterData = chapters[pageInfo.chapter]
    if chapterData and C_QuestLog.IsQuestFlaggedCompleted(chapterData.questID) then
        tooltip:AddLine(colored("Chapter " .. pageInfo.chapter .. " completed", tooltipStatusColors.NOT_NEEDED))
    elseif StvPages.hasItemInBags(itemID) then
        tooltip:AddLine(colored("Already in bags", tooltipStatusColors.NOT_NEEDED))
    elseif StvPages.hasItemInBank(itemID) then
        tooltip:AddLine(colored("Already in bank", tooltipStatusColors.NOT_NEEDED))
    else
        tooltip:AddLine(colored("Needed for chapter " .. pageInfo.chapter .. ", page " .. pageInfo.pageNumber, tooltipStatusColors.NEEDED))
    end

    tooltip:Show()
end

StvPages.frame = createMainFrame()
StvPages.frame:Hide()
StvPages.frame:RegisterEvent("ADDON_LOADED")
StvPages.frame:SetScript("OnEvent", HandleEvent)

GameTooltip:HookScript("OnTooltipSetItem", tooltip)
