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

function CheckGuildPermissions()
    if not IsInGuild() then
        return false
    end
    
    if not CanEditOfficerNote() then
        return false
    end
    
    local playerName = UnitName("player")
    local playerInfo = MuteManager:GetPlayerInfo(playerName)
    
    if not playerInfo then
        return false
    end
    
    if playerInfo.rankIndex >= 2 then
        return false
    end
    
    return true
end

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
    
    if CheckGuildPermissions() then
        minimapButton.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    else
        minimapButton.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_06")
    end
    
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
        if CheckGuildPermissions() then
            GameTooltip:AddLine("ЛКМ - Меню (доступны функции гильдии)", 0.8, 0.8, 0.8)
        else
            GameTooltip:AddLine("ЛКМ - Меню", 0.8, 0.8, 0.8)
        end
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
    
    local hasGuildPermissions = CheckGuildPermissions()
    
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
        }
    }
    
    if hasGuildPermissions then
        table.insert(menuItems, {
            text = "Управление гильдией",
            isTitle = true,
            notCheckable = true
        })
        
        table.insert(menuItems, {
            text = "MuteManager",
            func = function() 
                MuteManager:ToggleWindow()
            end,
            notCheckable = true
        })
        
        table.insert(menuItems, {
            text = "Активные муты",
            func = function() 
                MuteManager:ShowTab(2)
                MuteManager:ToggleWindow()
            end,
            notCheckable = true
        })
        
        table.insert(menuItems, {
            text = "Настройки мутов",
            func = function() 
                MuteManager:ShowTab(3)
                MuteManager:ToggleWindow()
            end,
            notCheckable = true
        })
        
        table.insert(menuItems, {
            text = "Очистка гильдии",
            func = function() 
                MuteManager:ShowTab(4)
                MuteManager:ToggleWindow()
            end,
            notCheckable = true
        })
    end
    
    EasyMenu(menuItems, menuFrame, "cursor", 0, 0, "MENU")
end

function MuteManager:CreateMainWindow()
    local frame = CreateFrame("Frame", "MuteManagerFrame", UIParent, "BasicFrameTemplate")
    frame:SetSize(500, 600)
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
    local tabs = {"Управление игроком", "Активные муты", "Настройки", "Очистка"}
    local tabFrames = {}
    
    for i, tabName in ipairs(tabs) do
        local tab = CreateFrame("Button", "MuteManagerTab"..i, parent, "CharacterFrameTabButtonTemplate")
        tab:SetText(tabName)
        tab:SetID(i)
        tab:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 5 + ((i-1) * 120), 2)
        tab:SetScript("OnClick", function() 
            self:ShowTab(i) 
        end)
        
        local tabFrame = CreateFrame("Frame", nil, parent)
        tabFrame:SetSize(480, 530)
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
    local yOffset = -10
    
    local searchLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("TOPLEFT", 10, yOffset)
    searchLabel:SetText("Поиск игрока:")
    
    local nameEdit = CreateFrame("EditBox", "MuteManagerNameEdit", parent)
    nameEdit:SetSize(180, 20)
    nameEdit:SetPoint("TOPLEFT", 100, yOffset)
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
    
    local searchBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    searchBtn:SetSize(80, 22)
    searchBtn:SetPoint("TOPLEFT", 290, yOffset)
    searchBtn:SetText("Поиск")
    
    yOffset = yOffset - 30
    
    local infoFrame = CreateFrame("Frame", nil, parent)
    infoFrame:SetPoint("TOPLEFT", 10, yOffset)
    infoFrame:SetPoint("TOPRIGHT", -10, yOffset)
    infoFrame:SetHeight(200)
    
    infoFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    infoFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    infoFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    
    local infoTitle = infoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoTitle:SetPoint("TOP", 0, -8)
    infoTitle:SetText("Информация об игроке")
    infoTitle:SetTextColor(1, 1, 0)
    
    local infoText = infoFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    infoText:SetPoint("TOPLEFT", 15, -30)
    infoText:SetSize(440, 160)
    infoText:SetJustifyH("LEFT")
    infoText:SetJustifyV("TOP")
    infoText:SetText("Введите ник игрока и нажмите 'Поиск'")
    
    yOffset = yOffset - 210
    
    local notesLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    notesLabel:SetPoint("TOPLEFT", 10, yOffset)
    notesLabel:SetText("Управление заметками:")
    notesLabel:SetTextColor(1, 1, 0)
    
    yOffset = yOffset - 25
    
    local publicNoteLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    publicNoteLabel:SetPoint("TOPLEFT", 20, yOffset)
    publicNoteLabel:SetText("Публичная заметка:")
    
    yOffset = yOffset - 20
    
    local publicNoteEdit = CreateFrame("EditBox", "MuteManagerPublicNoteEdit", parent)
    publicNoteEdit:SetSize(350, 20)
    publicNoteEdit:SetPoint("TOPLEFT", 20, yOffset)
    publicNoteEdit:SetAutoFocus(false)
    publicNoteEdit:SetFontObject("GameFontNormal")
    publicNoteEdit:SetTextInsets(8, 8, 0, 0)
    
    publicNoteEdit:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    publicNoteEdit:SetBackdropColor(0, 0, 0, 0.5)
    publicNoteEdit:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    
    local savePublicNoteBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    savePublicNoteBtn:SetSize(80, 22)
    savePublicNoteBtn:SetPoint("TOPLEFT", 380, yOffset)
    savePublicNoteBtn:SetText("Сохранить")
    
    yOffset = yOffset - 30
    
    local officerNoteLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    officerNoteLabel:SetPoint("TOPLEFT", 20, yOffset)
    officerNoteLabel:SetText("Офицерская заметка:")
    
    yOffset = yOffset - 20
    
    local officerNoteEdit = CreateFrame("EditBox", "MuteManagerOfficerNoteEdit", parent)
    officerNoteEdit:SetSize(350, 20)
    officerNoteEdit:SetPoint("TOPLEFT", 20, yOffset)
    officerNoteEdit:SetAutoFocus(false)
    officerNoteEdit:SetFontObject("GameFontNormal")
    officerNoteEdit:SetTextInsets(8, 8, 0, 0)
    
    officerNoteEdit:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    officerNoteEdit:SetBackdropColor(0, 0, 0, 0.5)
    officerNoteEdit:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    
    local saveOfficerNoteBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    saveOfficerNoteBtn:SetSize(80, 22)
    saveOfficerNoteBtn:SetPoint("TOPLEFT", 380, yOffset)
    saveOfficerNoteBtn:SetText("Сохранить")
    
    yOffset = yOffset - 40
    
    local rankLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rankLabel:SetPoint("TOPLEFT", 10, yOffset)
    rankLabel:SetText("Изменение ранга:")
    rankLabel:SetTextColor(1, 1, 0)
    
    yOffset = yOffset - 25
    
    local newRankLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    newRankLabel:SetPoint("TOPLEFT", 20, yOffset)
    newRankLabel:SetText("Новый ранг:")
    
    local rankDropdown = CreateFrame("Frame", "MuteManagerPlayerRankDropdown", parent, "UIDropDownMenuTemplate")
    rankDropdown:SetPoint("TOPLEFT", 120, yOffset)
    rankDropdown.initialize = function() self:InitializePlayerRankDropdown() end
    
    local changeRankBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    changeRankBtn:SetSize(120, 25)
    changeRankBtn:SetPoint("TOPLEFT", 300, yOffset)
    changeRankBtn:SetText("Изменить ранг")
    
    yOffset = yOffset - 40
    
    local muteLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    muteLabel:SetPoint("TOPLEFT", 10, yOffset)
    muteLabel:SetText("Система мута:")
    muteLabel:SetTextColor(1, 1, 0)
    
    yOffset = yOffset - 25
    
    local timeLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timeLabel:SetPoint("TOPLEFT", 20, yOffset)
    timeLabel:SetText("Время (минуты):")
    
    local timeEdit = CreateFrame("EditBox", "MuteManagerTimeEdit", parent)
    timeEdit:SetSize(80, 20)
    timeEdit:SetPoint("TOPLEFT", 20, yOffset - 20)
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
    
    local reasonLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    reasonLabel:SetPoint("TOPLEFT", 120, yOffset)
    reasonLabel:SetText("Причина:")
    
    local reasonEdit = CreateFrame("EditBox", "MuteManagerReasonEdit", parent)
    reasonEdit:SetSize(200, 20)
    reasonEdit:SetPoint("TOPLEFT", 120, yOffset - 20)
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
    
    yOffset = yOffset - 50
    
    local muteBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    muteBtn:SetSize(120, 25)
    muteBtn:SetPoint("TOPLEFT", 20, yOffset)
    muteBtn:SetText("Замутить")
    
    local unmuteBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    unmuteBtn:SetSize(120, 25)
    unmuteBtn:SetPoint("TOPLEFT", 150, yOffset)
    unmuteBtn:SetText("Размутить")
    
    parent.nameEdit = nameEdit
    parent.searchBtn = searchBtn
    parent.infoText = infoText
    parent.publicNoteEdit = publicNoteEdit
    parent.officerNoteEdit = officerNoteEdit
    parent.savePublicNoteBtn = savePublicNoteBtn
    parent.saveOfficerNoteBtn = saveOfficerNoteBtn
    parent.rankDropdown = rankDropdown
    parent.changeRankBtn = changeRankBtn
    parent.timeEdit = timeEdit
    parent.reasonEdit = reasonEdit
    parent.muteBtn = muteBtn
    parent.unmuteBtn = unmuteBtn
    
    searchBtn:SetScript("OnClick", function()
        self:SearchPlayer(nameEdit:GetText())
    end)
    
    nameEdit:SetScript("OnEnterPressed", function(self)
        MuteManager:SearchPlayer(self:GetText())
        self:ClearFocus()
    end)
    
    nameEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    savePublicNoteBtn:SetScript("OnClick", function()
        self:SavePublicNote(nameEdit:GetText(), publicNoteEdit:GetText())
    end)
    
    saveOfficerNoteBtn:SetScript("OnClick", function()
        self:SaveOfficerNote(nameEdit:GetText(), officerNoteEdit:GetText())
    end)
    
    changeRankBtn:SetScript("OnClick", function()
        self:ChangePlayerRank(nameEdit:GetText())
    end)
    
    muteBtn:SetScript("OnClick", function()
        self:MuteFromUI(nameEdit:GetText(), timeEdit:GetText(), reasonEdit:GetText())
    end)
    
    unmuteBtn:SetScript("OnClick", function()
        self:UnmuteFromUI(nameEdit:GetText())
    end)
    
    publicNoteEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    officerNoteEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    timeEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    reasonEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
end

function MuteManager:SearchPlayer(playerName)
    if not playerName or playerName == "" then
        self.tabFrames[1].infoText:SetText("|cFFFF0000Введите ник игрока|r")
        return
    end
    
    local playerInfo = self:GetPlayerInfo(playerName)
    if not playerInfo then
        self.tabFrames[1].infoText:SetText("|cFFFF0000Игрок '" .. playerName .. "' не найден в гильдии|r")
        return
    end
    
    local infoText = string.format(
        "|cFFFFFF00Игрок:|r |cFFFFFFFF%s|r\n" ..
        "|cFFFFFF00Ранг:|r |cFFFFFFFF%s (%d)|r\n" ..
        "|cFFFFFF00Статус:|r %s\n" ..
        "|cFFFFFF00Класс:|r |cFFFFFFFF%s|r\n" ..
        "|cFFFFFF00Уровень:|r |cFFFFFFFF%d|r\n" ..
        "|cFFFFFF00Зона:|r |cFFFFFFFF%s|r\n" ..
        "|cFFFFFF00Публичная заметка:|r |cFFFFFFFF%s|r\n" ..
        "|cFFFFFF00Офицерская заметка:|r |cFFFFFFFF%s|r",
        playerInfo.fullName,
        playerInfo.rankName,
        playerInfo.rankIndex,
        playerInfo.online and "|cFF00FF00Онлайн|r" or "|cFFFF0000Оффлайн|r",
        playerInfo.class or "Неизвестно",
        playerInfo.level or 0,
        playerInfo.zone or "Неизвестно",
        playerInfo.note or "нет",
        playerInfo.officernote or "нет"
    )
    
    if self.db.activeMutes[playerName] then
        local muteData = self.db.activeMutes[playerName]
        local remaining = math.max(0, muteData.expireTime - time())
        local remainingMinutes = math.floor(remaining / 60)
        local remainingSeconds = remaining % 60
        
        infoText = infoText .. string.format(
            "\n\n|cFFFF0000СТАТУС: ЗАМУЧЕН|r\n" ..
            "|cFFFFFF00Осталось:|r |cFFFFFFFF%d:%02d|r\n" ..
            "|cFFFFFF00Причина:|r |cFFFFFFFF%s|r\n" ..
            "|cFFFFFF00Выдал:|r |cFFFFFFFF%s|r",
            remainingMinutes,
            remainingSeconds,
            muteData.reason or "не указана",
            muteData.mutedBy or "неизвестно"
        )
    end
    
    self.tabFrames[1].infoText:SetText(infoText)
    
    self.tabFrames[1].publicNoteEdit:SetText(playerInfo.note or "")
    self.tabFrames[1].officerNoteEdit:SetText(playerInfo.officernote or "")
    
    UIDropDownMenu_SetText(self.tabFrames[1].rankDropdown, playerInfo.rankIndex .. " - " .. playerInfo.rankName)
    
    self.currentPlayer = playerInfo
end

function MuteManager:SavePublicNote(playerName, noteText)
    if not playerName or playerName == "" then
        self:ShowNotification("Сначала найдите игрока")
        return
    end
    
    if self:SetGuildMemberNote(playerName, noteText, false) then
        self:ShowNotification("Публичная заметка обновлена")
        self:SearchPlayer(playerName)
    else
        self:ShowNotification("Ошибка обновления заметки")
    end
end

function MuteManager:SaveOfficerNote(playerName, noteText)
    if not playerName or playerName == "" then
        self:ShowNotification("Сначала найдите игрока")
        return
    end
    
    if self:SetGuildMemberNote(playerName, noteText, true) then
        self:ShowNotification("Офицерская заметка обновлена")
        self:SearchPlayer(playerName)
    else
        self:ShowNotification("Ошибка обновления заметки")
    end
end

function MuteManager:InitializePlayerRankDropdown()
    local info = UIDropDownMenu_CreateInfo()
    
    for i = 0, #self.db.guildRanks do
        if self.db.guildRanks[i] then
            info.text = i .. " - " .. self.db.guildRanks[i]
            info.value = i
            info.func = function(self)
                UIDropDownMenu_SetText(MuteManager.tabFrames[1].rankDropdown, self.value .. " - " .. MuteManager.db.guildRanks[self.value])
            end
            UIDropDownMenu_AddButton(info)
        end
    end
end

function MuteManager:ChangePlayerRank(playerName)
    if not playerName or playerName == "" then
        self:ShowNotification("Сначала найдите игрока")
        return
    end
    
    local targetRankText = UIDropDownMenu_GetText(self.tabFrames[1].rankDropdown)
    if not targetRankText then
        self:ShowNotification("Выберите ранг")
        return
    end
    
    local targetRankIndex = tonumber(targetRankText:match("^(%d+)"))
    if targetRankIndex == nil then
        self:ShowNotification("Ошибка определения ранга")
        return
    end
    
    local playerInfo = self:GetPlayerInfo(playerName)
    if not playerInfo then
        self:ShowNotification("Игрок не найден")
        return
    end
    
    if playerInfo.rankIndex == targetRankIndex then
        self:ShowNotification("Игрок уже имеет этот ранг")
        return
    end
    
    if self:ExecuteRankCommands(playerInfo.fullName, targetRankIndex) then
        self:ShowNotification("Ранг изменен")
        self:DelayedExecute(3, function()
            self:SearchPlayer(playerName)
        end)
    else
        self:ShowNotification("Ошибка изменения ранга")
    end
end

function MuteManager:MuteFromUI(playerName, timeText, reason)
    if not playerName or playerName == "" then
        self:ShowNotification("Сначала найдите игрока")
        return
    end
    
    local duration = tonumber(timeText)
    if not duration or duration <= 0 then
        self:ShowNotification("Введите корректное время")
        return
    end
    
    if self:MutePlayer(playerName, duration, reason) then
        self.tabFrames[1].timeEdit:SetText("")
        self.tabFrames[1].reasonEdit:SetText("")
        self:DelayedExecute(2, function()
            self:SearchPlayer(playerName)
        end)
    end
end

function MuteManager:UnmuteFromUI(playerName)
    if not playerName or playerName == "" then
        self:ShowNotification("Сначала найдите игрока")
        return
    end
    
    if self:UnmutePlayer(playerName) then
        self:DelayedExecute(2, function()
            self:SearchPlayer(playerName)
        end)
    end
end

function MuteManager:CreateActiveMutesTab(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    local scrollChild = CreateFrame("Frame")
    scrollFrame:SetScrollChild(scrollChild)
    scrollChild:SetSize(440, 400)
    
    local content = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    content:SetPoint("TOPLEFT")
    content:SetSize(440, 400)
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
    statsText:SetSize(440, 100)
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
    daysEdit:SetSize(30, 20)
    daysEdit:SetPoint("TOPLEFT", 135, yOffset)
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
    
    yOffset = yOffset - 30
    
    local levelLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    levelLabel:SetPoint("TOPLEFT", 10, yOffset)
    levelLabel:SetText("Макс. уровень для кика:")
    
    local levelEdit = CreateFrame("EditBox", nil, parent)
    levelEdit:SetSize(30, 20)
    levelEdit:SetPoint("TOPLEFT", 160, yOffset)
    levelEdit:SetAutoFocus(false)
    levelEdit:SetNumeric(true)
    levelEdit:SetFontObject("GameFontNormal")
    levelEdit:SetTextInsets(8, 8, 0, 0)
    levelEdit:SetText("80")
    
    levelEdit:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    levelEdit:SetBackdropColor(0, 0, 0, 0.5)
    levelEdit:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    
    yOffset = yOffset - 40
    
    local notesLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    notesLabel:SetPoint("TOPLEFT", 10, yOffset)
    notesLabel:SetText("Исключить из поиска:")
    notesLabel:SetTextColor(1, 1, 0)
    
    yOffset = yOffset - 25
    
    local excludePublicNoteCheckbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    excludePublicNoteCheckbox:SetPoint("TOPLEFT", 20, yOffset)
    excludePublicNoteCheckbox:SetChecked(false)
    
    local excludePublicNoteLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    excludePublicNoteLabel:SetPoint("LEFT", excludePublicNoteCheckbox, "RIGHT", 5, 0)
    excludePublicNoteLabel:SetText("Игроков с публичной заметкой")
    
    local excludeOfficerNoteCheckbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    excludeOfficerNoteCheckbox:SetPoint("TOPLEFT", 250, yOffset)
    excludeOfficerNoteCheckbox:SetChecked(false)
    
    local excludeOfficerNoteLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    excludeOfficerNoteLabel:SetPoint("LEFT", excludeOfficerNoteCheckbox, "RIGHT", 5, 0)
    excludeOfficerNoteLabel:SetText("Игроков с офицерской заметкой")
    
    yOffset = yOffset - 30
    
    local ranksLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ranksLabel:SetPoint("TOPLEFT", 10, yOffset)
    ranksLabel:SetText("Ранги для проверки:")
    ranksLabel:SetTextColor(1, 1, 0)
    
    yOffset = yOffset - 25
    
    local ranksContainer = CreateFrame("Frame", nil, parent)
    ranksContainer:SetPoint("TOPLEFT", 10, yOffset)
    ranksContainer:SetSize(280, 75)
    
    yOffset = yOffset - 80
    
    local findBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    findBtn:SetSize(120, 25)
    findBtn:SetPoint("TOPLEFT", 10, yOffset)
    findBtn:SetText("Найти неактивных")
    findBtn:SetScript("OnClick", function()
        local days = tonumber(daysEdit:GetText()) or 30
        local maxLevel = tonumber(levelEdit:GetText()) or 80
        local selectedRanks = self:GetSelectedRanks()
        local excludePublicNote = excludePublicNoteCheckbox:GetChecked()
        local excludeOfficerNote = excludeOfficerNoteCheckbox:GetChecked()
        
        self.db.settings.cleanupDays = days
        self:FindInactivePlayers(days, maxLevel, selectedRanks, excludePublicNote, excludeOfficerNote)
    end)
    
    yOffset = yOffset - 40
    
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
    
    local candidatesFrame = CreateFrame("Frame", "MuteManagerCandidatesFrame", UIParent, "BasicFrameTemplate")
    candidatesFrame:SetSize(500, 550)
    candidatesFrame:SetPoint("LEFT", parent, "RIGHT", 10, 0) 
    candidatesFrame:SetMovable(true)
    candidatesFrame:EnableMouse(true)
    candidatesFrame:RegisterForDrag("LeftButton")
    candidatesFrame:SetScript("OnDragStart", candidatesFrame.StartMoving)
    candidatesFrame:SetScript("OnDragStop", candidatesFrame.StopMovingOrSizing)
    candidatesFrame:SetFrameStrata("DIALOG")
    
    candidatesFrame.title = candidatesFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    candidatesFrame.title:SetPoint("TOP", 0, -5)
    candidatesFrame.title:SetText("Список кандидатов на удаление")
    
    local candidatesScrollFrame = CreateFrame("ScrollFrame", "MuteManagerCandidatesScroll", candidatesFrame, "UIPanelScrollFrameTemplate")
    candidatesScrollFrame:SetPoint("TOPLEFT", 10, -30)
    candidatesScrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)
    
    local candidatesScrollChild = CreateFrame("Frame")
    candidatesScrollFrame:SetScrollChild(candidatesScrollChild)
    candidatesScrollChild:SetSize(460, 500)
    
    local checkboxesContainer = CreateFrame("Frame", nil, candidatesScrollChild)
    checkboxesContainer:SetAllPoints()
    
    local closeCandidatesBtn = CreateFrame("Button", nil, candidatesFrame, "UIPanelButtonTemplate")
    closeCandidatesBtn:SetSize(100, 25)
    closeCandidatesBtn:SetPoint("BOTTOM", 0, 10)
    closeCandidatesBtn:SetText("Закрыть")
    closeCandidatesBtn:SetScript("OnClick", function()
        candidatesFrame:Hide()
    end)
    
    candidatesFrame:Hide()
    
    parent.daysEdit = daysEdit
    parent.levelEdit = levelEdit
    parent.excludePublicNoteCheckbox = excludePublicNoteCheckbox
    parent.excludeOfficerNoteCheckbox = excludeOfficerNoteCheckbox
    parent.ranksContainer = ranksContainer
    parent.candidatesFrame = candidatesFrame
    parent.candidatesScrollFrame = candidatesScrollFrame
    parent.checkboxesContainer = checkboxesContainer
    parent.statusText = statusText
    parent.removeBtn = removeBtn
    
    self:CreateRankCheckboxes(ranksContainer)
end

function MuteManager:CreateRankCheckboxes(container)
    if container.checkboxes then
        for _, checkbox in pairs(container.checkboxes) do
            checkbox:Hide()
            if checkbox.label then
                checkbox.label:Hide()
            end
        end
    end
    
    local ranks = {}
    for i = 0, #self.db.guildRanks do
        if self.db.guildRanks[i] then
            table.insert(ranks, {index = i, name = self.db.guildRanks[i]})
        end
    end
    
    table.sort(ranks, function(a, b) return a.index < b.index end)
    
    local checkboxes = {}
    local maxRows = 3
    local columnWidth = 140
    
    for i, rankData in ipairs(ranks) do
        local row = (i - 1) % maxRows
        local column = math.floor((i - 1) / maxRows)
        
        local xOffset = column * columnWidth
        local yOffset = row * -25
        
        local checkbox = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", xOffset, yOffset)
        checkbox:SetChecked(true)
        checkbox.rankIndex = rankData.index
        
        local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
        label:SetText(rankData.index .. " - " .. rankData.name)
        checkbox.label = label
        
        checkboxes[rankData.index] = checkbox
    end
    
    local numColumns = math.ceil(#ranks / maxRows)
    local containerHeight = maxRows * 25
    
    container.checkboxes = checkboxes
    container:SetHeight(containerHeight)
    container:SetWidth(numColumns * columnWidth)
end

function MuteManager:GetSelectedRanks()
    local selectedRanks = {}
    local container = self.tabFrames[4].ranksContainer
    
    if container and container.checkboxes then
        for rankIndex, checkbox in pairs(container.checkboxes) do
            if checkbox:GetChecked() then
                table.insert(selectedRanks, rankIndex)
            end
        end
    end
    
    if #selectedRanks == 0 then
        for i = 0, #self.db.guildRanks do
            if self.db.guildRanks[i] then
                table.insert(selectedRanks, i)
            end
        end
    end
    
    return selectedRanks
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
                if self.tabFrames[4].candidatesFrame then
                    self.tabFrames[4].candidatesFrame:Hide()
                end
                if self.tabFrames[4].ranksContainer then
                    self:CreateRankCheckboxes(self.tabFrames[4].ranksContainer)
                end
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

function MuteManager:FindInactivePlayers(daysThreshold, maxLevel, selectedRanks, excludePublicNote, excludeOfficerNote)
    if not IsInGuild() then
        self:ShowNotification("Ошибка: Вы не в гильдии")
        return
    end
    
    local currentTime = time()
    local thresholdTime = currentTime - (daysThreshold * 86400)
    self.cleanupCandidates = {}
    
    local allowedRanks = {}
    for _, rank in ipairs(selectedRanks) do
        allowedRanks[rank] = true
    end
    
    GuildRoster()
    
    for i = 1, GetNumGuildMembers() do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status = GetGuildRosterInfo(i)
        
        if allowedRanks[rankIndex] then
            if level <= maxLevel then
                local hasPublicNote = note and note ~= ""
                local hasOfficerNote = officernote and officernote ~= ""
                
                local noteFilterPass = true
                
                if excludePublicNote and hasPublicNote then
                    noteFilterPass = false
                end
                
                if excludeOfficerNote and hasOfficerNote then
                    noteFilterPass = false
                end
                
                if noteFilterPass then
                    local yearsOffline, monthsOffline, daysOffline, hoursOffline = GetGuildRosterLastOnline(i)
                    local totalDaysOffline = (yearsOffline or 0) * 365 + (monthsOffline or 0) * 30 + (daysOffline or 0)
                    
                    if totalDaysOffline >= daysThreshold and not online then
                        table.insert(self.cleanupCandidates, {
                            name = name,
                            rank = rank,
                            rankIndex = rankIndex,
                            level = level,
                            class = class or "Неизвестно",
                            daysOffline = totalDaysOffline,
                            note = note or "",
                            officernote = officernote or "",
                            zone = zone or "Неизвестно"
                        })
                    end
                end
            end
        end
    end
    
    self:UpdateCleanupList()
    
    local excludeText = ""
    if excludePublicNote then
        excludeText = excludeText .. ", исключая с публичной заметкой"
    end
    if excludeOfficerNote then
        excludeText = excludeText .. ", исключая с офицерской заметкой"
    end
    
    local statsText = string.format("Найдено: %d игроков (уровень ≤%d, ранги: %s%s)", 
        #self.cleanupCandidates, maxLevel, table.concat(selectedRanks, ","), excludeText)
    self.tabFrames[4].statusText:SetText(statsText)
end

function MuteManager:UpdateCleanupList()
    local parent = self.tabFrames[4]
    local container = parent.checkboxesContainer
    local statusText = parent.statusText
    local candidatesFrame = parent.candidatesFrame
    
    if container.candidateFrames then
        for _, frame in pairs(container.candidateFrames) do
            frame:Hide()
        end
    end
    
    container.candidateFrames = {}
    
    if #self.cleanupCandidates == 0 then
        statusText:SetText("Неактивные игроки не найдены")
        parent.removeBtn:Disable()
        candidatesFrame:Hide()
        return
    end
    
    table.sort(self.cleanupCandidates, function(a, b) 
        return a.daysOffline > b.daysOffline 
    end)
    
    local columnWidth = 220
    local maxRows = math.ceil(#self.cleanupCandidates / 2)
    local frameHeight = 70
    
    for i, candidate in ipairs(self.cleanupCandidates) do
        local column = math.floor((i - 1) / maxRows)
        local row = (i - 1) % maxRows
        
        local xOffset = column * columnWidth
        local yOffset = row * -frameHeight
        
        local candidateFrame = CreateFrame("Frame", nil, container)
        candidateFrame:SetPoint("TOPLEFT", xOffset, yOffset)
        candidateFrame:SetSize(columnWidth - 10, frameHeight)
        
        local checkbox = CreateFrame("CheckButton", nil, candidateFrame, "UICheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", 5, -5)
        checkbox:SetChecked(true)
        checkbox.candidateIndex = i
        
        local nameText = candidateFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("TOPLEFT", 35, -5)
        nameText:SetSize(columnWidth - 45, 15)
        nameText:SetJustifyH("LEFT")
        nameText:SetText(candidate.name .. " (" .. candidate.level .. " ур.)")
        
        local rankText = candidateFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        rankText:SetPoint("TOPLEFT", 35, -20)
        rankText:SetSize(columnWidth - 45, 12)
        rankText:SetJustifyH("LEFT")
        rankText:SetText("Ранг: " .. candidate.rank)
        
        local daysText = candidateFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        daysText:SetPoint("TOPLEFT", 35, -32)
        daysText:SetSize(columnWidth - 45, 12)
        daysText:SetJustifyH("LEFT")
        daysText:SetText("Неактивен: " .. candidate.daysOffline .. " дн.")
        
        local publicNoteText = candidateFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        publicNoteText:SetPoint("TOPLEFT", 35, -44)
        publicNoteText:SetSize(columnWidth - 45, 12)
        publicNoteText:SetJustifyH("LEFT")
        
        local publicNote = candidate.note or ""
        if publicNote == "" then 
            publicNote = "нет" 
            publicNoteText:SetTextColor(0.7, 0.7, 0.7)
        else
            publicNoteText:SetTextColor(1, 1, 1)
        end
        publicNoteText:SetText("Публичная: " .. publicNote)
        
        local officerNoteText = candidateFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        officerNoteText:SetPoint("TOPLEFT", 35, -56)
        officerNoteText:SetSize(columnWidth - 45, 12)
        officerNoteText:SetJustifyH("LEFT")
        
        local officerNote = candidate.officernote or ""
        if officerNote == "" then 
            officerNote = "нет" 
            officerNoteText:SetTextColor(0.7, 0.7, 0.7)
        else
            officerNoteText:SetTextColor(1, 1, 1)
        end
        officerNoteText:SetText("Офицерская: " .. officerNote)
        
        candidateFrame.checkbox = checkbox
        candidateFrame.nameText = nameText
        candidateFrame.rankText = rankText
        candidateFrame.daysText = daysText
        candidateFrame.publicNoteText = publicNoteText
        candidateFrame.officerNoteText = officerNoteText
        
        container.candidateFrames[i] = candidateFrame
    end
    
    local totalHeight = maxRows * frameHeight
    container:SetHeight(math.max(totalHeight, 100))
    container:SetWidth(columnWidth * 2)
    
    parent.removeBtn:Enable()
    
    candidatesFrame:Show()
    
    statusText:SetText(string.format("Найдено: %d игроков", #self.cleanupCandidates))
end

function MuteManager:RemoveSelectedPlayers()
    local parent = self.tabFrames[4]
    local container = parent.checkboxesContainer
    local statusText = parent.statusText
    
    if not container.candidateFrames then
        self:ShowNotification("Нет игроков для удаления")
        return
    end
    
    local removedCount = 0
    local skippedCount = 0
    local errors = {}
    
    for i, candidateFrame in ipairs(container.candidateFrames) do
        if candidateFrame.checkbox:GetChecked() and self.cleanupCandidates[i] then
            local candidate = self.cleanupCandidates[i]
            
            if candidate.rankIndex > 0 then
                local success = GuildUninvite(candidate.name)
                if success then
                    removedCount = removedCount + 1
                    self:Print("Удален: " .. candidate.name .. " (" .. candidate.daysOffline .. " дней оффлайн, ур. " .. candidate.level .. ")")
                else
                    table.insert(errors, candidate.name)
                end
            else
                skippedCount = skippedCount + 1
                self:Print("Пропущен: " .. candidate.name .. " (лидер гильдии)")
            end
        end
    end
    
    self:DelayedExecute(2, function()
        GuildRoster()
        local days = tonumber(parent.daysEdit:GetText()) or 30
        local maxLevel = tonumber(parent.levelEdit:GetText()) or 80
        local selectedRanks = self:GetSelectedRanks()
        self:FindInactivePlayers(days, maxLevel, selectedRanks)
    end)
    
    local statusMsg = string.format("Удалено: %d, Пропущено: %d", removedCount, skippedCount)
    if #errors > 0 then
        statusMsg = statusMsg .. ", Ошибок: " .. #errors
    end
    
    statusText:SetText(statusMsg)
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
    
    SLASH_AFERISTHELPERADMIN1 = "/ahadmin"
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
        
        if not CheckGuildPermissions() then
            self.mainFrame:Hide()
        end
    end
end

function MuteManager:PLAYER_LOGIN()
end

function MuteManager:GUILD_ROSTER_UPDATE()
    self:UpdateGuildRanks()
    
    if self.tabFrames and self.tabFrames[4] and self.tabFrames[4].ranksContainer then
        self:CreateRankCheckboxes(self.tabFrames[4].ranksContainer)
    end
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
                    note = note,
                    officernote = officernote,
                    level = level,
                    rosterIndex = i
                }
            end
        end
    end
    
    return nil
end

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
