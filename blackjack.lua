-- blackjack.lua — CC:Tweaked single‑player Blackjack
-- Terminal game vs. dealer with simple betting and persistent balance.
-- Drop this file in your computer and run:  blackjack
-- Made for CC:Tweaked (works in CraftOS terminal / advanced monitors not required).

-----------------------------
-- Utilities & Persistence  --
-----------------------------
local SAVE_FILE = "bj_balance.dat"
local START_BANKROLL = 500

local function seedRng()
  local ok, t = pcall(os.epoch, "utc")
  if not ok then t = os.clock() * 1000 end
  math.randomseed(t)
  -- throw away a few to decorrelate
  for _=1,5 do math.random() end
end

local function saveBalance(n)
  local f = fs.open(SAVE_FILE, "w")
  if f then f.writeLine(tostring(n)) f.close() end
end

local function loadBalance()
  if not fs.exists(SAVE_FILE) then return START_BANKROLL end
  local f = fs.open(SAVE_FILE, "r")
  if not f then return START_BANKROLL end
  local s = f.readLine() or tostring(START_BANKROLL)
  f.close()
  local n = tonumber(s)
  if not n or n < 0 then return START_BANKROLL end
  return math.floor(n)
end

-----------------------------
-- UI Helpers              --
-----------------------------
local w,h = term.getSize()
local useColor = term.isColor()

local function clr()
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1,1)
end

local function center(y, text, textColor)
  local x = math.floor((w - #text) / 2) + 1
  term.setCursorPos(x, y)
  if textColor and useColor then term.setTextColor(textColor) end
  write(text)
  if textColor and useColor then term.setTextColor(colors.white) end
end

local function hr(y)
  term.setCursorPos(1,y)
  term.clearLine()
  write(string.rep("-", w))
end

local function prompt(inputLabel)
  term.setCursorPos(2, h-1)
  term.clearLine()
  term.write(inputLabel)
  return read()
end

local function pause(msg)
  center(h, msg or "Druk op een toets om verder te gaan...")
  os.pullEvent("key")
end

-----------------------------
-- Cards & Deck            --
-----------------------------
local SUITS = {"♠","♥","♦","♣"}
local RANKS = {"A","2","3","4","5","6","7","8","9","10","J","Q","K"}

local function newDeck(numDecks)
  numDecks = numDecks or 4 -- shoe of 4 decks
  local d = {}
  for _=1,numDecks do
    for _,s in ipairs(SUITS) do
      for _,r in ipairs(RANKS) do
        d[#d+1] = {rank=r, suit=s}
      end
    end
  end
  return d
end

local function shuffle(deck)
  for i = #deck, 2, -1 do
    local j = math.random(1,i)
    deck[i], deck[j] = deck[j], deck[i]
  end
end

local function cardString(c)
  return c.rank .. c.suit
end

local function handValue(hand)
  local total, aces = 0, 0
  for _,c in ipairs(hand) do
    if c.rank == "A" then total = total + 11; aces = aces + 1
    elseif c.rank == "K" or c.rank == "Q" or c.rank == "J" then total = total + 10
    else total = total + tonumber(c.rank)
    end
  end
  while total > 21 and aces > 0 do
    total = total - 10
    aces = aces - 1
  end
  return total
end

local function isBlackjack(hand)
  return #hand == 2 and handValue(hand) == 21
end

-----------------------------
-- Rendering               --
-----------------------------
local function drawHands(player, dealer, hideDealerHole, bankroll, bet)
  clr()
  center(1, "🂡  Blackjack", useColor and colors.yellow or nil)
  hr(2)

  term.setCursorPos(2,4)
  write("Dealer:")
  term.setCursorPos(2,5)
  if hideDealerHole then
    local shown = dealer[1] and cardString(dealer[1]) or "?"
    write("[".. shown .. "] [??]")
  else
    local s = {}
    for i,c in ipairs(dealer) do s[i] = "["..cardString(c).."]" end
    write(table.concat(s, " ") .. "  ("..handValue(dealer)..")")
  end

  term.setCursorPos(2,8)
  write("Speler:")
  term.setCursorPos(2,9)
  local p = {}
  for i,c in ipairs(player) do p[i] = "["..cardString(c).."]" end
  write(table.concat(p, " ") .. "  ("..handValue(player)..")")

  hr(h-3)
  term.setCursorPos(2,h-2)
  term.clearLine()
  write("Bankroll: "..bankroll.."   Inzet: "..(bet or 0))
end

-----------------------------
-- Game Flow               --
-----------------------------
local function askBet(bankroll)
  while true do
    local s = prompt("Inzet (1-"..bankroll.."): ")
    local n = tonumber(s)
    if n and n >= 1 and n <= bankroll then return math.floor(n) end
    center(h, "Ongeldige inzet.")
    sleep(0.8)
  end
end

local function dealerPlay(deck, dealer)
  -- Dealer hits on 16, stands on 17+ (including soft 17 = stand)
  while handValue(dealer) < 17 do
    dealer[#dealer+1] = table.remove(deck)
  end
end

local function settle(player, dealer, bet)
  local pv, dv = handValue(player), handValue(dealer)
  if pv > 21 then return -bet, "Bust! Verliest "..bet
  elseif dv > 21 then return bet, "Dealer bust! Jij wint "..bet
  elseif isBlackjack(player) and not isBlackjack(dealer) then
    local win = math.floor(bet * 3/2)
    return win, "Blackjack! Payout 3:2 ("..win..")"
  elseif isBlackjack(dealer) and not isBlackjack(player) then
    return -bet, "Dealer blackjack. Verliest "..bet
  elseif pv > dv then return bet, "Je wint "..bet
  elseif pv < dv then return -bet, "Je verliest "..bet
  else return 0, "Push. Inzet terug"
  end
end

local function runHand(shoe, bankroll)
  if #shoe < 20 then
    shoe = newDeck()
    shuffle(shoe)
  end
  local bet = askBet(bankroll)
  local player, dealer = {}, {}

  -- Deal
  player[#player+1] = table.remove(shoe)
  dealer[#dealer+1] = table.remove(shoe)
  player[#player+1] = table.remove(shoe)
  dealer[#dealer+1] = table.remove(shoe)

  -- Player turn
  while true do
    drawHands(player, dealer, true, bankroll, bet)

    -- Immediate blackjack check
    if isBlackjack(player) or handValue(player) >= 21 then break end

    center(h-1, "(H)it  (S)tand  (D)ouble")
    local e, key = os.pullEvent("key")
    local k = keys.getName(key)
    if k == "h" then
      player[#player+1] = table.remove(shoe)
    elseif k == "d" then
      if bankroll >= bet*2 then
        bet = bet * 2
        player[#player+1] = table.remove(shoe)
        break
      else
        center(h, "Onvoldoende bankroll voor te verdubbelen!")
        sleep(0.9)
      end
    elseif k == "s" then
      break
    end
  end

  -- Dealer turn
  drawHands(player, dealer, false, bankroll, bet)
  if handValue(player) <= 21 then
    sleep(0.6)
    dealerPlay(shoe, dealer)
  end

  drawHands(player, dealer, false, bankroll, bet)
  local delta, msg = settle(player, dealer, bet)
  center(h-1, msg)
  pause("Druk op een toets voor volgende hand…")

  return shoe, bankroll + delta
end

-----------------------------
-- Main Loop               --
-----------------------------
local function main()
  seedRng()
  local bankroll = loadBalance()
  local shoe = newDeck()
  shuffle(shoe)

  while true do
    drawHands({}, {}, true, bankroll, 0)
    center(4, "Welkom bij Blackjack!", useColor and colors.lime)
    center(6, "Besturing: H=Hit  S=Stand  D=Double")
    center(7, "Inzet gaat via tekstinvoer onderaan")
    center(9, "(N)ieuwe hand   (R)eset saldo   (Q)uit")

    local e, key = os.pullEvent("key")
    local k = keys.getName(key)

    if k == "n" then
      if bankroll <= 0 then
        center(h-1, "Je bent blut. Reset of sluit af.")
        pause()
      else
        shoe, bankroll = runHand(shoe, bankroll)
        saveBalance(bankroll)
      end
    elseif k == "r" then
      bankroll = START_BANKROLL
      saveBalance(bankroll)
      center(h-1, "Saldo gereset naar "..START_BANKROLL)
      sleep(0.9)
    elseif k == "q" then
      break
    end
  end

  clr()
  center(math.floor(h/2), "Bedankt voor het spelen! Eindsaldo: "..bankroll)
  term.setCursorPos(1, h)
end

main()
