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

function CreateGuildTabButtons()
    -- Отложенная инициализация для гарантии готовности GuildFrame
    if not GuildFrame then
        -- Пробуем создать через небольшую задержку
        local checkFrame = CreateFrame("Frame")
        local attempts = 0
        checkFrame:SetScript("OnUpdate", function(self, elapsed)
            attempts = attempts + 1
            if GuildFrame then
                checkFrame:SetScript("OnUpdate", nil)
                CreateGuildTabButtons()
            elseif attempts > 50 then -- Проверяем максимум 5 секунд (50 * 0.1)
                checkFrame:SetScript("OnUpdate", nil)
                print("|cFFFF0000MuteManager:|r Не удалось найти GuildFrame")
            end
        end)
        return
    end
    
    -- Проверяем, что кнопки еще не созданы
    if _G.GuildExtraTabButton1 then
        return -- Кнопки уже созданы
    end
    
    local tab = CreateFrame("Button", "GuildExtraTabButton1", UIParent)
    tab:SetSize(30, 30)
    
    local normalTexture = tab:CreateTexture(nil, "BACKGROUND")
    normalTexture:SetAllPoints()
    normalTexture:SetTexture("Interface\\GuildFrame\\GuildFrame")
    normalTexture:SetTexCoord(0.26171875, 0.31640625, 0.37109375, 0.45703125)
    tab:SetNormalTexture(normalTexture)
    
    local pushedTexture = tab:CreateTexture(nil, "BACKGROUND")
    pushedTexture:SetAllPoints()
    pushedTexture:SetTexture("Interface\\GuildFrame\\GuildFrame")
    pushedTexture:SetTexCoord(0.3203125, 0.375, 0.37109375, 0.45703125)
    tab:SetPushedTexture(pushedTexture)
    
    local highlightTexture = tab:CreateTexture(nil, "HIGHLIGHT")
    highlightTexture:SetAllPoints()
    highlightTexture:SetTexture("Interface\\GuildFrame\\GuildFrame")
    highlightTexture:SetTexCoord(0.37890625, 0.43359375, 0.37109375, 0.45703125)
    tab:SetHighlightTexture(highlightTexture)
    
    local disabledTexture = tab:CreateTexture(nil, "BACKGROUND")
    disabledTexture:SetAllPoints()
    disabledTexture:SetTexture("Interface\\GuildFrame\\GuildFrame")
    disabledTexture:SetTexCoord(0.26171875, 0.31640625, 0.37109375, 0.45703125)
    disabledTexture:SetDesaturated(true)
    tab:SetDisabledTexture(disabledTexture)
    
    local icon = tab:CreateTexture(nil, "OVERLAY")
    icon:SetSize(28, 28)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    
    tab:SetPoint("TOPRIGHT", GuildFrame, "TOPRIGHT", 27, -235)
    
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Библиотека конфигов")
        GameTooltip:Show()
    end)
    
    tab:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    tab:SetScript("OnClick", function()
        SlashCmdList["AFERISTHELPER"]("")
    end)
    
    local additionalButtons = {}
    local buttonNames = {"Рейтинг аферистов", "Управление гильдией"}
    local buttonIcons = {
        "Interface\\Icons\\Inv_Misc_Note_03", 
        "Interface\\Icons\\Inv_Misc_Gear_01"
    }
    
    for i = 1, 2 do
        local additionalTab = CreateFrame("Button", "GuildExtraTabButton"..(i+1), UIParent)
        additionalTab:SetSize(30, 30)
        
        local normalTex = additionalTab:CreateTexture(nil, "BACKGROUND")
        normalTex:SetAllPoints()
        normalTex:SetTexture("Interface\\GuildFrame\\GuildFrame")
        normalTex:SetTexCoord(0.26171875, 0.31640625, 0.37109375, 0.45703125)
        additionalTab:SetNormalTexture(normalTex)
        
        local pushedTex = additionalTab:CreateTexture(nil, "BACKGROUND")
        pushedTex:SetAllPoints()
        pushedTex:SetTexture("Interface\\GuildFrame\\GuildFrame")
        pushedTex:SetTexCoord(0.3203125, 0.375, 0.37109375, 0.45703125)
        additionalTab:SetPushedTexture(pushedTex)
        
        local highlightTex = additionalTab:CreateTexture(nil, "HIGHLIGHT")
        highlightTex:SetAllPoints()
        highlightTex:SetTexture("Interface\\GuildFrame\\GuildFrame")
        highlightTex:SetTexCoord(0.37890625, 0.43359375, 0.37109375, 0.45703125)
        additionalTab:SetHighlightTexture(highlightTex)
        
        local disabledTex = additionalTab:CreateTexture(nil, "BACKGROUND")
        disabledTex:SetAllPoints()
        disabledTex:SetTexture("Interface\\GuildFrame\\GuildFrame")
        disabledTex:SetTexCoord(0.26171875, 0.31640625, 0.37109375, 0.45703125)
        disabledTex:SetDesaturated(true)
        additionalTab:SetDisabledTexture(disabledTex)
        
        local additionalIcon = additionalTab:CreateTexture(nil, "OVERLAY")
        additionalIcon:SetSize(28, 28)
        additionalIcon:SetPoint("CENTER")
        additionalIcon:SetTexture(buttonIcons[i])
        
        if i == 1 then
            additionalTab:SetPoint("TOP", tab, "BOTTOM", 0, -10)
        else
            additionalTab:SetPoint("TOP", additionalButtons[i-1], "BOTTOM", 0, -10)
        end
        
        additionalTab:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(buttonNames[i])
            GameTooltip:Show()
        end)
        
        additionalTab:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        if i == 1 then
            additionalTab:SetScript("OnClick", function()
                if _G.AferistHelperRatingUI and _G.AferistHelperRatingManager then
                    local canShow, message = _G.AferistHelperRatingManager:CanShowRatingUI()
                    if canShow then
                        _G.AferistHelperRatingUI:Show()
                    else
                        if message then
                            local dialogFrame = CreateFrame("Frame", "RatingUIWarningFrame", UIParent, "BasicFrameTemplate")
                            dialogFrame:SetSize(450, 180)
                            dialogFrame:SetPoint("CENTER")
                            dialogFrame:SetFrameStrata("FULLSCREEN_DIALOG")
                            dialogFrame:SetMovable(true)
                            dialogFrame:EnableMouse(true)
                            dialogFrame:RegisterForDrag("LeftButton")
                            dialogFrame:SetScript("OnDragStart", dialogFrame.StartMoving)
                            dialogFrame:SetScript("OnDragStop", dialogFrame.StopMovingOrSizing)
                            
                            dialogFrame.TitleText:SetText("Внимание")
                            
                            local messageText = dialogFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                            messageText:SetPoint("TOP", 0, -30)
                            messageText:SetWidth(400)
                            messageText:SetJustifyH("LEFT")
                            messageText:SetJustifyV("TOP")
                            messageText:SetText(message)
                            
                            local closeBtn = CreateFrame("Button", nil, dialogFrame, "UIPanelButtonTemplate")
                            closeBtn:SetSize(100, 25)
                            closeBtn:SetPoint("BOTTOM", 0, 15)
                            closeBtn:SetText("Понятно")
                            closeBtn:SetScript("OnClick", function()
                                dialogFrame:Hide()
                            end)
                            
                            dialogFrame:Show()
                        else
                            print("|cFFFF0000Ошибка:|r Интерфейс рейтингов не загружен")
                        end
                    end
                else
                    print("|cFFFF0000Ошибка:|r Интерфейс рейтингов не загружен")
                end
            end)
        else
            additionalTab:SetScript("OnClick", function()
                if CheckGuildPermissions() then
                    MuteManager:ToggleWindow()
                else
                    MuteManager:ShowNotification("Недостаточно прав для управления гильдией")
                end
            end)
        end
        
        table.insert(additionalButtons, additionalTab)
    end
    
    local function UpdateTabVisibility()
        if GuildFrame and GuildFrame:IsVisible() then
            tab:Show()
            for _, btn in ipairs(additionalButtons) do
                btn:Show()
            end
        else
            tab:Hide()
            for _, btn in ipairs(additionalButtons) do
                btn:Hide()
            end
        end
    end
    
    GuildFrame:HookScript("OnShow", UpdateTabVisibility)
    GuildFrame:HookScript("OnHide", UpdateTabVisibility)
    
    -- Инициализация видимости при первом открытии
    UpdateTabVisibility()
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
    
    local kickBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    kickBtn:SetSize(120, 25)
    kickBtn:SetPoint("TOPLEFT", 280, yOffset)
    kickBtn:SetText("Исключить")
    
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
    parent.kickBtn = kickBtn
    
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
	
	kickBtn:SetScript("OnClick", function()
        self:KickFromUI(nameEdit:GetText())
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
    
    if self:ExecuteRankCommands(playerName, targetRankIndex) then
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

function MuteManager:KickFromUI(playerName)
    if not playerName or playerName == "" then
        self:ShowNotification("Сначала найдите игрока")
        return
    end
    
    local playerInfo = self:GetPlayerInfo(playerName)
    if not playerInfo then
        self:ShowNotification("Игрок не найден в гильдии")
        return
    end

    self:ShowKickConfirmation(playerName, playerInfo)
end

function MuteManager:ShowKickConfirmation(playerName, playerInfo)
    local confirmFrame = CreateFrame("Frame", "MuteManagerKickConfirmFrame", UIParent, "BasicFrameTemplate")
    confirmFrame:SetSize(400, 200)
    confirmFrame:SetPoint("CENTER")
    confirmFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    confirmFrame:SetMovable(true)
    confirmFrame:EnableMouse(true)
    confirmFrame:RegisterForDrag("LeftButton")
    confirmFrame:SetScript("OnDragStart", confirmFrame.StartMoving)
    confirmFrame:SetScript("OnDragStop", confirmFrame.StopMovingOrSizing)
    
    confirmFrame.title = confirmFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    confirmFrame.title:SetPoint("TOP", 0, -5)
    confirmFrame.title:SetText("Подтверждение исключения")
    
    local warningText = confirmFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    warningText:SetPoint("TOP", 0, -25)
    warningText:SetText("Вы действительно хотите исключить игрока?")
    warningText:SetTextColor(1, 1, 0)
    
    local playerText = confirmFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    playerText:SetPoint("TOP", 0, -50)
    playerText:SetText(string.format("|cFFFF0000%s|r - %s (%d уровень)", 
        playerName, 
        playerInfo.rankName, 
        playerInfo.level or 0))
    
    local detailsText = confirmFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailsText:SetPoint("TOP", 0, -70)
    detailsText:SetText(string.format("Класс: %s | Зона: %s", 
        playerInfo.class or "Неизвестно", 
        playerInfo.zone or "Неизвестно"))
    
    local cautionText = confirmFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cautionText:SetPoint("TOP", 0, -90)
    cautionText:SetText("Это действие нельзя отменить!")
    cautionText:SetTextColor(1, 0.5, 0.5)
    
    local confirmBtn = CreateFrame("Button", nil, confirmFrame, "UIPanelButtonTemplate")
    confirmBtn:SetSize(120, 25)
    confirmBtn:SetPoint("BOTTOMLEFT", 50, 10)
    confirmBtn:SetText("Исключить")
    confirmBtn:SetScript("OnClick", function()
        self:PerformKickPlayer(playerName, playerInfo)
        confirmFrame:Hide()
    end)
    
    local cancelBtn = CreateFrame("Button", nil, confirmFrame, "UIPanelButtonTemplate")
    cancelBtn:SetSize(120, 25)
    cancelBtn:SetPoint("BOTTOMRIGHT", -50, 10)
    cancelBtn:SetText("Отмена")
    cancelBtn:SetScript("OnClick", function()
        confirmFrame:Hide()
    end)
    
    confirmFrame:Show()
end

function MuteManager:PerformKickPlayer(playerName, playerInfo)
    if not IsInGuild() then
        self:ShowNotification("Ошибка: Вы не в гильдии")
        return false
    end
    
    if not CanEditOfficerNote() then
        self:ShowNotification("Ошибка: Недостаточно прав для исключения")
        return false
    end
    
    local myInfo = self:GetPlayerInfo(UnitName("player"))
    if myInfo and playerInfo.fullName == myInfo.fullName then
        self:ShowNotification("Ошибка: Нельзя исключить себя")
        return false
    end
    
    local success = GuildUninvite(playerName)
    
    if success then
        self:ShowNotification(string.format("Игрок |cFFFF0000%s|r исключен из гильдии", playerName))
        self:Print(string.format("ИСКЛЮЧЕН: %s (%s, %d уровень) - %s", 
            playerName, 
            playerInfo.rankName, 
            playerInfo.level or 0,
            date("%d.%m %H:%M")))
        
        self:DelayedExecute(2, function()
            self:SearchPlayer(playerName)
        end)
        
        return true
    else
        self:ShowNotification("Ошибка при исключении игрока")
        return false
    end
end

function MuteManager:CreateActiveMutesTab(parent)
    local scrollFrame = CreateFrame("ScrollFrame", "MuteManagerActiveMutesScrollFrame", parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(400, 400)
    scrollFrame:SetScrollChild(scrollChild)
    
    parent.scrollFrame = scrollFrame
    parent.scrollChild = scrollChild
    
    local refreshBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    refreshBtn:SetSize(120, 25)
    refreshBtn:SetPoint("BOTTOMLEFT", 10, 10)
    refreshBtn:SetText("Обновить")
    refreshBtn:SetScript("OnClick", function()
        self:UpdateActiveMutesTab()
    end)
    
    parent.refreshBtn = refreshBtn
end

function MuteManager:UpdateActiveMutesTab()
    local parent = self.tabFrames[2]
    local scrollChild = parent.scrollChild
    
    for i = 1, #scrollChild.buttons or 0 do
        if scrollChild.buttons[i] then
            scrollChild.buttons[i]:Hide()
        end
    end
    
    scrollChild.buttons = {}
    
    local yOffset = -10
    local buttonHeight = 80
    
    local activeCount = 0
    
    for playerName, muteData in pairs(self.db.activeMutes) do
        local remaining = math.max(0, muteData.expireTime - time())
        if remaining > 0 then
            activeCount = activeCount + 1
            
            local button = CreateFrame("Frame", nil, scrollChild)
            button:SetSize(420, buttonHeight)
            button:SetPoint("TOPLEFT", 10, yOffset)
            
            button:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 }
            })
            button:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
            button:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
            
            local playerText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            playerText:SetPoint("TOPLEFT", 10, -10)
            playerText:SetText("|cFFFFFF00Игрок:|r |cFFFF0000" .. playerName .. "|r")
            
            local timeText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            timeText:SetPoint("TOPLEFT", 10, -30)
            
            local reasonText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            reasonText:SetPoint("TOPLEFT", 10, -50)
            reasonText:SetText("|cFFFFFF00Причина:|r " .. (muteData.reason or "не указана"))
            
            local mutedByText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            mutedByText:SetPoint("TOPRIGHT", -10, -10)
            mutedByText:SetText("|cFFFFFF00Выдал:|r " .. (muteData.mutedBy or "неизвестно"))
            
            local unmuteBtn = CreateFrame("Button", nil, button, "UIPanelButtonTemplate")
            unmuteBtn:SetSize(80, 22)
            unmuteBtn:SetPoint("BOTTOMRIGHT", -10, 10)
            unmuteBtn:SetText("Размутить")
            unmuteBtn:SetScript("OnClick", function()
                self:UnmuteFromUI(playerName)
                self:UpdateActiveMutesTab()
            end)
            
            button.playerText = playerText
            button.timeText = timeText
            button.reasonText = reasonText
            button.mutedByText = mutedByText
            button.unmuteBtn = unmuteBtn
            button.muteData = muteData
            button.playerName = playerName
            
            table.insert(scrollChild.buttons, button)
            
            yOffset = yOffset - buttonHeight - 5
        end
    end
    
    if activeCount == 0 then
        local noMutesText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noMutesText:SetPoint("CENTER")
        noMutesText:SetText("|cFFFF0000Нет активных мутов|r")
        table.insert(scrollChild.buttons, noMutesText)
    end
    
    scrollChild:SetHeight(math.max(400, math.abs(yOffset) + 10))
    
    self.activeMutesUpdateFrame = self.activeMutesUpdateFrame or CreateFrame("Frame")
    self.activeMutesUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
        MuteManager:UpdateActiveMutesTimers()
    end)
end

function MuteManager:UpdateActiveMutesTimers()
    if not self.tabFrames[2] or not self.tabFrames[2].scrollChild or not self.tabFrames[2].scrollChild.buttons then
        return
    end
    
    for _, button in ipairs(self.tabFrames[2].scrollChild.buttons) do
        if button.muteData then
            local remaining = math.max(0, button.muteData.expireTime - time())
            local remainingMinutes = math.floor(remaining / 60)
            local remainingSeconds = remaining % 60
            
            if remaining > 0 then
                button.timeText:SetText(string.format("|cFFFFFF00Осталось:|r |cFFFFFFFF%d:%02d|r", remainingMinutes, remainingSeconds))
                
                if remaining < 300 then
                    button.timeText:SetTextColor(1, 0.5, 0.5)
                else
                    button.timeText:SetTextColor(1, 1, 1)
                end
            else
                button.timeText:SetText("|cFFFF0000Истек|r")
                self:ScheduleTimer(function()
                    self:UpdateActiveMutesTab()
                end, 1)
            end
        end
    end
end

function MuteManager:CreateSettingsTab(parent)
    local yOffset = -20
    
    local autoDemoteCheckbox = CreateFrame("CheckButton", "MuteManagerAutoDemoteCheckbox", parent, "UICheckButtonTemplate")
    autoDemoteCheckbox:SetPoint("TOPLEFT", 20, yOffset)
    autoDemoteCheckbox:SetSize(24, 24)
    autoDemoteCheckbox.text:SetText("Автоматическое понижение ранга при муте")
    autoDemoteCheckbox:SetChecked(self.db.settings.autoDemote)
    
    yOffset = yOffset - 40
    
    local useOfficerNotesCheckbox = CreateFrame("CheckButton", "MuteManagerUseOfficerNotesCheckbox", parent, "UICheckButtonTemplate")
    useOfficerNotesCheckbox:SetPoint("TOPLEFT", 20, yOffset)
    useOfficerNotesCheckbox:SetSize(24, 24)
    useOfficerNotesCheckbox.text:SetText("Использовать офицерские заметки для хранения данных")
    useOfficerNotesCheckbox:SetChecked(self.db.settings.useOfficerNotes)
    
    yOffset = yOffset - 40
    
    local showNotificationsCheckbox = CreateFrame("CheckButton", "MuteManagerShowNotificationsCheckbox", parent, "UICheckButtonTemplate")
    showNotificationsCheckbox:SetPoint("TOPLEFT", 20, yOffset)
    showNotificationsCheckbox:SetSize(24, 24)
    showNotificationsCheckbox.text:SetText("Показывать уведомления")
    showNotificationsCheckbox:SetChecked(self.db.settings.showNotifications)
    
    yOffset = yOffset - 60
    
    local cleanupLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cleanupLabel:SetPoint("TOPLEFT", 20, yOffset)
    cleanupLabel:SetText("Автоочистка старых данных (дней):")
    
    yOffset = yOffset - 25
    
    local cleanupEdit = CreateFrame("EditBox", "MuteManagerCleanupEdit", parent)
    cleanupEdit:SetSize(80, 20)
    cleanupEdit:SetPoint("TOPLEFT", 20, yOffset)
    cleanupEdit:SetAutoFocus(false)
    cleanupEdit:SetNumeric(true)
    cleanupEdit:SetFontObject("GameFontNormal")
    cleanupEdit:SetTextInsets(8, 8, 0, 0)
    cleanupEdit:SetText(self.db.settings.cleanupDays)
    
    cleanupEdit:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    cleanupEdit:SetBackdropColor(0, 0, 0, 0.5)
    cleanupEdit:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    
    yOffset = yOffset - 40
    
    local saveSettingsBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    saveSettingsBtn:SetSize(120, 25)
    saveSettingsBtn:SetPoint("TOPLEFT", 20, yOffset)
    saveSettingsBtn:SetText("Сохранить настройки")
    
    parent.autoDemoteCheckbox = autoDemoteCheckbox
    parent.useOfficerNotesCheckbox = useOfficerNotesCheckbox
    parent.showNotificationsCheckbox = showNotificationsCheckbox
    parent.cleanupEdit = cleanupEdit
    parent.saveSettingsBtn = saveSettingsBtn
    
    saveSettingsBtn:SetScript("OnClick", function()
        self.db.settings.autoDemote = autoDemoteCheckbox:GetChecked()
        self.db.settings.useOfficerNotes = useOfficerNotesCheckbox:GetChecked()
        self.db.settings.showNotifications = showNotificationsCheckbox:GetChecked()
        self.db.settings.cleanupDays = tonumber(cleanupEdit:GetText()) or 30
        
        self:ShowNotification("Настройки сохранены")
    end)
    
    cleanupEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
end

function MuteManager:CreateCleanupTab(parent)
    local yOffset = -20
    
    local infoText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoText:SetPoint("TOPLEFT", 20, yOffset)
    infoText:SetSize(440, 100)
    infoText:SetJustifyH("LEFT")
    infoText:SetJustifyV("TOP")
    infoText:SetText("Эта функция позволяет очистить старые данные мута из офицерских заметок.\n\n|cFFFFFF00Внимание:|r Это действие нельзя отменить! Рекомендуется сделать бэкап данных перед очисткой.")
    
    yOffset = yOffset - 120
    
    local scanBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    scanBtn:SetSize(120, 25)
    scanBtn:SetPoint("TOPLEFT", 20, yOffset)
    scanBtn:SetText("Сканировать")
    
    yOffset = yOffset - 40
    
    local resultsFrame = CreateFrame("Frame", nil, parent)
    resultsFrame:SetPoint("TOPLEFT", 20, yOffset)
    resultsFrame:SetPoint("BOTTOMRIGHT", -20, 20)
    resultsFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    resultsFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    resultsFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    
    local resultsScroll = CreateFrame("ScrollFrame", "MuteManagerCleanupResultsScroll", resultsFrame, "UIPanelScrollFrameTemplate")
    resultsScroll:SetPoint("TOPLEFT", 10, -10)
    resultsScroll:SetPoint("BOTTOMRIGHT", -30, 10)
    
    local resultsContent = CreateFrame("Frame")
    resultsContent:SetSize(400, 400)
    resultsScroll:SetScrollChild(resultsContent)
    
    yOffset = yOffset - 280
    
    local cleanupBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    cleanupBtn:SetSize(120, 25)
    cleanupBtn:SetPoint("BOTTOMLEFT", 20, 20)
    cleanupBtn:SetText("Очистить")
    cleanupBtn:Disable()
    
    parent.infoText = infoText
    parent.scanBtn = scanBtn
    parent.resultsFrame = resultsFrame
    parent.resultsScroll = resultsScroll
    parent.resultsContent = resultsContent
    parent.cleanupBtn = cleanupBtn
    
    scanBtn:SetScript("OnClick", function()
        self:ScanForOldMutes()
    end)
    
    cleanupBtn:SetScript("OnClick", function()
        self:CleanupOldMutes()
    end)
end

function MuteManager:ScanForOldMutes()
    self.cleanupCandidates = {}
    local cutoffTime = time() - (self.db.settings.cleanupDays * 86400)
    
    local totalScanned = 0
    local candidatesFound = 0
    
    for i = 1, GetNumGuildMembers() do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName = GetGuildRosterInfo(i)
        totalScanned = totalScanned + 1
        
        if officernote and officernote ~= "" then
            local muteData = self:ParseMuteData(officernote)
            if muteData and muteData.timestamp and muteData.timestamp < cutoffTime then
                candidatesFound = candidatesFound + 1
                table.insert(self.cleanupCandidates, {
                    name = name,
                    officernote = officernote,
                    muteData = muteData,
                    daysOld = math.floor((time() - muteData.timestamp) / 86400)
                })
            end
        end
    end
    
    local resultsContent = self.tabFrames[4].resultsContent
    
    for i = 1, #resultsContent.lines or 0 do
        if resultsContent.lines[i] then
            resultsContent.lines[i]:Hide()
        end
    end
    
    resultsContent.lines = {}
    
    local yOffset = -10
    
    local summaryText = resultsContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    summaryText:SetPoint("TOPLEFT", 10, yOffset)
    summaryText:SetText(string.format("Просканировано: %d игроков\nНайдено кандидатов на очистку: %d", totalScanned, candidatesFound))
    table.insert(resultsContent.lines, summaryText)
    
    yOffset = yOffset - 40
    
    for i, candidate in ipairs(self.cleanupCandidates) do
        local lineText = resultsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lineText:SetPoint("TOPLEFT", 10, yOffset)
        lineText:SetSize(380, 30)
        lineText:SetJustifyH("LEFT")
        lineText:SetText(string.format("%s - %d дней (был замучен %s)", 
            candidate.name, 
            candidate.daysOld,
            date("%d.%m.%Y", candidate.muteData.timestamp)))
        table.insert(resultsContent.lines, lineText)
        
        yOffset = yOffset - 20
    end
    
    resultsContent:SetHeight(math.max(400, math.abs(yOffset) + 10))
    
    if candidatesFound > 0 then
        self.tabFrames[4].cleanupBtn:Enable()
    else
        self.tabFrames[4].cleanupBtn:Disable()
    end
end

function MuteManager:CleanupOldMutes()
    if #self.cleanupCandidates == 0 then
        self:ShowNotification("Нет данных для очистки")
        return
    end
    
    local cleaned = 0
    
    for _, candidate in ipairs(self.cleanupCandidates) do
        if self:SetGuildMemberNote(candidate.name, "", true) then
            cleaned = cleaned + 1
        end
    end
    
    self:ShowNotification(string.format("Очищено %d заметок", cleaned))
    self.tabFrames[4].cleanupBtn:Disable()
    self:ScanForOldMutes()
end

function MuteManager:ShowTab(tabIndex)
    for i, frame in ipairs(self.tabFrames) do
        if i == tabIndex then
            frame:Show()
            PanelTemplates_SetTab(self.mainFrame, i)
        else
            frame:Hide()
        end
    end
end

function MuteManager:ToggleWindow()
    if not self.mainFrame then
        self:CreateMainWindow()
    end
    
    if self.mainFrame:IsShown() then
        self.mainFrame:Hide()
    else
        self.mainFrame:Show()
        self:UpdateActiveMutesTab()
    end
end

function MuteManager:ShowNotification(message)
    if self.db.settings.showNotifications then
        UIErrorsFrame:AddMessage(message, 1.0, 1.0, 0.0, 1.0)
    end
end

function MuteManager:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00MuteManager:|r " .. message)
end

function MuteManager:GetPlayerInfo(playerName)
    if not IsInGuild() then return nil end
    
    for i = 1, GetNumGuildMembers() do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName = GetGuildRosterInfo(i)
        if name and (name:lower() == playerName:lower() or Ambiguate(name, "none"):lower() == playerName:lower()) then
            return {
                fullName = name,
                rankName = rank,
                rankIndex = rankIndex,
                level = level,
                class = class,
                zone = zone,
                note = note,
                officernote = officernote,
                online = online,
                status = status,
                classFileName = classFileName
            }
        end
    end
    return nil
end

function MuteManager:SetGuildMemberNote(playerName, noteText, isOfficerNote)
    if not IsInGuild() then return false end
    
    if isOfficerNote and not CanEditOfficerNote() then
        self:ShowNotification("Недостаточно прав для редактирования офицерских заметок")
        return false
    end
    
    for i = 1, GetNumGuildMembers() do
        local name = GetGuildRosterInfo(i)
        if name and (name:lower() == playerName:lower() or Ambiguate(name, "none"):lower() == playerName:lower()) then
            GuildRosterSetPublicNote(i, isOfficerNote and "" or noteText)
            if isOfficerNote then
                GuildRosterSetOfficerNote(i, noteText)
            end
            GuildRoster()
            return true
        end
    end
    
    return false
end

function MuteManager:ExecuteRankCommands(playerName, targetRankIndex)
    if not IsInGuild() then return false end
    
    if not CanEditOfficerNote() then
        self:ShowNotification("Недостаточно прав для изменения рангов")
        return false
    end
    
    local playerInfo = self:GetPlayerInfo(playerName)
    if not playerInfo then
        self:ShowNotification("Игрок не найден")
        return false
    end
    
    if playerInfo.rankIndex == targetRankIndex then
        self:ShowNotification("Игрок уже имеет этот ранг")
        return true
    end
    
    local myInfo = self:GetPlayerInfo(UnitName("player"))
    if myInfo and playerInfo.fullName == myInfo.fullName then
        self:ShowNotification("Нельзя изменить свой собственный ранг")
        return false
    end
    
    local success = GuildSetRankOrder(playerInfo.fullName, targetRankIndex)
    
    if success then
        self:ShowNotification(string.format("Ранг игрока %s изменен на %d", playerName, targetRankIndex))
        return true
    else
        self:ShowNotification("Ошибка изменения ранга")
        return false
    end
end

function MuteManager:MutePlayer(playerName, duration, reason)
    if not IsInGuild() then
        self:ShowNotification("Ошибка: Вы не в гильдии")
        return false
    end
    
    if not CanEditOfficerNote() then
        self:ShowNotification("Ошибка: Недостаточно прав для мута")
        return false
    end
    
    local playerInfo = self:GetPlayerInfo(playerName)
    if not playerInfo then
        self:ShowNotification("Ошибка: Игрок не найден в гильдии")
        return false
    end
    
    local myInfo = self:GetPlayerInfo(UnitName("player"))
    if myInfo and playerInfo.fullName == myInfo.fullName then
        self:ShowNotification("Ошибка: Нельзя замутить себя")
        return false
    end
    
    if self.db.activeMutes[playerName] then
        self:ShowNotification("Ошибка: Игрок уже замучен")
        return false
    end
    
    local expireTime = time() + (duration * 60)
    local muteData = {
        expireTime = expireTime,
        reason = reason or "не указана",
        mutedBy = UnitName("player"),
        timestamp = time(),
        originalRank = playerInfo.rankIndex
    }
    
    self.db.activeMutes[playerName] = muteData
    
    if self.db.settings.useOfficerNotes then
        local noteData = string.format("MUTE:%d:%s:%s:%d", expireTime, reason or "", UnitName("player"), playerInfo.rankIndex)
        self:SetGuildMemberNote(playerName, noteData, true)
    end
    
    if self.db.settings.autoDemote and playerInfo.rankIndex < self.db.muteRank then
        self:ExecuteRankCommands(playerName, self.db.muteRank)
    end
    
    self:ShowNotification(string.format("Игрок |cFFFF0000%s|r замучен на %d минут", playerName, duration))
    self:Print(string.format("МУТ: %s на %d мин - %s [%s]", playerName, duration, reason or "не указана", UnitName("player")))
    
    return true
end

function MuteManager:UnmutePlayer(playerName)
    if not IsInGuild() then
        self:ShowNotification("Ошибка: Вы не в гильдии")
        return false
    end
    
    if not CanEditOfficerNote() then
        self:ShowNotification("Ошибка: Недостаточно прав для размута")
        return false
    end
    
    local playerInfo = self:GetPlayerInfo(playerName)
    if not playerInfo then
        self:ShowNotification("Ошибка: Игрок не найден в гильдии")
        return false
    end
    
    if not self.db.activeMutes[playerName] then
        self:ShowNotification("Ошибка: Игрок не замучен")
        return false
    end
    
    local muteData = self.db.activeMutes[playerName]
    
    self.db.activeMutes[playerName] = nil
    
    if self.db.settings.useOfficerNotes then
        self:SetGuildMemberNote(playerName, "", true)
    end
    
    if self.db.settings.autoDemote and muteData.originalRank then
        self:ExecuteRankCommands(playerName, muteData.originalRank)
    end
    
    self:ShowNotification(string.format("Игрок |cFF00FF00%s|r размучен", playerName))
    self:Print(string.format("РАЗМУТ: %s [%s]", playerName, UnitName("player")))
    
    return true
end

function MuteManager:ParseMuteData(noteText)
    if not noteText or type(noteText) ~= "string" then
        return nil
    end
    
    if noteText:match("^MUTE:") then
        local parts = {strsplit(":", noteText)}
        if #parts >= 4 then
            return {
                expireTime = tonumber(parts[2]),
                reason = parts[3],
                mutedBy = parts[4],
                originalRank = tonumber(parts[5]),
                timestamp = tonumber(parts[6]) or time()
            }
        end
    end
    
    return nil
end

function MuteManager:LoadMutesFromNotes()
    if not IsInGuild() then return end
    
    for i = 1, GetNumGuildMembers() do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status = GetGuildRosterInfo(i)
        if officernote and officernote ~= "" then
            local muteData = self:ParseMuteData(officernote)
            if muteData then
                if muteData.expireTime > time() then
                    self.db.activeMutes[name] = muteData
                else
                    self:SetGuildMemberNote(name, "", true)
                end
            end
        end
    end
end

function MuteManager:CheckExpiredMutes()
    local currentTime = time()
    local expiredPlayers = {}
    
    for playerName, muteData in pairs(self.db.activeMutes) do
        if muteData.expireTime <= currentTime then
            table.insert(expiredPlayers, playerName)
        end
    end
    
    for _, playerName in ipairs(expiredPlayers) do
        self:UnmutePlayer(playerName)
    end
end

function MuteManager:DelayedExecute(delay, func)
    -- Реализация для WoW 3.3.5 без C_Timer
    local frame = CreateFrame("Frame")
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= delay then
            func()
            self:SetScript("OnUpdate", nil)
        end
    end)
end

function MuteManager:ScheduleTimer(func, delay)
    -- Реализация для WoW 3.3.5 без C_Timer
    local frame = CreateFrame("Frame")
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= delay then
            func()
            self:SetScript("OnUpdate", nil)
        end
    end)
end

function MuteManager:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        -- Исправлено: проверяем правильное имя аддона
        if addonName == "AferistHelper" then
            MuteManagerDB = MuteManagerDB or {}
            self.db = setmetatable(MuteManagerDB, {__index = self.db})
            
            self:LoadMutesFromNotes()
            self:ScheduleRepeatingTimer(function() self:CheckExpiredMutes() end, 60)
            
            -- Отложенная инициализация кнопок через таймер (совместимо с WoW 3.3.5)
            local initFrame = CreateFrame("Frame")
            local elapsed = 0
            initFrame:SetScript("OnUpdate", function(self, delta)
                elapsed = elapsed + delta
                if elapsed >= 1 then
                    self:SetScript("OnUpdate", nil)
                    CreateGuildTabButtons()
                end
            end)
            
            self:Print("MuteManager загружен")
        end
    elseif event == "GUILD_ROSTER_UPDATE" then
        self:UpdateGuildRanks()
        self:LoadMutesFromNotes()
    end
end

function MuteManager:UpdateGuildRanks()
    if not IsInGuild() then return end
    
    for i = 1, GuildControlGetNumRanks() do
        self.db.guildRanks[i-1] = GuildControlGetRankName(i)
    end
end

function MuteManager:ScheduleRepeatingTimer(func, interval)
    local frame = CreateFrame("Frame")
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= interval then
            func()
            elapsed = 0
        end
    end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:SetScript("OnEvent", function(self, event, ...)
    MuteManager:OnEvent(event, ...)
end)

SLASH_MUTEMANAGER1 = "/mm"
SLASH_MUTEMANAGER2 = "/mutemanager"
SlashCmdList["MUTEMANAGER"] = function(msg)
    if CheckGuildPermissions() then
        MuteManager:ToggleWindow()
    else
        MuteManager:ShowNotification("Недостаточно прав для управления гильдией")
    end
end
