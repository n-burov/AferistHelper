local RatingManager = {}
local ADDON_NAME = "AferistHelper"

local CONFIG = {
    MAX_RATINGS_PER_DAY = 10,
    SYNC_INTERVAL = 120,
    MESSAGE_PREFIX = "AFERIST_RATING",
    VERSION = "1.0",
    WEEKLY_DECAY_PERCENT = 10,
    NOTE_UPDATE_DELAY = 1.5,
    NOTE_BATCH_SIZE = 5,
}

local ratings = {}
local pending_sync = {}
local sync_queue = {}
local last_sync = 0
local daily_ratings = {}
local daily_reset_time = 0
local initialized = false

local commPrefix = "AFERIST_RATING"

local note_update_queue = {}
local note_update_timer = nil
local last_note_update_time = 0
local pending_note_updates = {}
local processed_ratings = {}

function RatingManager:Initialize()
    if initialized then
        return true
    end
    
    self:LoadData()
    self:SetupEventHandlers()
    self:SetupChatMonitor()
    self:StartSyncTimer()
    self:ResetDailyCounters()
    self:InitializeContextMenu()
    self:CleanupProcessedRatings()
    
    if RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(commPrefix)
    end
    
    initialized = true
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

function RatingManager:CleanupProcessedRatings()
    if not processed_ratings then
        processed_ratings = {}
        return
    end
    
    local currentTime = time()
    local maxAge = 86400
    local keysToRemove = {}
    
    for key, _ in pairs(processed_ratings) do
        local parts = {key:match("([^_]+)_([^_]+)_(%d+)")}
        if #parts == 3 then
            local timestamp = tonumber(parts[3])
            if timestamp and (currentTime - timestamp) > maxAge then
                table.insert(keysToRemove, key)
            end
        else
            table.insert(keysToRemove, key)
        end
    end
    
    for _, key in ipairs(keysToRemove) do
        processed_ratings[key] = nil
    end
end

function RatingManager:SetupChatMonitor()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("CHAT_MSG_GUILD")
    eventFrame:RegisterEvent("CHAT_MSG_OFFICER")
    
    eventFrame:SetScript("OnEvent", function(self, event, message, sender, ...)
        RatingManager:ParseChatMessage(message, sender, event)
    end)
end

function RatingManager:ParseChatMessage(message, sender, channel)
    if sender == UnitName("player") then return end
    
    local cleanMessage = message
    cleanMessage = cleanMessage:match(":%s+(.+)") or cleanMessage
    cleanMessage = cleanMessage:match("[%+%-].+") or cleanMessage
    
    local patterns = {
        "([%+%-])rep%s+(.+)",
        "([%+%-])реп%s+(.+)",
        "([%+%-])%s+rep%s+(.+)", 
        "([%+%-])%s+реп%s+(.+)"
    }
    
    for i, pattern in ipairs(patterns) do
        local sign, rest = cleanMessage:match(pattern)
        
        if sign and rest then
            local targetPlayer = rest:match("([^%s]+)")
            local reason = rest:sub(#targetPlayer + 2) or "Голосование в чате"
            
            if targetPlayer then
                local rating = (sign == "+") and 1 or -1
                self:ProcessChatVote(sender, targetPlayer, rating, reason)
                return
            end
        end
    end
    
    local repPos = message:find("+rep") or message:find("-rep") or message:find("+реп") or message:find("-реп")
    if repPos then
        local afterRep = message:sub(repPos)
        local sign = afterRep:sub(1, 1)
        local rest = afterRep:sub(5)
        
        if afterRep:sub(2, 3) == "ре" then
            rest = afterRep:sub(5)
        end
        
        rest = rest:gsub("^%s*", "")
        
        local targetPlayer = rest:match("([^%s]+)")
        local reason = rest:sub(#targetPlayer + 2) or "Голосование в чате"
        self:ProcessChatVote(sender, targetPlayer, (sign == "+") and 1 or -1, reason)
        return
    end
end

function RatingManager:ProcessChatVote(sender, targetPlayer, rating, reason)
    if not self:IsPlayerInGuild(targetPlayer) then
        return
    end
    
    if not self:CanRatePlayerChat(targetPlayer, sender) then
        return
    end
    
    local ratingData = {
        target = targetPlayer,
        rating = rating,
        reason = reason,
        timestamp = time(),
        sender = sender,
        source = "chat"
    }
    
    if not ratings[targetPlayer] then
        ratings[targetPlayer] = {
            total_rating = 0,
            ratings = {},
            last_updated = time()
        }
    end
    
    local isDuplicate = false
    for _, existingRating in ipairs(ratings[targetPlayer].ratings) do
        if existingRating.sender == sender and
           existingRating.target == targetPlayer and
           (time() - existingRating.timestamp) < 3600 then
            isDuplicate = true
            break
        end
    end
    
    if not isDuplicate then
        table.insert(ratings[targetPlayer].ratings, ratingData)
        ratings[targetPlayer].total_rating = ratings[targetPlayer].total_rating + rating
        ratings[targetPlayer].last_updated = time()
        
        self:SaveData()
        
        if CanEditPublicNote() then
            local applied = self:ApplyRatingToNoteSimple(targetPlayer, rating, ratingData)
            if applied then
                table.insert(sync_queue, ratingData)
                self:SyncWithOfficers()
            end
        else
            table.insert(sync_queue, ratingData)
            self:SyncWithOfficers()
        end
    end
end

function RatingManager:ApplyRatingToNote(targetPlayer, ratingChange, ratingData)
    if not ratingData or not ratingData.timestamp then
        return false
    end
    
    local currentTime = time()
    if currentTime - ratingData.timestamp > 30 then
        return false
    end
    
    GuildRoster()
    
    local waitFrame = CreateFrame("Frame")
    local waitComplete = false
    waitFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed >= 0.2 then
            waitComplete = true
            self:SetScript("OnUpdate", nil)
        end
    end)
    
    while not waitComplete do
        coroutine.yield()
    end
    
    local playerInfo = self:GetPlayerInfo(targetPlayer)
    if not playerInfo then
        return false
    end
    
    local currentNote = playerInfo.note or ""
    local currentRating = self:GetRatingFromNote(currentNote)
    
    local expectedPreviousRating = currentRating - ratingChange
    
    local ratingKey = string.format("%s_%s_%d", 
        targetPlayer, 
        ratingData.sender or "", 
        ratingData.timestamp or 0)
    
    if not processed_ratings then
        processed_ratings = {}
    end
    
    if processed_ratings[ratingKey] then
        return false
    end
    
    if currentRating ~= expectedPreviousRating then
        return false
    end
    
    local expectedNewRating = currentRating + ratingChange
    local updatedNote = self:UpdateNoteWithRating(currentNote, expectedNewRating)
    
    if not self:SetGuildMemberNoteSilent(targetPlayer, updatedNote) then
        return false
    end
    
    GuildRoster()
    
    waitFrame = CreateFrame("Frame")
    waitComplete = false
    waitFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed >= 0.3 then
            waitComplete = true
            self:SetScript("OnUpdate", nil)
        end
    end)
    
    while not waitComplete do
        coroutine.yield()
    end
    
    local verifyInfo = self:GetPlayerInfo(targetPlayer)
    if not verifyInfo then
        return false
    end
    
    local verifyNote = verifyInfo.note or ""
    local verifyRating = self:GetRatingFromNote(verifyNote)
    
    if verifyRating == expectedNewRating then
        processed_ratings[ratingKey] = true
        return true
    end
    
    return false
end

function RatingManager:ApplyRatingToNoteSimple(targetPlayer, ratingChange, ratingData)
    if not ratingData or not ratingData.timestamp then
        return false
    end
    
    local currentTime = time()
    if currentTime - ratingData.timestamp > 30 then
        return false
    end
    
    if not processed_ratings then
        processed_ratings = {}
    end
    
    local ratingKey = string.format("%s_%s_%d", 
        targetPlayer, 
        ratingData.sender or "", 
        ratingData.timestamp or 0)
    
    if processed_ratings[ratingKey] then
        return false
    end
    
    GuildRoster()
    
    local playerInfo = self:GetPlayerInfo(targetPlayer)
    if not playerInfo then
        processed_ratings[ratingKey] = true
        return false
    end
    
    local currentNote = playerInfo.note or ""
    local currentRating = self:GetRatingFromNote(currentNote)
    local expectedNewRating = currentRating + ratingChange
    
    local localRatingCheck = false
    if ratings[targetPlayer] then
        for _, existingRating in ipairs(ratings[targetPlayer].ratings) do
            if existingRating.sender == ratingData.sender and
               existingRating.target == ratingData.target and
               math.abs(existingRating.timestamp - ratingData.timestamp) < 5 then
                localRatingCheck = true
                break
            end
        end
    end
    
    if localRatingCheck then
        processed_ratings[ratingKey] = true
        return false
    end
    
    if not CanEditPublicNote() then
        processed_ratings[ratingKey] = true
        return false
    end
    
    local updatedNote = self:UpdateNoteWithRating(currentNote, expectedNewRating)
    
    if not self:SetGuildMemberNoteSilent(targetPlayer, updatedNote) then
        processed_ratings[ratingKey] = true
        return false
    end
    
    GuildRoster()
    
    local verifyFrame = CreateFrame("Frame")
    local verified = false
    local verificationComplete = false
    
    verifyFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
    verifyFrame:SetScript("OnEvent", function(self, event)
        if verificationComplete then
            return
        end
        
        verificationComplete = true
        self:UnregisterEvent("GUILD_ROSTER_UPDATE")
        
        local verifyInfo = RatingManager:GetPlayerInfo(targetPlayer)
        if verifyInfo then
            local verifyNote = verifyInfo.note or ""
            local verifyRating = RatingManager:GetRatingFromNote(verifyNote)
            
            if verifyRating == expectedNewRating then
                verified = true
            end
        end
        
        processed_ratings[ratingKey] = true
    end)
    
    GuildRoster()
    
    local elapsed = 0
    local timeoutFrame = CreateFrame("Frame")
    timeoutFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= 1.0 then
            self:SetScript("OnUpdate", nil)
            if not verificationComplete then
                verificationComplete = true
                verifyFrame:UnregisterEvent("GUILD_ROSTER_UPDATE")
                
                local verifyInfo = RatingManager:GetPlayerInfo(targetPlayer)
                if verifyInfo then
                    local verifyNote = verifyInfo.note or ""
                    local verifyRating = RatingManager:GetRatingFromNote(verifyNote)
                    
                    if verifyRating == expectedNewRating then
                        verified = true
                    end
                end
                
                processed_ratings[ratingKey] = true
            end
        end
    end)
    
    return true
end

function RatingManager:CanRatePlayerChat(targetPlayer, sender)
    if targetPlayer == sender then
        return false
    end
    
    if not self:IsPlayerInGuild(targetPlayer) then
        return false
    end
    
    if not self:IsPlayerInGuild(sender) then
        return false
    end
    
    local today = date("%Y-%m-%d")
    if daily_ratings[today] and daily_ratings[today][sender] then
        if daily_ratings[today][sender] >= CONFIG.MAX_RATINGS_PER_DAY then
            return false
        end
    end
    
    return true
end

function RatingManager:GetRatingFromNote(noteText)
    if not noteText or noteText == "" then
        return 0
    end
    
    local ratingStr = noteText:match("%(([%+%-]?%d+)%)")
    if ratingStr then
        return tonumber(ratingStr) or 0
    end
    
    return 0
end

function RatingManager:UpdateNoteWithRating(noteText, newRating)
    local ratingPrefix = string.format("(%d)", newRating)
    
    if not noteText or noteText == "" then
        return ratingPrefix
    end
    
    local currentRatingText = noteText:match("%([%+%-]?%d+%)")
    if currentRatingText then
        return noteText:gsub("%([%+%-]?%d+%)", ratingPrefix)
    else
        return string.format("%s %s", ratingPrefix, noteText)
    end
end

function RatingManager:GetPlayerRating(playerName)
    if not initialized then
        return 0, {}
    end
    
    if not ratings[playerName] then
        return 0, {}
    end
    
    local noteRating = 0
    local playerInfo = self:GetPlayerInfo(playerName)
    
    if playerInfo and playerInfo.note then
        noteRating = self:GetRatingFromNote(playerInfo.note)
    end
    
    return noteRating, ratings[playerName].ratings
end

function RatingManager:ScanGuildForNoteRatings()
    if not IsInGuild() then
        return {}
    end
    
    GuildRoster()
    
    local playersFromNotes = {}
    local totalMembers = GetNumGuildMembers()
    
    for i = 1, totalMembers do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status = GetGuildRosterInfo(i)
        if name then
            local plainName = name:gsub("-.*", "")
            local noteRating = self:GetRatingFromNote(note)
            
            if noteRating ~= 0 then
                table.insert(playersFromNotes, {
                    name = plainName,
                    rating = noteRating,
                    rank = rank,
                    level = level,
                    class = class,
                    online = online,
                    note = note,
                    zone = zone,
                    status = status
                })
            end
        end
    end
    
    return playersFromNotes
end

function RatingManager:GetTopPlayers(limit)
    if not initialized then
        return {}
    end
    
    limit = limit or 10
    
    GuildRoster()
    
    local players = self:ScanGuildForNoteRatings()
    
    table.sort(players, function(a, b)
        if a.rating == b.rating then
            return a.name < b.name
        end
        return a.rating > b.rating
    end)
    
    local result = {}
    for i = 1, math.min(limit, #players) do
        table.insert(result, players[i])
    end
    
    return result
end

function RatingManager:DelayedGuildScan(callback)
    if not IsInGuild() then
        if callback then callback({}) end
        return
    end
    
    GuildRoster()
    
    local scanFrame = CreateFrame("Frame")
    local currentIndex = 1
    local totalMembers = GetNumGuildMembers()
    local scannedPlayers = {}
    local BATCH_SIZE = 10
    
    scanFrame:SetScript("OnUpdate", function(self, elapsed)
        local endIndex = math.min(currentIndex + BATCH_SIZE - 1, totalMembers)
        
        for i = currentIndex, endIndex do
            local name, rank, rankIndex, level, class, zone, note, officernote, online, status = GetGuildRosterInfo(i)
            if name then
                local plainName = name:gsub("-.*", "")
                local noteRating = RatingManager:GetRatingFromNote(note)
                
                if noteRating ~= 0 then
                    table.insert(scannedPlayers, {
                        name = plainName,
                        rating = noteRating,
                        rank = rank,
                        level = level,
                        class = class,
                        online = online,
                        zone = zone,
                        status = status
                    })
                end
            end
        end
        
        currentIndex = endIndex + 1
        
        if currentIndex > totalMembers then
            self:SetScript("OnUpdate", nil)
            if callback then
                callback(scannedPlayers)
            end
        end
    end)
end

function RatingManager:GetTopPlayersAsync(limit, callback)
    if not initialized then
        if callback then callback({}) end
        return
    end
    
    limit = limit or 10
    
    self:DelayedGuildScan(function(players)
        if not players then
            players = {}
        end
        
        table.sort(players, function(a, b)
            if a.rating == b.rating then
                return a.name < b.name
            end
            return a.rating > b.rating
        end)
        
        local result = {}
        for i = 1, math.min(limit, #players) do
            table.insert(result, players[i])
        end
        
        if callback then
            callback(result)
        end
    end)
end

function RatingManager:FindOfficersWithNoteAccess()
    local officers = {}
    for i = 1, GetNumGuildMembers() do
        local name, _, rankIndex, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if name and online and rankIndex <= 2 then
            table.insert(officers, name)
        end
    end
    return officers
end

function RatingManager:SyncWithOfficers()
    if not initialized or #sync_queue == 0 then
        return
    end
    
    if not processed_ratings then
        processed_ratings = {}
    end
    
    local filtered_queue = {}
    
    for _, ratingData in ipairs(sync_queue) do
        local ratingKey = string.format("%s_%s_%d", 
            ratingData.target, 
            ratingData.sender or "", 
            ratingData.timestamp or 0)
        
        if not processed_ratings[ratingKey] then
            table.insert(filtered_queue, ratingData)
        end
    end
    
    if #filtered_queue == 0 then
        sync_queue = {}
        return
    end
    
    local officers = self:FindOfficersWithNoteAccess()
    local playerName = UnitName("player")
    
    for _, officerName in ipairs(officers) do
        if officerName ~= playerName then
            self:SendRatingData(officerName, filtered_queue, "officer_sync")
        end
    end
    
    for _, ratingData in ipairs(filtered_queue) do
        local ratingKey = string.format("%s_%s_%d", 
            ratingData.target, 
            ratingData.sender or "", 
            ratingData.timestamp or 0)
        processed_ratings[ratingKey] = true
    end
    
    sync_queue = {}
    last_sync = time()
    self:SaveData()
end

function RatingManager:ProcessOfficerSync(messageData)
    if not messageData or not messageData.data then
        return
    end
    
    if not processed_ratings then
        processed_ratings = {}
    end
    
    for _, ratingData in ipairs(messageData.data) do
        local ratingKey = string.format("%s_%s_%d", 
            ratingData.target, 
            ratingData.sender or "", 
            ratingData.timestamp or 0)
        
        if not processed_ratings[ratingKey] then
            if CanEditPublicNote() then
                self:ApplyRatingToNoteSimple(ratingData.target, ratingData.rating, ratingData)
            end
        end
    end
end

function RatingManager:ScheduleBatchNoteUpdates()
    if note_update_timer then
        return
    end
    
    local currentTime = GetTime()
    local timeSinceLastUpdate = currentTime - last_note_update_time
    
    if timeSinceLastUpdate < CONFIG.NOTE_UPDATE_DELAY then
        note_update_timer = CreateFrame("Frame")
        local elapsed = 0
        local delay = CONFIG.NOTE_UPDATE_DELAY - timeSinceLastUpdate
        note_update_timer:SetScript("OnUpdate", function(self, delta)
            elapsed = elapsed + delta
            if elapsed >= delay then
                self:SetScript("OnUpdate", nil)
                note_update_timer = nil
                RatingManager:ExecuteBatchNoteUpdates()
            end
        end)
    else
        self:ExecuteBatchNoteUpdates()
    end
end

function RatingManager:ExecuteBatchNoteUpdates()
    last_note_update_time = GetTime()
    
    if not next(pending_note_updates) then
        return
    end
    
    local updates_to_process = {}
    local processed_count = 0
    local total_rating_changes = 0
    
    GuildRoster()
    
    for updateKey, updateData in pairs(pending_note_updates) do
        local playerInfo = self:GetPlayerInfo(updateData.target)
        if playerInfo then
            local currentNote = playerInfo.note or ""
            local actualCurrentRating = self:GetRatingFromNote(currentNote)
            
            local newRating = actualCurrentRating + updateData.ratingChange
            local updatedNote = self:UpdateNoteWithRating(currentNote, newRating)
            
            table.insert(updates_to_process, {
                target = updateData.target,
                newNote = updatedNote,
                ratingChange = updateData.ratingChange
            })
            
            total_rating_changes = total_rating_changes + math.abs(updateData.ratingChange)
        end
    end
    
    pending_note_updates = {}
    
    if #updates_to_process == 0 then
        return
    end
    
    for i = 1, #updates_to_process do
        local updateData = updates_to_process[i]
        
        if self:SetGuildMemberNoteSilent(updateData.target, updateData.newNote) then
            processed_count = processed_count + 1
        end
        
        if i % CONFIG.NOTE_BATCH_SIZE == 0 then
            GuildRoster()
            local waitFrame = CreateFrame("Frame")
            waitFrame:SetScript("OnUpdate", function(self, elapsed)
                self.elapsed = (self.elapsed or 0) + elapsed
                if self.elapsed >= 0.1 then
                    self:SetScript("OnUpdate", nil)
                end
            end)
        end
    end
    
    GuildRoster()
    
    if processed_count > 0 then
        if processed_count == 1 then
            local singleUpdate = updates_to_process[1]
            print(string.format("|cFF00FF00Рейтинг обновлен:|r %s %s%d", 
                singleUpdate.target, 
                singleUpdate.ratingChange >= 0 and "+" or "", 
                singleUpdate.ratingChange))
        else
            print(string.format("|cFF00FF00Обновлено рейтингов:|r %d игроков (%s%d)", 
                processed_count,
                total_rating_changes >= 0 and "+" or "",
                total_rating_changes))
        end
    end
end

function RatingManager:SetGuildMemberNoteSilent(playerName, noteText)
    local targetInfo = self:GetPlayerInfo(playerName)
    if not targetInfo then
        return false
    end
    
    if not CanEditPublicNote() then
        return false
    end
    
    GuildRosterSetPublicNote(targetInfo.rosterIndex, noteText)
    return true
end

function RatingManager:SetGuildMemberNote(playerName, noteText, isOfficerNote)
    local targetInfo = self:GetPlayerInfo(playerName)
    if not targetInfo then 
        return false 
    end
    
    if not CanEditPublicNote() then 
        return false 
    end
    
    GuildRosterSetPublicNote(targetInfo.rosterIndex, noteText)
    GuildRoster()
    
    return true
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
    
    self:IncrementDailyCounter()
    self:SaveData()
    
    if CanEditPublicNote() then
        local applied = self:ApplyRatingToNoteSimple(targetPlayer, rating, ratingData)
        if applied then
            table.insert(sync_queue, ratingData)
            self:SyncWithOfficers()
        end
    else
        table.insert(sync_queue, ratingData)
        self:SyncWithOfficers()
    end
    
    return true, "Рейтинг успешно добавлен"
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
        tostring(message.timestamp),
        message.sync_type or "normal"
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
    
    if #parts < 5 then
        return nil
    end
    
    local message = {
        type = parts[1],
        version = parts[2],
        sender = parts[3],
        timestamp = tonumber(parts[4]),
        sync_type = parts[5],
        data = {}
    }
    
    for i = 6, #parts, 5 do
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

function RatingManager:SendRatingData(targetPlayer, data, sync_type)
    local message = {
        type = CONFIG.MESSAGE_PREFIX,
        version = CONFIG.VERSION,
        data = data,
        sender = UnitName("player"),
        timestamp = time(),
        sync_type = sync_type or "normal"
    }
    
    local serialized = self:SerializeMessage(message)
    
    if SendAddonMessage then
        SendAddonMessage(commPrefix, serialized, "GUILD")
    end
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
    
    if messageData.sync_type == "officer_sync" then
        self:ProcessOfficerSync(messageData)
    else
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
    
    local last_roster_update = 0
    local roster_update_cooldown = 2
    
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "CHAT_MSG_ADDON" then
            local prefix, message, channel, sender = ...
            RatingManager:OnAddonMessage(prefix, message, channel, sender)
        elseif event == "GUILD_ROSTER_UPDATE" then
            local currentTime = GetTime()
            if currentTime - last_roster_update > roster_update_cooldown then
                last_roster_update = currentTime
                RatingManager:ResetDailyCounters()
            end
        end
    end)
end

function RatingManager:StartSyncTimer()
    local timerFrame = CreateFrame("Frame")
    local elapsed = 0
    
    timerFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= CONFIG.SYNC_INTERVAL then
            RatingManager:SyncWithOfficers()
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
        text = "Рейтинг аферистов",
        isTitle = true,
        notCheckable = true
    })
    
    local menuItems = {
        {
            text = "+1 Рейтинг",
            func = function()
                self:QuickRatePlayer(playerName, 1)
            end,
            notCheckable = true
        },
        {
            text = "-1 Рейтинг",
            func = function()
                self:QuickRatePlayer(playerName, -1)
            end,
            notCheckable = true
        },
        {
            text = string.format("Рейтинг: %s%d", 
                currentRating >= 0 and "+" or "", 
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
        text = "Рейтинг аферистов",
        isTitle = true,
        notCheckable = true
    })
    
    local menuItems = {
        {
            text = "+1 Рейтинг",
            func = function()
                self:QuickRatePlayer(playerName, 1)
            end,
            notCheckable = true
        },
        {
            text = "-1 Рейтинг",
            func = function()
                self:QuickRatePlayer(playerName, -1)
            end,
            notCheckable = true
        },
        {
            text = string.format("Рейтинг: %s%d", 
                currentRating >= 0 and "+" or "", 
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
        return
    end
    
    if not self:HasDailyRatingLeft() then
        return
    end
    
    local reason = "Быстрый рейтинг"
    local success, message = self:AddRating(playerName, rating, reason)
end

function RatingManager:ShowPlayerRatingInfo(playerName)
    local rating, ratings = self:GetPlayerRating(playerName)
    
    if #ratings == 0 then
        print(string.format("%s: рейтинг 0 (нет рейтингов)", playerName))
        return
    end
    
    print(string.format("%s: рейтинг %s%d (%d рейтингов)", 
        playerName,
        rating >= 0 and "+" or "",
        rating,
        #ratings
    ))
    
    local recentRatings = {}
    for i = math.max(1, #ratings - 2), #ratings do
        table.insert(recentRatings, ratings[i])
    end
    
    for _, ratingData in ipairs(recentRatings) do
        local color = ratingData.rating > 0 and "+" or ""
        local reason = ratingData.reason and ratingData.reason ~= "" and " (" .. ratingData.reason .. ")" or ""
        print(string.format("  %s%d от %s%s", 
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

function RatingManager:GetPlayerInfo(playerName)
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

function RatingManager:DelayedExecute(delay, callback)
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
    
    self:SyncWithOfficers()
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
        print("Игрок " .. targetPlayer .. " не найден")
        return
    end
    
    local data = ratings[targetPlayer]
    local original_rating = data.total_rating
    local decayed_rating = RatingManager:GetDecayedRating(data)
    local last_update_week = RatingManager:GetWeekFromTimestamp(data.last_updated or time())
    local current_year, current_week = RatingManager:GetCurrentWeek()
    local actual_weeks_passed = current_week - last_update_week.week
    
    print("=== Тест затухания " .. targetPlayer .. " ===")
    print("Исходный рейтинг: " .. (original_rating >= 0 and "+" or "") .. original_rating)
    print("Текущий рейтинг: " .. (decayed_rating >= 0 and "+" or "") .. decayed_rating)
    print("Реальных недель прошло: " .. actual_weeks_passed)
    
    local total_weeks_to_simulate = simulate_weeks > 0 and simulate_weeks or actual_weeks_passed
    
    if simulate_weeks > 0 then
        print("Симуляция затухания за " .. simulate_weeks .. " недель:")
    end
    
    local test_rating = original_rating
    for i = 1, total_weeks_to_simulate do
        local old_rating = test_rating
        test_rating = RatingManager:ApplySingleDecay(test_rating)
        print("Неделя " .. i .. ": " .. (old_rating >= 0 and "+" or "") .. old_rating .. " → " .. (test_rating >= 0 and "+" or "") .. test_rating)
        if test_rating == 0 then
            print("Достигнут нулевой рейтинг")
            break
        end
    end
    
    if simulate_weeks > 0 then
        print("Итог после " .. simulate_weeks .. " недель: " .. (test_rating >= 0 and "+" or "") .. test_rating)
    end
end

SLASH_REPHELP1 = "/rephelp"
SlashCmdList["REPHELP"] = function()
    print("=== Система репутации гильдии ===")
    print("Голосовать могут все участники гильдии:")
    print("- +rep Игрок причина - повысить репутацию")
    print("- -rep Игрок причина - понизить репутацию")
    print("Пример: +rep Иван Отлично помогает в подземельях")
    print("Ограничение: 1 голос в час на игрока")
    print("Рейтинг отображается в заметке игрока")
end

function RatingManager:AddAdminCommands()
    SLASH_RATINGADMIN1 = "/ratingadmin"
    SLASH_RATINGADMIN2 = "/ra"
    SlashCmdList["RATINGADMIN"] = function(msg)
        local playerName = UnitName("player")
        if playerName ~= "Worog" then
            print("Ошибка: Недостаточно прав")
            return
        end
        
        local args = {}
        for arg in msg:gmatch("%S+") do
            table.insert(args, arg)
        end
        
        if #args < 2 then
            print("Использование:")
            print("/ratingadmin <ник> <рейтинг> [причина]")
            print("/ra <ник> <рейтинг> [причина]")
            return
        end
        
        local targetPlayer = args[1]
        local rating = tonumber(args[2])
        local reason = table.concat(args, " ", 3)
        
        if rating ~= 1 and rating ~= -1 then
            print("Ошибка: Рейтинг может быть только +1 или -1")
            return
        end
        
        local ratingData = {
            target = targetPlayer,
            rating = rating,
            reason = reason or "Административный рейтинг",
            timestamp = time(),
            sender = "Worog"
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
        
        sync_queue = {ratingData}
        self:SyncWithOfficers()
        self:SaveData()
        
        print(string.format("Админ-рейтинг: %s %s%d (%s)", 
            targetPlayer, 
            rating > 0 and "+" or "", 
            rating, 
            reason or "без причины"))
    end
    
    SLASH_RATINGRESET1 = "/ratingreset"
    SlashCmdList["RATINGRESET"] = function(msg)
        local playerName = UnitName("player")
        if playerName ~= "Worog" then
            print("Ошибка: Недостаточно прав")
            return
        end
        
        local targetPlayer = msg:match("%S+")
        if not targetPlayer then
            print("Использование: /ratingreset <ник>")
            return
        end
        
        if ratings[targetPlayer] then
            ratings[targetPlayer] = nil
            self:SaveData()
            
            local deleteData = {
                target = targetPlayer,
                rating = 0,
                reason = "Сброс рейтинга",
                timestamp = time(),
                sender = "Worog",
                isReset = true
            }
            sync_queue = {deleteData}
            self:SyncWithOfficers()
            
            print("Рейтинг игрока " .. targetPlayer .. " сброшен")
        else
            print("Игрок " .. targetPlayer .. " не найден")
        end
    end
    
    SLASH_RATINGMASS1 = "/ratingmass"
    SlashCmdList["RATINGMASS"] = function(msg)
        local playerName = UnitName("player")
        if playerName ~= "Worog" then
            print("Ошибка: Недостаточно прав")
            return
        end
        
        local args = {}
        for arg in msg:gmatch("%S+") do
            table.insert(args, arg)
        end
        
        if #args < 2 then
            print("Использование:")
            print("/ratingmass <рейтинг> <игрок1> <игрок2> ...")
            return
        end
        
        local rating = tonumber(args[1])
        if rating ~= 1 and rating ~= -1 then
            print("Ошибка: Рейтинг может быть только +1 или -1")
            return
        end
        
        local players = {}
        for i = 2, #args do
            table.insert(players, args[i])
        end
        
        local count = 0
        sync_queue = {}
        
        for _, targetPlayer in ipairs(players) do
            local ratingData = {
                target = targetPlayer,
                rating = rating,
                reason = "Массовый рейтинг",
                timestamp = time(),
                sender = "Worog"
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
            count = count + 1
        end
        
        self:SyncWithOfficers()
        self:SaveData()
        
        print(string.format("Массовый рейтинг: установлен %s%d для %d игроков", 
            rating > 0 and "+" or "", 
            rating, 
            count))
    end
    
    SLASH_RATINGVIEW1 = "/ratingview"
    SlashCmdList["RATINGVIEW"] = function(msg)
        local playerName = UnitName("player")
        if playerName ~= "Worog" then
            print("Ошибка: Недостаточно прав")
            return
        end
        
        local targetPlayer = msg:match("%S+")
        if not targetPlayer then
            print("Использование: /ratingview <ник>")
            return
        end
        
        local rating, allRatings = self:GetPlayerRating(targetPlayer)
        
        print("=== Рейтинг игрока " .. targetPlayer .. " ===")
        print("Общий рейтинг: " .. (rating >= 0 and "+" or "") .. rating)
        print("Всего рейтингов: " .. #allRatings)
        
        if #allRatings > 0 then
            print("История рейтингов:")
            for i, ratingData in ipairs(allRatings) do
                local color = ratingData.rating > 0 and "+" or ""
                local timeStr = date("%d.%m %H:%M", ratingData.timestamp)
                print("  " .. color .. ratingData.rating .. " от " .. ratingData.sender .. " - " .. (ratingData.reason or "без причины") .. " (" .. timeStr .. ")")
            end
        end
    end
end

function RatingManager:HasOfflineMembers()
    if not IsInGuild() then
        return false
    end
    
    GuildRoster()
    
    local totalMembers = GetNumGuildMembers()
    local checkedCount = 0
    local maxCheck = math.min(50, totalMembers)
    
    for i = 1, maxCheck do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status = GetGuildRosterInfo(i)
        if name then
            checkedCount = checkedCount + 1
            if not online then
                return true
            end
        end
    end
    
    if checkedCount == totalMembers and totalMembers > 10 then
        return false
    end
    
    for i = 1, totalMembers do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status = GetGuildRosterInfo(i)
        if name and not online then
            return true
        end
    end
    
    return false
end

function RatingManager:CanShowRatingUI()
    if not IsInGuild() then
        return false, "Вы не в гильдии"
    end
    
    local hasOffline = self:HasOfflineMembers()
    
    if not hasOffline then
        return false, "|cFFFF0000Внимание!|r Для корректного отображения рейтинга необходимо установить галочку 'Показывать отсутствующих' в окне гильдии.\n\nБез этой галочки данные будут некорректными, так как часть игроков не будет отображаться в списке."
    end
    
    return true, nil
end

RatingManager:AddAdminCommands()

_G.AferistHelperRatingManager = RatingManager

return RatingManager
