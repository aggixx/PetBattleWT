local AceGUI = LibStub("AceGUI-3.0");

local ADDON_NAME = "PetBattleWT";

local ADDON_COLOR = "FFF9CC30";
local ADDON_CHAT_HEADER  = "|c" .. ADDON_COLOR .. ADDON_NAME .. ":|r ";
local ADDON_MSG_PREFIX = ADDON_NAME;

RegisterAddonMessagePrefix(ADDON_MSG_PREFIX)

local debugOn = 0;

local queueingWith;
local myForfeit = true;
local inviteName;
local partnerQueueTime;
local selfQueueTime;
local currentPets;
local opponentsPets;
local lastPetLevelCheck = 0;

local function debug(msg, verbosity)
  if (not verbosity or debugOn >= verbosity) then
    if type(msg) == "string" or type(msg) == "number" then
      print(ADDON_CHAT_HEADER..msg);
    elseif type(msg) == "table" then
      if not DevTools_Dump then
        LoadAddOn("Blizzard UI Debug Tools");
      end
      DevTools_Dump(msg);
    end
  end
end

local button = CreateFrame("Button", "PetBattleWT_Button", UIParent, "UIPanelButtonTemplate")
button:SetWidth(400);
button:SetHeight(200);
button:SetText("Forfeit");
button:EnableMouse(true)
button:Hide();
button:SetPoint("CENTER")
local buttonText = button:GetFontString()
buttonText:SetJustifyV("MIDDLE")
button:SetScript("OnClick", function(this, event)
  C_PetBattles.ForfeitGame()
  myForfeit = false;
  if queueingWith then
    SendAddonMessage(ADDON_MSG_PREFIX, "you_next", "WHISPER", queueingWith)
  end
  this:Hide()
end)

local queueIndicator = CreateFrame("Frame", "PetBattleWT_QueueIndicator", PetBattleQueueReadyFrame)
queueIndicator:SetPoint("TOP", PetBattleQueueReadyFrame, "BOTTOM");
queueIndicator:SetWidth(PetBattleQueueReadyFrame:GetWidth())
queueIndicator:SetHeight(30)
queueIndicator:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background.png"
})
queueIndicator:Show()

local inQueueIndicator = CreateFrame("Frame", "PetBattleWT_inQueueIndicator", UIParent)
inQueueIndicator:SetWidth(15)
inQueueIndicator:SetHeight(28)
inQueueIndicator:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background.png"
})
inQueueIndicator:SetBackdropColor(1, 0, 0, 0.90)
inQueueIndicator:Hide()

local petLevelIndicator = CreateFrame("Frame", "PetBattleWT_petLevelIndicator", UIParent)
petLevelIndicator:SetWidth(15)
petLevelIndicator:SetHeight(328)
petLevelIndicator:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background.png"
})
petLevelIndicator:SetBackdropColor(1, 0, 0, 0.90)
petLevelIndicator:Hide()

local function indicator_onUpdate(self, elapsed)
  if not partnerQueueTime then
    if GetTime() - selfQueueTime <= 3 then
      queueIndicator:SetBackdropColor(1, 1, 0, 0.90)
    else
      queueIndicator:SetBackdropColor(1, 0, 0, 0.90)
    end
  else
    if math.abs(selfQueueTime - partnerQueueTime) <= 3 then
      queueIndicator:SetBackdropColor(0, 1, 0, 0.90)
    else
      queueIndicator:SetBackdropColor(1, 0, 0, 0.90)
    end
  end
end

local function petLevelIndicator_SetColor()
  if currentPets and opponentsPets then
    if currentPets == opponentsPets then
      petLevelIndicator:SetBackdropColor(0, 1, 0, 0.90);
    else
      local mine = {string.match(currentPets, "(%d+)/?(%d*)/?(%d*)")};
      local enemy = {string.match(opponentsPets, "(%d+)/?(%d*)/?(%d*)")};
      
      local limit1, limit2 = #mine, #enemy;
      for i=0,limit1-1 do
        for j=0,limit2-1 do
	  if mine[limit1-i] == enemy[limit2-j] then
	    table.remove(mine, limit1-i);
	    table.remove(enemy, limit2-j);
	    break;
	  end
	end
      end
      
      if #mine == 1 and #enemy == 1 and math.abs(mine[1]-enemy[1]) <= 1 then
        petLevelIndicator:SetBackdropColor(1, 1, 0, 0.90);
      else
        petLevelIndicator:SetBackdropColor(1, 0, 0, 0.90);
      end
    end
  else
    petLevelIndicator:SetBackdropColor(1, 0, 0, 0.90);
  end
end

local function petLevelCheck(sendAnyway)
  local t = {};
  
  for i=1,C_PetJournal.GetNumPets() do
    local GUID, _, _, _, level = C_PetJournal.GetPetInfoByIndex(i);
    if GUID and C_PetJournal.PetIsSlotted(GUID) then
      table.insert(t, tonumber(level) or 0);
    end
  end
  
  table.sort(t, function(a,b) return a>b end);
    
  local s = "";
  for i=1,#t do
    if i > 1 then
      s = s .. "/";
    end
    s = s .. t[i]
  end
  
  if s ~= currentPets or sendAnyway then
    currentPets = s;
    debug("Current Pets: "..currentPets, 1)
    petLevelIndicator_SetColor()
    SendAddonMessage(ADDON_MSG_PREFIX, "pets:"..s, "WHISPER", queueingWith);
  end
end

local function updateQueueStatus()
  local status = C_PetBattles.GetPVPMatchmakingInfo() or "notQueued";
  SendAddonMessage(ADDON_MSG_PREFIX, status, "WHISPER", queueingWith)
end

local function sessionStart(name)
  queueingWith = name;
  inQueueIndicator:Show()
  petLevelIndicator:Show()
  petLevelCheck(true);
  inQueueIndicator:SetBackdropColor(1, 0, 0, 0.90);
  updateQueueStatus();
end

StaticPopupDialogs[ADDON_NAME.."_SESSION_INVITE"] = {
  text = "",
  button1 = ACCEPT,
  button2 = CANCEL,
  OnAccept = function(self)
    SendAddonMessage(ADDON_MSG_PREFIX, "session_accept", "WHISPER", inviteName);
    sessionStart(inviteName);
    inviteName = nil;
    myForfeit = false;
  end,
  OnCancel = function(self)
    SendAddonMessage(ADDON_MSG_PREFIX, "session_declined", "WHISPER", inviteName);
    inviteName = nil;
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
}

local function sessionEnd()
  queueingWith = nil;
  inQueueIndicator:Hide()
  petLevelIndicator:Hide()
  inQueueIndicator:SetBackdropColor(0.5, 0.5, 0.5, 0.90);
end

local onUpdate_frame = CreateFrame("frame");
onUpdate_frame:SetScript("OnUpdate", function()
  if queueingWith and GetTime()-lastPetLevelCheck > 1 then
    lastPetLevelCheck = GetTime();
    petLevelCheck();
  end
end)

SLASH_PBWT1 = "/pbwt";
local function slashParse(msg, editbox)
  if msg == "end" then
    if queueingWith then
      SendAddonMessage(ADDON_MSG_PREFIX, "session_end", "WHISPER", queueingWith);
      sessionEnd();
      debug("You have ended your current session.")
    else
      debug("You must be in a session to do that.")
    end
  elseif msg ~= "" then
    if queueingWith then
      debug("You must first end your current session with " .. queueingWith .. " using /pbwt end.")
    else
      SendAddonMessage(ADDON_MSG_PREFIX, "session_invite", "WHISPER", msg);
      debug("Sending invite to "..msg.."...")
    end
  end
end
SlashCmdList["PBWT"] = slashParse;

local frame, events = CreateFrame("Frame"), {}
function events:PET_BATTLE_OPENING_START()
  debug("PET_BATTLE_OPENING_START", 1)
  if myForfeit then
    button:Show()
  end
end
function events:PET_BATTLE_CLOSE()
  debug("PET_BATTLE_CLOSE", 1)
  button:Hide()
end
function events:PET_BATTLE_QUEUE_PROPOSE_MATCH()
  debug("PET_BATTLE_QUEUE_PROPOSE_MATCH", 1);
  if queueingWith then
    queueIndicator:SetScript("OnUpdate", indicator_onUpdate)
    SendAddonMessage(ADDON_MSG_PREFIX, "queue_pop", "WHISPER", queueingWith);
    selfQueueTime = GetTime();
  end
end
function events:PET_BATTLE_QUEUE_PROPOSAL_DECLINED()
  if queueingWith then
    queueIndicator:SetScript("OnUpdate", nil)
    selfQueueTime = nil;
    partnerQueueTime = nil;
  end
end
function events:PET_BATTLE_QUEUE_PROPOSAL_ACCEPTED()
  if queueingWith then
    queueIndicator:SetScript("OnUpdate", nil)
    selfQueueTime = nil;
    partnerQueueTime = nil;
  end
end
function events:PET_BATTLE_QUEUE_STATUS(...)
  debug("PET_BATTLE_QUEUE_STATUS", 1)
  if queueingWith then
    updateQueueStatus();
  end
end
function events:PET_BATTLE_ABILITY_CHANGED()
  debug("PET_BATTLE_ABILITY_CHANGED", 1);
end
function events:ADDON_LOADED(name)
  if PetJournal and not inQueueIndicator:GetPoint(1) then
    inQueueIndicator:SetPoint("BOTTOMLEFT", PetJournal, "BOTTOMRIGHT", 1, 0);
    inQueueIndicator:SetParent(PetJournal);
    petLevelIndicator:SetPoint("BOTTOM", inQueueIndicator, "TOP");
    petLevelIndicator:SetParent(PetJournal);
  end
end
function events:PLAYER_LOGOUT()
  sessionEnd();
end
function events:CHAT_MSG_ADDON(prefix, message, channel, sender)
  if prefix == ADDON_MSG_PREFIX then
    if queueingWith then
      if sender == queueingWith then
        if message == "queue_pop" then
          partnerQueueTime = GetTime();
        elseif message == "you_next" then
          myForfeit = true
        elseif message == "session_end" then
          debug(queuingWith .. " has terminated the session.");
	  sessionEnd()
        elseif message == "queued" then
	  inQueueIndicator:SetBackdropColor(0, 1, 0, 0.90)
        elseif message == "notQueued" then
          inQueueIndicator:SetBackdropColor(1, 0, 0, 0.90)
        elseif string.match(message, "pets:%d+/%d+/%d+") then
          opponentsPets = string.match(message, "pets:(%d+/?%d*/?%d*)")
	  if opponentsPets and opponentsPets ~= "" then
            debug("Your opponents pets' levels are "..opponentsPets..".")
          else
            debug("Your opponent has no pets.")
          end
	  petLevelIndicator_SetColor()
        end
      else
        if message == "session_invite" then
          SendAddonMessage(ADDON_MSG_PREFIX, "already_in_session", "WHISPER", sender)
        end
      end
    else
      if message == "session_invite" then
        if not queueingWith and not inviteName then
	  inviteName = sender;
	  StaticPopupDialogs[ADDON_NAME.."_SESSION_INVITE"]["text"] = sender .. " has invited you to a "..ADDON_NAME.." session."
	  StaticPopup_Show(ADDON_NAME.."_SESSION_INVITE")
	else
	  SendAddonMessage(ADDON_MSG_PREFIX, "already_in_session", "WHISPER", sender)
	end
      elseif message == "session_accept" then
        sessionStart(sender)
        debug("You have started a session with " .. queueingWith .. ".")
        myForfeit = true;
      elseif message == "already_in_session" then
        debug(sender.." is already in a session.")
      elseif message == "session_declined" then
        debug(sender.." declined your invitation.")
      end
    end
  end
end
frame:SetScript("OnEvent", function(self, event, ...)
  events[event](self, ...) -- call one of the functions above
end)
for k, v in pairs(events) do
  frame:RegisterEvent(k) -- Register all events for which handlers have been defined
end
