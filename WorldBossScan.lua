local foundBossLayers = {}
local isLoggingOut = false
local layerIdRange = 70
local minLayerId = -1
local maxLayerId = -1
local currentLayerId = -1
local waitingForNWB = true
local maxNWBWaitTime = 30
local statusUpdateTimer = nil
local joinedBossGroups = {}

WorldBossScanDB = WorldBossScanDB or {}
WorldBossScanDB.buttonPosition = WorldBossScanDB.buttonPosition or { x = 0, y = -50 } -- Default top center

-- Create main frame
local frame = CreateFrame("Frame", "WorldBossScanFrame", UIParent)

-- Create alert button
local scanner_button = CreateFrame("Button", "WorldBossScanButton", UIParent, "BackdropTemplate")
scanner_button:Hide()
scanner_button:SetIgnoreParentScale(true)
scanner_button:SetFrameStrata("MEDIUM")
scanner_button:SetFrameLevel(200)
scanner_button:SetSize(200, 50)
scanner_button:SetScale(0.8)
scanner_button:RegisterForClicks("AnyUp")
scanner_button:SetNormalTexture([[Interface\AchievementFrame\UI-Achievement-Parchment-Horizontal-Desaturated]])
scanner_button:SetMovable(true)
scanner_button:EnableMouse(true)

scanner_button:RegisterForDrag("LeftButton")
if WorldBossScanDB.buttonPosition then
    scanner_button:SetPoint("TOP", UIParent, "TOP", WorldBossScanDB.buttonPosition.x, WorldBossScanDB.buttonPosition.y)
else
    scanner_button:SetPoint("TOP", UIParent, "TOP", 0, -50)
end
scanner_button:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
scanner_button:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    WorldBossScanDB.buttonPosition = { x = xOfs, y = yOfs }
end)

-- Creat Close Button
local closeButton = CreateFrame("Button", nil, scanner_button, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", -4, -4)
closeButton:SetSize(16, 16)


-- Add border texture
local TitleBackground = scanner_button:CreateTexture(nil, "BORDER")
TitleBackground:SetTexture([[Interface\AchievementFrame\UI-Achievement-RecentHeader]])
TitleBackground:SetPoint("TOPRIGHT", -5, -7)
TitleBackground:SetPoint("LEFT", 5, 0)
TitleBackground:SetSize(180, 10)
TitleBackground:SetTexCoord(0, 1, 0, 1)
TitleBackground:SetAlpha(0.8)

-- Add text
scanner_button.text = scanner_button:CreateFontString(nil, "OVERLAY", "GameFontNormal", 1)
scanner_button.text:SetNonSpaceWrap(true)
scanner_button.text:SetPoint("TOPLEFT", TitleBackground, 0, 0)
scanner_button.text:SetPoint("RIGHT", TitleBackground)
scanner_button.text:SetTextColor(1, 1, 1, 1)
scanner_button:SetFontString(scanner_button.text)

-- Add background textures
local Background = scanner_button:GetNormalTexture()
Background:SetDrawLayer("BACKGROUND")
Background:ClearAllPoints()
Background:SetPoint("BOTTOMLEFT", 3, 3)
Background:SetPoint("TOPRIGHT", -3, -3)
Background:SetTexCoord(0, 1, 0, 0.25)

-- Hook into the Logout and Quit functions
local function HookLogoutFunctions()
    hooksecurefunc("Logout", function()
        isLoggingOut = true
    end)

    hooksecurefunc("Quit", function()
        isLoggingOut = true
    end)

    hooksecurefunc("CancelLogout", function()
        isLoggingOut = false
    end)
end

-- Sound handling
local lastPlayedSound = 0
local function PlaySoundAlert()
    if (GetTime() - lastPlayedSound < 2) then 
        return
    end
    
    PlaySound(8959)
    lastPlayedSound = GetTime()
end

local scanStatus = CreateFrame("Frame", "WorldBossScanStatus", UIParent, "BackdropTemplate")
scanStatus:SetSize(300, 30)
scanStatus:SetPoint("TOP", UIParent, "TOP", 0, -5)
scanStatus:SetFrameStrata("HIGH")
scanStatus:Hide() -- Hide initially

-- Add backdrop
scanStatus:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
scanStatus:SetBackdropColor(0, 0, 0, 0.7)
scanStatus:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)

scanStatus.text = scanStatus:CreateFontString(nil, "OVERLAY", "GameFontNormal")
scanStatus.text:SetPoint("CENTER")
scanStatus.text:SetTextColor(0.2, 1, 0.2) -- Green text

local function MonitorLayerStatus()
    -- Cancel existing timer if there is one
    if statusUpdateTimer then
        statusUpdateTimer:Cancel()
    end

    statusUpdateTimer = C_Timer.NewTicker(1, function()
        local currentLayer = NWB_CurrentLayer
        if currentLayer and currentLayer > 0 then
            UpdateScanStatus()
            statusUpdateTimer:Cancel()
            statusUpdateTimer = nil
        end
    end, 30)
end

local function CheckNWBInitialized()
    if NWB and NWB.currentLayer then
        waitingForNWB = false
        return true
    end
    return false
end

local function InitializeLayerDetection()
    if not NWB then
        print("|cffff0000[WorldBossScan]|r: NovaWorldBuffs not detected. Layer detection may be less reliable.")
        waitingForNWB = false
        return
    end
    -- Start a timer to check for NWB initialization
    local waitTime = 0
    C_Timer.NewTicker(1, function()
        if not waitingForNWB then return end
        
        waitTime = waitTime + 1
        if CheckNWBInitialized() then
            UpdateScanStatus()
        elseif waitTime >= maxNWBWaitTime then
            waitingForNWB = false
        end
    end)
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        InitializeLayerDetection()
        -- rest of your login code
    end
    -- rest of your event handling
end)

local function GetCurrentLayer()
    -- Use NWB_CurrentLayer global
    if NWB_CurrentLayer and NWB_CurrentLayer > 0 then
        return tostring(NWB_CurrentLayer)
    end
    
    -- Fallback to NWB if available
    if NWB and NWB.currentLayer and NWB.currentLayer > 0 then
        return tostring(NWB.currentLayer)
    end
    
    return "Unknown"
end

function UpdateScanStatus()
    local layer = GetCurrentLayer()
    local currentZone = C_Map.GetBestMapForUnit("player")
    local bossesInZone = {}
    local hasWorldBossInZone = false

    -- Check if current zone has any world bosses
    for bossName, bossInfo in pairs(WorldBosses) do
        if bossInfo.zones[currentZone] then
            table.insert(bossesInZone, bossName)
            hasWorldBossInZone = true
        end
    end

    if hasWorldBossInZone then
        local bossList = table.concat(bossesInZone, ", ")
        scanStatus.text:SetText(string.format("Layer %s: Scanning for %s", layer, bossList))
        scanStatus:Show()
    else
        scanStatus:Hide()
    end
end

-- Invite Button to pop up on player's screen.
local function CreateInviteButton(parentButton, playerName, bossName)
    if parentButton.inviteButton then
        parentButton.inviteButton:Hide()
    end
    
    local inviteButton = CreateFrame("Button", nil, parentButton, "GameMenuButtonTemplate")
    inviteButton:SetPoint("TOP", parentButton, "Center", 0, 0)
    inviteButton:SetSize(100, 25)
    inviteButton:SetText("Request Invite")
    inviteButton:SetScript("OnClick", function()
        local currentLayer = GetCurrentLayer()
        local bossLayerKey = bossName.."-"..currentLayer
        joinedBossGroups[bossLayerKey] = GetTime() 
        SendChatMessage("inv", "WHISPER", nil, playerName)
    end)
    
    parentButton.inviteButton = inviteButton
    inviteButton:Show()
    return inviteButton
end

-- Show alert function for when boss is found
local function ShowAlert(bossName, finderName)
    local currentLayer = GetCurrentLayer()
    scanner_button.bossName = bossName
    local bossLayerKey = bossName.."-"..currentLayer

    if (foundBossLayers[bossLayerKey] and (GetTime() - foundBossLayers[bossLayerKey]) < (4 * 3600)) or
       (joinedBossGroups[bossLayerKey] and (GetTime() - joinedBossGroups[bossLayerKey]) < (4 * 3600)) then
        return
    end

    if foundBossLayers[bossLayerKey] and (GetTime() - foundBossLayers[bossLayerKey]) < (4 * 3600) then
        return
    end
    
    if not finderName then
        foundBossLayers[bossLayerKey] = GetTime()
        if IsInGuild() then
            local playerFullName = UnitName("player") .. "-" .. GetRealmName()
            local message = "WSB:" .. bossName .. ":" .. playerFullName .. ":" .. currentLayer
            C_ChatInfo.SendAddonMessage("WorldBossScan", message, "GUILD")
        end
        finderName = UnitName("player")
    end

    if finderName == UnitName("player") then
        scanner_button.text:SetText(bossName .. " found on Layer " .. currentLayer .. "!")
        if IsInGuild() then
            SendChatMessage(bossName .. " found on Layer " .. currentLayer .. " /w for invite!", "GUILD")
        end
    else
        scanner_button.text:SetText(finderName .. " found " .. bossName .. "!")
        CreateInviteButton(scanner_button, finderName, bossName)
    end

    scanner_button:Show()
    PlaySoundAlert()

    print("|cffff0000[WorldBossScan]|r: " .. bossName .. " found on Layer " .. currentLayer .. "!")
end

-- Add forbidden action tracking
local npcFound = false
local function OnAddonActionForbidden(addonName, functionName)
    if (addonName == 'WorldBossScan') then
        npcFound = true
    end
end

-- Close error popups
local function CloseErrorPopUp()
    if StaticPopup_HasDisplayedFrames() then
        for idx = STATICPOPUP_NUMDIALOGS, 1, -1 do
            local dialog = _G["StaticPopup" .. idx]
            if dialog and dialog:IsShown() and dialog.which ~= "PARTY_INVITE" then
                local OnCancel = dialog.OnCancel
                local noCancelOnEscape = dialog.noCancelOnEscape
                if OnCancel and not noCancelOnEscape then
                    OnCancel(dialog)
                end
                StaticPopupSpecial_Hide(dialog)
            end
        end
    end
end

-- Scanning function 
local checking = false

local function ScanForBosses()
    local currentLayer = GetCurrentLayer()
    if (checking or isLoggingOut) then
        return
    end
    checking = true
    local currentZone = C_Map.GetBestMapForUnit("player")
    if not currentZone then
        checking = false
        return
    end
    for bossName, bossInfo in pairs(WorldBosses) do
        local bossLayerKey = bossName.."-"..currentLayer
        if bossInfo.zones[currentZone] then
            TargetUnit(bossName)
            
            if (npcFound) then
                CloseErrorPopUp()
                ShowAlert(bossName)
                npcFound = false
            elseif (not npcFound) then
                foundBossLayers[bossLayerKey] = nil
            end
        end
    end
    checking = false
end

-- Register events
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("CHAT_MSG_MONSTER_YELL")
frame:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
frame:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
frame:RegisterEvent("CHAT_MSG_MONSTER_SAY")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:RegisterEvent("LOGOUT_CANCEL")
frame:RegisterEvent("UNIT_TARGET")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
HookLogoutFunctions()

-- Register addon prefix
C_ChatInfo.RegisterAddonMessagePrefix("WorldBossScan")

-- Event handler
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_ACTION_FORBIDDEN" then
        OnAddonActionForbidden(...)     
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, function()
            InitializeLayerDetection()
            RespawnTracker:Initialize()
            UpdateScanStatus()
            ScanForBosses() 
            scanStatus:Show()
            MonitorLayerStatus()
        end)    
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
        C_Timer.After(1, function()
            InitializeLayerDetection()
            RespawnTracker:Initialize()
            UpdateScanStatus()
            ScanForBosses() 
            scanStatus:Show() 
            MonitorLayerStatus()
        end)    
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == "WorldBossScan" and channel == "GUILD" then
            local command, param1, param2, param3 = strsplit(":", message)
            local playerFullName = UnitName("player").."-"..GetRealmName()
            
            if command == "WSB" and sender ~= playerFullName then
                local bossName, playerName, layer = param1, param2, param3
                local bossLayerKey = bossName.."-"..layer
                foundBossLayers[bossLayerKey] = GetTime()
                founedBossGroups[bossLayerKey] = GetTime()
                ShowAlert(bossName, playerName)
            elseif command == "BOSS_KILL" and sender ~= playerFullName then
                local bossName, layer, killTime = param1, param2, tonumber(param3)
                local key = bossName .. "-" .. layer
                
                RespawnTracker.respawnTimes[key] = {
                    lastKilled = killTime,
                    estimatedRespawn = killTime + (RespawnTracker.respawnDurations[bossName] or (3 * 24 * 60 * 60))
                }
                WorldBossScanDB.respawnTimes = RespawnTracker.respawnTimes
            end
        end
    elseif event == "CHAT_MSG_MONSTER_YELL" or event == "CHAT_MSG_MONSTER_EMOTE" 
        or event == "CHAT_MSG_RAID_BOSS_EMOTE" or event == "CHAT_MSG_MONSTER_SAY" then
    local message, monsterName = ...
    for bossName, yells in pairs(BossYells) do
        if monsterName and monsterName:match(bossName) then
            if message == yells.spawn then
                ShowAlert(bossName)
            elseif yells.combat then
                for _, combatYell in ipairs(yells.combat) do
                    if message == combatYell then
                        ShowAlert(bossName)
                    end
                end
            end
        end
    end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName = CombatLogGetCurrentEventInfo()
        
        if subevent == "UNIT_DIED" then
            local bossName = RespawnTracker:IsBoss(destGUID)
            if bossName then
                local currentLayer = GetCurrentLayer()
                if currentLayer and currentLayer ~= "Unknown" then
                    RespawnTracker:RecordKill(bossName, currentLayer)
                end
            end
        elseif subevent == "SPELL_CAST_START" or subevent == "SPELL_CAST_SUCCESS" or subevent == "SWING_DAMAGE" then
            local bossName = RespawnTracker:IsBoss(sourceGUID)
            if bossName then
                ShowAlert(bossName)
            end
        end
    elseif event == "LOGOUT_CANCEL" then
        isLoggingOut = false  
    end
end)

-- Button scripts
scanner_button:SetScript("OnClick", function(self, button)
    if button == "LeftButton" and self.bossName then
        TargetUnit(self.bossName)
        if UnitExists("target") then
            SetRaidTarget("target", 8)  -- Set skull marker
        end
    elseif button == "RightButton" then
        self:Hide()
        if self.inviteButton then
            self.inviteButton:Hide()
        end
    end
end)

-- Cleanup timer for old entries
C_Timer.NewTicker(3600, function()
    local now = GetTime()
    for key, timestamp in pairs(foundBossLayers) do
        if (now - timestamp) > (4 * 3600) then
            foundBossLayers[key] = nil
        end
    end
    for key, timestamp in pairs(joinedBossGroups) do
        if (now - timestamp) > (4 * 3600) then
            joinedBossGroups[key] = nil
        end
    end
end)

SLASH_WORLDBOSSSCAN1 = '/wbs'
SlashCmdList["WORLDBOSSSCAN"] = function(msg)
    local command, rest = strsplit(" ", msg, 2)
    
    if command == "test" then
        local currentLayer = GetCurrentLayer()
        print("Current layer for test:", currentLayer)
        local testBossName = "Azuregos"
        local bossLayerKey = testBossName.."-"..(currentLayer or "1")
        foundBossLayers[bossLayerKey] = nil
        scanner_button.bossName = testBossName
        scanner_button.text:SetText(testBossName .. " found" .. (currentLayer ~= "Unknown" and " on Layer " .. currentLayer or "") .. "!")
        scanner_button:Show()
        PlaySoundAlert()
        print("|cffff0000[WorldBossScan]|r: Test alert shown for " .. testBossName)
    elseif command == "joined" then
        local currentLayer = GetCurrentLayer() or "1"
        local testBossName = "Undertaker Mordo"
        local bossLayerKey = testBossName.."-"..currentLayer
        foundBossLayers[bossLayerKey] = GetTime()
        joinedBossGroups[bossLayerKey] = GetTime()
        print("|cffff0000[WorldBossScan]|r: Simulated joining TestPlayer's group - scanning paused for "..testBossName.." on layer "..currentLayer)
    elseif command == "debug" then
        local target = "target"
        if UnitExists(target) and not UnitIsPlayer(target) then
            local guid = UnitGUID(target)
            if guid then
                local unittype, zero, server_id, instance_id, zone_uid = strsplit("-", guid)
                print("Debug Info:")
                print("GUID:", guid)
                print("Server ID:", server_id)
                print("Instance ID:", instance_id)
                print("Zone UID:", zone_uid)
            end
        end
    elseif command == "kill" and rest then
        local currentLayer = GetCurrentLayer()
        if currentLayer and currentLayer ~= "Unknown" then
            RespawnTracker:RecordKill(rest, currentLayer)
            print("|cffff0000[WorldBossScan]|r: Recorded kill of " .. rest .. " on layer " .. currentLayer)
        else
            print("|cffff0000[WorldBossScan]|r: Couldn't determine current layer, please use the kill command to manually add entry!")
        end
    elseif command == "cd" or command == "cooldowns" then
        print("|cffff0000[WorldBossScan]|r: World Boss Cooldowns:")
        for bossName, _ in pairs(RespawnTracker.respawnDurations) do
            print("---" .. bossName .. "---")
            local foundAny = false
            for i = 1, 10 do
                local key = bossName .. "-" .. i
                if RespawnTracker.respawnTimes[key] then
                    local data = RespawnTracker.respawnTimes[key]
                    local timeLeft = data.estimatedRespawn - GetServerTime()
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
        RespawnTracker:GetBossInfo(command)
    else
        print("WorldBossScan commands:")
        print("/wbs test - Test the guild alert system")
        print("/wbs debug - Show debug info for current target")
        print("/wbs cd - Show all boss cooldowns")
        print("/wbs <bossalias> - Show cooldowns for specific boss (azu, kaz, etc)")
        print("/wbs kill <bossname> - Manually record a boss kill")
    end
end

-- Mute targeting errors
MuteSoundFile(567464)
MuteSoundFile(567490)

-- Run scans frequently
C_Timer.NewTicker(1, ScanForBosses)