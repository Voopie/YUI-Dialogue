local _, addon = ...
local L = addon.L;
local API = addon.API;
local PixelUtil = addon.PixelUtil;
local TooltipFrame = addon.SharedTooltip;
local GossipDataProvider = addon.GossipDataProvider;
local PlaySound = addon.PlaySound;
local ThemeUtil = addon.ThemeUtil;
local GetPrimaryControlKey = addon.KeyboardControl.GetPrimaryControlKey;

-- User Settings
local SHOW_QUEST_TYPE_TEXT = true;
local INPUT_DEVICE_GAME_PAD = false;
------------------

local BUTTON_TEXT_SPACING = 4;      --Font Size * 0.35
local BUTTON_PADDING_SMALL = 6.0;   --Font Size * 0.5
local BUTTON_PADDING_LARGE = 12.0;  --Font Size
local BUTTON_ICON_SIZE = 14.0;      --Font Size + 2

local NAME_PADDING_H = 12.0;        --
local ICON_PADDING_H = 6.0;

local NAME_OFFSET_QUEST = 24;       --BUTTON_ICON_SIZE + 1.5*ICON_PADDING_H

local BUTTON_HEIGHT_LARGE = 36.0;   --Affected by Font Size
local HOTKEYFRAME_PADDING = 8.0;
local HOTKEYFRAME_SIZE = 20;        --Font Size + 8

local ITEMBUTTON_TEXT_WDITH_SHRINK = 48.0;
local SMALLITEMBUTTON_TEXT_WIDTH_SHRINK = 24.0;

local GAME_PAD_CONFIRM_KEY = nil;

local ANIM_DURATION_BUTTON_HOVER = 0.25;
local ANIM_OFFSET_H_BUTTON_HOVER = 8;       --12 using GamePad

local AbbreviateNumbers = API.AbbreviateNumbers;
local Esaing_OutQuart = addon.EasingFunctions.outQuart;
local Round = API.Round;
local GetQuestIcon = API.GetQuestIcon;
local IsQuestItem = API.IsQuestItem;
local IsCosmeticItem = API.IsCosmeticItem;
local strlen = string.len;
local CreateFrame = CreateFrame;
local GetItemCount = C_Item.GetItemCount or GetItemCount;
local IsEquippableItem = IsEquippableItem;
local C_GossipInfo = C_GossipInfo;
local CompleteQuest = CompleteQuest;
local CloseQuest = CloseQuest;
local DeclineQuest = DeclineQuest;
local GetQuestItemInfo = GetQuestItemInfo;
local GetQuestCurrencyInfo = GetQuestCurrencyInfo;
local GetQuestCurrencyID = GetQuestCurrencyID;
local GetNumQuestChoices = GetNumQuestChoices;
local GetQuestReward = GetQuestReward;
local GetSpellInfo = GetSpellInfo;
local SelectActiveQuest = SelectActiveQuest;        --QUEST_GREETING
local SelectAvailableQuest = SelectAvailableQuest;  --QUEST_GREETING
local BreakUpLargeNumbers = BreakUpLargeNumbers;


local MAJOR_FACTION_REPUTATION_REWARD_ICON_FORMAT = [[Interface\Icons\UI_MajorFaction_%s]];
local ICON_PATH = "Interface/AddOns/DialogueUI/Art/Icons/";

local GOSSIP_ICONS = {
    [132053] = ICON_PATH.."Gossip.png",
    ["Gossip Red"] = ICON_PATH.."Gossip-Red.png",       --<Skip Chaptor>
    ["Gossip Quest"] = ICON_PATH.."Gossip-Quest.png",   --(Quest) flags == 1

    [132058] = ICON_PATH.."Trainer.png",                --Trainer
    [132060] = ICON_PATH.."Buy.png",                    --Merchant
    ["Inn"] = ICON_PATH.."Innkeeper.png",
    [1019848] = ICON_PATH.."Gossip.png",                --Tavio in Iskaara (likely meant to use Fishing icon)
    ["Profession Trainer"] = ICON_PATH.."Mine.png",
    ["Class Trainer"] = ICON_PATH.."Trainer.png",
    ["Stable Master"] = ICON_PATH.."Stablemaster.png",
    [1673939] = "interface/minimap/tracking/transmogrifier.blp",

    ["Trading Post"] = ICON_PATH.."TradingPost.png",
    ["Battle Pet Trainer"] = ICON_PATH.."BattlePet.png",

    ["Transmogrification"] = "interface/minimap/tracking/transmogrifier.blp",
    ["Void Storage"] = "interface/cursor/crosshair/voidstorage.blp",
    ["Auction House"] = "interface/minimap/tracking/auctioneer.blp",
    ["Bank"] = "interface/minimap/tracking/banker.blp",
    ["Barber"] = "interface/minimap/tracking/barbershop.blp",
    ["Flight Master"] = "interface/minimap/tracking/flightmaster.blp",

    ["Mailbox"] = "interface/minimap/tracking/mailbox.blp",
    --["Points of Interest"] = "",
    --["Other Continents"] = "Interface/AddOns/DialogueUI/Art/Icons/Continent.png",
    ["Vendor"] = "interface/cursor/crosshair/buy.blp",

    [1130518] = "interface/cursor/crosshair/workorders.blp",                            --Work Orders (Class Hall)
    [132050] = "interface/minimap/tracking/banker.blp",
};

GOSSIP_ICONS[132052] = GOSSIP_ICONS["Inn"];

local CUSTOM_ICONS = {
    [1121020] = "trophy_of_strife.png",
    [1455894] = "honor.png",
    [1523630] = "conquest.png",
};


local function Anim_ShiftButtonCentent_OnUpdate(optionButton, elapsed)
    optionButton.t = optionButton.t + elapsed;
    local offset;
    if optionButton.t < ANIM_DURATION_BUTTON_HOVER then
        offset = Esaing_OutQuart(optionButton.t, 0, ANIM_OFFSET_H_BUTTON_HOVER, ANIM_DURATION_BUTTON_HOVER);
    else
        offset = ANIM_OFFSET_H_BUTTON_HOVER;
        optionButton:SetScript("OnUpdate", nil);
    end
    optionButton.offset = offset;
    optionButton.Content:SetPoint("TOPLEFT", offset, optionButton.pushOffsetY or 0);
end

local function Anim_ResetButtonCentent_OnUpdate(optionButton, elapsed)
    optionButton.t = optionButton.t + elapsed;
    local offset;
    if optionButton.t < ANIM_DURATION_BUTTON_HOVER then
        offset = Esaing_OutQuart(optionButton.t, optionButton.offset, 0, ANIM_DURATION_BUTTON_HOVER);
    else
        offset = 0;
        optionButton:SetScript("OnUpdate", nil);
    end
    optionButton.offset = offset;
    optionButton.Content:SetPoint("TOPLEFT", offset, 0);
end

local function OnClickFunc_SelectOption(gossipButton)
    gossipButton.owner:SetConsumeGossipClose(false);
    gossipButton.owner:SetSelectedGossipIndex(gossipButton.id);     --For Dialogue History: Grey out other buttons

    --Classic
    if gossipButton.isTrainer then
        addon.CallbackRegistry:Trigger("PlayerInteraction.Trainer", true);
    end

    C_GossipInfo.SelectOptionByIndex(gossipButton.id);
end

local function OnClickFunc_SelectAvailableQuest(questButton)
    questButton.owner:SetConsumeGossipClose(true);
    questButton.owner:MarkQuestIsFromGossip(true);
    C_GossipInfo.SelectAvailableQuest(questButton.questID);
end

local function OnClickFunc_SelectActiveQuest(questButton)
    questButton.owner:SetConsumeGossipClose(true);
    questButton.owner:MarkQuestIsFromGossip(true);
    C_GossipInfo.SelectActiveQuest(questButton.questID);
end

local function OnClickFunc_SelectGreetingAvailableQuest(questButton)
    questButton.owner:SetConsumeGossipClose(true);
    questButton.owner:MarkQuestIsFromGossip(true);
    SelectAvailableQuest(questButton.id);
end

local function OnClickFunc_SelectGreetingActiveQuest(questButton)
    questButton.owner:SetConsumeGossipClose(true);
   SelectActiveQuest(questButton.id);
end

local function OnClickFunc_AcceptQuest(acceptButton, fromMouseClick)
    --[[
    if ( QuestFlagsPVP() ) then
		QuestFrame.dialog = StaticPopup_Show("CONFIRM_ACCEPT_PVP_QUEST");
	else
		if ( QuestFrame.autoQuest ) then
			AcknowledgeAutoAcceptQuest();
		else
			AcceptQuest();
		end
	end
    --]]


    return addon.DialogueUI:ScrollDownOrAcceptQuest(fromMouseClick);

    --Events Order:
    --(QUEST_DETAIL)
    --QUEST_FINISHED
    --QUEST_ACCEPTED
    --GOSSIP_SHOW (if the quest can be complete right after being accepted)
end

local function OnClickFunc_ContinueQuest(continueButton)
    CompleteQuest();
end

local function OnClickFunc_DeclineQuest(exitButton)
    DeclineQuest();
end

local function OnClickFunc_CloseQuest(exitButton)
    CloseQuest();
    exitButton.owner:HideUI();
end

local function OnClickFunc_Goodbye(exitButton)
    exitButton.owner:HideUI();
end

local function OnClickFunc_GetRewardAndCompleteQuest(completeButton)
    local numChoices = GetNumQuestChoices();
    local choiceID;

    if numChoices == 0 then
        choiceID = 0;
    elseif numChoices == 1 then
        choiceID = 1;
    else
        choiceID = completeButton.owner.rewardChoiceID;
    end

    if numChoices > 1 and not choiceID then
        --not chosen error
    else
        --We move money confirmation to the previous step (Continue Quest)
        --local money = GetQuestMoneyToGet();
        --if ( money and money > 0 ) then
        --    StaticPopup_Show("CONFIRM_COMPLETE_EXPENSIVE_QUEST");
        --end
        GetQuestReward(choiceID);
    end
end

local function OnClickFunc_ConfirmGossip(acceptButton)
    if acceptButton.confirmGossipID then
        C_GossipInfo.SelectOption(acceptButton.confirmGossipID, "", true);
    end
end

local function OnClickFunc_CancelConfirmGossip(cancelButton)
    cancelButton.owner:OnEvent("GOSSIP_CONFIRM_CANCEL");
end


DUIDialogOptionButtonMixin = {};

function DUIDialogOptionButtonMixin:OnLoad()
    self.Icon = self.Content.Icon;
    self.Name = self.Content.Name;
    self.Name:SetSpacing(BUTTON_TEXT_SPACING);
    self.offset = 0;
    API.DisableSharpening(self.Background);

    self.Icon:SetSize(BUTTON_ICON_SIZE, BUTTON_ICON_SIZE);

    self:SetHyperlinksEnabled(true);
end

function DUIDialogOptionButtonMixin:OnHyperlinkEnter(link, text, region, left, bottom, width, height)
    --print(link, text);
    self:OnEnter();
    if link then
        TooltipFrame:SetOwner(self, "ANCHOR_NONE");
        TooltipFrame:SetPoint("BOTTOMLEFT", self, "TOPLEFT", left + ANIM_OFFSET_H_BUTTON_HOVER, 0);
        TooltipFrame:SetHyperlink(link);
        local itemID = API.GetItemIDFromHyperlink(link);
        if itemID then
            local numInBags = GetItemCount(itemID);
            TooltipFrame:AddLeftLine(L["Format You Have X"]:format(numInBags), 1, 0.82, 0);
            TooltipFrame:Show();
        end
    end
end

function DUIDialogOptionButtonMixin:OnHyperlinkLeave()
    TooltipFrame:Hide();
    self:OnLeave();
end

function DUIDialogOptionButtonMixin:OnHyperlinkClick()
    self:Click("LeftButton");
end

function DUIDialogOptionButtonMixin:ShowHoverVisual()
    self.t = 0;
    self:SetScript("OnUpdate", Anim_ShiftButtonCentent_OnUpdate);
end

function DUIDialogOptionButtonMixin:ShowHoverVisualIfFocusChanged()
    if self:IsEnabled() then
        local isSameButton = self.owner:HighlightButton(self);
        if not isSameButton then
            self:ShowHoverVisual();
        end
    end
end

function DUIDialogOptionButtonMixin:PlayKeyFeedback()
    if not self:IsMouseOver() then
        self:ShowHoverVisualIfFocusChanged();
        --PlaySound("DIALOG_OPTION_CLICK");
    end
end

function DUIDialogOptionButtonMixin:OnEnter()
    self:ShowHoverVisualIfFocusChanged();

    if self.type == "gossip" and self.gossipOptionID then
        local hasTooltip = GossipDataProvider:SetupTooltipByGossipOptionID(self.gossipOptionID);
        if hasTooltip then
            TooltipFrame:SetPoint("TOPRIGHT", self, "TOPLEFT", 0, 0);
            TooltipFrame:Show();
        end
    elseif self.type == "autoAccepted" then
        TooltipFrame:Hide();
        TooltipFrame:SetOwner(self, "ANCHOR_NONE");
        TooltipFrame:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 4);
        TooltipFrame:AddLeftLine(L["Quest Auto Accepted Tooltip"], 1, 1, 1);
        TooltipFrame:Show();
    end
end

function DUIDialogOptionButtonMixin:OnLeave()
    if self:IsMouseOver() then return end;
    self.owner:HighlightButton(nil);
    self.t = 0;
    self:SetScript("OnUpdate", Anim_ResetButtonCentent_OnUpdate);
    TooltipFrame:Hide();
end

function DUIDialogOptionButtonMixin:OnClick(button)
    if button == "LeftButton" or button == "GamePad" then
        if self.onClickFunc then
            --PlaySound("DIALOG_OPTION_CLICK");
            return self.onClickFunc(self, button == "LeftButton");
        end
    elseif button == "RightButton" then
        self.owner:HideUI();
    end
end

function DUIDialogOptionButtonMixin:OnMouseDown(button)
    if button == "LeftButton" then
        if self:IsEnabled() then
            self.pushOffsetY = -1;
            self.Content:SetPoint("TOPLEFT", self.offset, self.pushOffsetY);
        else
            if self.type == "complete" then
                self.owner:FlashRewardChoices();
            end
        end
    end
end

function DUIDialogOptionButtonMixin:OnMouseUp(button)
    self.pushOffsetY = 0;
    self.Content:SetPoint("TOPLEFT", self.offset, self.pushOffsetY);
end

function DUIDialogOptionButtonMixin:SetButtonText(name, bigPadding)
    self.Name:SetText(name);
    self:Layout(bigPadding);
end

function DUIDialogOptionButtonMixin:SetGossip(data, hotkey)
    self.gossipOptionID = data.gossipOptionID;

    local name = GossipDataProvider:GetOverrideName(self.gossipOptionID) or data.name;

    local hasColor = false;
    name, hasColor = ThemeUtil:AdjustTextColor(name);

    if hasColor then
        self.Icon:SetTexture( GOSSIP_ICONS["Gossip Red"] );
    elseif data.flags == 1 then
        self.Icon:SetTexture( GOSSIP_ICONS["Gossip Quest"] );
    else
        if data.overrideIconID then
            self.Icon:SetTexture(data.overrideIconID);
        else
            if GOSSIP_ICONS[name] then
                self.Icon:SetTexture( GOSSIP_ICONS[name] );
            else
                local icon = data.icon or 132053;
                if GOSSIP_ICONS[icon] then
                    self.Icon:SetTexture( GOSSIP_ICONS[icon] );
                else
                    self.Icon:SetTexture(icon);
                end
            end
        end
    end

    self.showIcon = true;
    self.id = data.orderIndex or 0;
    self.type = "gossip";
    self.onClickFunc = OnClickFunc_SelectOption;

    self:SetHotkey(false);  --Put Key in name (1. Options 1)
    if hotkey then
        name = hotkey..". "..name;
    end

    self:RemoveQuestTypeText();
    self:SetButtonText(name, false);
    self:SetButtonArt(0);
    self:Enable();

    --Classic
    self.isTrainer = data.icon == 132058;
end

function DUIDialogOptionButtonMixin:FlagAsPreviousGossip(selectedGossipID)
    if not self:IsEnabled() then return end;

    self:Disable();
    self:ResetVisual();

    if self.id ~= selectedGossipID then
        self:SetAlpha(0.5);
    end
end

function DUIDialogOptionButtonMixin:RemoveQuestTypeText()
    if self.hasQuestType then
        self.hasQuestType = nil;
        self.rightFrameWidth = nil;
        self.Name:SetWidth(self.defaultNameWidth);
    end
end

function DUIDialogOptionButtonMixin:SetQuestTypeText(questInfo)
    local typeText;

    if questInfo.isTrivial then
        typeText = L["Quest Type Trivial"];
    else
        if SHOW_QUEST_TYPE_TEXT then
            if questInfo.repeatable then
                typeText = L["Quest Type Repeatable"];
            elseif questInfo.frequency == 1 then
                typeText = L["Quest Frequency Daily"];
            elseif questInfo.frequency == 2 then
                typeText = L["Quest Frequency Weekly"];
            end
        end
    end

    if typeText then
        local questTypeFrame = addon.DialogueUI.questTypeFramePool:Acquire();
        questTypeFrame:SetRightText(typeText);
        questTypeFrame:SetPoint("RIGHT", self, "RIGHT", -HOTKEYFRAME_PADDING, 0);
        questTypeFrame:SetParent(self);
        local frameWidth = questTypeFrame:GetContentWidth();
        self.hasQuestType = true;
        self.rightFrameWidth = Round(frameWidth);
        return
    end

    self:RemoveQuestTypeText();
end

function DUIDialogOptionButtonMixin:SetQuestVisual(questInfo)
    self.Icon:SetTexture(GetQuestIcon(questInfo));  --We fill in the QuestInfo through this API

    if questInfo.isComplete or (not questInfo.isOnQuest) then
        if questInfo.repeatable or questInfo.frequency ~= 0 then
            self:SetButtonArt(2);
        else
            self:SetButtonArt(1);
        end
    else
        self:SetButtonArt(4);
    end
end

function DUIDialogOptionButtonMixin:SetQuest(questInfo, hotkey)
    if INPUT_DEVICE_GAME_PAD then
        self:SetHotkey(nil);
    else
        self:SetHotkey(hotkey);
    end

    self.showIcon = true;
    self.questID = questInfo.questID;
    self:SetQuestVisual(questInfo);
    self:SetQuestTypeText(questInfo);
    self:SetButtonText(questInfo.title, true);
end

function DUIDialogOptionButtonMixin:SetAvailableQuest(questInfo, index, hotkey)
    --QuestUtil.ApplyQuestIconOfferToTextureForQuestID(self.Icon, questInfo.questID, questInfo.isLegendary, questInfo.frequency, questInfo.isRepeatable, questInfo.isImportant);

    self.id = index;
    self.type = "availableQuest";
    self.onClickFunc = OnClickFunc_SelectAvailableQuest;

    self:SetQuest(questInfo, hotkey);
    self:Enable();
end

function DUIDialogOptionButtonMixin:SetActiveQuest(questInfo, index, hotkey)
    --QuestUtil.ApplyQuestIconOfferToTextureForQuestID(self.Icon, questInfo.questID, questInfo.isLegendary, questInfo.frequency, questInfo.isRepeatable, questInfo.isImportant);

    self.id = index;
    self.type = "activeQuest";
    self.onClickFunc = OnClickFunc_SelectActiveQuest;

    self:SetQuest(questInfo, hotkey);
    self:Enable();
end


function DUIDialogOptionButtonMixin:SetGreetingAvailableQuest(questInfo, index, hotkey)
    --Handle QUEST_GREETING event
    --questInfo is manully constructed. the raw data are title and questID

    self.id = index;
    self.type = "availableQuest";
    self.onClickFunc = OnClickFunc_SelectGreetingAvailableQuest;

    self:SetQuest(questInfo, hotkey);
    self:Enable();
end

function DUIDialogOptionButtonMixin:SetGreetingActiveQuest(questInfo, index, hotkey)
    self.id = index;
    self.type = "activeQuest";
    self.onClickFunc = OnClickFunc_SelectGreetingActiveQuest;

    self:SetQuest(questInfo, hotkey);
    self:Enable();
end


function DUIDialogOptionButtonMixin:SetButtonExitGossip()
    self.showIcon = false;
    self.id = 0;
    self.type = "goodbye";
    self.Icon:SetTexture(nil);
    self.onClickFunc = OnClickFunc_Goodbye;
    self:SetHotkey("Esc");
    self:SetButtonText(L["Goodbye"], true);
    self:SetButtonArt(4);
    self:Enable();
end

function DUIDialogOptionButtonMixin:SetButtonDeclineQuest(canReturn)
    self.showIcon = false;
    self.id = 0;
    self.type = "decline";
    self.Icon:SetTexture(nil);

    if canReturn then
        self.onClickFunc = OnClickFunc_DeclineQuest;
    else
        self.onClickFunc = OnClickFunc_CloseQuest;
    end

    self:SetHotkey("Esc");
    self:SetButtonText(L["Decline"], true);
    self:SetButtonArt(4);
end

function DUIDialogOptionButtonMixin:SetButtonAcceptQuest()
    self.showIcon = false;
    self.id = 0;
    self.type = "accept";
    self.Icon:SetTexture(nil);
    self.onClickFunc = OnClickFunc_AcceptQuest;


    local canAccept = true;     --It's hard to determine if the player can accept more quests in Retail

    if canAccept then
        self:Enable();
        self:SetButtonArt(1);
        self:SetHotkey("PRIMARY");
        self:SetButtonText(L["Accept"], true);
    else
        self:Disable();
        self:SetButtonArt(3);
        self:SetHotkey(nil);
        self.showIcon = true;
        self.Icon:SetTexture(nil);
        self:SetButtonText(L["Quest Log Full"], true);
    end
end

function DUIDialogOptionButtonMixin:SetButtonAlreadyOnQuest()
    self.showIcon = false;
    self.id = 0;
    self.type = "autoAccepted";
    self.Icon:SetTexture(nil);
    self.onClickFunc = OnClickFunc_AcceptQuest;

    self:Enable();
    self:SetButtonArt(3);
    self:SetHotkey(nil);
    self.showIcon = true;
    self.Icon:SetTexture(nil);
    self:SetButtonText(L["Quest Accepted"], true);
end

function DUIDialogOptionButtonMixin:SetButtonCloseAutoAcceptQuest()
    --For auto-accepted quest: change the "Decline" button to "OK"
    self.showIcon = false;
    self.id = 0;
    self.type = "decline";
    self.Icon:SetTexture(nil);
    self.onClickFunc = OnClickFunc_CloseQuest;
    self:SetHotkey("PRIMARY");
    self:SetButtonText(L["OK"], true);
    self:SetButtonArt(4);
    self:Enable();
end

function DUIDialogOptionButtonMixin:SetButtonContinueQuest(canContinue, lockDuration)
    self.id = 0;
    self.type = "continue";
    self.onClickFunc = OnClickFunc_ContinueQuest;

    if canContinue then
        if lockDuration and self.ButtonLock then
            self.showIcon = true;
            self:Disable();
            self:SetButtonArt(3);
            self:SetHotkey(nil);

            local function callback()
                self:SetButtonContinueQuest(canContinue);
            end

            self.ButtonLock:SetParentButton(self, callback, lockDuration);
        else
            self.showIcon = false;
            self:Enable();
            self:SetButtonArt(1);
            self:SetHotkey("PRIMARY");
        end

        self.Icon:SetTexture(nil);
        self:SetButtonText(L["Continue"], true);
    else
        self:Disable();
        self:SetButtonArt(3);
        self:SetHotkey(nil);
        self.showIcon = true;
        self.Icon:SetTexture(nil);
        self:SetButtonText(L["Incomplete"], true);
    end
end

function DUIDialogOptionButtonMixin:SetButtonCompleteQuest()
    self.showIcon = false;
    self.id = 0;
    self.type = "complete";
    self.onClickFunc = OnClickFunc_GetRewardAndCompleteQuest;

    local rewardChosen = self.owner:IsRewardChosen();

    if rewardChosen then
        self:SetHotkey("PRIMARY");
        self.showIcon = false;
        self:SetButtonText(L["Complete Quest"], true);
        self:Enable();
        self:SetButtonArt(1);
    else
        self:SetHotkey(nil);
        self.showIcon = true;
        self:SetButtonText(L["Complete Quest"], true);
        self:Disable();
        self:SetButtonArt(3);
    end
end

function DUIDialogOptionButtonMixin:SetButtonCancelQuestProgress(canReturn)
    self.showIcon = false;
    self.id = 0;
    self.type = "cancel";

    if canReturn then
        self.onClickFunc = OnClickFunc_DeclineQuest;
    else
        self.onClickFunc = OnClickFunc_Goodbye;
    end

    self:SetHotkey("Esc");
    self:SetButtonText(L["Cancel"], true);
    self:SetButtonArt(4);
    self:Enable();
end

function DUIDialogOptionButtonMixin:SetButtonConfirmGossip(gossipID, lockDuration)
    self.showIcon = false;
    self.id = 0;
    self.type = "confirmGossip";
    self.confirmGossipID = gossipID;
    self.onClickFunc = OnClickFunc_ConfirmGossip;

    if lockDuration and self.ButtonLock then
        self:SetHotkey(nil);
        self.showIcon = true;
        self:SetButtonText(L["Accept"], true);
        self:Disable();
        self:SetButtonArt(3);

        local function callback()
            self:SetButtonConfirmGossip(gossipID);
        end

        self.ButtonLock:SetParentButton(self, callback, lockDuration);
    else
        self:SetHotkey("PRIMARY");
        self.showIcon = false;
        self:SetButtonText(L["Accept"], true);
        self:Enable();
        self:SetButtonArt(1);
    end
end

function DUIDialogOptionButtonMixin:SetButtonCancelConfirmGossip()
    self.showIcon = false;
    self.id = 0;
    self.type = "cancelConfirmGossip";
    self.onClickFunc = OnClickFunc_CancelConfirmGossip;
    self:SetHotkey("Esc");
    self:SetButtonText(L["Cancel"], true);
    self:SetButtonArt(4);
    self:Enable();
end

function DUIDialogOptionButtonMixin:SetButtonWidth(width)
    self:SetWidth(width);
    self.baseWidth = width;
    self.defaultNameWidth = width - NAME_OFFSET_QUEST - NAME_PADDING_H;
    self.Name:SetWidth(self.defaultNameWidth);
end

function DUIDialogOptionButtonMixin:Layout(largePadding)
    local padding = (largePadding and BUTTON_PADDING_LARGE) or BUTTON_PADDING_SMALL;
    local nameOffset;
    local iconOffset = 0;

    if self.hasHotkey then
        local hotkeyWidth = self.HotkeyFrame:GetWidth();
        local fromOffset = HOTKEYFRAME_PADDING + hotkeyWidth + HOTKEYFRAME_PADDING;
        iconOffset = fromOffset;
        if self.showIcon then
            nameOffset = iconOffset + BUTTON_ICON_SIZE + ICON_PADDING_H;
        else
            nameOffset = fromOffset;
        end
    else
        nameOffset = padding;
        if self.showIcon then
            iconOffset = padding;
            nameOffset = iconOffset + BUTTON_ICON_SIZE + ICON_PADDING_H;
        end
    end

    if self.rightFrameWidth then
        self.Name:SetWidth(self.baseWidth - self.rightFrameWidth - nameOffset - ANIM_OFFSET_H_BUTTON_HOVER);
    end

    local textHeight = self.Name:GetHeight();

    self:SetHeight( Round(textHeight + 2*padding) );
    self.Name:SetPoint("TOPLEFT", self.Content, "TOPLEFT", nameOffset, -padding);
    self.Icon:SetPoint("TOPLEFT", self.Content, "TOPLEFT", iconOffset, -padding + 1);
end

local SharedHighlightTexture = {
    [0] = {backTexture = "ButtonHighlight-Gossip.png", blendMode = "BLEND"},
    [1] = {backTexture = "ButtonHighlight-Add.png", blendMode = "ADD", color = {0.62, 0, 0}, frontTexture = "ButtonHighlight-Front.png"},    --Red
    [2] = {backTexture = "ButtonHighlight-Add.png", blendMode = "ADD", color = {0, 0.3, 0.4}, frontTexture = "ButtonHighlight-Front.png"},   --Blue
    [3] = {backTexture = "ButtonHighlight-Add.png", blendMode = "ADD", color = {0.23, 0.23, 0.23}, frontTexture = "ButtonHighlight-Front.png"},
    [4] = {backTexture = "ButtonHighlight-Add.png", blendMode = "ADD", color = {0.23, 0.23, 0.23}, frontTexture = "ButtonHighlight-Front.png"},
};

function DUIDialogOptionButtonMixin:SetParentHighlightTexture(parentHighlightFrame)
    parentHighlightFrame:SetParent(self);
    parentHighlightFrame:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0);
    parentHighlightFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0);
    parentHighlightFrame:Show();
    parentHighlightFrame:SetFrameLevel(self:GetFrameLevel());
    parentHighlightFrame.BackTexture:SetDrawLayer("ARTWORK");
    if parentHighlightFrame.artID ~= self.artID then
        parentHighlightFrame.artID = self.artID;
        local data = self.artID and SharedHighlightTexture[self.artID];
        if data then
            parentHighlightFrame.BackTexture:SetTexture(ThemeUtil:GetTextureFile(data.backTexture));
            parentHighlightFrame.BackTexture:SetBlendMode(data.blendMode);
            if data.color then
                parentHighlightFrame.BackTexture:SetVertexColor(data.color[1], data.color[2], data.color[3]);
            else
                parentHighlightFrame.BackTexture:SetVertexColor(1, 1, 1);
            end
            parentHighlightFrame.FrontTexture:SetTexture(ThemeUtil:GetTextureFile(data.frontTexture));
        end
    end


    parentHighlightFrame.FrontTexture:SetWidth(self:GetHeight());
    parentHighlightFrame.FrontTexture:ClearAllPoints();
    parentHighlightFrame.FrontTexture:SetHeight(self:GetHeight());
    parentHighlightFrame.FrontTexture:SetPoint("TOPLEFT", self.Content, "TOPLEFT", 0, 0);
end

function DUIDialogOptionButtonMixin:SetButtonArt(id)
    if self.artID ~= id then
        self.artID = id;
    else
        return
    end

    local prefix = ThemeUtil:GetTexturePath();
    local bgName

    if id == 0 then         --Gossip
        self.Background:SetTexture(nil);
        self.Name:SetFontObject("DUIFont_Quest_Gossip");
    elseif id == 1 then     --Red
        bgName = "OptionBackground-Common.png";
        self.Background:SetTexture(prefix..bgName);
        self.Name:SetFontObject("DUIFont_Quest_Quest");
    elseif id == 2 then     --Daily
        bgName = "OptionBackground-Blue.png";
        self.Background:SetTexture(prefix..bgName);
        self.Name:SetFontObject("DUIFont_Quest_Quest");
    elseif id == 3 then     --Goodbye/Declick Button, Unfinished Quest
        bgName = "OptionBackground-Hollow.png"; --Grey
        self.Background:SetTexture(prefix..bgName);
        self.Name:SetFontObject("DUIFont_Quest_Disabled");
    elseif id == 4 then     --Exit / Incomplete Quest
        bgName = "OptionBackground-Grey.png";
        self.Background:SetTexture(prefix..bgName);
        self.Name:SetFontObject("DUIFont_Quest_Quest");
    end
end

function DUIDialogOptionButtonMixin:LoadTheme()
    local artID = self.artID;
    self.artID = nil;
    self:SetButtonArt(artID);

    if self.HotkeyFrame then
        self.HotkeyFrame:LoadTheme();
    end
end

function DUIDialogOptionButtonMixin:OnFontSizeChanged()
    self.Icon:SetSize(BUTTON_ICON_SIZE, BUTTON_ICON_SIZE);
end

function DUIDialogOptionButtonMixin:ResetVisual()
    self:SetScript("OnUpdate", nil);
    self.Content:SetPoint("TOPLEFT", 0, 0);
    self:SetAlpha(1);
    self.t = nil;
    self.offset = 0;
    self.pushOffsetY = 0;
end

function DUIDialogOptionButtonMixin:SetOwner(owner)
    self.owner = owner;
end

function DUIDialogOptionButtonMixin:SetHotkey(hotkey)
    if hotkey then
        local hotkeyFrame = self.HotkeyFrame or addon.DialogueUI.hotkeyFramePool:Acquire();

        self.HotkeyFrame = hotkeyFrame;
        hotkeyFrame:ClearAllPoints();
        hotkeyFrame:SetPoint("TOPLEFT", self.Content, "TOPLEFT", HOTKEYFRAME_PADDING, -HOTKEYFRAME_PADDING);
        hotkeyFrame:SetParent(self);

        if hotkeyFrame:SetKey(hotkey) then
            self.hasHotkey = true;
            hotkeyFrame:Show();
        else
            self.hasHotkey = false;
            hotkeyFrame:Hide();
        end

    else
        self.hasHotkey = false;
        if self.HotkeyFrame then
            self.HotkeyFrame:ClearKey();
        end
    end
end


local HotkeyIcons = {
    SPACE = {file = "SPACE.png", ratio = 1, rightCoord = 1, tint = true},
    ERROR = {file = "ERROR.png", ratio = 1, rightCoord = 1},

    XBOX_PADLSHOULDER = {file = "HotkeyBackground-LB.png", themed = true, text = "LB", ratio = 1.5, rightCoord = 0.75, noBackground = true, useFrameSize = true, trilinear = true},
    XBOX_PADRSHOULDER = {file = "HotkeyBackground-RB.png", themed = true, text = "RB", ratio = 1.5, rightCoord = 0.75, noBackground = true, useFrameSize = true, trilinear = true},
    XBOX_PAD1 = {file = "XBOX-PAD1.png", themed = true, ratio = 1, rightCoord = 1, noBackground = true, useFrameSize = true, trilinear = true},
    XBOX_PAD2 = {file = "XBOX-PAD2.png", themed = true, ratio = 1, rightCoord = 1, noBackground = true, useFrameSize = true, trilinear = true},
    XBOX_PAD4 = {file = "XBOX-PAD4.png", themed = true, ratio = 1, rightCoord = 1, noBackground = true, useFrameSize = true, trilinear = true},

    PS_PADLSHOULDER = {file = "HotkeyBackground-LB.png", themed = true, text = "L1", ratio = 1.5, rightCoord = 0.75, noBackground = true, useFrameSize = true, trilinear = true},
    PS_PADRSHOULDER = {file = "HotkeyBackground-RB.png", themed = true, text = "R1", ratio = 1.5, rightCoord = 0.75, noBackground = true, useFrameSize = true, trilinear = true},
    PS_PAD1 = {file = "PS-PAD1.png", themed = true, ratio = 1, rightCoord = 1, noBackground = true, useFrameSize = true, trilinear = true},
    PS_PAD2 = {file = "PS-PAD2.png", themed = true, ratio = 1, rightCoord = 1, noBackground = true, useFrameSize = true, trilinear = true},
    PS_PAD4 = {file = "PS-PAD4.png", themed = true, ratio = 1, rightCoord = 1, noBackground = true, useFrameSize = true, trilinear = true},
};

HotkeyIcons.PADLSHOULDER = HotkeyIcons.XBOX_PADLSHOULDER;
HotkeyIcons.PADRSHOULDER = HotkeyIcons.XBOX_PADRSHOULDER;
HotkeyIcons.XBOX_Esc = HotkeyIcons.XBOX_PAD2;
HotkeyIcons.PS_Esc = HotkeyIcons.PS_PAD2;
HotkeyIcons.XBOX_Shift = HotkeyIcons.XBOX_PAD4;
HotkeyIcons.PS_Shift = HotkeyIcons.PS_PAD4;


DUIDialogHotkeyFrameMixin = {};

function DUIDialogHotkeyFrameMixin:OnLoad()
    self:LoadTheme();
    self.Icon:SetVertexColor(0.72, 0.72, 0.72);
    --API.DisableSharpening(self.Background);

    self.Background:SetTexelSnappingBias(0.81);
    self.Background:SetSnapToPixelGrid(true);

    self:UpdateBaseHeight();
end

function DUIDialogHotkeyFrameMixin:ReloadKey()
    local key = self.key;
    self.key = nil;
    self:SetKey(key);
end

function DUIDialogHotkeyFrameMixin:LoadTheme()
    self.Background:SetTexture(ThemeUtil:GetTextureFile("HotkeyBackground.png"));
    self:ReloadKey();
end

function DUIDialogHotkeyFrameMixin:SetBaseHeight(height)
    self.baseHeight = height;
    self:SetSize(height, height);
end

function DUIDialogHotkeyFrameMixin:UpdateBaseHeight()
    --Font Size + 8
    self:SetBaseHeight(HOTKEYFRAME_SIZE);

    local iconSize = HOTKEYFRAME_SIZE - 6;
    self.defaultIconSize = iconSize;
    self.Icon:SetSize(iconSize, iconSize);

    self:ReloadKey();
end

function DUIDialogHotkeyFrameMixin:SetKey(key)
    if key == "PRIMARY" then
        key = GAME_PAD_CONFIRM_KEY or GetPrimaryControlKey();
    end

    if key ~= self.key then
        self.key = key;
    else
        return true
    end

    if key then
        local height = self.baseHeight;
        local width;
        if HotkeyIcons[key] then
            local iconData = HotkeyIcons[key];
            local filterMode = (iconData.trilinear and "TRILINEAR") or "LINEAR";

            if iconData.themed then
                self.Icon:SetTexture(ThemeUtil:GetTextureFile(iconData.file), nil, nil, filterMode);
            else
                local prefix = "Interface/AddOns/DialogueUI/Art/Keys/";
                self.Icon:SetTexture(prefix..iconData.file, nil, nil, filterMode);
            end

            self.Icon:Show();

            if iconData.text then
                self.KeyName:SetText(iconData.text);
                self.KeyName:Show();
            else
                self.KeyName:Hide();
            end

            if iconData.tint then
                self.Icon:SetVertexColor(0.72, 0.72, 0.72);
            else
                self.Icon:SetVertexColor(1, 1, 1);
            end

            self.Icon:SetTexCoord(0, iconData.rightCoord, 0, 1);
            self.Background:SetShown(not iconData.noBackground);

            width = height * iconData.ratio;

            if iconData.useFrameSize then
                self.Icon:SetSize(width, height);
                --self.Icon:SetSize(self.defaultIconSize * iconData.ratio, self.defaultIconSize);
            else
                self.Icon:SetSize(self.defaultIconSize, self.defaultIconSize);
            end
        else
            self.Icon:Hide();
            self.KeyName:SetText(key);
            self.KeyName:Show();
            self.Background:Show();

            if strlen(key) == 1 then
                width = height;
            else
                width = Round(self.KeyName:GetWidth() + 12);
            end
        end

        self:SetSize(width, height);
        self:Show();
        return true
    else
        self:ClearKey();
        return false
    end
end

function DUIDialogHotkeyFrameMixin:ClearKey()
    if self.key then
        self.key = nil;
        self.Icon:Hide();
        self.KeyName:Hide();
        self.Background:Hide();
    end
    self:Hide();
end




local ItemButtonSharedMixin = {};

function ItemButtonSharedMixin:SetButtonWidth(width)
    self:SetWidth(width);
end

function ItemButtonSharedMixin:PlaySheen()
    self.AnimSheen:Stop();
    self.Sheen:Show();
    self.AnimSheen:Play();
end

function ItemButtonSharedMixin:OnEnter()
    if self.type == "choice" then
        addon.DialogueUI:HighlightRewardChoice(self);
    end

    local tooltip = TooltipFrame;
    tooltip:Hide();
    tooltip:SetOwner(self, "ANCHOR_NONE");
    tooltip:SetPoint("BOTTOMLEFT", self.Icon, "TOPRIGHT", 0, 2);
    tooltip.itemID = nil;

    if self.objectType == "item" then
        local allowCollectionText = true;
        tooltip:SetQuestItem(self.type, self.index, allowCollectionText);

        if self.type == "required" and self.itemID and (not IsQuestItem(self.itemID)) then
            local numInBags = GetItemCount(self.itemID);
            local numTotal = GetItemCount(self.itemID, true);
            if numInBags and numTotal then
                if numInBags == numTotal then
                    tooltip:AddLeftLine(L["Format You Have X"]:format(numTotal), 1, 0.82, 0);
                else
                    tooltip:AddLeftLine(L["Format You Have X And Y In Bank"]:format(numTotal, numTotal - numInBags), 1, 0.82, 0);
                end
                tooltip:Show();
            end
        end

    elseif self.objectType == "currency" then
        tooltip:SetQuestCurrency(self.type, self.index);
        if self.currencyID then
            local factionStatus = API.GetFactionStatusTextByCurrencyID(self.currencyID);
            if factionStatus then
                tooltip:AddLeftLine(factionStatus, 1, 0.82, 0);
                tooltip:Show();
            end
        end
    elseif self.objectType == "spell" then
        tooltip:SetSpellByID(self.spellID);
    elseif self.objectType == "reputation" then
        tooltip:SetTitle(self.factionName, 1, 1, 1);
        tooltip:AddLeftLine(L["Format Reputation Reward Tooltip"]:format(self.rewardAmount, self.factionName), 1, 0.82, 0, true);
        if self.factionID then
            local factionStatus = API.GetFactionStatusText(self.factionID);
            if factionStatus then
                tooltip:AddLeftLine(factionStatus, 1, 0.82, 0);
            end
        end
        tooltip:Show();
    elseif self.objectType == "skill" then
        --C_TradeSkillUI.OpenTradeSkill(185) --Require Hardware Event
        local bonusPoint = self.Count:GetText();
        local skillName = self.Name:GetText();
        tooltip:SetTitle(bonusPoint.." "..skillName, 1, 1, 1);
        local info = self.skillLineID and C_TradeSkillUI.GetProfessionInfoBySkillLineID(self.skillLineID);
        if info then
            local currentLevel = info.skillLevel;
            local maxLevel = info.maxSkillLevel;
            if currentLevel and maxLevel and maxLevel ~= 0 then
                tooltip:AddLeftLine(L["Format Current Skill Level"]:format(currentLevel, maxLevel), 1, 0.82, 0);
            end
            tooltip:Show();
        end
    elseif self.objectType == "follower" then
        tooltip:SetFollowerByID(self.followerID);
    elseif self.objectType == "warmode" then
        tooltip:SetTitle(L["War Mode Bonus"], 1, 0.82, 0);
        tooltip:AddLeftLine(WAR_MODE_BONUS_QUEST, 1, 1, 1, true);
        tooltip:Show();
    elseif self.objectType == "honor" then
        tooltip:SetCurrencyByID(self.currencyID);
    else
        tooltip:Hide();
    end
end

function ItemButtonSharedMixin:OnLeave()
    TooltipFrame:Hide();
    if self.type == "choice" then
        addon.DialogueUI:HighlightRewardChoice(nil);
    end
end

function ItemButtonSharedMixin:OnRelease()
    self:ClearAllPoints();
    self:Hide();
    self:SetScript("OnUpdate", nil);
end

function ItemButtonSharedMixin:RemoveTextureBorder(state)
    if state then
        self.Icon:SetTexCoord(0.0625, 0.9275, 0.0625, 0.9275);
    else
        self.Icon:SetTexCoord(0, 1, 0, 1);
    end
end

function ItemButtonSharedMixin:SetBaseGridSize(gridTakenX, gridWidth, gridSpacing)
    self.baseGridTakenX = gridTakenX;
    self.gridWidth = gridWidth;
    self.gridSpacing = gridSpacing;
end

function ItemButtonSharedMixin:SetWidthByGridTaken(gridTakenX)
    if gridTakenX and self.gridWidth and self.gridSpacing then
        local buttonWidth = gridTakenX * (self.gridWidth + self.gridSpacing) - self.gridSpacing;
        self:SetWidth(buttonWidth);
        self.gridTakenX = gridTakenX;
        return buttonWidth
    end
end

function ItemButtonSharedMixin:ResetToDefaultSize()
    self:SetWidthByGridTaken(self.baseGridTakenX);
end

function ItemButtonSharedMixin:IsNameTruncated(nameWidth, buttonWidth)
    --the game finish text truncating in the next frame so fontString:IsTruncated() doesn't work immediately

    nameWidth = (nameWidth or self.Name:GetWrappedWidth());
    buttonWidth = buttonWidth or self:GetWidth();

    return (((nameWidth / self.textMaxLines) + 0.5) > (buttonWidth - self.textShrink));
end

function ItemButtonSharedMixin:FitToName()
    if INPUT_DEVICE_GAME_PAD and self.type == "choice" then
        --Choice Items are aligned vertically (single column) when gamepad is enabled
        self:SetWidthByGridTaken(4);
        return
    end

    local nameWidth = self.Name:GetWrappedWidth();
    local isTruncated = self:IsNameTruncated(nameWidth);

    if isTruncated and self.dynamicResize then
        --If the name is truncated, increase the button's width by one grid width (repeat once if still being truncated)

        local gridTakenX = self.baseGridTakenX + 1;
        local buttonWidth = self:SetWidthByGridTaken(gridTakenX);

        if self:IsNameTruncated(nameWidth, buttonWidth) then
            gridTakenX = gridTakenX + 1;
            buttonWidth = self:SetWidthByGridTaken(gridTakenX);
        end
    else
        self.gridTakenX = self.baseGridTakenX;
    end
end

function ItemButtonSharedMixin:GetActualGridTaken()
    return self.gridTakenX
end

function ItemButtonSharedMixin:ShowOverflowIcon()
    local iconFrame = addon.DialogueUI.iconFramePool:Acquire();
    iconFrame:SetCurrencyOverflow();
    iconFrame:SetParent(self);
    iconFrame:SetPoint("CENTER", self.Icon, "TOPRIGHT", -2, -2);
end

function ItemButtonSharedMixin:GetClipboardOutput()
    local idFormat, id;
    local name = self.Name:GetText();

    if self.objectType == "item" then
        idFormat = "[ItemID: %s]";
        id = self.itemID;
    elseif self.objectType == "spell" then
        idFormat = "[SpellID: %s]";
        id = self.spellID;
    elseif self.objectType == "reputation" then
        idFormat = "[FactionID: %s]";
        id = self.factionID;
        name = self.factionName.." "..self.rewardAmount

    elseif self.objectType == "skill" then
        local skillName, skillIcon, skillPoints = GetRewardSkillPoints();
        name = skillName .. " "..skillPoints;
    elseif self.objectType == "title" then

    elseif self.objectType == "follower" then
        idFormat = "[FollowerID: %s]";
        id = self.followerID;
    elseif self.objectType == "xp" then
        local xp = GetRewardXP();
        local level = UnitLevel("player");
        name = xp.." XP (Level "..level..")";
    elseif self.objectType == "money" then
        local rawCopper = GetRewardMoney();
        name = L["Format Copper Amount"]:format(rawCopper);
    end

    if idFormat and id then
        id = idFormat:format(id);
        name = id.." "..name;
    end

    return name
end


DUIDialogItemButtonMixin = API.CreateFromMixins(ItemButtonSharedMixin);

function DUIDialogItemButtonMixin:OnLoad()
    self.textMaxLines = 2;
    self.textShrink = ITEMBUTTON_TEXT_WDITH_SHRINK;
    self.dynamicResize = true;
    self:SetBackgroundTexture(1);
    self.ItemOverlay:SetTexture(ThemeUtil:GetTextureFile("ItemOverlays.png"));
    self:UpdatePixel();
    PixelUtil:AddPixelPerfectObject(self);
    self:RemoveTextureBorder(true);
    self.Sheen:SetTexture(ThemeUtil:GetTextureFile("RewardChoice-Sheen.png"));
end

function DUIDialogItemButtonMixin:LoadTheme()
    self.ItemOverlay:SetTexture(ThemeUtil:GetTextureFile("ItemOverlays.png"));
    self.Sheen:SetTexture(ThemeUtil:GetTextureFile("RewardChoice-Sheen.png"));

    local backgroundID = self.backgroundID;
    self.backgroundID = nil;
    self.nameColor = nil;
    self:SetBackgroundTexture(backgroundID);
end

function DUIDialogItemButtonMixin:SetBackgroundTexture(id)
    if self.backgroundID ~= id then
        self.backgroundID = id;
    else
        return
    end

    local prefix = ThemeUtil:GetTexturePath();
    local borderFile, bgFile, fontObject;

    if id == 1 then
        borderFile = "ItemBorder.png";
        bgFile = "ItemButtonBackground.png";
        fontObject = "DUIFont_Item";
    elseif id == 2 then
        borderFile = "RewardChoice-ItemBorder.png";
        bgFile = "RewardChoice-Pending.png";
        fontObject = "DUIFont_ItemSelect";
    elseif id == 3 then
        borderFile = "RewardChoice-ItemBorder.png";
        bgFile = "RewardChoice-Selected.png";
        fontObject = "DUIFont_ItemSelect";
    end

    self.ItemBorder:SetTexture(prefix..borderFile);
    self.Background:SetTexture(prefix..bgFile);
    self.Name:SetFontObject(fontObject);
end

function DUIDialogItemButtonMixin:UpdatePixel(scale)
    if not scale then
        scale = self:GetEffectiveScale();
    end

    local iconShrink = 6.0;
    local offset = API.GetPixelForScale(scale, iconShrink);
    self.Icon:ClearAllPoints();
    self.Icon:SetPoint("TOPLEFT", self.ItemBorder, "TOPLEFT", offset, -offset);
    self.Icon:SetPoint("BOTTOMRIGHT", self.ItemBorder, "BOTTOMRIGHT", -offset, offset);
end

function DUIDialogItemButtonMixin:OnClick(button)
    if self.type == "choice" then
        if button == "GamePad" then
            addon.DialogueUI:SelectRewardChoice(self.index);
            addon.DialogueUI:HighlightRewardChoice(self);
            return true
        else
            local isValid = addon.DialogueUI:SelectRewardChoice(self.index);
            if isValid then
                TooltipFrame:Hide();
            end
        end
    end
end

function DUIDialogItemButtonMixin:Refresh()
    if self.objectType == "item" then
        self:SetItem(self.type, self.index);
    elseif self.objectType == "currency" then
        self:SetCurrency(self.type, self.index);
    elseif self.objectType == "spell" then
        self:SetRewardspell(self.spellID, self.icon);
    end
end

local function RefreshAfter_OnUpdate(self, elapsed)
    self.t = self.t + elapsed;
    if self.t > 0.05 then
        self.t = 0;
        self:Refresh();
    end
end

function DUIDialogItemButtonMixin:RequestInfo()
    self.t = 0;
    self:SetScript("OnUpdate", RefreshAfter_OnUpdate);
end

function DUIDialogItemButtonMixin:OnInfoReceived()
    self:SetScript("OnUpdate", nil);
    self.t = nil;
end

function DUIDialogItemButtonMixin:SetItemName(name, quality)
    if name and name ~= "" then
        self:OnInfoReceived();
    else
        self:RequestInfo();
    end

    self:ResetToDefaultSize();
    self.Name:SetText(name);
    self:FitToName();

    self.quality = quality;
    self:UpdateNameColor(quality);
end

function DUIDialogItemButtonMixin:UpdateNameColor(quality)
    if self.backgroundID == 2 then  --Choose reward
        self.nameColor = nil;
        self.Name:SetTextColor(ThemeUtil:GetItemSelectColor());
    else
        quality = quality or self.quality or 0;
        if quality ~= self.nameColor then
            self.nameColor = quality;
            self.Name:SetTextColor(ThemeUtil:GetQualityColor(quality));
        end
    end
end

function DUIDialogItemButtonMixin:SetItemCount(amount, alignToCenter)
    if amount then
        if self.type == "required" and self.itemID and (not IsQuestItem(self.itemID)) then
            local numInBags = GetItemCount(self.itemID);
            if numInBags > 999 then
                numInBags = "*";
            end
            self.Count:SetText("|cffaaaaaa"..numInBags.."/|r"..amount);
        elseif amount > 1 then
            self.Count:SetText(amount);
        else
            self.Count:SetText(nil);
        end
    else
        self.Count:SetText(nil);
    end

    self.Count:SetTextColor(1, 1, 1);
    self.Count:ClearAllPoints();

    if alignToCenter then
        self.Count:SetPoint("BOTTOM", self.Icon, "BOTTOM", 0, 1);
        self.Count:SetJustifyH("CENTER");
    else
        self.Count:SetPoint("BOTTOMRIGHT", self.Icon, "BOTTOMRIGHT", -1, 1);
        self.Count:SetJustifyH("RIGHT");
    end
end

local ITEM_OVERLAYS = {
    --[1] = 1,        --Common
    [2] = 2,        --Uncommon
    [3] = 3,        --Rare
    [4] = 4,        --Epic
    [5] = 5,        --Legendary
    cosmetic = 8,
    skill = 9,      --Tradeskill
    alert = 10,     --Unusable Equipment (Classic)

    followerQuality1 = 17,
};

function DUIDialogItemButtonMixin:SetItemOverlay(id)
    if id and ITEM_OVERLAYS[id] and self.type ~= "required" then
        if self.itemOverlayID ~= id then
            self.itemOverlayID = id;
            local index = ITEM_OVERLAYS[id];
            -- 8x8 Atlas
            local col = index % 8;
            if col == 0 then col = 8 end;
            local row = 1 + (index - col) / 8;
            self.ItemOverlay:SetTexCoord(0.125*(col - 1), 0.125*col, 0.125*(row - 1), 0.125*row);
        end
        self.ItemOverlay:Show();
    else
        self.ItemOverlay:Hide();
    end
end

function DUIDialogItemButtonMixin:SetItem(sourceType, index)
    self.objectType = "item";
    self.type = sourceType;
    self.index = index;
    self.currencyID = nil;

    local name, texture, count, quality, isUsable, itemID = GetQuestItemInfo(sourceType, index);    --no itemID in Classic

    self.itemID = itemID;
    self.Icon:SetTexture(texture);
    self:SetItemName(name, quality);
    self:SetItemCount(count);

    local itemOverlayID;

    if not isUsable then
        itemOverlayID = "alert";
    elseif IsCosmeticItem(itemID) then
        itemOverlayID = "cosmetic";
    elseif IsEquippableItem(itemID) then
        itemOverlayID = quality;
    else
        itemOverlayID = quality;
    end

    self:SetItemOverlay(itemOverlayID);
end

function DUIDialogItemButtonMixin:SetRewardItem(index)
    self.dynamicResize = true;
    self:SetItem("reward", index);
end

function DUIDialogItemButtonMixin:SetRewardChoiceItem(index, isOnlyChoice)
    if isOnlyChoice then
        self.dynamicResize = true;
    else
        self.dynamicResize = false;
    end

    self:SetItem("choice", index);
end

function DUIDialogItemButtonMixin:SetRequiredItem(index)
    self.dynamicResize = true;
    self:SetItem("required", index);
end

function DUIDialogItemButtonMixin:SetCurrency(sourceType, index)
    self.objectType = "currency";
    self.type = sourceType;
    self.index = index;

    local name, texture, amount, quality = GetQuestCurrencyInfo(sourceType, index);
    local currencyID = GetQuestCurrencyID(sourceType, index);
    self.currencyID = currencyID;

    --For Reputation, it's the faction's name, but the game prefer to find a GetCurrencyContainerInfo (CurrencyContainer.lua)

    local showAsItem = false;
    if showAsItem then
        name, texture, amount, quality = API.GetCurrencyContainerInfo(currencyID, amount, name, texture, quality);
    end

    if name then
        self:OnInfoReceived();
    else
        self:RequestInfo();
    end

    self:SetItemName(name, quality);
    self.Icon:SetTexture(texture);
    self.Count:SetText(AbbreviateNumbers(amount));

    if API.WillCurrencyRewardOverflow(currencyID, amount) then
        self.Count:SetTextColor(1.000, 0.125, 0.125);   --RED_FONT_COLOR
        self:ShowOverflowIcon();
    else
        self.Count:SetTextColor(1, 1, 1);
    end

    self:SetItemOverlay(nil);
end

function DUIDialogItemButtonMixin:SetRewardCurrency(index)
    self.dynamicResize = true;
    self:SetCurrency("reward", index);
end

function DUIDialogItemButtonMixin:SetRewardChoiceCurrency(index, isOnlyChoice)
    if isOnlyChoice then
        self.dynamicResize = true;
    else
        self.dynamicResize = false;
    end

    self:SetCurrency("choice", index);
end

function DUIDialogItemButtonMixin:SetRequiredCurrency(index)
    self.dynamicResize = true;
    self:SetCurrency("required", index);
end

function DUIDialogItemButtonMixin:SetMajorFactionReputation(reputationRewardInfo)    --SetUpMajorFactionReputationReward
    self.objectType = "reputation";
    self.dynamicResize = true;
    self.factionID = reputationRewardInfo.factionID;

	local majorFactionData = C_MajorFactions.GetMajorFactionData(self.factionID);
	local factionName = majorFactionData.name;
	local rewardAmount = reputationRewardInfo.rewardAmount;

    self.factionName = factionName;
    self.rewardAmount = rewardAmount;

	--self.Name:SetText(QUEST_REPUTATION_REWARD_TITLE:format(self.factionName));
	--self.RewardAmount:SetText(AbbreviateNumbers(self.rewardAmount));

	local majorFactionIcon = MAJOR_FACTION_REPUTATION_REWARD_ICON_FORMAT:format(majorFactionData.textureKit);
	self.Icon:SetTexture(majorFactionIcon);
    self.Name:SetText(factionName.. " +"..rewardAmount);
    self:SetItemCount(nil);
    self:SetItemOverlay(nil);
    self:OnInfoReceived();
end

function DUIDialogItemButtonMixin:SetRewardspell(spellID, icon, name)
    self.dynamicResize = true;
    self.objectType = "spell";
    self.spellID = spellID;
    self.itemID = nil;
    self.currencyID = nil;

    self.icon = icon;
    self.Icon:SetTexture(icon);

    if not name then
        if C_Spell.DoesSpellExist(spellID) then
            name = GetSpellInfo(spellID);
        else
            name = "Unknown Spell";
        end
    end

    self:SetItemName(name);
    self:SetItemCount(nil);
    self:SetItemOverlay(nil);
end

function DUIDialogItemButtonMixin:SetRewardSkill(skillIcon, skillPoints, skillName, skillLineID)
    self.dynamicResize = true;
    self.objectType = "skill";
    self.spellID = nil;
    self.itemID = nil;
    self.skillLineID = skillLineID;

    self.Icon:SetTexture(skillIcon);
    skillName = skillName or SKILL or "Skill";
    self:SetItemName(skillName);

    self.Count:SetText("+"..skillPoints);
    self.Count:SetTextColor(1, 0.82, 0);
    self:SetItemOverlay("skill");
end

function DUIDialogItemButtonMixin:SetRewardTitle(titleName)
    self.dynamicResize = true;
    self.objectType = "title";
    self.spellID = nil;
    self.itemID = nil;

    self.Icon:SetTexture(134328);   --interface/icons/inv_misc_note_02.blp
    self:SetItemName(L["Format Reward Title"]:format(titleName));
    self:SetItemCount(nil);
    self:SetItemOverlay(nil);
end

function DUIDialogItemButtonMixin:SetWarModeBonus(bonus)
    --bonus: 10%
    self.dynamicResize = true;
    self.objectType = "warmode";
    self.spellID = nil;
    self.itemID = nil;

    self.Icon:SetTexture("Interface/Icons/UI_WARMODE");
    self:SetItemName(L["War Mode Bonus"]);
    self.Count:SetText("+"..bonus.."%");    --PLUS_PERCENT_FORMAT
    self.Count:SetTextColor(0.1, 1, 0.1);
    self:SetItemOverlay(nil);
end

function DUIDialogItemButtonMixin:SetRewardHonor(honor)
    --Classic

    self.dynamicResize = true;
    self.objectType = "honor";
    self.spellID = nil;
    self.itemID = nil;

    local currencyID = 1792;   --Constants.CurrencyConsts.HONOR_CURRENCY_ID;
    self.currencyID = currencyID;
    self.Icon:SetTexture(API.GetHonorIcon());
    self:SetItemName(L["Honor Points"]);
    self:SetItemCount(honor);
    self:SetItemOverlay(nil);
end

function DUIDialogItemButtonMixin:SetRewardFollower(followerID)
    --https://warcraft.wiki.gg/wiki/API_C_Garrison.GetFollowerInfo

    local followerInfo = C_Garrison.GetFollowerInfo(followerID);

    self.dynamicResize = true;
    self.objectType = "follower";
    self.spellID = nil;
    self.itemID = nil;
    self.followerID = followerID;

    local quality = followerInfo.quality;
    if quality == 0 or quality > 6 then
        quality = 1;
    elseif quality == 6 then
        quality = 4;
    end

    local name = followerInfo.name;

    if followerInfo.level and followerInfo.className then
        local title = L["Format Follower Level Class"]:format(followerInfo.level, followerInfo.className);
        name = name.."   "..title;
    end

    self.Icon:SetTexture(followerInfo.portraitIconID);
    self:SetItemName(name);
    self:SetItemCount(nil);
    self:SetItemOverlay(quality);
end


DUIDialogSmallItemButtonMixin = API.CreateFromMixins(ItemButtonSharedMixin); --no name, only quantity

function DUIDialogSmallItemButtonMixin:OnLoad()
    self.textMaxLines = 1;
    self.textShrink = SMALLITEMBUTTON_TEXT_WIDTH_SHRINK;
    self.dynamicResize = true;
    self:SetBackgroundTexture();
end

function DUIDialogSmallItemButtonMixin:SetBackgroundTexture()
    self.Background:SetTexture(ThemeUtil:GetTextureFile("ItemButtonBackground.png"));
end

function DUIDialogSmallItemButtonMixin:SetIcon(file)
    if CUSTOM_ICONS[file] then
        self.Icon:SetTexture(ICON_PATH..CUSTOM_ICONS[file]);
        self:RemoveTextureBorder(false);
    else
        self.Icon:SetTexture(file);
        self:RemoveTextureBorder(true);
    end
end

function DUIDialogSmallItemButtonMixin:SetItemName(name)
    --name is in fact quantity
    self:ResetToDefaultSize();
    self.Name:SetText(name);
    self:FitToName();
end

function DUIDialogSmallItemButtonMixin:SetCurrency(sourceType, index)
    self.objectType = "currency";
    self.type = sourceType;
    self.index = index;

    local name, texture, amount, quality = GetQuestCurrencyInfo(sourceType, index);
    local currencyID = GetQuestCurrencyID(sourceType, index);
    self.currencyID = currencyID;

    self:SetIcon(texture);
    self:SetItemName(amount);

    local overflow = API.WillCurrencyRewardOverflow(currencyID, amount);
    if overflow then
        self:ShowOverflowIcon();
    end
end

function DUIDialogSmallItemButtonMixin:SetRewardCurrency(index)
    self:SetCurrency("reward", index);
end

local function SetCoinIcon(button, rawCopper)
    if rawCopper < 100 then
        button.Icon:SetTexture(ICON_PATH.."Coin-Copper.png");
    elseif rawCopper < 10000 then
        button.Icon:SetTexture(ICON_PATH.."Coin-Silver.png");
    else
        button.Icon:SetTexture(ICON_PATH.."Coin-Gold.png");
    end
end

function DUIDialogSmallItemButtonMixin:SetMoney(rawCopper)
    self.objectType = "money";
    self.type = nil;
    self.index = 0;

    SetCoinIcon(self, rawCopper);
    self:RemoveTextureBorder(false);

    local colorized = ThemeUtil:IsDarkMode();
    local moneyText = API.GenerateMoneyText(rawCopper, colorized);
    self:SetItemName(moneyText);
end

function DUIDialogSmallItemButtonMixin:SetRequiredMoney(rawCopper)
    self.objectType = "money";
    self.type = nil;
    self.index = 0;

    SetCoinIcon(self, rawCopper);
    self:RemoveTextureBorder(false);

    local colorized = false;
    local noAbbreviation = true;
    local moneyText = API.GenerateMoneyText(rawCopper, colorized, noAbbreviation);
    self:SetItemName(moneyText);

    local playerMoney = GetMoney();
    if rawCopper > playerMoney then
        self:ShowOverflowIcon();
    end
end

function DUIDialogSmallItemButtonMixin:SetXP(amount)
    self.objectType = "xp";
    self.type = nil;
    self.index = 0;

    self.Icon:SetTexture(ICON_PATH.."XP-Purple.png");
    self:RemoveTextureBorder(false);

    local percentage = API.GetXPPercentage(amount);
    amount = BreakUpLargeNumbers(amount);
    if percentage then
        amount = amount .. " ("..percentage.."%)";
    end
    self:SetItemName(amount);
end

function DUIDialogSmallItemButtonMixin:SetMajorFactionReputation(reputationRewardInfo)    --SetUpMajorFactionReputationReward
    self.objectType = "reputation";
    self.type = nil;
    self.index = 0;
    self.factionID = reputationRewardInfo.factionID;

	local majorFactionData = C_MajorFactions.GetMajorFactionData(self.factionID);
	local factionName = majorFactionData.name;
	local rewardAmount = reputationRewardInfo.rewardAmount;

	local majorFactionIcon = MAJOR_FACTION_REPUTATION_REWARD_ICON_FORMAT:format(majorFactionData.textureKit);
	self.Icon:SetTexture(majorFactionIcon);
    self:RemoveTextureBorder(true);
    self:SetItemName(rewardAmount);

    self.factionName = factionName;
    self.rewardAmount = rewardAmount;
end

function DUIDialogSmallItemButtonMixin:SetRewardHonor(honor)
    --Classic

    self.objectType = "honor";
    self.spellID = nil;
    self.itemID = nil;

    local currencyID = 1792;   --Constants.CurrencyConsts.HONOR_CURRENCY_ID;
    self.currencyID = currencyID;
    self.Icon:SetTexture(API.GetHonorIcon());
    self:RemoveTextureBorder(true);
    self:SetItemName(honor);
end

DUIDialogOptionButtonLockMixin = {};

function DUIDialogOptionButtonLockMixin:ClearProgress()
    if self.fullBarCoord then
        self.fullBarCoord = nil;
        self.t = nil;
        self:SetScript("OnUpdate", nil);
        self:ClearAllPoints();
        self:Hide();
    end
end

function DUIDialogOptionButtonLockMixin:OnHide()
    self:ClearProgress();
end

function DUIDialogOptionButtonLockMixin:UpdateProgress()
    local progress = self.t / self.lockDuration;
    self.ProgressTexture:SetTexCoord(0, self.fullBarCoord * progress, 0, 1);
    self.ProgressTexture:SetWidth(self.fullWidth * progress);
end

function DUIDialogOptionButtonLockMixin:OnUpdate(elapsed)
    self.t = self.t + elapsed;

    if self.t >= self.lockDuration then
        self:ClearProgress();
        if self.callback then
            self.callback();
            self.callback = nil;
        end
    else
        self:UpdateProgress();
    end
end

function DUIDialogOptionButtonLockMixin:SetParentButton(optionButton, callback, lockDuration)
    self:ClearProgress();
    self:SetParent(optionButton);
    self:SetPoint("TOPLEFT", optionButton, "TOPLEFT", 0, 0);
    self:SetPoint("BOTTOMRIGHT", optionButton, "BOTTOMRIGHT", 0, 0);

    local width, height = optionButton:GetSize();

    local fullBarCoord = width / (8 * height);
    if fullBarCoord > 1 then
        fullBarCoord = 1;
    end

    self.fullBarCoord = fullBarCoord;
    self.fullWidth = width;

    self.t = 0.01;
    self.lockDuration = lockDuration or 2;
    self.callback = callback;

    self:LoadTheme();
    self:UpdateProgress();
    self:SetScript("OnUpdate", self.OnUpdate);
    self:Show();
end

function DUIDialogOptionButtonLockMixin:LoadTheme()
    self.ProgressTexture:SetTexture(ThemeUtil:GetTextureFile("ButtonLockProgress.png"));
end

function DUIDialogOptionButtonLockMixin:OnLoad()
    self:LoadTheme();
end


local InputButtonScripts = {};

function InputButtonScripts.OnEditFocusLost(self)
    self:ClearHighlightText();
    self:UnlockHighlight();
    self.Highlight:SetTexCoord(0, 1, 0.25, 0.5);
end

function InputButtonScripts.OnEditFocusGained(self)
    self:LockHighlight();
    self.Highlight:SetTexCoord(0, 1, 0.5, 0.75);
end

function InputButtonScripts.OnEscapePressed(self)
    self:ClearFocus();
    self:GetParent().owner:HideInputBox();
end

function InputButtonScripts.OnEnterPressed(self)
    self:ClearFocus();
    self:GetParent():ConfirmGossip();
end


DUIDialogInputBoxMixin = {};

function DUIDialogInputBoxMixin:OnLoad()
    self:SetBackgroundTexture();
    self:UpdateHeight();

    for method, script in pairs(InputButtonScripts) do
        self.EditBox:SetScript(method, script);
    end

    InputButtonScripts.OnEditFocusLost(self.EditBox);
    self.owner = self:GetParent();
end

function DUIDialogInputBoxMixin:OnShow()
    self:RegisterEvent("GLOBAL_MOUSE_DOWN");
end

function DUIDialogInputBoxMixin:OnHide()
    self:Hide();
    self:ClearText();
    self.gossipID = nil;
    self:UnregisterEvent("GLOBAL_MOUSE_DOWN");
end

function DUIDialogInputBoxMixin:OnEvent(event, ...)
    if not self:IsMouseOver() then
        self.owner:HideInputBox();
    end
end

function DUIDialogInputBoxMixin:SetBackgroundTexture()
    local bgFile = ThemeUtil:GetTextureFile("InputBox-SingleLine.png");

    self.EditBox.Background:SetTexture(bgFile);
    self.EditBox.Highlight:SetTexture(bgFile);

    self.EditBox.Background:SetTexCoord(0, 1, 0, 0.25);
    self.EditBox.Highlight:SetTexCoord(0, 1, 0.25, 0.5);
end

function DUIDialogInputBoxMixin:UpdateHeight()
    local textHeight = 12.0;
    local editBoxHeight = BUTTON_HEIGHT_LARGE;

    self:SetHeight(6 + textHeight + editBoxHeight);
end

function DUIDialogInputBoxMixin:SetLabel(text)
    self.Label:SetText(text);
end

function DUIDialogInputBoxMixin:SetEditboxText(text)
    self.EditBox:SetText(text);
end

function DUIDialogInputBoxMixin:ClearText()
    self.EditBox:SetText("");
end

function DUIDialogInputBoxMixin:SetFocus()
    self:ClearText();
    C_Timer.After(0, function()
        --Avoid OnKeyDown propagation
        self.EditBox:SetFocus();
    end);
end

function DUIDialogInputBoxMixin:SetGossipID(gossipID)
    self.gossipID = gossipID;
end

function DUIDialogInputBoxMixin:ConfirmGossip()
    C_GossipInfo.SelectOption(self.gossipID, self.EditBox:GetText(), true);
end




do
    local ICON_TEXT_GAP = 0;
    local ICON_SIZE = 12.0;

    DUIDialogQuestTypeFrameMixin = {};

    function DUIDialogQuestTypeFrameMixin:Remove()
        self:ClearAllPoints();
        self:Hide();
        self.Name:SetText("");
        if self.Icon then
            self.Icon:SetTexture(nil);
        end
        if self.hasScripts then
            self:SetScript("OnEnter", nil);
            self:SetScript("OnLeave", nil);
        end
    end

    function DUIDialogQuestTypeFrameMixin:SetRightText(text)
        self.Name:SetFontObject("DUIFont_QuestType_Right");
        self:SetNameAndIcon(text);
        self:SetAlignment("RIGHT");
    end

    function DUIDialogQuestTypeFrameMixin:SetLeftText(text)
        self.Name:SetFontObject("DUIFont_QuestType_Left");
        self:SetNameAndIcon(text);
        self:SetAlignment("LEFT");
    end

    function DUIDialogQuestTypeFrameMixin:SetQuestTagNameAndIcon(tagName, tagIcon)
        self.Name:SetFontObject("DUIFont_QuestType_Left");
        self:SetNameAndIcon(tagName, tagIcon);
        self:SetAlignment("LEFT");
    end

    function DUIDialogQuestTypeFrameMixin:SetNameAndIcon(name, icon)
        self.Name:SetText(name);

        if icon then
            if not self.Icon then
                self.Icon = self:CreateTexture(nil, "OVERLAY");
                self.Icon:SetSize(ICON_SIZE, ICON_SIZE);
            end
            self.Icon:SetTexture(icon, nil, nil, "LINEAR");
        elseif self.Icon then
            self.Icon:SetTexture(nil);
        end

        self.hasIcon = icon ~= nil;
        self:SetWidth(self:GetContentWidth());
    end

    function DUIDialogQuestTypeFrameMixin:SetAlignment(alignment)
        self.Name:ClearAllPoints();
        if alignment == "RIGHT" then
            self.alignment = alignment;
            self.Name:SetPoint("RIGHT", self, "RIGHT", 0, 0);
            if self.Icon then
                self.Icon:ClearAllPoints();
                self.Icon:SetPoint("RIGHT", self.Name, "LEFT", -ICON_TEXT_GAP, 0);
            end
        else
            self.alignment = "LEFT";
            if self.Icon then
                self.Icon:ClearAllPoints();
                self.Icon:SetPoint("LEFT", self, "LEFT", 0, 0);
            end

            if self.hasIcon then
                self.Name:SetPoint("LEFT", self, "LEFT", BUTTON_ICON_SIZE + ICON_TEXT_GAP, 0);
            else
                self.Name:SetPoint("LEFT", self, "LEFT", 0, 0);
            end
        end
        self.Name:SetJustifyH(alignment);
    end

    function DUIDialogQuestTypeFrameMixin:GetContentWidth()
        local width = self.Name:GetWrappedWidth();
        if self.hasIcon then
            width = width + BUTTON_ICON_SIZE + ICON_TEXT_GAP;
        end
        return width
    end

    local function CampaignName_OnEnter(self)
        local tooltip = TooltipFrame;
        tooltip:Hide();

        if self.campaignID then
            tooltip:SetOwner(self, "ANCHOR_NONE");
            tooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 0, 0);

            local campaignInfo = C_CampaignInfo.GetCampaignInfo(self.campaignID);
            tooltip:SetTitle(campaignInfo.name);
            tooltip:AddLeftLine(TRACKER_HEADER_CAMPAIGN_QUESTS or "Campaign", 1, 1, 1);
            if campaignInfo.description then
                tooltip:AddLeftLine(campaignInfo.description, 1, 0.82, 0);
            end
            tooltip:Show();
        end
    end

    local function CampaignName_OnLeave(self)
        TooltipFrame:Hide();
    end

    function DUIDialogQuestTypeFrameMixin:SetCampaignNameID(name, campaignID)
        self:SetLeftText(name);
        self.campaignID = campaignID;
        self.hasScripts = true;
        self:SetScript("OnEnter", CampaignName_OnEnter);
        self:SetScript("OnLeave", CampaignName_OnLeave);
    end
end

do
    DUIDialogIconFrameMixin = {};

    function DUIDialogIconFrameMixin:Remove()
        self:ClearAllPoints();
        self:Hide();
        self.Icon:SetTexture(nil);
    end

    function DUIDialogIconFrameMixin:SetCurrencyOverflow()
        self:SetSize(14, 14);
        self.Icon:SetTexture(ICON_PATH.."CurrencyOverflow.png");
    end
end


do
    local function Settings_QuestTypeText(dbValue)
        SHOW_QUEST_TYPE_TEXT = dbValue == true;
        addon.DialogueUI:OnSettingsChanged();
    end

    addon.CallbackRegistry:Register("SettingChanged.QuestTypeText", Settings_QuestTypeText);


    local function Settings_InputDevice(dbValue)
        INPUT_DEVICE_GAME_PAD = dbValue ~= 1;

        if INPUT_DEVICE_GAME_PAD then
            ANIM_OFFSET_H_BUTTON_HOVER = 8;
            local prefix = "XBOX_";
            if dbValue == 2 then

            elseif dbValue == 3 then
                prefix = "PS_";
            end

            local buttons = {
                "PADLSHOULDER", "PADRSHOULDER", "Esc", "Shift",
            };

            for _, name in ipairs(buttons) do
                HotkeyIcons[name] = HotkeyIcons[prefix..name];
            end

            GAME_PAD_CONFIRM_KEY = prefix.."PAD1";
        else
            ANIM_OFFSET_H_BUTTON_HOVER = 8;
            HotkeyIcons.Esc = nil;
            HotkeyIcons.Shift = nil;
            GAME_PAD_CONFIRM_KEY = nil;
        end

        addon.CallbackRegistry:Trigger("PostInputDeviceChanged", dbValue);
    end
    addon.CallbackRegistry:Register("SettingChanged.InputDevice", Settings_InputDevice);
end


do
    local DEFAULT_FONT_SIZE_ID = 1;

    local FONT_SIZE_INDEX = {
        --[sizeIndex] = {BUTTON_HEIGHT_LARGE, HOTKEYFRAME_PADDING, BUTTON_PADDING_SMALL, BUTTON_PADDING_LARGE};
        [1] = {36, 8, 6, 12},
        [2] = {42, 8, 6, 12},
        [3] = {48, 8, 6, 12},
    };

    local function OnFontSizeChanged(baseFontSize, fontSizeID)
        BUTTON_HEIGHT_LARGE = 3*baseFontSize;
        HOTKEYFRAME_SIZE = baseFontSize + 8;
        BUTTON_ICON_SIZE = baseFontSize + 2;
        NAME_OFFSET_QUEST = BUTTON_ICON_SIZE + 1.5*ICON_PADDING_H;
        --HOTKEYFRAME_PADDING = v[2];
        --BUTTON_PADDING_SMALL = v[3];
        --BUTTON_PADDING_LARGE = v[4];

        --BUTTON_PADDING_LARGE = baseFontSize
        HOTKEYFRAME_PADDING = math.min(8, (BUTTON_HEIGHT_LARGE - HOTKEYFRAME_SIZE)/2);
        BUTTON_PADDING_LARGE = (2*HOTKEYFRAME_PADDING + HOTKEYFRAME_SIZE - baseFontSize)/2
        --print("HOTKEYFRAME_PADDING", HOTKEYFRAME_PADDING)

        addon.CallbackRegistry:Trigger("PostFontSizeChanged");
    end

    addon.CallbackRegistry:Register("FontSizeChanged", OnFontSizeChanged);
end