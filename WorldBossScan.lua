local WorldBosses = {
    ["Azuregos"] = 6109,
    ["Lord Kazzak"] = 12397,
    ["Emeriss"] = 14889,
    ["Lethon"] = 14888,
    ["Taerar"] = 14890,
    ["Ysondre"] = 14887,
    ["Undertaker Mordo"] = 1666  -- Test NPC
}

local BossYells = {
    ["Azuregos"] = {
        spawn = "This place is under my protection. The mysteries of the arcane shall remain inviolate.",
        combat = {
            "Such is the price of curiosity.",
            "Come, little ones. Face me!"
        }
    },
    ["Lord Kazzak"] = {
        spawn = "I remember well the sting of defeat at the conclusion of the Third War. I have waited far too long for my revenge. Now the shadow of the Legion falls over this world. It is only a matter of time until all of your failed creation... is undone.",
        combat = {
            "All mortals will perish!",
            "The Legion will conquer all!",
            "Your own strength feeds me!"
        },
        death = "The Legion... will never... fall."
    },
    ["Ysondre"] = {
        combat = {
            "The Dragons of Nightmare will conquer all!",
            "Hope is a DISEASE of the soul! This land shall wither and die!"
        }
    },
    ["Lethon"] = {
        combat = {
            "I can sense the SHADOW on your hearts. There can be no rest for the wicked!",
            "Your wicked souls shall feed my power!"
        }
    },
    ["Emeriss"] = {
        combat = {
            "Hope is a DISEASE of the soul! This land shall wither and die!",
            "Nature's rage comes full circle! Earth and sky shall burn!"
        }
    },
    ["Taerar"] = {
        combat = {
            "Peace is but a fleeting dream! Let the NIGHTMARE reign!",
            "Children of Madness - I release you upon this world!"
        }
    }
}

local foundBossLayers = {}

-- Create main frame
local frame = CreateFrame("Frame", "WorldBossScanFrame", UIParent)

-- Create alert button
local scanner_button = CreateFrame("Button", "WorldBossScanButton", UIParent, "SecureActionButtonTemplate, BackdropTemplate")
scanner_button:Hide()
scanner_button:SetIgnoreParentScale(true)
scanner_button:SetFrameStrata("MEDIUM")
scanner_button:SetFrameLevel(200)
scanner_button:SetSize(200, 50)
scanner_button:SetScale(0.8)
scanner_button:RegisterForClicks("RightButtonUp", "LeftButtonUp")
scanner_button:SetAttribute("*type1", "macro")
scanner_button:SetAttribute("*type2", "closebutton")
scanner_button:SetNormalTexture([[Interface\AchievementFrame\UI-Achievement-Parchment-Horizontal-Desaturated]])
scanner_button:SetPoint("BOTTOM", UIParent, 0, 128)
scanner_button:SetMovable(true)
scanner_button:EnableMouse(true)
scanner_button:RegisterForDrag("LeftButton")
scanner_button:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
scanner_button:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
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

-- Sound handling
local lastPlayedSound = 0
local function PlaySoundAlert()
    if (GetTime() - lastPlayedSound < 2) then 
        return
    end
    
    PlaySound(8959)
    lastPlayedSound = GetTime()
end

-- Get current layer
local function GetCurrentLayer()
    local guid = UnitGUID("player")
    if guid then
        local _, _, serverID = strsplit("-", guid)
        return serverID
    end
    return nil
end

-- Invite Button to pop up on player's screen.
local function CreateInviteButton(parentButton, playerName, bossName)
    if parentButton.inviteButton then
        parentButton.inviteButton:Hide()
    end
    
    local inviteButton = CreateFrame("Button", nil, parentButton, "UIPanelButtonTemplate")
    inviteButton:SetPoint("TOP", parentButton, "BOTTOM", 0, -5)
    inviteButton:SetSize(100, 25)
    inviteButton:SetText("Request Invite")
    inviteButton:SetScript("OnClick", function()
        SendChatMessage("inv", "WHISPER", nil, playerName)
    end)
    
    parentButton.inviteButton = inviteButton
    inviteButton:Show()
    return inviteButton
end

-- Show alert function for when boss is found
local function ShowAlert(bossName, finderName)
    local currentLayer = GetCurrentLayer()
    if not currentLayer then return end
    
    local bossLayerKey = bossName.."-"..currentLayer

    if foundBossLayers[bossLayerKey] and (GetTime() - foundBossLayers[bossLayerKey]) < (4 * 3600) then -- 4 hours
        return
    end
    
    if not finderName then
        foundBossLayers[bossLayerKey] = GetTime()
        if IsInGuild() then
            local message = "WSB:"..bossName..":"..UnitName("player")..":"..currentLayer
            C_ChatInfo.SendAddonMessage("WorldBossScan", message, "GUILD")
        end
        finderName = UnitName("player")
    end

    if finderName == UnitName("player") then
        scanner_button.text:SetText(bossName.." found!")
        local macrotext = "/cleartarget\n/targetexact "..bossName
        scanner_button:SetAttribute("macrotext", macrotext)
    else
        scanner_button.text:SetText(finderName.." found "..bossName.."!")
        CreateInviteButton(scanner_button, finderName, bossName)
    end
    
    scanner_button:Show()
    PlaySoundAlert()
    
    if finderName == UnitName("player") then
        print("|cffff0000[WorldBossScan]|r: "..bossName.." has been found!")
    else
        print("|cffff0000[WorldBossScan]|r: "..finderName.." has found "..bossName.."!")
    end
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
    if (StaticPopup_HasDisplayedFrames()) then
        for idx = STATICPOPUP_NUMDIALOGS,1,-1 do
            local dialog = _G["StaticPopup"..idx]
            local OnCancel = dialog.OnCancel
            local noCancelOnEscape = dialog.noCancelOnEscape
            if (OnCancel and not noCancelOnEscape) then
                OnCancel(dialog)
            end
            StaticPopupSpecial_Hide(dialog)
        end
    end
end

-- Scanning function 
local checking = false
local function ScanForBosses()
    if (checking) then
        return
    end
    
    checking = true
    
    for bossName, _ in pairs(WorldBosses) do
        TargetUnit(bossName)
        
        if (npcFound) then
            CloseErrorPopUp()
            ShowAlert(bossName) 
            npcFound = false
        end
    end
    
    checking = false
end

-- Register events
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("CHAT_MSG_MONSTER_YELL")

-- Register addon prefix
C_ChatInfo.RegisterAddonMessagePrefix("WorldBossScan")

-- Event handler
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_ACTION_FORBIDDEN" then
        OnAddonActionForbidden(...)
        
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, ScanForBosses)
        
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
        C_Timer.After(1, ScanForBosses)
        
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == "WorldBossScan" and channel == "GUILD" then
            -- Parse the message
            local command, bossName, playerName, layer = strsplit(":", message)
            if command == "WSB" and sender ~= UnitName("player") then
                -- Record this boss+layer combination
                local bossLayerKey = bossName.."-"..layer
                foundBossLayers[bossLayerKey] = GetTime()
                ShowAlert(bossName, playerName)
            end
        end
        
    elseif event == "CHAT_MSG_MONSTER_YELL" then
        local message, monsterName = ...
        for bossName, yells in pairs(BossYells) do
            if monsterName and monsterName:match(bossName) then
                -- If it's a spawn yell
                if message == yells.spawn then
                    print("|cffff0000[WorldBossScan]|r: "..bossName.." has spawned!")
                    ShowAlert(bossName)
                -- If it's a combat yell
                elseif yells.combat then
                    for _, combatYell in ipairs(yells.combat) do
                        if message == combatYell then
                            print("|cffff0000[WorldBossScan]|r: "..bossName.." is in combat!")
                        end
                    end
                end
            end
        end
    end
end)

-- Button scripts
scanner_button:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
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
end)

-- Test command
SLASH_WORLDBOSSSCAN1 = '/wbs'
SlashCmdList["WORLDBOSSSCAN"] = function(msg)
    if msg == "test" then
        -- Force a simulated alert
        local currentLayer = GetCurrentLayer() or "1"
        local testBossName = "Undertaker Mordo"
        local bossLayerKey = testBossName.."-"..currentLayer
        foundBossLayers[bossLayerKey] = nil  -- Reset this boss so we can test again
        ShowAlert(testBossName, "TestPlayer")
    elseif msg == "joined" then
        -- Simulate joining the test group
        local currentLayer = GetCurrentLayer() or "1"
        local testBossName = "Undertaker Mordo"
        local bossLayerKey = testBossName.."-"..currentLayer
        foundBossLayers[bossLayerKey] = GetTime()
        print("|cffff0000[WorldBossScan]|r: Simulated joining TestPlayer's group - scanning paused for "..testBossName.." on current layer.")
    else
        print("WorldBossScan commands:")
        print("/wbs test - Test the guild alert system")
    end
end

-- Mute targeting errors
MuteSoundFile(567464)
MuteSoundFile(567490)

-- Run scans frequently
C_Timer.NewTicker(1, ScanForBosses)