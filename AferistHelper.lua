local ADDON_NAME, addon = ...

AferistHelperDB = AferistHelperDB or {
    _metadata = {
        version = "1.0.0",
        last_updated = 0
    },
    configs = {},
    favorites = {},
    class = nil,
    mailDonationShown = false,
    mailShownCount = 0
}

local Config = {
    showClassRecommendations = true
}

local frame, classFrame
local selectedCategory = "elvui"
local searchResults = {}
local currentPlayerClass = nil
local mailShownCount = 0
local MAX_MAIL_SHOW_COUNT = 2

local function FixElvUIConflict()
    if not IsAddOnLoaded("ElvUI") then return end
    
    -- Защищаем функцию от nil значений
    local orig_UnitPopup_AddDropDownTitle = UnitPopup_AddDropDownTitle
    UnitPopup_AddDropDownTitle = function(dropdownMenu, text, colorCode)
        colorCode = colorCode or "FFFFFFFF" -- Защита от nil
        return orig_UnitPopup_AddDropDownTitle(dropdownMenu, text, colorCode)
    end
end



function ShowCopyWindow(name, config)
    local copyFrame = CreateFrame("Frame", "AferistHelperCopyFrame", UIParent, "BasicFrameTemplate")
    copyFrame:SetSize(700, 500)
    copyFrame:SetPoint("CENTER")
    copyFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    copyFrame:SetMovable(true)
    copyFrame:EnableMouse(true)
    copyFrame:RegisterForDrag("LeftButton")
    copyFrame:SetScript("OnDragStart", copyFrame.StartMoving)
    copyFrame:SetScript("OnDragStop", copyFrame.StopMovingOrSizing)
    
    copyFrame.title = copyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    copyFrame.title:SetPoint("TOP", 0, -5)
    copyFrame.title:SetText("Копирование конфига: " .. name)
    
    local instructionText = copyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    instructionText:SetPoint("TOP", 0, -25)
    instructionText:SetText("Выделите текст ниже и скопируйте (Ctrl+A затем Ctrl+C):")
    
    local scrollFrame = CreateFrame("ScrollFrame", "AferistHelperCopyScrollFrame", copyFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 15, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)
    
    local editBox = CreateFrame("EditBox", "AferistHelperCopyEditBox", scrollFrame)
    editBox:SetSize(scrollFrame:GetWidth() - 20, scrollFrame:GetHeight())
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("GameFontHighlight")
    editBox:SetText(config.config_string)
    editBox:SetScript("OnEscapePressed", function() copyFrame:Hide() end)
    
    editBox:SetMaxLetters(0)
    editBox:SetWidth(scrollFrame:GetWidth() - 20)
    
    editBox:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    editBox:SetBackdropColor(0, 0, 0, 1)
    editBox:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    scrollFrame:SetScrollChild(editBox)
    
    local selectAllBtn = CreateFrame("Button", nil, copyFrame, "UIPanelButtonTemplate")
    selectAllBtn:SetSize(120, 25)
    selectAllBtn:SetPoint("BOTTOMLEFT", 20, 10)
    selectAllBtn:SetText("Выделить всё")
    selectAllBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)
    
    local closeBtn = CreateFrame("Button", nil, copyFrame, "UIPanelButtonTemplate")
    closeBtn:SetSize(100, 25)
    closeBtn:SetPoint("BOTTOMRIGHT", -20, 10)
    closeBtn:SetText("Закрыть")
    closeBtn:SetScript("OnClick", function() copyFrame:Hide() end)
    
    copyFrame:SetScript("OnSizeChanged", function(self, width, height)
        scrollFrame:SetSize(width - 45, height - 90)
        editBox:SetWidth(scrollFrame:GetWidth() - 20)
    end)
    
    local timerFrame = CreateFrame("Frame")
    local elapsed = 0
    timerFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.1 then
            editBox:SetFocus()
            editBox:HighlightText()
            self:SetScript("OnUpdate", nil)
        end
    end)
    
    print("|cFF00FF00Открыто окно копирования конфига '" .. name .. "'|r")
    print("|cFFFFFF00Выделите текст и нажмите Ctrl+C для копирования|r")
end

function CopyToClipboard(text)
    ShowCopyWindow("Конфиг", {config_string = text})
end

function CreateMainFrame()
    frame = CreateFrame("Frame", "AferistHelperFrame", UIParent, "BasicFrameTemplate")
    frame:SetSize(650, 500)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", 0, -5)
    frame.title:SetText("Aferist Helper - Библиотека конфигов")
    
    frame:Hide()
    
    CreateTabs()
    CreateContentArea()
    CreateSearchPanel()
    CreateStatusBar()
end

function CreateTabs()
    local tabs = {"ElvUI", "WeakAuras", "Details", "Other"}
    
    for i, tabName in ipairs(tabs) do
        local tab = CreateFrame("Button", "AferistHelperTab"..i, frame, "UIPanelButtonTemplate")
        tab:SetSize(100, 22)
        tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 15 + ((i-1) * 105), 2)
        tab:SetText(tabName)
        
        tab:SetScript("OnClick", function() 
            SwitchTab(tabName:lower()) 
        end)
        
        tab:SetScript("OnShow", function()
            if selectedCategory == tabName:lower() then
                tab:SetButtonState("PUSHED", true)
            else
                tab:SetButtonState("NORMAL", false)
            end
        end)
    end
end

function CreateContentArea()
    frame.configList = CreateFrame("Frame", nil, frame)
    frame.configList:SetPoint("TOPLEFT", 10, -70)
    frame.configList:SetPoint("BOTTOMRIGHT", -10, 40)
    
    frame.scrollFrame = CreateFrame("ScrollFrame", "AferistHelperScrollFrame", frame.configList, "UIPanelScrollFrameTemplate")
    frame.scrollFrame:SetPoint("TOPLEFT", 5, -5)
    frame.scrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)
    
    frame.scrollChild = CreateFrame("Frame", "AferistHelperScrollChild", frame.scrollFrame)
    frame.scrollFrame:SetScrollChild(frame.scrollChild)
    frame.scrollChild:SetSize(580, 350)
    
    frame.classBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.classBtn:SetSize(160, 25)
    frame.classBtn:SetPoint("TOPRIGHT", -30, -35)
    frame.classBtn:SetText("Для моего класса")
    frame.classBtn:SetScript("OnClick", ShowClassRecommendations)
end

function CreateSearchPanel()
    frame.searchBox = CreateFrame("EditBox", "AferistHelperSearchBox", frame, "SearchBoxTemplate")
    frame.searchBox:SetPoint("TOPLEFT", 15, -30)
    frame.searchBox:SetSize(200, 20)
    frame.searchBox:SetScript("OnTextChanged", function(self) SearchConfigs(self:GetText()) end)
    frame.searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
end

function CreateStatusBar()
    frame.statusBar = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.statusBar:SetPoint("BOTTOMLEFT", 10, 10)
    UpdateStatusBar()
end

function UpdateStatusBar()
    local lastUpdate = AferistHelperDB._metadata.last_updated or 0
    local dateStr = lastUpdate > 0 and date("%Y-%m-%d %H:%M", lastUpdate) or "никогда"
    local totalConfigs = CountTotalConfigs()
    
    frame.statusBar:SetText(string.format("Конфигов: %d | Версия: %s", totalConfigs, AferistHelperDB._metadata.version))
end

function CountTotalConfigs()
    local count = 0
    for category, configs in pairs(AferistHelperDB.configs) do
        for _ in pairs(configs) do
            count = count + 1
        end
    end
    return count
end

function SwitchTab(category)
    selectedCategory = category
    
    for i = 1, 4 do
        local tab = _G["AferistHelperTab"..i]
        if tab then
            if selectedCategory == string.lower(tab:GetText()) then
                tab:SetButtonState("PUSHED", true)
            else
                tab:SetButtonState("NORMAL", false)
            end
        end
    end
    
    RefreshConfigList()
end

function RefreshConfigList()
    if not frame.scrollChild then return end
    
    if frame.scrollChild.buttons then
        for i, button in ipairs(frame.scrollChild.buttons) do
            if button then
                button:Hide()
            end
        end
    end
    
    frame.scrollChild.buttons = {}
    
    local configsToShow = {}
    if #searchResults > 0 then
        configsToShow = searchResults
    else
        local categoryConfigs = AferistHelperDB.configs[selectedCategory] or {}
        for name, config in pairs(categoryConfigs) do
            table.insert(configsToShow, {name = name, config = config})
        end
    end
    
    table.sort(configsToShow, function(a, b)
        return (a.config.downloads or 0) > (b.config.downloads or 0)
    end)
    
    for i, configData in ipairs(configsToShow) do
        local button = CreateConfigButton(i)
        ConfigureConfigButton(button, configData.name, configData.config, i)
        button:Show()
        frame.scrollChild.buttons[i] = button
    end
    
    if #configsToShow > 0 then
        frame.scrollChild:SetHeight(#configsToShow * 60)
    else
        frame.scrollChild:SetHeight(100)
        
        if not frame.scrollChild.noConfigsText then
            frame.scrollChild.noConfigsText = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            frame.scrollChild.noConfigsText:SetPoint("CENTER")
            frame.scrollChild.noConfigsText:SetText("Нет конфигов в этой категории")
        end
        frame.scrollChild.noConfigsText:Show()
    end
end

function CreateConfigButton(index)
    local button = CreateFrame("Frame", nil, frame.scrollChild)
    button:SetSize(560, 55)
    button:SetPoint("TOPLEFT", 0, -(index-1) * 60)
    
    button:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    button:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    button:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    
    button.name = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.name:SetPoint("TOPLEFT", 10, -8)
    button.name:SetJustifyH("LEFT")
    button.name:SetWidth(300)
    
    button.details = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.details:SetPoint("TOPLEFT", 10, -25)
    button.details:SetJustifyH("LEFT")
    
    button.copyBtn = CreateFrame("Button", nil, button, "UIPanelButtonTemplate")
    button.copyBtn:SetSize(80, 22)
    button.copyBtn:SetPoint("BOTTOMRIGHT", -10, 5)
    button.copyBtn:SetText("Копировать")
    
    button.infoBtn = CreateFrame("Button", nil, button, "UIPanelButtonTemplate")
    button.infoBtn:SetSize(60, 22)
    button.infoBtn:SetPoint("BOTTOMRIGHT", -95, 5)
    button.infoBtn:SetText("Инфо")
    
    return button
end

function ConfigureConfigButton(button, name, config, index)
    button.name:SetText("|cFFFFFFFF" .. name .. "|r")
    button.details:SetText(string.format("Автор: |cFF00FF00%s|r", config.author))
    
    button.copyBtn:SetScript("OnClick", function()
        ShowCopyWindow(name, config)
    end)
    
    button.infoBtn:SetScript("OnClick", function()
        ShowConfigInfo(name, config)
    end)
    
    button:SetScript("OnEnter", function()
        button:SetBackdropColor(0.2, 0.2, 0.2, 0.9)
        button:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    end)
    
    button:SetScript("OnLeave", function()
        button:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        button:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    end)
end

function SearchConfigs(searchText)
    searchResults = {}
    
    if searchText and searchText:len() > 2 then
        local searchLower = string.lower(searchText)
        
        for category, configs in pairs(AferistHelperDB.configs) do
            for name, config in pairs(configs) do
                if string.find(string.lower(name), searchLower) or
                   string.find(string.lower(config.description or ""), searchLower) then
                    table.insert(searchResults, {name = name, config = config})
                end
            end
        end
    end
    
    RefreshConfigList()
end

function ShowConfigInfo(name, config)
    local infoFrame = CreateFrame("Frame", "AferistHelperInfoFrame", UIParent, "BasicFrameTemplate")
    infoFrame:SetSize(500, 400)
    infoFrame:SetPoint("CENTER", -100, 0)
    infoFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    infoFrame:SetMovable(true)
    infoFrame:EnableMouse(true)
    infoFrame:RegisterForDrag("LeftButton")
    infoFrame:SetScript("OnDragStart", infoFrame.StartMoving)
    infoFrame:SetScript("OnDragStop", infoFrame.StopMovingOrSizing)
    
    infoFrame.title = infoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoFrame.title:SetPoint("TOP", 0, -5)
    infoFrame.title:SetText("Информация о конфиге")
    
    local scrollFrame = CreateFrame("ScrollFrame", "AferistHelperInfoScrollFrame", infoFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)
    
    local scrollChild = CreateFrame("Frame", "AferistHelperInfoScrollChild", scrollFrame)
    scrollFrame:SetScrollChild(scrollChild)
    scrollChild:SetSize(460, 600)
    
    local infoStartY = -10
    
    local nameText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameText:SetPoint("TOP", 0, infoStartY)
    nameText:SetText("|cFFFFFF00" .. name .. "|r")
    
    local details = {
        string.format("Автор: |cFF00FF00%s|r", config.author),
        string.format("Обновлен: |cFFFFFFFF%s|r", date("%Y-%m-%d", config.last_updated))
    }
    
	if config.class and config.class ~= "ALL" then
		table.insert(details, string.format("Класс: |cFFFFFFFF%s|r", config.class))
	end
    
    for i, detail in ipairs(details) do
        local text = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("TOPLEFT", 20, infoStartY - 30 - (i-1)*20)
        text:SetText(detail)
        text:SetJustifyH("LEFT")
    end
    
    local featuresStartY = infoStartY - 30 - (#details * 20)
    
    if config.features and #config.features > 0 then
        local featuresText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        featuresText:SetPoint("TOP", 0, featuresStartY)
        featuresText:SetText("Особенности:")
        
        for i, feature in ipairs(config.features) do
            local featureText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            featureText:SetPoint("TOP", 0, featuresStartY - 20 - (i-1)*18)
            featureText:SetText("• " .. feature)
        end
        
        featuresStartY = featuresStartY - 20 - (#config.features * 18)
    end
    
    local descText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    descText:SetPoint("TOP", 0, featuresStartY - 10)
    descText:SetText("Описание:")
    
    local desc = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOP", 0, featuresStartY - 30)
    desc:SetText(config.description or "Нет описания")
    desc:SetWidth(440)
    desc:SetJustifyH("LEFT")
    desc:SetJustifyV("TOP")
    
    local closeBtn = CreateFrame("Button", nil, infoFrame, "UIPanelButtonTemplate")
    closeBtn:SetSize(100, 25)
    closeBtn:SetPoint("BOTTOM", 0, 10)
    closeBtn:SetText("Закрыть")
    closeBtn:SetScript("OnClick", function() infoFrame:Hide() end)
    
end

function CreateClassRecommendationsFrame()
    classFrame = CreateFrame("Frame", "AferistHelperClassFrame", UIParent, "BasicFrameTemplate")
    classFrame:SetSize(700, 550)
    classFrame:SetPoint("CENTER")
    classFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    classFrame:SetMovable(true)
    classFrame:EnableMouse(true)
    classFrame:RegisterForDrag("LeftButton")
    classFrame:SetScript("OnDragStart", classFrame.StartMoving)
    classFrame:SetScript("OnDragStop", classFrame.StopMovingOrSizing)
    
    classFrame.title = classFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    classFrame.title:SetPoint("TOP", 0, -5)
    
    classFrame:Hide()
    
    CreateClassRecommendationsContent()
end

function CreateClassRecommendationsContent()
    classFrame.content = CreateFrame("Frame", nil, classFrame)
    classFrame.content:SetPoint("TOPLEFT", 10, -50)
    classFrame.content:SetPoint("BOTTOMRIGHT", -10, 40)
    
    classFrame.welcomeText = classFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    classFrame.welcomeText:SetPoint("TOP", 0, -35)
    classFrame.welcomeText:SetJustifyH("CENTER")
    
    classFrame.scrollFrame = CreateFrame("ScrollFrame", "AferistHelperClassScrollFrame", classFrame.content, "UIPanelScrollFrameTemplate")
    classFrame.scrollFrame:SetPoint("TOPLEFT", 5, -10)
    classFrame.scrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)
    
    classFrame.scrollChild = CreateFrame("Frame", "AferistHelperClassScrollChild", classFrame.scrollFrame)
    classFrame.scrollFrame:SetScrollChild(classFrame.scrollChild)
    classFrame.scrollChild:SetSize(650, 400)
end

function ShowClassRecommendations()
    if not classFrame then return end
    
    classFrame.title:SetText(string.format("Рекомендации для |cFFFFFFFF%s|r", currentPlayerClass))
	classFrame.welcomeText:SetText(string.format("Подборка лучших конфигов для |cFFFFFFFF%s|r", currentPlayerClass))
    
    local classConfigs = GetConfigsForClass(currentPlayerClass)
    
    DisplayClassConfigs(classConfigs)
    
    classFrame:Show()
end

function GetConfigsForClass(playerClass)
    local configs = {}
    local priorityConfigs = {}
    
    for category, categoryConfigs in pairs(AferistHelperDB.configs) do
        for name, config in pairs(categoryConfigs) do
            if config.class == playerClass or config.class == "ALL" then
                local configData = {
                    name = name,
                    config = config,
                    category = category
                }
                
                if config.class == playerClass then
                    table.insert(priorityConfigs, configData)
                else
                    table.insert(configs, configData)
                end
            end
        end
    end
    
    for _, config in ipairs(configs) do
        table.insert(priorityConfigs, config)
    end
    
    return priorityConfigs
end

function DisplayClassConfigs(configs)
    if not classFrame.scrollChild then return end
    
    if classFrame.scrollChild.buttons then
        for i, button in ipairs(classFrame.scrollChild.buttons) do
            if button then
                button:Hide()
            end
        end
    end
    
    classFrame.scrollChild.buttons = {}
    
    for i, configData in ipairs(configs) do
        local card = CreateClassConfigCard(i)
        ConfigureClassConfigCard(card, configData.name, configData.config, configData.category, i)
        card:Show()
        classFrame.scrollChild.buttons[i] = card
    end
    
    if #configs > 0 then
        classFrame.scrollChild:SetHeight(#configs * 120)
    else
        classFrame.scrollChild:SetHeight(100)
        
        if not classFrame.scrollChild.noConfigsText then
            classFrame.scrollChild.noConfigsText = classFrame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            classFrame.scrollChild.noConfigsText:SetPoint("CENTER")
            classFrame.scrollChild.noConfigsText:SetText("Нет конфигов для вашего класса")
        end
        classFrame.scrollChild.noConfigsText:Show()
    end
end

function CreateClassConfigCard(index)
    local card = CreateFrame("Frame", nil, classFrame.scrollChild)
    card:SetSize(630, 115)
    card:SetPoint("TOPLEFT", 0, -(index-1) * 120)
    
    card:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    card:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
    card:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.3)
    
    card.infoArea = CreateFrame("Frame", nil, card)
    card.infoArea:SetPoint("TOPLEFT", 10, -10)
    card.infoArea:SetPoint("BOTTOMRIGHT", -10, 10)
    
    card.name = card.infoArea:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.name:SetPoint("TOPLEFT", 0, 0)
    card.name:SetJustifyH("LEFT")
    card.name:SetWidth(400)
    
    card.category = card.infoArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.category:SetPoint("TOPLEFT", 0, -20)
    card.category:SetJustifyH("LEFT")
    
    card.description = card.infoArea:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    card.description:SetPoint("TOPLEFT", 0, -35)
    card.description:SetJustifyH("LEFT")
    card.description:SetWidth(400)
    card.description:SetHeight(30)
    
    card.details = card.infoArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.details:SetPoint("BOTTOMLEFT", 0, 5)
    card.details:SetJustifyH("LEFT")
    
    card.copyBtn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
    card.copyBtn:SetSize(80, 22)
    card.copyBtn:SetPoint("BOTTOMRIGHT", -10, 5)
    card.copyBtn:SetText("Копировать")
    
    card.infoBtn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
    card.infoBtn:SetSize(60, 22)
    card.infoBtn:SetPoint("BOTTOMRIGHT", -95, 5)
    card.infoBtn:SetText("Инфо")
    
    return card
end

function ConfigureClassConfigCard(card, name, config, category, index)
    card.name:SetText("|cFFFFFFFF" .. name .. "|r")
    card.category:SetText(string.format("Категория: |cFF00FF00%s|r", category:upper()))
    card.description:SetText(config.description or "Нет описания")
    
    card.details:SetText(string.format("Автор: |cFF00FF00%s|r", config.author))
    
    card.copyBtn:SetScript("OnClick", function()
        ShowCopyWindow(name, config)
    end)
    
    card.infoBtn:SetScript("OnClick", function()
        ShowConfigInfo(name, config)
    end)
    
    card:SetScript("OnEnter", function()
        card:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
        card:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    end)
    
    card:SetScript("OnLeave", function()
        card:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
        card:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.3)
    end)
end

function CreateMailDonationFrame()
    local mailFrame = CreateFrame("Frame", "AferistHelperMailFrame", UIParent)
    mailFrame:SetSize(400, 200)
    mailFrame:SetPoint("CENTER", 0, 100)
    mailFrame:SetFrameStrata("DIALOG")
    mailFrame:SetMovable(true)
    mailFrame:EnableMouse(true)
    mailFrame:RegisterForDrag("LeftButton")
    mailFrame:SetScript("OnDragStart", mailFrame.StartMoving)
    mailFrame:SetScript("OnDragStop", mailFrame.StopMovingOrSizing)
    
    mailFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    
    mailFrame.title = mailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mailFrame.title:SetPoint("TOP", 0, -15)
    mailFrame.title:SetText("Aferist Helper")
    
    local messageText = mailFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    messageText:SetPoint("TOP", 0, -40)
    messageText:SetWidth(360)
    messageText:SetJustifyH("CENTER")
    messageText:SetJustifyV("TOP")
    messageText:SetText("Вижу, ты используешь аддон Aferist Helper...\n\nЕсли тебе понравился данный аддон и ты хочешь как-то поощрить старания автора - можешь отправить любую сумму золота на ник |cFFFFD700Worog|r. :)\n\nСпасибо за использование аддона!")
    
    mailFrame.closeBtn = CreateFrame("Button", nil, mailFrame, "UIPanelCloseButton")
    mailFrame.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    mailFrame.closeBtn:SetScript("OnClick", function() mailFrame:Hide() end)
    
    local dontShowBtn = CreateFrame("Button", nil, mailFrame, "UIPanelButtonTemplate")
    dontShowBtn:SetSize(140, 25)
    dontShowBtn:SetPoint("BOTTOM", 0, 15)
    dontShowBtn:SetText("Больше не показывать")
    dontShowBtn:SetScript("OnClick", function()
        AferistHelperDB.mailDonationShown = true
        mailFrame:Hide()
    end)
    
    local closeBtn = CreateFrame("Button", nil, mailFrame, "UIPanelButtonTemplate")
    closeBtn:SetSize(100, 25)
    closeBtn:SetPoint("BOTTOM", 0, 45)
    closeBtn:SetText("Закрыть")
    closeBtn:SetScript("OnClick", function() mailFrame:Hide() end)
    
    mailFrame:Hide()
    return mailFrame
end

function ShowMailDonationMessage()
    if AferistHelperDB.mailDonationShown then
        return
    end
    
    if mailShownCount >= MAX_MAIL_SHOW_COUNT then
        AferistHelperDB.mailDonationShown = true
        return
    end
    
    if not AferistHelperMailFrame then
        CreateMailDonationFrame()
    end
    
    AferistHelperMailFrame:Show()
    mailShownCount = mailShownCount + 1
    AferistHelperDB.mailShownCount = mailShownCount
    
    if mailShownCount >= MAX_MAIL_SHOW_COUNT then
        AferistHelperDB.mailDonationShown = true
    end
end

local mailEventHandler = CreateFrame("Frame")
mailEventHandler:RegisterEvent("MAIL_SHOW")
mailEventHandler:SetScript("OnEvent", function(self, event)
    if event == "MAIL_SHOW" then
        local timerFrame = CreateFrame("Frame")
        local elapsed = 0
        timerFrame:SetScript("OnUpdate", function(self, delta)
            elapsed = elapsed + delta
            if elapsed >= 1 then
                ShowMailDonationMessage()
                self:SetScript("OnUpdate", nil)
            end
        end)
    end
end)

SLASH_AFERISTHELPER1 = "/ah"
SLASH_AFERISTHELPER2 = "/aferisthelper"

SlashCmdList["AFERISTHELPER"] = function(msg)
    msg = msg:lower()
    
    if msg == "reset" then
        AferistHelperDB = {
            _metadata = {
                version = "1.0.0",
                last_updated = time()
            },
            configs = {},
            favorites = {},
            class = currentPlayerClass,
            mailDonationShown = false,
            mailShownCount = 0
        }
        LoadDefaulConfigs()
        RefreshConfigList()
        print("|cFF00FF00Aferist Helper:|r База конфигов полностью сброшена и перезагружена")
    elseif msg == "class" or msg == "recommend" then
        ShowClassRecommendations()
    elseif msg == "help" then
        print("|cFF00FF00Aferist Helper команды:|r")
        print("|cFFFFFF00/ah|r - открыть главное окно")
        print("|cFFFFFF00/ah class|r - рекомендации для вашего класса")
        print("|cFFFFFF00/ah reset|r - сбросить базу конфигов")
        print("|cFFFFFF00/ah help|r - показать эту справку")
    else
        if frame and frame:IsShown() then
            frame:Hide()
        else
            if not frame then
                CreateMainFrame()
            end
            frame:Show()
            RefreshConfigList()
        end
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "AferistHelper" then
        FixElvUIConflict()
        
        currentPlayerClass = select(2, UnitClass("player"))
        AferistHelperDB.class = currentPlayerClass
        
        if not AferistHelperDB.configs or not next(AferistHelperDB.configs) then
            if type(LoadDefaultConfigs) == "function" then
                LoadDefaultConfigs()
            else
                AferistHelperDB.configs = {
                    elvui = {},
                    weakauras = {},
                    details = {},
                    other = {
                        ["DBM настройки"] = {
                            author = "SegaZBS",
                            description = "Оптимизированные настройки DeadlyBossMods для всех рейдов",
                            config_string = "В разработке",
                            last_updated = time(),
                            class = "ALL",
                            features = {"Таймеры", "Предупреждения", "Спец-предупреждения"}
                        }
                    }
                }
                AferistHelperDB._metadata.last_updated = time()
            end
        end
        
        mailShownCount = AferistHelperDB.mailShownCount or 0
        
        CreateMainFrame()
        CreateClassRecommendationsFrame()
        
        print("|cFF00FF00Aferist Helper|r загружен! Используйте |cFFFFFF00/ah|r для открытия.")
        print("|cFFFFFF00Рекомендации для |r" .. currentPlayerClass .. "|cFFFFFF00: /ah class|r")
        
        self:UnregisterEvent("ADDON_LOADED")
    end
end)