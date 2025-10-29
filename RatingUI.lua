local RatingUI = {}
local RatingManager = _G.AferistHelperRatingManager

-- Создание основного окна рейтингов
function RatingUI:CreateMainFrame()
    local frame = CreateFrame("Frame", "AferistHelperRatingFrame", UIParent, "BasicFrameTemplate")
    frame:SetSize(600, 450) -- Уменьшено с 800x600 до 600x450
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    frame.TitleText:SetText("Система рейтингов гильдии")
    
    -- Создание вкладок
    self:CreateTabs(frame)
    
    -- Создание области контента
    self:CreateContentArea(frame)
    
    frame:Hide()
    return frame
end

-- Создание вкладок
function RatingUI:CreateTabs(parent)
    local tabs = {"Топ игроков", "Мой рейтинг", "Поставить рейтинг", "Статистика"}
    
    for i, tabName in ipairs(tabs) do
        local tab = CreateFrame("Button", "AferistHelperRatingTab"..i, parent, "UIPanelButtonTemplate")
        tab:SetSize(100, 22) -- Уменьшено с 120x25 до 100x22
        tab:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 10 + ((i-1) * 105), 2) -- Уменьшены отступы
        tab:SetText(tabName)
        
        tab:SetScript("OnClick", function() 
            self:SwitchTab(tabName:lower():gsub(" ", "_")) 
        end)
        
        parent.tabs = parent.tabs or {}
        parent.tabs[tabName:lower():gsub(" ", "_")] = tab
    end
end

-- Создание области контента
function RatingUI:CreateContentArea(parent)
    parent.content = CreateFrame("Frame", nil, parent)
    parent.content:SetPoint("TOPLEFT", 8, -45) -- Уменьшены отступы
    parent.content:SetPoint("BOTTOMRIGHT", -8, 35)
    
    -- Создание скролл-фрейма
    parent.scrollFrame = CreateFrame("ScrollFrame", "AferistHelperRatingScrollFrame", parent.content, "UIPanelScrollFrameTemplate")
    parent.scrollFrame:SetPoint("TOPLEFT", 3, -3)
    parent.scrollFrame:SetPoint("BOTTOMRIGHT", -20, 3)
    
    parent.scrollChild = CreateFrame("Frame", "AferistHelperRatingScrollChild", parent.scrollFrame)
    parent.scrollFrame:SetScrollChild(parent.scrollChild)
    parent.scrollChild:SetSize(550, 350) -- Уменьшено с 750x500
end

-- Обновленная функция SwitchTab
function RatingUI:SwitchTab(tabName)
    local frame = _G.AferistHelperRatingFrame
    if not frame then return end
    
    -- Сброс состояния всех вкладок
    for name, tab in pairs(frame.tabs) do
        tab:SetButtonState("NORMAL", false)
    end
    
    -- Установка активной вкладки
    if frame.tabs[tabName] then
        frame.tabs[tabName]:SetButtonState("PUSHED", true)
    end
    
    -- Очистка контента
    if frame.scrollChild.elements then
        for _, element in pairs(frame.scrollChild.elements) do
            element:Hide()
        end
    end
    frame.scrollChild.elements = {}
    
    -- Загрузка контента вкладки
    if tabName == "топ_игроков" then
        self:ShowTopPlayers(frame.scrollChild)
    elseif tabName == "мой_рейтинг" then
        self:ShowMyRating(frame.scrollChild)
    elseif tabName == "поставить_рейтинг" then
        self:ShowRatingForm(frame.scrollChild)
    elseif tabName == "статистика" then
        self:ShowStats(frame.scrollChild)
    end
end

-- Показ топа игроков
function RatingUI:ShowTopPlayers(parent)
    local topPlayers = RatingManager:GetTopPlayers(15) -- Уменьшено с 20 до 15
    
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -5) -- Уменьшен отступ
    title:SetText("|cFFFFFF00Топ игроков по рейтингу|r")
    table.insert(parent.elements, title)
    
    if #topPlayers == 0 then
        local noData = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noData:SetPoint("TOP", 0, -35) -- Уменьшен отступ
        noData:SetText("Нет данных о рейтингах")
        table.insert(parent.elements, noData)
        return
    end
    
    local yOffset = -35 -- Уменьшен отступ
    for i, player in ipairs(topPlayers) do
        local playerFrame = self:CreatePlayerCard(parent, player, i, yOffset)
        table.insert(parent.elements, playerFrame)
        yOffset = yOffset - 50 -- Уменьшено с 60 до 50
    end
end

-- Создание карточки истории рейтинга
function RatingUI:CreateRatingHistoryCard(parent, ratingData, yOffset)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(550, 30) -- Уменьшено с 700x35 до 550x30
    card:SetPoint("TOPLEFT", 0, yOffset)
    
    card:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    card:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
    card:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
    
    -- Рейтинг
    local ratingText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ratingText:SetPoint("LEFT", 8, 0) -- Уменьшен отступ
    local color = ratingData.rating > 0 and "|cFF00FF00+" or "|cFFFF0000"
    ratingText:SetText(string.format("%s%d|r", color, ratingData.rating))
    
    -- От кого
    local senderText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    senderText:SetPoint("LEFT", 50, 0) -- Уменьшен отступ
    senderText:SetText("от |cFF00FF00" .. ratingData.sender .. "|r")
    
    -- Причина
    if ratingData.reason and ratingData.reason ~= "" then
        local reasonText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        reasonText:SetPoint("LEFT", 180, 0) -- Уменьшен отступ
        reasonText:SetText("(" .. ratingData.reason .. ")")
    end
    
    -- Время
    local timeText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timeText:SetPoint("RIGHT", -8, 0) -- Уменьшен отступ
    timeText:SetText(date("%d.%m %H:%M", ratingData.timestamp))
    
    return card
end

-- Показ моего рейтинга
function RatingUI:ShowMyRating(parent)
    local playerName = UnitName("player")
    local rating, ratings = RatingManager:GetPlayerRating(playerName)
    
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -5) -- Уменьшен отступ
    title:SetText("|cFFFFFF00Мой рейтинг|r")
    table.insert(parent.elements, title)
    
    local ratingText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ratingText:SetPoint("TOP", 0, -35) -- Уменьшен отступ
    local color = rating >= 0 and "|cFF00FF00" or "|cFFFF0000"
    ratingText:SetText(string.format("Общий рейтинг: %s%d|r", color, rating))
    table.insert(parent.elements, ratingText)
    
    if #ratings == 0 then
        local noData = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noData:SetPoint("TOP", 0, -65) -- Уменьшен отступ
        noData:SetText("У вас пока нет рейтингов")
        table.insert(parent.elements, noData)
        return
    end
    
    local historyTitle = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    historyTitle:SetPoint("TOP", 0, -65) -- Уменьшен отступ
    historyTitle:SetText("История рейтингов:")
    table.insert(parent.elements, historyTitle)
    
    local yOffset = -85 -- Уменьшен отступ
    for i, ratingData in ipairs(ratings) do
        if i > 15 then break end -- Уменьшено с 20 до 15
        
        local ratingFrame = self:CreateRatingHistoryCard(parent, ratingData, yOffset)
        table.insert(parent.elements, ratingFrame)
        yOffset = yOffset - 35 -- Уменьшено с 40 до 35
    end
end

-- Создание карточки игрока
function RatingUI:CreatePlayerCard(parent, player, rank, yOffset)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(550, 45) -- Уменьшено с 700x55 до 550x45
    card:SetPoint("TOPLEFT", 0, yOffset)
    
    card:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    
    -- Цвет фона в зависимости от места
    if rank <= 3 then
        local colors = {
            {1, 0.84, 0}, -- Золото
            {0.75, 0.75, 0.75}, -- Серебро
            {0.8, 0.5, 0.2} -- Бронза
        }
        card:SetBackdropColor(colors[rank][1], colors[rank][2], colors[rank][3], 0.3)
    else
        card:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    end
    
    card:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    
    -- Место
    local rankText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rankText:SetPoint("LEFT", 8, 0) -- Уменьшен отступ
    rankText:SetText(string.format("#%d", rank))
    
    -- Имя игрока
    local nameText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", 50, 0) -- Уменьшен отступ
    nameText:SetText("|cFFFFFFFF" .. player.name .. "|r")
    
    -- Рейтинг
    local ratingText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ratingText:SetPoint("RIGHT", -8, 0) -- Уменьшен отступ
    local color = player.rating >= 0 and "|cFF00FF00" or "|cFFFF0000"
    ratingText:SetText(string.format("%s%d|r", color, player.rating))
    
    -- Детали
    local detailsText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailsText:SetPoint("LEFT", 50, -12) -- Уменьшен отступ
    detailsText:SetText(string.format("Обновлено: %s", date("%d.%m.%Y %H:%M", player.last_updated)))
    
    return card
end

-- Создание карточки истории рейтинга
function RatingUI:CreateRatingHistoryCard(parent, ratingData, yOffset)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(700, 35)
    card:SetPoint("TOPLEFT", 0, yOffset)
    
    card:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    card:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
    card:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
    
    -- Рейтинг
    local ratingText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ratingText:SetPoint("LEFT", 10, 0)
    local color = ratingData.rating > 0 and "|cFF00FF00+" or "|cFFFF0000"
    ratingText:SetText(string.format("%s%d|r", color, ratingData.rating))
    
    -- От кого
    local senderText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    senderText:SetPoint("LEFT", 60, 0)
    senderText:SetText("от |cFF00FF00" .. ratingData.sender .. "|r")
    
    -- Причина
    if ratingData.reason and ratingData.reason ~= "" then
        local reasonText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        reasonText:SetPoint("LEFT", 200, 0)
        reasonText:SetText("(" .. ratingData.reason .. ")")
    end
    
    -- Время
    local timeText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timeText:SetPoint("RIGHT", -10, 0)
    timeText:SetText(date("%d.%m %H:%M", ratingData.timestamp))
    
    return card
end

-- Показ формы для постановки рейтинга
function RatingUI:ShowRatingForm(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -5)
    title:SetText("|cFFFFFF00Поставить рейтинг|r")
    table.insert(parent.elements, title)
    
    -- Поиск игрока
    local searchLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("TOPLEFT", 15, -35)
    searchLabel:SetText("Поиск игрока:")
    table.insert(parent.elements, searchLabel)
    
    local nameEditBox = CreateFrame("EditBox", nil, parent)
    nameEditBox:SetSize(200, 18)
    nameEditBox:SetPoint("TOPLEFT", 15, -50)
    nameEditBox:SetAutoFocus(false)
    nameEditBox:SetFontObject("GameFontNormal")
    nameEditBox:SetTextInsets(8, 8, 0, 0)
    
    nameEditBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    nameEditBox:SetBackdropColor(0, 0, 0, 0.5)
    nameEditBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    table.insert(parent.elements, nameEditBox)
    
    local searchBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    searchBtn:SetSize(80, 22)
    searchBtn:SetPoint("TOPLEFT", 225, -45)
    searchBtn:SetText("Найти")
    searchBtn:SetScript("OnClick", function()
        self:SearchPlayerForRating(nameEditBox:GetText())
    end)
    table.insert(parent.elements, searchBtn)
    
    -- Информация об игроке
    local infoFrame = CreateFrame("Frame", nil, parent)
    infoFrame:SetPoint("TOPLEFT", 15, -80)
    infoFrame:SetPoint("TOPRIGHT", -15, -80)
    infoFrame:SetHeight(120)
    
    infoFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    infoFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    infoFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    table.insert(parent.elements, infoFrame)
    
    local infoTitle = infoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoTitle:SetPoint("TOP", 0, -8)
    infoTitle:SetText("Информация об игроке")
    infoTitle:SetTextColor(1, 1, 0)
    
    local infoText = infoFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    infoText:SetPoint("TOPLEFT", 15, -30)
    infoText:SetSize(infoFrame:GetWidth() - 30, 80)
    infoText:SetJustifyH("LEFT")
    infoText:SetJustifyV("TOP")
    infoText:SetText("Введите ник игрока и нажмите 'Найти'")
    
    -- Сохраняем ссылки для использования в других функциях
    parent.nameEditBox = nameEditBox
    parent.searchBtn = searchBtn
    parent.infoFrame = infoFrame
    parent.infoText = infoText
    
    -- Поле ввода причины
    local reasonLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    reasonLabel:SetPoint("TOPLEFT", 15, -210)
    reasonLabel:SetText("Причина (необязательно):")
    table.insert(parent.elements, reasonLabel)
    
    local reasonEditBox = CreateFrame("EditBox", nil, parent)
    reasonEditBox:SetSize(350, 18)
    reasonEditBox:SetPoint("TOPLEFT", 15, -225)
    reasonEditBox:SetAutoFocus(false)
    reasonEditBox:SetFontObject("GameFontNormal")
    reasonEditBox:SetTextInsets(8, 8, 0, 0)
    
    reasonEditBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    reasonEditBox:SetBackdropColor(0, 0, 0, 0.5)
    reasonEditBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    table.insert(parent.elements, reasonEditBox)
    
    -- Выбор рейтинга
    local ratingLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ratingLabel:SetPoint("TOPLEFT", 15, -255)
    ratingLabel:SetText("Рейтинг:")
    table.insert(parent.elements, ratingLabel)
    
    local positiveBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    positiveBtn:SetSize(70, 22)
    positiveBtn:SetPoint("TOPLEFT", 15, -275)
    positiveBtn:SetText("+1")
    positiveBtn:SetScript("OnClick", function()
        self:SubmitRating(nameEditBox:GetText(), 1, reasonEditBox:GetText())
    end)
    table.insert(parent.elements, positiveBtn)
    
    local negativeBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    negativeBtn:SetSize(70, 22)
    negativeBtn:SetPoint("TOPLEFT", 90, -275)
    negativeBtn:SetText("-1")
    negativeBtn:SetScript("OnClick", function()
        self:SubmitRating(nameEditBox:GetText(), -1, reasonEditBox:GetText())
    end)
    table.insert(parent.elements, negativeBtn)
    
    -- Информация о лимитах
    local limitInfo = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    limitInfo:SetPoint("TOPLEFT", 15, -305)
    limitInfo:SetText("Лимит: 10 рейтингов в день, 1 рейтинг в час на игрока")
    table.insert(parent.elements, limitInfo)
    
    -- Обработчики событий
    nameEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    nameEditBox:SetScript("OnEnterPressed", function(self)
        self:SearchPlayerForRating(self:GetText())
        self:ClearFocus()
    end)
    
    reasonEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
end

-- Поиск игрока для рейтинга
function RatingUI:SearchPlayerForRating(playerName)
    if not playerName or playerName == "" then
        self:UpdatePlayerInfo("|cFFFF0000Введите ник игрока|r")
        return
    end
    
    if not IsInGuild() then
        self:UpdatePlayerInfo("|cFFFF0000Вы не в гильдии|r")
        return
    end
    
    -- Поиск игрока в гильдии
    local playerInfo = self:GetGuildPlayerInfo(playerName)
    if not playerInfo then
        self:UpdatePlayerInfo("|cFFFF0000Игрок '" .. playerName .. "' не найден в гильдии|r")
        return
    end
    
    -- Получение рейтинга игрока
    local rating, ratings = RatingManager:GetPlayerRating(playerName)
    
    -- Формирование информации об игроке (упрощенная версия)
    local infoText = string.format(
        "|cFFFFFF00Игрок:|r |cFFFFFFFF%s|r\n" ..
        "|cFFFFFF00Ранг:|r |cFFFFFFFF%s (%d)|r\n" ..
        "|cFFFFFF00Класс:|r |cFFFFFFFF%s|r\n" ..
        "|cFFFFFF00Текущий рейтинг:|r %s%d|r\n" ..
        "|cFFFFFF00Всего рейтингов:|r |cFFFFFFFF%d|r",
        playerInfo.fullName,
        playerInfo.rankName,
        playerInfo.rankIndex,
        playerInfo.class or "Неизвестно",
        rating >= 0 and "|cFF00FF00+" or "|cFFFF0000",
        rating,
        #ratings
    )
    
    self:UpdatePlayerInfo(infoText)
end

-- Обновление информации об игроке
function RatingUI:UpdatePlayerInfo(text)
    local frame = _G.AferistHelperRatingFrame
    if frame and frame.scrollChild and frame.scrollChild.infoText then
        frame.scrollChild.infoText:SetText(text)
    end
end

-- Получение информации об игроке из гильдии
function RatingUI:GetGuildPlayerInfo(playerName)
    if not IsInGuild() then return nil end
    if not playerName or playerName == "" then return nil end
    
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

-- Отправка рейтинга
function RatingUI:SubmitRating(playerName, rating, reason)
    if not playerName or playerName == "" then
        print("|cFFFF0000Ошибка:|r Введите имя игрока")
        return
    end
    
    -- Проверка, что игрок найден в гильдии
    local playerInfo = self:GetGuildPlayerInfo(playerName)
    if not playerInfo then
        print("|cFFFF0000Ошибка:|r Игрок '" .. playerName .. "' не найден в гильдии")
        return
    end
    
    local success, message = RatingManager:AddRating(playerName, rating, reason)
    if success then
        print("|cFF00FF00" .. message .. "|r")
        -- Обновление информации об игроке после добавления рейтинга
        self:SearchPlayerForRating(playerName)
    else
        print("|cFFFF0000Ошибка:|r " .. message)
    end
end

-- Показ статистики
function RatingUI:ShowStats(parent)
    local stats = RatingManager:GetStats()
    
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cFFFFFF00Статистика системы рейтингов|r")
    table.insert(parent.elements, title)
    
    local statsText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsText:SetPoint("TOP", 0, -50)
    statsText:SetText(string.format([[
|cFFFFFFFFОбщая статистика:|r
• Всего игроков с рейтингом: |cFF00FF00%d|r
• Всего поставлено рейтингов: |cFF00FF00%d|r
• Средний рейтинг: |cFF00FF00%.1f|r
• Последняя синхронизация: |cFF00FF00%s|r
]], 
        stats.totalPlayers,
        stats.totalRatings,
        stats.avgRating,
        stats.lastSync > 0 and date("%d.%m.%Y %H:%M", stats.lastSync) or "никогда"
    ))
    table.insert(parent.elements, statsText)
    
end

-- Показ окна
function RatingUI:Show()
    if not _G.AferistHelperRatingFrame then
        self:CreateMainFrame()
    end
    
    _G.AferistHelperRatingFrame:Show()
    self:SwitchTab("топ_игроков")
end

-- Скрытие окна
function RatingUI:Hide()
    if _G.AferistHelperRatingFrame then
        _G.AferistHelperRatingFrame:Hide()
    end
end



-- Глобальный доступ
_G.AferistHelperRatingUI = RatingUI

return RatingUI
