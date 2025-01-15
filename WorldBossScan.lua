-- Define our world boss list
local WorldBosses = {
    ["Azuregos"] = true,
    ["Lord Kazzak"] = true,
    ["Emeriss"] = true,
    ["Lethon"] = true,
    ["Taerar"] = true,
    ["Ysondre"] = true,
    ["Undertaker Mordo"] = true  -- Test NPC
}

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

-- Found bosses tracking
local foundBosses = {}

-- Sound handling
local lastPlayedSound = 0
local function PlaySoundAlert()
    -- Don't play sounds too frequently
    if (GetTime() - lastPlayedSound < 2) then 
        return
    end
    
    -- Play raid warning sound
    PlaySound(8959)
    lastPlayedSound = GetTime()
end

local function CreateInviteButton(parentButton, playerName)
    -- Hide previous invite button if it exists
    if parentButton.inviteButton then
        parentButton.inviteButton:Hide()
    end
    
    local inviteButton = CreateFrame("Button", nil, parentButton, "UIPanelButtonTemplate")
    inviteButton:SetPoint("TOP", parentButton, "BOTTOM", 0, -5)
    inviteButton:SetSize(100, 25)
    inviteButton:SetText("Request Invite")
    inviteButton:SetScript("OnClick", function()
        SendChatMessage("inv", "WHISPER", nil, playerName)
        parentButton:Hide()
        inviteButton:Hide()
    end)
    
    parentButton.inviteButton = inviteButton
    inviteButton:Show()
    
    return inviteButton
end

local function ShowAlert(bossName, finderName)
    if not foundBosses[bossName] or finderName then  -- Allow showing if it's from another player
        -- If we found it, send guild alert
        if not finderName then
            if IsInGuild() then
                local message = "WSB:"..bossName..":"..UnitName("player")
                C_ChatInfo.SendAddonMessage("WorldBossScan", message, "GUILD")
            end
            finderName = UnitName("player")
        end
        
        -- Update button text
        if finderName == UnitName("player") then
            scanner_button.text:SetText(bossName.." found!")
            -- Set up targeting macro
            local macrotext = "/cleartarget\n/targetexact "..bossName
            scanner_button:SetAttribute("macrotext", macrotext)
        else
            scanner_button.text:SetText(finderName.." found "..bossName.."!")
            -- Create invite request button
            CreateInviteButton(scanner_button, finderName)
        end
        
        -- Show button
        scanner_button:Show()
        
        -- Play sound
        PlaySoundAlert()
        
        -- Print to chat
        if finderName == UnitName("player") then
            print("|cffff0000[WorldBossScan]|r: "..bossName.." has been found!")
        else
            print("|cffff0000[WorldBossScan]|r: "..finderName.." has found "..bossName.."!")
        end
        
        -- Auto-hide after 10 seconds
        C_Timer.After(10, function()
            scanner_button:Hide()
            if scanner_button.inviteButton then
                scanner_button.inviteButton:Hide()
            end
        end)
        
        foundBosses[bossName] = true
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
    -- If already scanning, skip
    if (checking) then
        return
    end
    
    checking = true
    
    -- Loop through our boss list
    for bossName, _ in pairs(WorldBosses) do
        -- Try to silently target the boss
        TargetUnit(bossName)
        
        -- If we got a forbidden action, we found the boss
        if (npcFound) then
            -- Hide error popup
            CloseErrorPopUp()
            
            -- Show alert
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
        wipe(foundBosses)
        
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == "WorldBossScan" and channel == "GUILD" then
            -- Parse the message
            local command, bossName, playerName = strsplit(":", message)
            if command == "WSB" and sender ~= UnitName("player") then
                ShowAlert(bossName, playerName)
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

-- Test command
SLASH_WORLDBOSSSCAN1 = '/wbs'
SlashCmdList["WORLDBOSSSCAN"] = function(msg)
    if msg == "test" then
        -- Force a simulated alert, ignoring the foundBosses table
        foundBosses["Undertaker Mordo"] = nil  -- Reset this boss so we can test again
        ShowAlert("Undertaker Mordo", "TestPlayer")
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