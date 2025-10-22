--[[
MuteManager - временное понижение ранга в гильдии
Графический интерфейс
--]]

local MAJOR, MINOR = "MuteManager", 1
local MuteManager = {
    db = {
        muteRank = 4,
        activeMutes = {},
        guildRanks = {},
        settings = {
            autoDemote = true,
            useOfficerNotes = true,
            showNotifications = true,
            cleanupDays = 30,
        }
    },
    commandQueue = {},
    cleanupCandidates = {}
}

local minimapButton

function CreateMinimapButton()
    minimapButton = CreateFrame("Button", "AferistHelperMinimapButton", Minimap)
    minimapButton:SetSize(32, 32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetMovable(true)
    minimapButton:EnableMouse(true)
    minimapButton:RegisterForDrag("LeftButton")
    
    minimapButton.icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    minimapButton.icon:SetSize(20, 20)
    minimapButton.icon:SetPoint("CENTER")
    minimapButton.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    
    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    
    minimapButton:RegisterForClicks("AnyUp")
    minimapButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            ToggleMinimapMenu()
        end
    end)
    
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Aferist Helper", 1, 1, 1)
        GameTooltip:AddLine("ЛКМ - Меню", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    
    minimapButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", -80, 0)
    
    minimapButton:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    
    minimapButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
end

function ToggleMinimapMenu()
    local menuFrame = CreateFrame("Frame", "AferistHelperMinimapMenu", UIParent, "UIDropDownMenuTemplate")
    
    local menuItems = {
        {
            text = "Aferist Helper",
            isTitle = true,
            notCheckable = true
        },
        {
            text = "Библиотека конфигов",
            func = function() 
                SlashCmdList["AFERISTHELPER"]("")
            end,
            notCheckable = true
        },
        {
            text = "Рекомендации для класса",
            func = function() 
                SlashCmdList["AFERISTHELPER"]("class")
            end,
            notCheckable = true
        },
        {
            text = "Управление гильдией",
            isTitle = true,
            notCheckable = true
        },
        {
            text = "MuteManager",
            func = function() 
                -- Проверяем права при клике, а не при создании меню
                if not IsInGuild() then
                    MuteManager:ShowNotification("Ошибка: Вы не в гильдии")
                    return
                end
                if not CanEditOfficerNote() then
                    MuteManager:ShowNotification("Ошибка: Недостаточно прав офицера")
                    return
                end
                MuteManager:ToggleWindow()
            end,
            notCheckable = true
        },
        {
            text = "Активные муты",
            func = function() 
                -- Проверяем права при клике, а не при создании меню
                if not IsInGuild() then
                    MuteManager:ShowNotification("Ошибка: Вы не в гильдии")
                    return
                end
                if not CanEditOfficerNote() then
                    MuteManager:ShowNotification("Ошибка: Недостаточно прав офицера")
                    return
                end
                MuteManager:ToggleWindow()
            end,
            notCheckable = true
        },
        {
            text = "Настройки мутов",
            func = function() 
                -- Проверяем права при клике, а не при создании меню
                if not IsInGuild() then
                    MuteManager:ShowNotification("Ошибка: Вы не в гильдии")
                    return
                end
                if not CanEditOfficerNote() then
                    MuteManager:ShowNotification("Ошибка: Недостаточно прав офицера")
                    return
                end
                MuteManager:ToggleWindow()
            end,
            notCheckable = true
        },
        {
            text = "Очистка гильдии",
            func = function() 
                -- Проверяем права при клике, а не при создании меню
                if not IsInGuild() then
                    MuteManager:ShowNotification("Ошибка: Вы не в гильдии")
                    return
                end
                if not CanEditOfficerNote() then
                    MuteManager:ShowNotification("Ошибка: Недостаточно прав офицера")
                    return
                end
                MuteManager:ToggleWindow()
            end,
            notCheckable = true
        }
    }
    
    EasyMenu(menuItems, menuFrame, "cursor", 0, 0, "MENU")
end



function MuteManager:CreateMainWindow()
    local frame = CreateFrame("Frame", "MuteManagerFrame", UIParent, "BasicFrameTemplate")
    frame:SetSize(450, 550)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", 0, -5)
    frame.title:SetText("MuteManager")

    self.mainFrame = frame
    self:CreateUIElements(frame)
end

function MuteManager:CreateUIElements(parent)
    local tabs = {"Основное", "Активные муты", "Настройки", "Очистка"}
    local tabFrames = {}
    
    for i, tabName in ipairs(tabs) do
        local tab = CreateFrame("Button", "MuteManagerTab"..i, parent, "CharacterFrameTabButtonTemplate")
        tab:SetText(tabName)
        tab:SetID(i)
        tab:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 5 + ((i-1) * 100), 2)
        tab:SetScript("OnClick", function() 
            self:ShowTab(i) 
        end)
        
        local tabFrame = CreateFrame("Frame", nil, parent)
        tabFrame:SetSize(430, 480)
        tabFrame:SetPoint("TOPLEFT", 10, -30)
        tabFrame:Hide()
        
        tabFrames[i] = tabFrame
        
        if i == 1 then
            self:CreateMainTab(tabFrame)
        elseif i == 2 then
            self:CreateActiveMutesTab(tabFrame)
        elseif i == 3 then
            self:CreateSettingsTab(tabFrame)
        elseif i == 4 then
            self:CreateCleanupTab(tabFrame)
        end
    end
    
    self.tabFrames = tabFrames
    self:ShowTab(1)
end


function MuteManager:CreateMainTab(parent)
    local nameLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", 10, -10)
    nameLabel:SetText("Ник игрока:")
    
    local nameEdit = CreateFrame("EditBox", nil, parent)
    nameEdit:SetSize(180, 20)
    nameEdit:SetPoint("TOPLEFT", 100, -10)
    nameEdit:SetAutoFocus(false)
    nameEdit:SetFontObject("GameFontNormal")
    nameEdit:SetTextInsets(8, 8, 0, 0)
    
    nameEdit:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    nameEdit:SetBackdropColor(0, 0, 0, 0.5)
    nameEdit:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    
    nameEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    local timeLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timeLabel:SetPoint("TOPLEFT", 10, -40)
    timeLabel:SetText("Время (минуты):")
    
    local timeEdit = CreateFrame("EditBox", nil, parent)
    timeEdit:SetSize(100, 20)
    timeEdit:SetPoint("TOPLEFT", 100, -40)
    timeEdit:SetAutoFocus(false)
    timeEdit:SetNumeric(true)
    timeEdit:SetFontObject("GameFontNormal")
    timeEdit:SetTextInsets(8, 8, 0, 0)
    
    timeEdit:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    timeEdit:SetBackdropColor(0, 0, 0, 0.5)
    timeEdit:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    
    timeEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    local reasonLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    reasonLabel:SetPoint("TOPLEFT", 10, -70)
    reasonLabel:SetText("Причина:")
    
    local reasonEdit = CreateFrame("EditBox", nil, parent)
    reasonEdit:SetSize(180, 20)
    reasonEdit:SetPoint("TOPLEFT", 100, -70)
    reasonEdit:SetAutoFocus(false)
    reasonEdit:SetFontObject("GameFontNormal")
    reasonEdit:SetTextInsets(8, 8, 0, 0)
    
    reasonEdit:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    reasonEdit:SetBackdropColor(0, 0, 0, 0.5)
    reasonEdit:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    
    reasonEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    local muteBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    muteBtn:SetSize(120, 25)
    muteBtn:SetPoint("TOPLEFT", 10, -100)
    muteBtn:SetText("Замутить")
    muteBtn:SetScript("OnClick", function()
        self:MuteFromUI(nameEdit:GetText(), timeEdit:GetText(), reasonEdit:GetText())
    end)
    
    local unmuteBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    unmuteBtn:SetSize(120, 25)
    unmuteBtn:SetPoint("TOPLEFT", 140, -100)
    unmuteBtn:SetText("Размутить")
    unmuteBtn:SetScript("OnClick", function()
        self:UnmuteFromUI(nameEdit:GetText())
    end)
    
    local playerInfo = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    playerInfo:SetPoint("TOPLEFT", 10, -140)
    playerInfo:SetSize(360, 100)
    playerInfo:SetJustifyH("LEFT")
    playerInfo:SetText("Информация об игроке появится здесь")
    
    local checkBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    checkBtn:SetSize(120, 25)
    checkBtn:SetPoint("TOPLEFT", 10, -250)
    checkBtn:SetText("Проверить игрока")
    checkBtn:SetScript("OnClick", function()
        self:ShowPlayerInfo(nameEdit:GetText(), playerInfo)
    end)
    
    parent.nameEdit = nameEdit
    parent.timeEdit = timeEdit
    parent.reasonEdit = reasonEdit
    parent.playerInfo = playerInfo
end


function MuteManager:CreateActiveMutesTab(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    local scrollChild = CreateFrame("Frame")
    scrollFrame:SetScrollChild(scrollChild)
    scrollChild:SetSize(350, 400)
    
    local content = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    content:SetPoint("TOPLEFT")
    content:SetSize(350, 400)
    content:SetJustifyH("LEFT")
    
    parent.content = content
    parent.scrollFrame = scrollFrame
    
    local refreshBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    refreshBtn:SetSize(120, 25)
    refreshBtn:SetPoint("BOTTOMLEFT", 10, 10)
    refreshBtn:SetText("Обновить")
    refreshBtn:SetScript("OnClick", function()
        self:UpdateActiveMutesTab()
    end)
end


function MuteManager:CreateSettingsTab(parent)
    local yOffset = -10
    
    local rankLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rankLabel:SetPoint("TOPLEFT", 10, yOffset)
    rankLabel:SetText("Ранг для мута:")
    
    local rankDropdown = CreateFrame("Frame", "MuteManagerRankDropdown", parent, "UIDropDownMenuTemplate")
    rankDropdown:SetPoint("TOPLEFT", 120, yOffset)
    rankDropdown.initialize = function() self:InitializeRankDropdown() end
    rankDropdown:Show()
    
    yOffset = yOffset - 40
    
    local notesCheckbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    notesCheckbox:SetPoint("TOPLEFT", 10, yOffset)
    notesCheckbox:SetChecked(self.db.settings.useOfficerNotes)
    notesCheckbox:SetScript("OnClick", function(self)
        MuteManager.db.settings.useOfficerNotes = self:GetChecked()
    end)
    
    local notesLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    notesLabel:SetPoint("TOPLEFT", 40, yOffset - 5)
    notesLabel:SetText("Использовать офицерские заметки")
    
    yOffset = yOffset - 40
    
    local notifyCheckbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    notifyCheckbox:SetPoint("TOPLEFT", 10, yOffset)
    notifyCheckbox:SetChecked(self.db.settings.showNotifications)
    notifyCheckbox:SetScript("OnClick", function(self)
        MuteManager.db.settings.showNotifications = self:GetChecked()
    end)
    
    local notifyLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    notifyLabel:SetPoint("TOPLEFT", 40, yOffset - 5)
    notifyLabel:SetText("Показывать уведомления")
    
    yOffset = yOffset - 40
    
    local cleanupLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cleanupLabel:SetPoint("TOPLEFT", 10, yOffset)
    cleanupLabel:SetText("Дни для очистки:")
    
    local cleanupEdit = CreateFrame("EditBox", nil, parent)
    cleanupEdit:SetSize(60, 20)
    cleanupEdit:SetPoint("TOPLEFT", 120, yOffset)
    cleanupEdit:SetAutoFocus(false)
    cleanupEdit:SetNumeric(true)
    cleanupEdit:SetFontObject("GameFontNormal")
    cleanupEdit:SetTextInsets(8, 8, 0, 0)
    cleanupEdit:SetText(tostring(self.db.settings.cleanupDays))
    
    cleanupEdit:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    cleanupEdit:SetBackdropColor(0, 0, 0, 0.5)
    cleanupEdit:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    
    cleanupEdit:SetScript("OnTextChanged", function(self)
        local days = tonumber(self:GetText())
        if days and days > 0 then
            MuteManager.db.settings.cleanupDays = days
        end
    end)
    
    cleanupEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    yOffset = yOffset - 60
    
    local statsLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsLabel:SetPoint("TOPLEFT", 10, yOffset)
    statsLabel:SetText("Статистика:")
    
    local statsText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsText:SetPoint("TOPLEFT", 10, yOffset - 20)
    statsText:SetSize(360, 100)
    statsText:SetJustifyH("LEFT")
    
    parent.statsText = statsText
    
    local statsBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    statsBtn:SetSize(120, 25)
    statsBtn:SetPoint("TOPLEFT", 10, yOffset - 120)
    statsBtn:SetText("Обновить статистику")
    statsBtn:SetScript("OnClick", function()
        self:UpdateStats()
    end)
end


function MuteManager:CreateCleanupTab(parent)
    local yOffset = -10
    
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, yOffset)
    title:SetText("Очистка неактивных игроков")
    title:SetTextColor(1, 1, 0)
    
    yOffset = yOffset - 30
    
    local daysLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    daysLabel:SetPoint("TOPLEFT", 10, yOffset)
    daysLabel:SetText("Дней неактивности:")
    
    local daysEdit = CreateFrame("EditBox", nil, parent)
    daysEdit:SetSize(60, 20)
    daysEdit:SetPoint("TOPLEFT", 130, yOffset)
    daysEdit:SetAutoFocus(false)
    daysEdit:SetNumeric(true)
    daysEdit:SetFontObject("GameFontNormal")
    daysEdit:SetTextInsets(8, 8, 0, 0)
    daysEdit:SetText(tostring(self.db.settings.cleanupDays))
    
    daysEdit:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    daysEdit:SetBackdropColor(0, 0, 0, 0.5)
    daysEdit:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    
    daysEdit:SetScript("OnTextChanged", function(self)
        local days = tonumber(self:GetText())
        if days and days > 0 then
            MuteManager.db.settings.cleanupDays = days
        end
    end)
    
    daysEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    yOffset = yOffset - 30
    
    local findBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    findBtn:SetSize(120, 25)
    findBtn:SetPoint("TOPLEFT", 10, yOffset)
    findBtn:SetText("Найти неактивных")
    findBtn:SetScript("OnClick", function()
        local days = tonumber(daysEdit:GetText()) or 30
        self.db.settings.cleanupDays = days
        self:FindInactivePlayers(days)
    end)
    
    yOffset = yOffset - 40
    
    local candidatesLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    candidatesLabel:SetPoint("TOPLEFT", 10, yOffset)
    candidatesLabel:SetText("Кандидаты на удаление:")
    
    yOffset = yOffset - 20
    
    local scrollFrame = CreateFrame("ScrollFrame", "MuteManagerCleanupScroll", parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, yOffset)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 50)
    
    local scrollChild = CreateFrame("Frame")
    scrollFrame:SetScrollChild(scrollChild)
    scrollChild:SetSize(390, 400)
    
    local checkboxesContainer = CreateFrame("Frame", nil, scrollChild)
    checkboxesContainer:SetAllPoints()
    
    local removeBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    removeBtn:SetSize(120, 25)
    removeBtn:SetPoint("BOTTOMLEFT", 10, 10)
    removeBtn:SetText("Удалить отмеченных")
    removeBtn:SetScript("OnClick", function()
        self:RemoveSelectedPlayers()
    end)
    
    local statusText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("BOTTOMLEFT", 140, 15)
    statusText:SetSize(250, 30)
    statusText:SetJustifyH("LEFT")
    statusText:SetText("Нажмите 'Найти неактивных' для поиска")
    
    parent.daysEdit = daysEdit
    parent.scrollFrame = scrollFrame
    parent.checkboxesContainer = checkboxesContainer
    parent.statusText = statusText
    parent.removeBtn = removeBtn
end

function MuteManager:ShowTab(tabIndex)
    for i, frame in ipairs(self.tabFrames) do
        if i == tabIndex then
            frame:Show()
            if i == 2 then
                self:UpdateActiveMutesTab()
            elseif i == 3 then
                self:UpdateStats()
            elseif i == 4 then
                self.cleanupCandidates = {}
                self.tabFrames[4].statusText:SetText("Нажмите 'Найти неактивных' для поиска")
                self.tabFrames[4].removeBtn:Disable()
            end
        else
            frame:Hide()
        end
    end
end


function MuteManager:InitializeRankDropdown()
    local info = UIDropDownMenu_CreateInfo()
    
    for i = 0, #self.db.guildRanks do
        if self.db.guildRanks[i] then
            info.text = i .. " - " .. self.db.guildRanks[i]
            info.value = i
            info.checked = (i == self.db.muteRank)
            info.func = function(self)
                MuteManager.db.muteRank = self.value
                UIDropDownMenu_SetText(MuteManager.tabFrames[3].rankDropdown, self.value .. " - " .. MuteManager.db.guildRanks[self.value])
            end
            UIDropDownMenu_AddButton(info)
        end
    end
end

function MuteManager:MuteFromUI(name, timeText, reason)
    if not name or name == "" then
        self:ShowNotification("Введите ник игрока")
        return
    end
    
    local duration = tonumber(timeText)
    if not duration or duration <= 0 then
        self:ShowNotification("Введите корректное время")
        return
    end
    
    self:MutePlayer(name, duration, reason)
    
    if self.tabFrames[1].nameEdit then
        self.tabFrames[1].nameEdit:SetText("")
        self.tabFrames[1].timeEdit:SetText("")
        self.tabFrames[1].reasonEdit:SetText("")
        self.tabFrames[1].playerInfo:SetText("Информация об игроке появится здесь")
    end
end

function MuteManager:UnmuteFromUI(name)
    if not name or name == "" then
        self:ShowNotification("Введите ник игрока")
        return
    end
    
    self:UnmutePlayer(name)
end


function MuteManager:ShowPlayerInfo(playerName, infoFrame)
    if not playerName or playerName == "" then
        infoFrame:SetText("Введите ник игрока")
        return
    end
    
    local playerInfo = self:GetPlayerInfo(playerName)
    if not playerInfo then
        infoFrame:SetText("Игрок не найден в гильдии")
        return
    end
    
    local infoText = string.format(
        "Игрок: |cFFFFFFFF%s|r\n" ..
        "Ранг: |cFFFFFFFF%s (%d)|r\n" ..
        "Статус: |cFFFFFFFF%s|r\n" ..
        "Класс: |cFFFFFFFF%s|r\n" ..
        "Зона: |cFFFFFFFF%s|r",
        playerInfo.fullName,
        playerInfo.rankName,
        playerInfo.rankIndex,
        playerInfo.online and "|cFF00FF00Онлайн|r" or "|cFFFF0000Оффлайн|r",
        playerInfo.class or "Неизвестно",
        playerInfo.zone or "Неизвестно"
    )
    
    if self.db.activeMutes[playerName] then
        local muteData = self.db.activeMutes[playerName]
        local remaining = math.max(0, muteData.expireTime - time())
        local remainingMinutes = math.floor(remaining / 60)
        
        infoText = infoText .. string.format(
            "\n\n|cFFFF0000ЗАМУЧЕН|r\n" ..
            "Осталось: |cFFFFFFFF%d минут|r\n" ..
            "Причина: |cFFFFFFFF%s|r\n" ..
            "Выдал: |cFFFFFFFF%s|r",
            remainingMinutes,
            muteData.reason or "не указана",
            muteData.mutedBy or "неизвестно"
        )
    end
    
    infoFrame:SetText(infoText)
end


function MuteManager:UpdateActiveMutesTab()
    local content = self.tabFrames[2].content
    if not content then return end
    
    if not next(self.db.activeMutes) then
        content:SetText("Активных мутов нет")
        return
    end
    
    local text = "|cFF00FF00Активные муты:|r\n\n"
    local count = 0
    
    for playerName, muteData in pairs(self.db.activeMutes) do
        count = count + 1
        local remaining = math.max(0, muteData.expireTime - time())
        local remainingMinutes = math.floor(remaining / 60)
        local remainingSeconds = remaining % 60
        
        text = text .. string.format(
            "|cFFFF0000%s|r\n" ..
            "  Осталось: %d:%02d\n" ..
            "  Причина: %s\n" ..
            "  Выдал: %s\n\n",
            playerName,
            remainingMinutes,
            remainingSeconds,
            muteData.reason or "не указана",
            muteData.mutedBy or "неизвестно"
        )
        
        if count >= 10 then
            text = text .. "... и другие (" .. (self:CountActiveMutes() - count) .. ")\n"
            break
        end
    end
    
    content:SetText(text)
end


function MuteManager:UpdateStats()
    local statsText = self.tabFrames[3].statsText
    if not statsText then return end
    
    local totalMutes = self:CountActiveMutes()
    local totalRanks = #self.db.guildRanks + 1
    
    local totalMembers = GetNumGuildMembers()
    local offlineCount = 0
    
    for i = 1, totalMembers do
        local name, rank, rankIndex, level, class, zone, note, officernote, online = GetGuildRosterInfo(i)
        if not online then
            offlineCount = offlineCount + 1
        end
    end
    
    local text = string.format(
        "Активных мутов: |cFFFFFFFF%d|r\n" ..
        "Всего рангов: |cFFFFFFFF%d|r\n" ..
        "Участников в гильдии: |cFFFFFFFF%d|r\n" ..
        "Оффлайн участников: |cFFFFFFFF%d|r\n" ..
        "Дней для очистки: |cFFFFFFFF%d|r\n" ..
        "Текущий ранг мута: |cFFFFFFFF%d - %s|r\n" ..
        "Заметки: |cFFFFFFFF%s|r\n" ..
        "Уведомления: |cFFFFFFFF%s|r",
        totalMutes,
        totalRanks,
        totalMembers,
        offlineCount,
        self.db.settings.cleanupDays,
        self.db.muteRank,
        self.db.guildRanks[self.db.muteRank] or "неизвестно",
        self.db.settings.useOfficerNotes and "Вкл" or "Выкл",
        self.db.settings.showNotifications and "Вкл" or "Выкл"
    )
    
    statsText:SetText(text)
end


function MuteManager:FindInactivePlayers(daysThreshold)
    if not IsInGuild() then
        self:ShowNotification("Ошибка: Вы не в гильдии")
        return
    end
    
    local currentTime = time()
    local thresholdTime = currentTime - (daysThreshold * 86400)
    self.cleanupCandidates = {}
    
    GuildRoster()
    
    for i = 1, GetNumGuildMembers() do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status = GetGuildRosterInfo(i)
        
        local yearsOffline, monthsOffline, daysOffline, hoursOffline = GetGuildRosterLastOnline(i)
        local totalDaysOffline = (yearsOffline or 0) * 365 + (monthsOffline or 0) * 30 + (daysOffline or 0)
        
        if totalDaysOffline >= daysThreshold and not online then
            table.insert(self.cleanupCandidates, {
                name = name,
                rank = rank,
                rankIndex = rankIndex,
                daysOffline = totalDaysOffline,
                officernote = officernote or "",
                class = class or "Неизвестно",
                level = level or "??"
            })
        end
    end
    
    self:UpdateCleanupList()
end


function MuteManager:UpdateCleanupList()
    local parent = self.tabFrames[4]
    local container = parent.checkboxesContainer
    local statusText = parent.statusText
    
    for i = 1, #container do
        if container[i] then
            container[i]:Hide()
        end
    end
    container.checkboxes = {}
    
    if #self.cleanupCandidates == 0 then
        statusText:SetText("Неактивные игроки не найдены")
        parent.removeBtn:Disable()
        return
    end
    
    table.sort(self.cleanupCandidates, function(a, b) 
        return a.daysOffline > b.daysOffline 
    end)
    
    local yOffset = 0
    local maxWidth = 380
    
    for i, candidate in ipairs(self.cleanupCandidates) do
        local checkbox = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", 10, yOffset)
        checkbox:SetChecked(true)
        checkbox.candidateIndex = i
        
        local playerText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        playerText:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
        playerText:SetSize(maxWidth - 40, 30)
        playerText:SetJustifyH("LEFT")
        
        local infoText = string.format("|cFFFFFFFF%s|r |cFFAAAAAA(%d ур.)|r\n%s | %d дн. | %s",
            candidate.name,
            candidate.level,
            candidate.class,
            candidate.daysOffline,
            candidate.officernote ~= "" and "|cFF00FF00Есть заметка|r" or "|cFFFF0000Нет заметки|r"
        )
        
        playerText:SetText(infoText)
        
        container.checkboxes[i] = checkbox
        yOffset = yOffset - 35
        
        if i >= 15 then
            break
        end
    end
    
    statusText:SetText(string.format("Найдено: %d игроков. Отмечено: %d", 
        #self.cleanupCandidates, #self.cleanupCandidates))
    parent.removeBtn:Enable()
    
    container:SetHeight(math.abs(yOffset) + 10)
end


function MuteManager:RemoveSelectedPlayers()
    local parent = self.tabFrames[4]
    local container = parent.checkboxesContainer
    local statusText = parent.statusText
    
    if not container.checkboxes then
        self:ShowNotification("Нет игроков для удаления")
        return
    end
    
    local removedCount = 0
    local skippedCount = 0
    
    for i, checkbox in ipairs(container.checkboxes) do
        if checkbox:GetChecked() and self.cleanupCandidates[i] then
            local candidate = self.cleanupCandidates[i]
            
            if candidate.rankIndex > 0 then
                GuildUninvite(candidate.name)
                removedCount = removedCount + 1
                self:Print("Удален: " .. candidate.name .. " (" .. candidate.daysOffline .. " дней оффлайн)")
            else
                skippedCount = skippedCount + 1
                self:Print("Пропущен: " .. candidate.name .. " (лидер гильдии)")
            end
        end
    end
    
    self:DelayedExecute(2, function()
        GuildRoster()
        self:FindInactivePlayers(self.db.settings.cleanupDays)
    end)
    
    statusText:SetText(string.format("Удалено: %d, Пропущено: %d", removedCount, skippedCount))
    self:ShowNotification("Удаление завершено")
end


function MuteManager:ShowNotification(message)
    if self.db.settings.showNotifications then
        UIErrorsFrame:AddMessage(message, 1.0, 0.1, 0.1, 1.0)
    end
    self:Print(message)
end


function MuteManager:ExecuteGuildCommand(command)
    table.insert(self.commandQueue, command)
    if not self.frame:GetScript("OnUpdate") then
        self:ProcessCommandQueue()
    end
end

function MuteManager:ProcessCommandQueue()
    if #self.commandQueue > 0 then
        local command = table.remove(self.commandQueue, 1)
        if ChatFrame1EditBox then
            ChatFrame1EditBox:SetText(command)
            ChatEdit_SendText(ChatFrame1EditBox)
        end
        self:DelayedExecute(0.8, function()
            self:ProcessCommandQueue()
        end)
    end
end

function MuteManager:CreateTimer(duration, callback)
    local timer = CreateFrame("Frame")
    timer.timeLeft = duration
    timer.callback = callback
    timer:SetScript("OnUpdate", function(self, elapsed)
        self.timeLeft = self.timeLeft - elapsed
        if self.timeLeft <= 0 then
            self:SetScript("OnUpdate", nil)
            if self.callback then
                self.callback()
            end
        end
    end)
    return timer
end

function MuteManager:DelayedExecute(delay, callback)
    local timer = CreateFrame("Frame")
    timer.timeLeft = delay
    timer:SetScript("OnUpdate", function(self, elapsed)
        self.timeLeft = self.timeLeft - elapsed
        if self.timeLeft <= 0 then
            self:SetScript("OnUpdate", nil)
            if callback then
                callback()
            end
        end
    end)
end

function MuteManager:OnLoad()
    self.frame = CreateFrame("Frame")
    self.frame:RegisterEvent("ADDON_LOADED")
    self.frame:RegisterEvent("GUILD_ROSTER_UPDATE")
    self.frame:RegisterEvent("PLAYER_LOGIN")
    self.frame:SetScript("OnEvent", function(_, event, ...) 
        self[event](self, ...) 
    end)
    
    SLASH_AFERISTHELPERADMIN1 = "/ah admin"
    SLASH_AFERISTHELPERADMIN2 = "/ah mute"
    SlashCmdList["AFERISTHELPERADMIN"] = function(msg) 
        if not CheckGuildPermissions() then
            MuteManager:ShowNotification("Ошибка: Недостаточно прав для управления гильдией")
            return
        end
        
        if msg and msg ~= "" then
            self:SlashHandler(msg)
        else
            self:ToggleWindow()
        end
    end
    
    self:Print("MuteManager загружен. Используйте /ah admin для открытия окна.")
end

function MuteManager:ADDON_LOADED(addonName)
    if addonName == "AferistHelper" then
        if MuteManagerDB then
            self.db = MuteManagerDB
        else
            MuteManagerDB = self.db
        end
        self:UpdateGuildRanks()
        self:LoadActiveMutes()
        self:CreateMainWindow()
        self.mainFrame:Hide()
        
        CreateMinimapButton()
    end
end

function MuteManager:PLAYER_LOGIN()
end

function MuteManager:GUILD_ROSTER_UPDATE()
    self:UpdateGuildRanks()
end

function MuteManager:UpdateGuildRanks()
    if not IsInGuild() then return end
    
    self.db.guildRanks = {}
    local numRanks = GuildControlGetNumRanks()
    
    for i = 0, numRanks - 1 do
        self.db.guildRanks[i] = GuildControlGetRankName(i + 1)
    end
end

function MuteManager:GetPlayerInfo(playerName)
    if not IsInGuild() then return nil end
    if not playerName or playerName == "" then return nil end
    
    -- Добавляем безопасную проверку
    if not GetNumGuildMembers or GetNumGuildMembers() == 0 then
        return nil
    end
    
    for i = 1, GetNumGuildMembers() do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status = GetGuildRosterInfo(i)
        if name then
            local plainName = name:gsub("-.*", "")
            
            if plainName:lower() == playerName:lower() then
                return {
                    fullName = name,
                    rankIndex = rankIndex,
                    rankName = rank,
                    online = online,
                    class = class,
                    zone = zone,
                    officernote = officernote,
                    rosterIndex = i
                }
            end
        end
    end
    
    return nil
end


MuteManager.GetPlayerInfo = MuteManager.GetPlayerInfo

function MuteManager:SetGuildMemberNote(playerName, noteText, isOfficerNote)
    local targetInfo = self:GetPlayerInfo(playerName)
    if not targetInfo then return false end
    
    if not CanEditOfficerNote() then return false end
    
    SetGuildRosterSelection(targetInfo.rosterIndex)
    
    if isOfficerNote then
        GuildRosterSetOfficerNote(targetInfo.rosterIndex, noteText)
    else
        GuildRosterSetPublicNote(targetInfo.rosterIndex, noteText)
    end
    
    return true
end

function MuteManager:CreateMuteRecord(mutedBy, durationMinutes, reason)
    local timestamp = date("%d.%m %H:%M")
    local durationText = durationMinutes .. "m"
    
    local shortBy = mutedBy:sub(1, 3)
    
    local record = string.format("%s %s %s", 
        timestamp, shortBy, durationText)
    
    if reason and reason ~= "" then
        local shortReason = reason:match("(%S+)") or ""
        if shortReason ~= "" and #record + #shortReason + 1 <= 31 then
            record = record .. " " .. shortReason
        end
    end
    
    return record:sub(1, 31)
end

function MuteManager:CheckPermissions(targetPlayerName)
    if not IsInGuild() then
        self:ShowNotification("Ошибка: Вы не в гильдии")
        return false
    end
    
    if not CanEditOfficerNote() then
        self:ShowNotification("Ошибка: Недостаточно прав офицера")
        return false
    end
    
    local myInfo = self:GetPlayerInfo(UnitName("player"))
    if not myInfo then return false end
    
    if myInfo.rankIndex > 1 then
        self:ShowNotification("Ошибка: Требуется ранг Офицера или выше")
        return false
    end
    
    local targetInfo = self:GetPlayerInfo(targetPlayerName)
    if not targetInfo then
        self:ShowNotification("Ошибка: Игрок " .. targetPlayerName .. " не найден в гильдии")
        return false
    end
    
    if targetInfo.fullName == myInfo.fullName then
        self:ShowNotification("Ошибка: Нельзя замутить себя")
        return false
    end
    
    if targetInfo.rankIndex < myInfo.rankIndex then
        self:ShowNotification("Ошибка: Нельзя замутить игрока с высшим рангом")
        return false
    end
    
    return true, myInfo, targetInfo
end

function MuteManager:ExecuteRankCommands(fullName, targetRankIndex)
    local currentInfo = self:GetPlayerInfo(fullName:gsub("-.*", ""))
    if not currentInfo then return false end
    
    local currentRank = currentInfo.rankIndex
    if currentRank == targetRankIndex then return true end
    
    local steps = targetRankIndex - currentRank
    local command = ""
    local count = 0
    
    if steps > 0 then
        command = "demote"
        count = steps
    else
        command = "promote"
        count = math.abs(steps)
    end
    
    for i = 1, count do
        self:DelayedExecute(i * 1.0, function()
            local cmd = string.format("/g%s %s", command, fullName)
            self:ExecuteGuildCommand(cmd)
        end)
    end
    
    self:DelayedExecute((count + 1) * 1.0, function()
        GuildRoster()
    end)
    
    return true
end

function MuteManager:MutePlayer(playerName, durationMinutes, reason)
    local maxRank = #self.db.guildRanks
    if self.db.muteRank < 0 or self.db.muteRank > maxRank then
        self:ShowNotification("Ошибка: Некорректный ранг для мута")
        return false
    end
    
    local canMute, myInfo, targetInfo = self:CheckPermissions(playerName)
    if not canMute then return false end
    
    if self.db.activeMutes[playerName] then
        self:ShowNotification("Ошибка: Игрок " .. playerName .. " уже замучен")
        return false
    end
    
    if targetInfo.rankIndex == self.db.muteRank then
        self:ShowNotification("Ошибка: Игрок уже имеет целевой ранг")
        return false
    end
    
    local durationSeconds = durationMinutes * 60
    local mutedBy = UnitName("player")
    local muteRecord = self:CreateMuteRecord(mutedBy, durationMinutes, reason)
    
    self.db.activeMutes[playerName] = {
        originalRank = targetInfo.rankIndex,
        expireTime = time() + durationSeconds,
        fullName = targetInfo.fullName,
        startTime = time(),
        reason = reason or "",
        mutedBy = mutedBy,
        originalNote = targetInfo.officernote or ""
    }
    
    if self:ExecuteRankCommands(targetInfo.fullName, self.db.muteRank) then
        self:DelayedExecute(3, function()
            if self.db.settings.useOfficerNotes then
                self:SetGuildMemberNote(playerName, muteRecord, true)
            end
        end)
        
        self.db.activeMutes[playerName].timer = self:CreateTimer(durationSeconds, function()
            self:UnmutePlayer(playerName)
        end)
        
        local message = string.format(
            "|cFFFF0000%s|r замучен на |cFF00FF00%d|r минут. Размут: |cFF00FFFF%s|r",
            playerName, 
            durationMinutes,
            date("%H:%M:%S", time() + durationSeconds)
        )
        
        if reason and reason ~= "" then
            message = message .. " | Причина: " .. reason
        end
        
        self:ShowNotification("Игрок успешно замучен")
        self:Print(message)
        
        if self.mainFrame:IsVisible() then
            self:UpdateActiveMutesTab()
        end
        
        return true
    else
        self.db.activeMutes[playerName] = nil
        return false
    end
end

function MuteManager:UnmutePlayer(playerName)
    local muteData = self.db.activeMutes[playerName]
    if not muteData then
        self:ShowNotification("Ошибка: Игрок " .. playerName .. " не замучен")
        return false
    end
    
    if self:ExecuteRankCommands(muteData.fullName, muteData.originalRank) then
        self:DelayedExecute(3, function()
            if self.db.settings.useOfficerNotes then
                self:SetGuildMemberNote(playerName, muteData.originalNote, true)
            end
        end)
        
        if muteData.timer and muteData.timer.SetScript then
            muteData.timer:SetScript("OnUpdate", nil)
        end
        
        local duration = time() - muteData.startTime
        local durationMinutes = math.floor(duration / 60)
        
        self.db.activeMutes[playerName] = nil
        self:ShowNotification("Игрок успешно размучен")
        self:Print(string.format(
            "Игрок |cFFFF0000%s|r размучен (был замучен %d минут)",
            playerName, 
            durationMinutes
        ))
        
        if self.mainFrame:IsVisible() then
            self:UpdateActiveMutesTab()
        end
        
        return true
    else
        return false
    end
end

function MuteManager:LoadActiveMutes()
    local currentTime = time()
    local restored = 0
    
    for playerName, muteData in pairs(self.db.activeMutes) do
        local remaining = muteData.expireTime - currentTime
        
        if remaining > 0 then
            muteData.timer = self:CreateTimer(remaining, function()
                self:UnmutePlayer(playerName)
            end)
            
            restored = restored + 1
        else
            self.db.activeMutes[playerName] = nil
        end
    end
    
    if restored > 0 then
        self:Print("Восстановлено " .. restored .. " активных мутов")
    end
end

function MuteManager:CountActiveMutes()
    local count = 0
    for _ in pairs(self.db.activeMutes) do
        count = count + 1
    end
    return count
end

function MuteManager:ToggleWindow()
    if self.mainFrame:IsVisible() then
        self.mainFrame:Hide()
    else
        self.mainFrame:Show()
        self:UpdateActiveMutesTab()
        self:UpdateStats()
    end
end

function MuteManager:SlashHandler(msg)
    local args = {}
    for arg in msg:gmatch("%S+") do
        table.insert(args, arg:lower())
    end
    
    local command = args[1]
    
    if command == "list" then
        self:ShowTab(2)
        self.mainFrame:Show()
    elseif command == "config" then
        self:ShowTab(3)
        self.mainFrame:Show()
    else
        self:ShowNotification("Используйте окно интерфейса для управления мутами")
        self.mainFrame:Show()
    end
end

function MuteManager:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00MuteManager:|r " .. msg)
end

MuteManager:OnLoad()