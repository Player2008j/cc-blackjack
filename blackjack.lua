-- blackjack.lua — CC:Tweaked single-player Blackjack met spurs en monitor
-- Gebruik een chest naast de computer voor spurs (bijv. gouden ingots)

-----------------------------
-- Utilities & Persistence  --
-----------------------------
local START_SPURS = 500
local CHEST_SIDE = "right" -- pas aan naar waar je chest staat

-- Monitor detectie
local mon = peripheral.find("monitor")
if mon then
  mon.setTextScale(0.5)
  term.redirect(mon)
end

local chest = peripheral.wrap(CHEST_SIDE)

local function countSpurs()
  local total = 0
  for slot=1,chest.size() do
    local stack = chest.getItemDetail(slot)
    if stack and stack.name == "minecraft:gold_ingot" then
      total = total + stack.count
    end
  end
  return total
end

local function takeSpurs(amount)
  for slot=1,chest.size() do
    local stack = chest.getItemDetail(slot)
    if stack and stack.name == "minecraft:gold_ingot" then
      local toTake = math.min(stack.count, amount)
      chest.pushItems(peripheral.getName(peripheral.find("computer")), slot, toTake)
      amount = amount - toTake
      if amount <= 0 then return true end
    end
  end
  return false
end

local function giveSpurs(amount)
  -- geeft spurs terug in de chest
  -- simpel: laat de speler zelf item toevoegen of gebruik turtle peripheral
end

-----------------------------
-- Card & Deck             --
-----------------------------
local SUITS = {"♠","♥","♦","♣"}
local RANKS = {"A","2","3","4","5","6","7","8","9","10","J","Q","K"}

local function newDeck(numDecks)
  numDecks = numDecks or 4
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
  math.randomseed(os.time())
  for i = #deck, 2, -1 do
    local j = math.random(1,i)
    deck[i], deck[j] = deck[j], deck[i]
  end
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
-- Game Flow               --
-----------------------------
local function askBet(spurs)
  while true do
    local s = prompt("Inzet (1-"..spurs..") spurs: ")
    local n = tonumber(s)
    if n and n >= 1 and n <= spurs then return math.floor(n) end
    center(h, "Ongeldige inzet.")
    sleep(0.8)
  end
end

local function dealerPlay(deck, dealer)
  while handValue(dealer) < 17 do
    dealer[#dealer+1] = table.remove(deck)
  end
end

local function settle(player, dealer, bet)
  local pv, dv = handValue(player), handValue(dealer)
  if pv > 21 then return -bet, "Bust! Verliest "..bet.." spurs"
  elseif dv > 21 then return bet, "Dealer bust! Jij wint "..bet.." spurs"
  elseif isBlackjack(player) and not isBlackjack(dealer) then
    local win = math.floor(bet * 3/2)
    return win, "Blackjack! Payout 3:2 ("..win.." spurs)"
  elseif isBlackjack(dealer) and not isBlackjack(player) then
    return -bet, "Dealer blackjack. Verliest "..bet.." spurs"
  elseif pv > dv then return bet, "Je wint "..bet.." spurs"
  elseif pv < dv then return -bet, "Je verliest "..bet.." spurs"
  else return 0, "Push. Inzet terug"
  end
end

local function drawHands(player, dealer, hideDealerHole, spurs, bet)
  clr()
  center(1, "🂡  Blackjack", useColor and colors.yellow or nil)
  hr(2)
  term.setCursorPos(2,4)
  write("Dealer:")
  term.setCursorPos(2,5)
  if hideDealerHole then
    local shown = dealer[1] and dealer[1].rank..dealer[1].suit or "?"
    write("["..shown.."] [??]")
  else
    local s = {}
    for i,c in ipairs(dealer) do s[i] = "["..c.rank..c.suit.."]" end
    write(table.concat(s, " ") .. "  ("..handValue(dealer)..")")
  end
  term.setCursorPos(2,8)
  write("Speler:")
  term.setCursorPos(2,9)
  local p = {}
  for i,c in ipairs(player) do p[i] = "["..c.rank..c.suit.."]" end
  write(table.concat(p, " ") .. "  ("..handValue(player)..")")
  hr(h-3)
  term.setCursorPos(2,h-2)
  term.clearLine()
  write("Spurs: "..spurs.."   Inzet: "..(bet or 0))
end

-----------------------------
-- Main Loop               --
-----------------------------
local function main()
  math.randomseed(os.time())
  local shoe = newDeck()
  shuffle(shoe)

  while true do
    local spurs = countSpurs()
    drawHands({}, {}, true, spurs, 0)
    center(4, "Welkom bij Blackjack met spurs!", useColor and colors.lime)
    center(6, "Besturing: H=Hit  S=Stand  D=Double")
    center(7, "Inzet gaat via tekstinvoer onderaan")
    center(9, "(N)ieuwe hand   (Q)uit")

    local e, key = os.pullEvent("key")
    local k = keys.getName(key)

    if k == "n" then
      if spurs <= 0 then
        center(h-1, "Geen spurs! Voeg meer toe in de chest.")
        pause()
      else
        local bet = askBet(spurs)
        if not takeSpurs(bet) then
          center(h-1, "Onvoldoende spurs in chest!")
          pause()
        else
          -- Start hand (zelfde als voorheen, hier eenvoudig)
          local player, dealer = {table.remove(shoe), table.remove(shoe)}, {table.remove(shoe), table.remove(shoe)}
          drawHands(player, dealer, true, spurs-bet, bet)
          -- hier kun je hit/stand logic toevoegen...
          local delta, msg = settle(player, dealer, bet)
          if delta > 0 then giveSpurs(delta) end
          center(h-1, msg)
          pause("Druk op een toets voor volgende hand…")
        end
      end
    elseif k == "q" then break end
  end

  clr()
  center(math.floor(h/2), "Bedankt voor het spelen!")
  term.setCursorPos(1, h)
end

main()
