RespawnTracker = RespawnTracker or {}
RespawnTracker.respawnTimes = {}
RespawnTracker = {
  respawnTimes = {},
  respawnDurations = {
      ["Azuregos"] = 3 * 24 * 60 * 60,
      ["Lord Kazzak"] = 3 * 24 * 60 * 60,
      ["Emeriss"] = 4 * 24 * 60 * 60,
      ["Lethon"] = 4 * 24 * 60 * 60,
      ["Taerar"] = 4 * 24 * 60 * 60,
      ["Ysondre"] = 4 * 24 * 60 * 60,
  },
  bossAliases = {
      ["azu"] = "Azuregos",
      ["kaz"] = "Lord Kazzak",
      ["eme"] = "Emeriss",
      ["let"] = "Lethon",
      ["tae"] = "Taerar",
      ["yso"] = "Ysondre",
  }
}

function RespawnTracker:Initialize()
  WorldBossScanDB.respawnTimes = WorldBossScanDB.respawnTimes or {}
  self.respawnTimes = WorldBossScanDB.respawnTimes
end

function RespawnTracker:RecordKill(bossName, layer)
  local currentTime = GetServerTime()
  local key = bossName .. "-" .. layer
  
  self.respawnTimes[key] = {
      lastKilled = currentTime,
      estimatedRespawn = currentTime + (self.respawnDurations[bossName] or (3 * 24 * 60 * 60))
  }
  
  WorldBossScanDB.respawnTimes = self.respawnTimes
  
  if IsInGuild() then
    local timeString = self:GetTimeString(self.respawnTimes[key].estimatedRespawn)
    SendChatMessage(bossName.." killed on layer "..layer..". Estimated respawn: "..timeString, "GUILD")
    local message = "BOSS_KILL:"..bossName..":"..layer..":"..currentTime
    C_ChatInfo.SendAddonMessage("WorldBossScan", message, "GUILD")
  end
end

function RespawnTracker:GetTimeString(timestamp)
  if not timestamp then return "Unknown" end
  
  local currentTime = GetServerTime()
  local timeLeft = timestamp - currentTime
  
  if timeLeft < 0 then
      return "Ready"
  end
  
  local days = math.floor(timeLeft / (24 * 60 * 60))
  local hours = math.floor((timeLeft % (24 * 60 * 60)) / (60 * 60))
  local minutes = math.floor((timeLeft % (60 * 60)) / 60)
  
  return string.format("%dd %dh %dm", days, hours, minutes)
end

function RespawnTracker:GetBossInfo(inputName)
  local bossName = self.bossAliases[string.lower(inputName)] or inputName
  
  if not self.respawnDurations[bossName] then
      print("|cffff0000[WorldBossScan]|r: Unknown boss name")
      return
  end
  
  print("|cffff0000[WorldBossScan]|r: Respawn times for " .. bossName .. ":")
  local foundAny = false
  
  local layerData = {}
  for key, data in pairs(self.respawnTimes) do
      local storedBoss, layer = strsplit("-", key)
      if storedBoss == bossName then
          table.insert(layerData, {
              layer = tonumber(layer),
              data = data
          })
      end
  end
  table.sort(layerData, function(a, b) return a.layer < b.layer end)
  
  if #layerData == 0 then
      for i = 1, 10 do
          print(string.format("Layer %d: Unknown", i))
      end
      return
  end

  for i = 1, 10 do
      local found = false
      for _, data in ipairs(layerData) do
          if data.layer == i then
              local respawnTime = self:GetTimeString(data.data.estimatedRespawn)
              print(string.format("Layer %d: %s", i, respawnTime))
              found = true
              break
          end
      end
      if not found then
          print(string.format("Layer %d: Unknown", i))
      end
  end
end

function RespawnTracker:IsBoss(guid)
  if not guid then return false end
  
  local _, _, _, _, _, npcId = strsplit("-", guid)
  if not npcId then return false end
  
  -- Check if this NPC ID matches any of our world bosses
  for bossName, bossData in pairs(WorldBosses) do
      if tostring(bossData.id) == npcId then
          return bossName
      end
  end
  
  return false
end

local originalSlashCmd = SlashCmdList["WORLDBOSSSCAN"]
SlashCmdList["WORLDBOSSSCAN"] = function(msg)
    local command, rest = strsplit(" ", msg, 2)
    if command == "kill" and rest then
        local currentLayer = GetCurrentLayer()
        if currentLayer and currentLayer ~= "Unknown" then
            RespawnTracker:RecordKill(rest, currentLayer)
            print("|cffff0000[WorldBossScan]|r: Recorded kill of " .. rest .. " on layer " .. currentLayer)
        else
            print("|cffff0000[WorldBossScan]|r: Couldn't determine current layer")
        end
    elseif command == "cd" or command == "cooldowns" then
        print("|cffff0000[WorldBossScan]|r: World Boss Cooldowns:")
        local currentTime = GetServerTime()
        for bossName, _ in pairs(RespawnTracker.respawnDurations) do
            print("---" .. bossName .. "---")
            local foundAny = false
            for i = 1, 10 do
                local key = bossName .. "-" .. i
                if RespawnTracker.respawnTimes[key] then
                    local data = RespawnTracker.respawnTimes[key]
                    local timeLeft = data.estimatedRespawn - currentTime
                    if timeLeft > 0 then
                        local days = math.floor(timeLeft / (24 * 60 * 60))
                        local hours = math.floor((timeLeft % (24 * 60 * 60)) / (60 * 60))
                        local minutes = math.floor((timeLeft % (60 * 60)) / 60)
                        print(string.format("Layer %d: %dd %dh %dm", i, days, hours, minutes))
                    else
                        print(string.format("Layer %d: Ready!", i))
                    end
                    foundAny = true
                end
            end
            if not foundAny then
                print("No known kill times")
            end
        end
    elseif RespawnTracker.bossAliases[string.lower(command)] then
        local bossName = RespawnTracker.bossAliases[string.lower(command)]
        print("|cffff0000[WorldBossScan]|r: Cooldowns for " .. bossName .. ":")
        local foundAny = false
        local currentTime = GetServerTime()
        
        for i = 1, 10 do
            local key = bossName .. "-" .. i
            if RespawnTracker.respawnTimes[key] then
                local data = RespawnTracker.respawnTimes[key]
                local timeLeft = data.estimatedRespawn - currentTime
                if timeLeft > 0 then
                    local days = math.floor(timeLeft / (24 * 60 * 60))
                    local hours = math.floor((timeLeft % (24 * 60 * 60)) / (60 * 60))
                    local minutes = math.floor((timeLeft % (60 * 60)) / 60)
                    print(string.format("Layer %d: %dd %dh %dm", i, days, hours, minutes))
                else
                    print(string.format("Layer %d: Ready!", i))
                end
                foundAny = true
            end
        end
        if not foundAny then
            print("No known kill times")
        end
    else
        originalSlashCmd(msg)
    end
end