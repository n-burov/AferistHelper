local RatingManager = {}
local ADDON_NAME = "AferistHelper"

local CONFIG = {
    MAX_RATINGS_PER_DAY = 10,
    SYNC_INTERVAL = 300,
    MESSAGE_PREFIX = "AFERIST_RATING",
    VERSION = "1.0",
    WEEKLY_DECAY_PERCENT = 10,
}

local ratings = {}
local pending_sync = {}
local sync_queue = {}
local last_sync = 0
local daily_ratings = {}
local daily_reset_time = 0
local initialized = false

local commPrefix = "AFERIST_RATING"

function RatingManager:Initialize()
    if initialized then
        return true
    end
    
    self:LoadData()
    self:SetupEventHandlers()
    self:StartSyncTimer()
    self:ResetDailyCounters()
    self:InitializeContextMenu()
    
    if RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(commPrefix)
    end
    
    initialized = true
    print("|cFF00FF00RatingManager инициализирован|r")
    return true
end

function RatingManager:IsInitialized()
    return initialized
end

function RatingManager:LoadData()
    if not AferistHelperDB then
        AferistHelperDB = {}
    end
    
    if not AferistHelperDB.guild_ratings then
        AferistHelperDB.guild_ratings = {
            ratings = {},
            sync_data = {},
            last_sync = 0,
            daily_counters = {}
        }
    end
    
    ratings = AferistHelperDB.guild_ratings.ratings or {}
    pending_sync = AferistHelperDB.guild_ratings.sync_data or {}
    last_sync = AferistHelperDB.guild_ratings.last_sync or 0
    daily_ratings = AferistHelperDB.guild_ratings.daily_counters or {}
end

function RatingManager:SaveData()
    if not AferistHelperDB then
        AferistHelperDB = {}
    end
    
    if not AferistHelperDB.guild_ratings then
        AferistHelperDB.guild_ratings = {}
    end
    
    AferistHelperDB.guild_ratings = {
        ratings = ratings,
        sync_data = pending_sync,
        last_sync = last_sync,
        daily_counters = daily_ratings
    }
end

function RatingManager:AddRating(targetPlayer, rating, reason)
    if not initialized then
        return false, "Система рейтингов не инициализирована"
    end
    
    if not self:CanRatePlayer(targetPlayer) then
        return false, "Нельзя поставить рейтинг этому игроку"
    end
    
    if not self:HasDailyRatingLeft() then
        return false, "Превышен лимит рейтингов на сегодня"
    end
    
    if rating ~= 1 and rating ~= -1 then
        return false, "Рейтинг может быть только +1 или -1"
    end
    
    local ratingData = {
        target = targetPlayer,
        rating = rating,
        reason = reason or "",
        timestamp = time(),
        sender = UnitName("player")
    }
    
    if not ratings[targetPlayer] then
        ratings[targetPlayer] = {
            total_rating = 0,
            ratings = {},
            last_updated = time()
        }
    end
    
    table.insert(ratings[targetPlayer].ratings, ratingData)
    ratings[targetPlayer].total_rating = ratings[targetPlayer].total_rating + rating
    ratings[targetPlayer].last_updated = time()
    
    table.insert(sync_queue, ratingData)
    
    self:IncrementDailyCounter()
    
    self:SaveData()
    
    local message = string.format("|cFF00FF00Рейтинг|r: %s %s%d|r (%s)", 
        targetPlayer, 
        rating > 0 and "|cFF00FF00+" or "|cFFFF0000", 
        rating, 
        reason or "без причины")
    print(message)
    
    return true, "Рейтинг успешно добавлен"
end

function RatingManager:GetPlayerRating(playerName)
    if not initialized then
        return 0, {}
    end
    
    if not ratings[playerName] then
        return 0, {}
    end
    
    local decayed_rating = self:GetDecayedRating(ratings[playerName])
    return decayed_rating, ratings[playerName].ratings
end

function RatingManager:GetTopPlayers(limit)
    if not initialized then
        return {}
    end
    
    limit = limit or 10
    local players = {}
    
    for playerName, data in pairs(ratings) do
        local decayed_rating = self:GetDecayedRating(data)
        table.insert(players, {
            name = playerName,
            rating = decayed_rating,
            base_rating = data.total_rating,
            last_updated = data.last_updated
        })
    end
    
    table.sort(players, function(a, b)
        if a.rating == b.rating then
            return a.last_updated > b.last_updated
        end
        return a.rating > b.rating
    end)
    
    local result = {}
    for i = 1, math.min(limit, #players) do
        table.insert(result, players[i])
    end
    
    return result
end

function RatingManager:CanRatePlayer(targetPlayer)
    local playerName = UnitName("player")
    
    if targetPlayer == playerName then
        return false
    end
    
    if not self:IsPlayerInGuild(targetPlayer) then
        return false
    end
    
    if ratings[targetPlayer] then
        local currentTime = time()
        for _, ratingData in ipairs(ratings[targetPlayer].ratings) do
            if ratingData.sender == playerName and 
               (currentTime - ratingData.timestamp) < 3600 then
                return false
            end
        end
    end
    
    return true
end

function RatingManager:HasDailyRatingLeft()
    local playerName = UnitName("player")
    local today = date("%Y-%m-%d")
    
    if daily_ratings[today] and daily_ratings[today][playerName] then
        return daily_ratings[today][playerName] < CONFIG.MAX_RATINGS_PER_DAY
    end
    
    return true
end

function RatingManager:IncrementDailyCounter()
    local playerName = UnitName("player")
    local today = date("%Y-%m-%d")
    
    if not daily_ratings[today] then
        daily_ratings[today] = {}
    end
    
    if not daily_ratings[today][playerName] then
        daily_ratings[today][playerName] = 0
    end
    
    daily_ratings[today][playerName] = daily_ratings[today][playerName] + 1
end

function RatingManager:ResetDailyCounters()
    local today = date("%Y-%m-%d")
    
    for dateStr, _ in pairs(daily_ratings) do
        if dateStr ~= today then
            daily_ratings[dateStr] = nil
        end
    end
end

function RatingManager:GetCurrentWeek()
    local current_time = time()
    local year = tonumber(date("%Y", current_time))
    local jan_first = time{year=year, month=1, day=1, hour=0, min=0, sec=0}
    local week_number = math.floor((current_time - jan_first) / (7 * 24 * 3600)) + 1
    return year, week_number
end

function RatingManager:GetDecayedRating(playerData)
    if not playerData or not playerData.total_rating then
        return 0
    end
    
    local base_rating = playerData.total_rating
    if base_rating == 0 then
        return 0
    end
    
    local last_update_week = self:GetWeekFromTimestamp(playerData.last_updated or time())
    local current_year, current_week = self:GetCurrentWeek()
    
    local weeks_passed = current_week - last_update_week.week
    if current_year ~= last_update_week.year then
        weeks_passed = 52 - last_update_week.week + current_week
    end
    
    weeks_passed = math.max(0, weeks_passed)
    
    local decayed_rating = base_rating
    for i = 1, weeks_passed do
        decayed_rating = self:ApplySingleDecay(decayed_rating)
        if decayed_rating == 0 then
            break
        end
    end
    
    return decayed_rating
end

function RatingManager:ApplySingleDecay(rating)
    if rating == 0 then return 0 end
    
    local decay_amount = 0
    if rating > 0 then
        decay_amount = -math.max(1, math.floor(rating * CONFIG.WEEKLY_DECAY_PERCENT / 100))
    else
        decay_amount = math.max(1, math.floor(math.abs(rating) * CONFIG.WEEKLY_DECAY_PERCENT / 100))
    end
    
    local new_rating = rating + decay_amount
    
    if (rating > 0 and new_rating < 0) or (rating < 0 and new_rating > 0) then
        return 0
    end
    
    return new_rating
end

function RatingManager:GetWeekFromTimestamp(timestamp)
    local year = tonumber(date("%Y", timestamp))
    local jan_first = time{year=year, month=1, day=1, hour=0, min=0, sec=0}
    local week_number = math.floor((timestamp - jan_first) / (7 * 24 * 3600)) + 1
    return {year = year, week = week_number}
end

function RatingManager:SerializeMessage(message)
    local parts = {
        message.type,
        message.version,
        message.sender,
        tostring(message.timestamp)
    }
    
    for _, ratingData in ipairs(message.data) do
        local ratingStr = string.format("%s|%d|%s|%d|%s",
            ratingData.target or "",
            ratingData.rating or 0,
            ratingData.reason or "",
            ratingData.timestamp or 0,
            ratingData.sender or ""
        )
        table.insert(parts, ratingStr)
    end
    
    return table.concat(parts, "||")
end

function RatingManager:DeserializeMessage(data)
    local parts = {}
    for part in data:gmatch("([^|]+)") do
        if part ~= "||" then
            table.insert(parts, part)
        end
    end
    
    if #parts < 4 then
        return nil
    end
    
    local message = {
        type = parts[1],
        version = parts[2],
        sender = parts[3],
        timestamp = tonumber(parts[4]),
        data = {}
    }
    
    for i = 5, #parts, 5 do
        if parts[i] and parts[i+1] and parts[i+2] and parts[i+3] and parts[i+4] then
            local ratingData = {
                target = parts[i],
                rating = tonumber(parts[i+1]),
                reason = parts[i+2],
                timestamp = tonumber(parts[i+3]),
                sender = parts[i+4]
            }
            
            if ratingData.target and ratingData.rating and ratingData.timestamp then
                table.insert(message.data, ratingData)
            end
        end
    end
    
    return message
end

function RatingManager:SendRatingData(targetPlayer, data)
    local message = {
        type = CONFIG.MESSAGE_PREFIX,
        version = CONFIG.VERSION,
        data = data,
        sender = UnitName("player"),
        timestamp = time()
    }
    
    local serialized = self:SerializeMessage(message)
    
    if SendAddonMessage then
        SendAddonMessage(commPrefix, serialized, "GUILD")
    end
end

function RatingManager:SyncWithGuild()
    if not initialized then
        return
    end
    
    if #sync_queue == 0 then
        return
    end
    
    local playerName = UnitName("player")
    local guildName = GetGuildInfo("player")
    
    if not guildName then
        return
    end
    
    local onlineMembers = 0
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if name and name ~= playerName and online then
            onlineMembers = onlineMembers + 1
            self:SendRatingData(name, sync_queue)
        end
    end
    
    local sentCount = #sync_queue
    sync_queue = {}
    last_sync = time()
    self:SaveData()
end

function RatingManager:OnAddonMessage(prefix, message, channel, sender)
    if not initialized then
        return
    end
    
    if prefix ~= commPrefix or channel ~= "GUILD" then
        return
    end
    
    if sender == UnitName("player") then
        return
    end
    
    local messageData = self:DeserializeMessage(message)
    if not messageData then
        return
    end
    
    if messageData.version ~= CONFIG.VERSION then
        return
    end
    
    if time() - messageData.timestamp > 86400 then
        return
    end
    
    local processed = 0
    for _, ratingData in ipairs(messageData.data) do
        if self:ProcessIncomingRating(ratingData) then
            processed = processed + 1
        end
    end
    
    if processed > 0 then
        self:SaveData()
    end
end

function RatingManager:ProcessIncomingRating(ratingData)
    local targetPlayer = ratingData.target
    
    if not targetPlayer or targetPlayer == "" then
        return false
    end
    
    if ratings[targetPlayer] then
        for _, existingRating in ipairs(ratings[targetPlayer].ratings) do
            if existingRating.sender == ratingData.sender and
               existingRating.target == ratingData.target and
               math.abs(existingRating.timestamp - ratingData.timestamp) < 60 then
                return false
            end
        end
    end
    
    if not ratings[targetPlayer] then
        ratings[targetPlayer] = {
            total_rating = 0,
            ratings = {},
            last_updated = time()
        }
    end
    
    table.insert(ratings[targetPlayer].ratings, ratingData)
    ratings[targetPlayer].total_rating = ratings[targetPlayer].total_rating + ratingData.rating
    ratings[targetPlayer].last_updated = time()
    
    return true
end

function RatingManager:SetupEventHandlers()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
    
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "CHAT_MSG_ADDON" then
            local prefix, message, channel, sender = ...
            RatingManager:OnAddonMessage(prefix, message, channel, sender)
        elseif event == "GUILD_ROSTER_UPDATE" then
            RatingManager:ResetDailyCounters()
        end
    end)
end

function RatingManager:StartSyncTimer()
    local timerFrame = CreateFrame("Frame")
    local elapsed = 0
    
    timerFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= CONFIG.SYNC_INTERVAL then
            RatingManager:SyncWithGuild()
            elapsed = 0
        end
    end)
end

function RatingManager:GetStats()
    if not initialized then
        return {
            totalPlayers = 0,
            totalRatings = 0,
            avgRating = 0,
            lastSync = 0
        }
    end
    
    local totalPlayers = 0
    local totalRatings = 0
    local avgRating = 0
    
    for playerName, data in pairs(ratings) do
        totalPlayers = totalPlayers + 1
        totalRatings = totalRatings + #data.ratings
        avgRating = avgRating + data.total_rating
    end
    
    if totalPlayers > 0 then
        avgRating = avgRating / totalPlayers
    end
    
    return {
        totalPlayers = totalPlayers,
        totalRatings = totalRatings,
        avgRating = avgRating,
        lastSync = last_sync
    }
end

function RatingManager:ExportData()
    if not initialized then
        return nil
    end
    
    return {
        ratings = ratings,
        stats = self:GetStats(),
        exportTime = time()
    }
end

function RatingManager:ImportData(data)
    if not initialized or not data or not data.ratings then
        return false
    end
    
    ratings = data.ratings
    self:SaveData()
    return true
end

function RatingManager:CleanupOldData()
    if not initialized then
        return
    end
    
    local currentTime = time()
    local maxAge = 30 * 24 * 3600
    
    for playerName, data in pairs(ratings) do
        local filteredRatings = {}
        for _, ratingData in ipairs(data.ratings) do
            if currentTime - ratingData.timestamp < maxAge then
                table.insert(filteredRatings, ratingData)
            end
        end
        
        if #filteredRatings == 0 then
            ratings[playerName] = nil
        else
            data.ratings = filteredRatings
            data.total_rating = 0
            for _, ratingData in ipairs(filteredRatings) do
                data.total_rating = data.total_rating + ratingData.rating
            end
        end
    end
    
    self:SaveData()
end

function RatingManager:InitializeContextMenu()
    local originalUnitPopup_ShowMenu = UnitPopup_ShowMenu
    UnitPopup_ShowMenu = function(dropdownMenu, which, unit, name, userData)
        originalUnitPopup_ShowMenu(dropdownMenu, which, unit, name, userData)
        if which == "PLAYER" or which == "GUILD" then
            RatingManager:AddRatingMenuItems(dropdownMenu, which, unit, name, userData)
        end
    end
    
    self:SetupChatMenuHooks()
end

function RatingManager:SetupChatMenuHooks()
    hooksecurefunc("UnitPopup_ShowMenu", function(dropdownMenu, which, unit, name, userData)
        if name and not unit then
            local playerName = name:gsub("-.*", "")
            
            if playerName and playerName ~= "" and playerName ~= UnitName("player") then
                RatingManager:AddChatRatingItems(dropdownMenu, playerName)
            end
        end
    end)
end

function RatingManager:AddChatRatingItems(dropdownMenu, playerName)
    if not self:IsPlayerInGuild(playerName) then
        return
    end
    
    local currentRating = self:GetPlayerRating(playerName)
    
    UIDropDownMenu_AddSeparator()
    
    UIDropDownMenu_AddButton({
        text = "|cFFFFD100Рейтинг аферистов|r",
        isTitle = true,
        notCheckable = true
    })
    
    local menuItems = {
        {
            text = "|cFF00FF00+1 Рейтинг|r",
            func = function()
                self:QuickRatePlayer(playerName, 1)
            end,
            notCheckable = true
        },
        {
            text = "|cFFFF0000-1 Рейтинг|r",
            func = function()
                self:QuickRatePlayer(playerName, -1)
            end,
            notCheckable = true
        },
        {
            text = string.format("Рейтинг: %s%d|r", 
                currentRating >= 0 and "|cFF00FF00+" or "|cFFFF0000", 
                currentRating),
            func = function()
                self:ShowPlayerRatingInfo(playerName)
            end,
            notCheckable = true
        }
    }
    
    for _, item in ipairs(menuItems) do
        UIDropDownMenu_AddButton(item)
    end
end

function RatingManager:AddRatingMenuItems(dropdownMenu, which, unit, name, userData)
    if not initialized then return end
    
    local playerName = nil
    if unit and UnitExists(unit) then
        playerName = UnitName(unit)
    elseif name then
        playerName = name
    end
    
    if not playerName then return end
    
    playerName = playerName:gsub("-.*", "")
    
    if playerName == UnitName("player") then return end
    
    if not self:IsPlayerInGuild(playerName) then
        return
    end
    
    local currentRating = self:GetPlayerRating(playerName)
    
    UIDropDownMenu_AddSeparator()
    
    UIDropDownMenu_AddButton({
        text = "|cFFFFD100Рейтинг аферистов|r",
        isTitle = true,
        notCheckable = true
    })
    
    local menuItems = {
        {
            text = "|cFF00FF00+1 Рейтинг|r",
            func = function()
                self:QuickRatePlayer(playerName, 1)
            end,
            notCheckable = true
        },
        {
            text = "|cFFFF0000-1 Рейтинг|r",
            func = function()
                self:QuickRatePlayer(playerName, -1)
            end,
            notCheckable = true
        },
        {
            text = string.format("Рейтинг: %s%d|r", 
                currentRating >= 0 and "|cFF00FF00+" or "|cFFFF0000", 
                currentRating),
            func = function()
                self:ShowPlayerRatingInfo(playerName)
            end,
            notCheckable = true
        }
    }
    
    for _, item in ipairs(menuItems) do
        UIDropDownMenu_AddButton(item)
    end
end

function RatingManager:QuickRatePlayer(playerName, rating)
    if not self:CanRatePlayer(playerName) then
        print("|cFFFF0000Ошибка:|r Нельзя поставить рейтинг этому игроку")
        return
    end
    
    if not self:HasDailyRatingLeft() then
        print("|cFFFF0000Ошибка:|r Превышен лимит рейтингов на сегодня")
        return
    end
    
    local reason = "Быстрый рейтинг"
    local success, message = self:AddRating(playerName, rating, reason)
    
    if success then
        print("|cFF00FF00" .. message .. "|r")
    else
        print("|cFFFF0000Ошибка:|r " .. message)
    end
end

function RatingManager:ShowPlayerRatingInfo(playerName)
    local rating, ratings = self:GetPlayerRating(playerName)
    
    if #ratings == 0 then
        print(string.format("|cFFFFFF00%s|r: рейтинг |cFF8080800|r (нет рейтингов)", playerName))
        return
    end
    
    print(string.format("|cFFFFFF00%s|r: рейтинг %s%d|r (%d рейтингов)", 
        playerName,
        rating >= 0 and "|cFF00FF00+" or "|cFFFF0000",
        rating,
        #ratings
    ))
    
    local recentRatings = {}
    for i = math.max(1, #ratings - 2), #ratings do
        table.insert(recentRatings, ratings[i])
    end
    
    for _, ratingData in ipairs(recentRatings) do
        local color = ratingData.rating > 0 and "|cFF00FF00+" or "|cFFFF0000"
        local reason = ratingData.reason and ratingData.reason ~= "" and " (" .. ratingData.reason .. ")" or ""
        print(string.format("  %s%d|r от |cFF00FF00%s|r%s", 
            color, 
            ratingData.rating, 
            ratingData.sender, 
            reason
        ))
    end
end

function RatingManager:IsPlayerInGuild(playerName)
    if not IsInGuild() then return false end
    
    playerName = playerName:gsub("-.*", "")
    
    for i = 1, GetNumGuildMembers() do
        local name = GetGuildRosterInfo(i)
        if name then
            local plainName = name:gsub("-.*", "")
            if plainName:lower() == playerName:lower() then
                return true
            end
        end
    end
    
    return false
end

function RatingManager:ShowRatingInterface()
    if _G.AferistHelperRatingUI then
        _G.AferistHelperRatingUI:Show()
    end
end

function RatingManager:ForceSync()
    if not IsInGuild() then
        return
    end
    
    sync_queue = {}
    for playerName, data in pairs(ratings) do
        for _, ratingData in ipairs(data.ratings) do
            if time() - ratingData.timestamp < 604800 then
                table.insert(sync_queue, ratingData)
            end
        end
    end
    
    self:SyncWithGuild()
end

SLASH_RATINGDEBUG1 = "/ratingdebug"
SlashCmdList["RATINGDEBUG"] = function(msg)
    RatingManager:ForceSync()
end

SLASH_RATINGDECAY1 = "/ratingdecay"
SlashCmdList["RATINGDECAY"] = function(msg)
    local args = {}
    for arg in msg:gmatch("%S+") do
        table.insert(args, arg)
    end
    
    local targetPlayer = UnitName("player")
    local simulate_weeks = 0
    
    if #args >= 1 then
        if tonumber(args[1]) then
            simulate_weeks = tonumber(args[1])
        else
            targetPlayer = args[1]
            if #args >= 2 then
                simulate_weeks = tonumber(args[2]) or 0
            end
        end
    end
    
    if not ratings[targetPlayer] then
        print("|cFFFFFF00Игрок " .. targetPlayer .. " не найден|r")
        return
    end
    
    local data = ratings[targetPlayer]
    local original_rating = data.total_rating
    local decayed_rating = RatingManager:GetDecayedRating(data)
    local last_update_week = RatingManager:GetWeekFromTimestamp(data.last_updated or time())
    local current_year, current_week = RatingManager:GetCurrentWeek()
    local actual_weeks_passed = current_week - last_update_week.week
    
    print(string.format("|cFFFFFF00=== Тест затухания %s ===|r", targetPlayer))
    print(string.format("Исходный рейтинг: %s%d|r", 
        original_rating >= 0 and "|cFF00FF00+" or "|cFFFF0000", 
        original_rating))
    print(string.format("Текущий рейтинг: %s%d|r", 
        decayed_rating >= 0 and "|cFF00FF00+" or "|cFFFF0000", 
        decayed_rating))
    print(string.format("Реальных недель прошло: |cFFFFFFFF%d|r", actual_weeks_passed))
    
    local total_weeks_to_simulate = simulate_weeks > 0 and simulate_weeks or actual_weeks_passed
    
    if simulate_weeks > 0 then
        print(string.format("|cFFFFD100Симуляция затухания за %d недель:|r", simulate_weeks))
    end
    
    local test_rating = original_rating
    for i = 1, total_weeks_to_simulate do
        local old_rating = test_rating
        test_rating = RatingManager:ApplySingleDecay(test_rating)
        print(string.format("Неделя %d: %s%d → %s%d|r", 
            i,
            old_rating >= 0 and "|cFF00FF00+" or "|cFFFF0000", old_rating,
            test_rating >= 0 and "|cFF00FF00+" or "|cFFFF0000", test_rating))
        if test_rating == 0 then
            print("|cFF808080Достигнут нулевой рейтинг|r")
            break
        end
    end
    
    if simulate_weeks > 0 then
        print(string.format("|cFFFFD100Итог после %d недель: %s%d|r", 
            simulate_weeks,
            test_rating >= 0 and "|cFF00FF00+" or "|cFFFF0000", 
            test_rating))
    end
end



_G.AferistHelperRatingManager = RatingManager

return RatingManager
