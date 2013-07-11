local AceGUI = LibStub("AceGUI-3.0");

local ADDON_NAME = "PetBattleWT";

local ADDON_COLOR = "FFF9CC30";
local ADDON_CHAT_HEADER  = "|c" .. ADDON_COLOR .. ADDON_NAME .. ":|r ";
local ADDON_MSG_PREFIX = ADDON_NAME;

local debugOn = 1;

local queueingWith;
local myForfeit = true;
local inviteName = "";
local partnerQueueTime;
local selfQueueTime;

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
end)

local queueIndicator = CreateFrame("Frame", "PetBattleWT_QueueIndicator", UIParent)
queueIndicator:SetPoint("TOP", PetBattleQueueReadyFrame, "BOTTOM");
queueIndicator:SetWidth(PetBattleQueueReadyFrame:GetWidth())
queueIndicator:SetHeight(40)

StaticPopupDialogs[ADDON_NAME.."_SESSION_INVITE"] = {
  text = inviteName .. " has invited you to a "..ADDON_NAME.." session.",
  button1 = ACCEPT,
  button2 = CANCEL,
  hasEditBox = true,
  OnAccept = function(self)
    SendAddonMessage(ADDON_MSG_PREFIX, "session_accept", "WHISPER", inviteName);
    queueingWith = inviteName;
    inviteName = "";
    myForfeit = false;
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
}

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

local function onUpdate(self, elapsed)
  if not partnerQueueTime then
    if GetTime() - selfQueueTime <= 3 then
      queueIndicator:SetBackdropColor(1, 1, 0, 0.5)
    else
      queueIndicator:SetBackdropColor(1, 0, 0, 0.5)
    end
  else
    if math.abs(selfQueueTime - partnerQueueTime) <= 3 then
      queueIndicator:SetBackdropColor(0, 1, 0, 0.5)
    else
      queueIndicator:SetBackdropColor(1, 0, 0, 0.5)
    end
  end
end

local ouframe = CreateFrame("frame")

SLASH_PBWT1 = "/pbwt";
local function slashParse(msg, editbox)
  if msg == "end" then
    queueingWith = nil;
  elseif msg ~= "" then
    if queueingWith then
      debug("You must first end your current session with " .. queueingWith .. " using /pbwt end.")
    else
      SendAddonMessage(ADDON_MSG_PREFIX, "session_invite", "WHISPER", msg);
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
  myForfeit = not myForfeit;
end
function events:PET_BATTLE_CLOSE()
  debug("PET_BATTLE_CLOSE", 1)
  button:Hide();
end
function events:PET_BATTLE_QUEUE_PROPOSE_MATCH()
  if queueingWith then
    ouframe:SetScript("OnUpdate", onUpdate)
    queueIndicator:Show();
    SendAddonMessage(ADDON_MSG_PREFIX, "queue_pop", "WHISPER", queueingWith);
    selfQueueTime = GetTime();
  end
end
function events:PET_BATTLE_QUEUE_PROPOSAL_DECLINED()
  if queueingWith then
    ouframe:SetScript("OnUpdate", nil)
    queueIndicator:Hide();
    selfQueueTime = nil;
    partnerQueueTime = nil;
  end
end
function events:PET_BATTLE_QUEUE_PROPOSAL_ACCEPTED()
  if queueingWith then
    ouframe:SetScript("OnUpdate", nil)
    queueIndicator:Hide();
    selfQueueTime = nil;
    partnerQueueTime = nil;
  end
end
function events:CHAT_MSG_ADDON(prefix, message, channel, sender)
  if prefix == ADDON_MSG_PREFIX then
    if queueingWith then
      if message == "queue_pop" then
        partnerQueueTime = GetTime();
      end
    else
      if message == "session_invite" then
        inviteName = sender;
        StaticPopup_Show(ADDON_NAME.."_SESSION_INVITE")
      elseif message == "session_accept" then
        queueingWith = sender;
        debug("You have started a session with " .. queueingWith .. ".")
        myForfeit = true;
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