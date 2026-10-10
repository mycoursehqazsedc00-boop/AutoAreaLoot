-- Mock WoW 1.12 + ClassicAPI environment for AutoAreaLoot logic tests (runs on texlua / Lua 5.3)
local path = arg[1]
local verbose = arg[2] == "-v"

table.getn = table.getn or function(t) return #t end
unpack = unpack or table.unpack
date = os.date

local clock = 100.0
local timers = {}
local frames = {}
local chat = {}

local NUM = { GetWidth=100, GetHeight=100, GetLeft=0, GetTop=0, GetRight=100, GetBottom=0, GetScale=1,
  GetFrameLevel=1, GetNumChildren=0, GetVerticalScroll=0, GetVerticalScrollRange=0, GetValue=0,
  GetStringWidth=50, GetStringHeight=10, GetHeight_=10 }
local function newFrame(name)
  local f = { _scripts = {}, _events = {}, _name = name, _shown = false }
  setmetatable(f, { __index = function(t, k)
    if NUM[k] then return function() return NUM[k] end end
    if k == "SetScript" then return function(self, n, fn) self._scripts[n] = fn end end
    if k == "GetScript" then return function(self, n) return self._scripts[n] end end
    if k == "RegisterEvent" then return function(self, e) self._events[e] = true end end
    if k == "UnregisterEvent" then return function(self, e) self._events[e] = nil end end
    if k == "IsShown" or k == "IsVisible" then return function(self) return self._shown end end
    if k == "Show" then return function(self) self._shown = true end end
    if k == "Hide" then return function(self) self._shown = false end end
    if k == "CreateTexture" or k == "CreateFontString" then return function(self) return newFrame() end end
    if k == "GetText" then return function(self) return self._text or "" end end
    if k == "SetText" then return function(self, s) self._text = s end end
    return function(self) return self end
  end })
  frames[#frames+1] = f
  return f
end
CreateFrame = function(kind, name) local f = newFrame(name); if name then _G[name] = f end; return f end
UIParent = newFrame("UIParent")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) chat[#chat+1] = m end }
GetTime = function() return clock end
C_Timer = { After = function(d, fn) timers[#timers+1] = { at = clock + d, fn = fn, seq = #timers } end }
C_EventUtils = { IsEventValid = function() return true end }
SlashCmdList = {}
LOOT_ITEM_SELF = "You receive loot: %s."
LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
GetCoinTextureString = function(n) return n .. "c" end

M = { speed = 0, combat = false, dead = false, casting = nil, channel = nil, money = 1000,
      px = 0, py = 0, pz = 0, dist = {}, scan = false, calls = 0, results = {}, callTimes = {} }
GetUnitSpeed = function() return M.speed end
UnitAffectingCombat = function() return M.combat end
UnitIsDeadOrGhost = function() return M.dead end
UnitCastingInfo = function() return M.casting end
UnitChannelInfo = function() return M.channel end
UnitPosition = function() return M.px, M.py, M.pz end
UnitDistanceSquared = function(g) local d = M.dist[g]; if d then return d*d, true end; return 0, false end
GetNetStats = function() return 0, 0, 50 end
GetMoney = function() return M.money end
GetGameTime = function() return 12, 0 end
CloseLoot = function() end
C_Loot = {
  LootAllCorpses = function() if M.scan then return false end; if M.speed > 0 or M.dead or M.casting or M.channel or (H and H.S and (H.S.manualLootOpen or H.S.playerSpellcastActive)) then M.violations = (M.violations or 0) + 1 end; M.scan = true; M.calls = M.calls + 1; M.callTimes[#M.callTimes+1] = clock; return true end,
  IsScanInProgress = function() return M.scan end,
  GetLastScanResults = function() return M.results end,
}

-- load addon with test hook appended (chunk-level locals visible at end of chunk)
local fh = assert(io.open(path, "rb")); local src = fh:read("a"); fh:close()
src = src .. "\n__AAL = { state = state, eventFrame = eventFrame, ShouldAcceptDeathTrigger = ShouldAcceptDeathTrigger }\n"
local chunk = assert(load(src, "@" .. path))
chunk()

local ef = __AAL.eventFrame
local S = __AAL.state
local function fire(ev, a1, a2)
  _G.event = ev; _G.arg1 = a1; _G.arg2 = a2; _G.this = ef
  ef._scripts.OnEvent()
end
local function runTimers()
  local progressed = true
  while progressed do
    progressed = false
    table.sort(timers, function(a, b) if a.at ~= b.at then return a.at < b.at end return a.seq < b.seq end)
    for i, t in ipairs(timers) do
      if t.at <= clock then table.remove(timers, i); t.fn(); progressed = true; break end
    end
  end
end
local function tick(dt)
  local steps = math.max(1, math.floor(dt / 0.05 + 0.5))
  local step = dt / steps
  for _ = 1, steps do
    clock = clock + step
    runTimers()
    _G.arg1 = step; _G.this = ef
    if ef._scripts.OnUpdate then ef._scripts.OnUpdate() end
  end
end
local function finishScan(results)
  M.results = results or {}
  M.scan = false
  fire("LOOT_SCAN_COMPLETED")
end
local function reset()
  -- return to a clean idle state without reloading the addon
  fire("PLAYER_LEAVING_WORLD"); M.scan = false; M.calls = 0; M.callTimes = {}; M.results = {}
  M.speed = 0; M.combat = false; M.dead = false; M.casting = nil; M.channel = nil; M.dist = {}; M.violations = 0
  timers = {}; chat = {}
  AutoAreaLootDB.enabled = true; AutoAreaLootDB.lootOnDeath = true; AutoAreaLootDB.lootOnStop = true; AutoAreaLootDB.lootInCombat = true
  S.lootEvents = {}; S.lootRecords = {}; S.lootRecordByKey = {}; S.lootMoney = 0; S.lootEventCount = 0
  clock = clock + 100 -- also lets any settle window lapse
  fire("PLAYER_ENTERING_WORLD"); tick(0.5)
end

fire("ADDON_LOADED", "AutoAreaLoot")
tick(0.5)

-- ---------------------------------------------------------------- test runner
local results, failed = {}, 0
local function test(name, fn)
  reset()
  local ok, err = pcall(fn)
  if not ok then failed = failed + 1 end
  results[#results+1] = (ok and "PASS " or "FAIL ") .. name .. (ok and "" or ("  -> " .. tostring(err)))
end
local function eq(a, b, msg) if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. " got " .. tostring(a), 2) end end
local function item(id, n) return { itemID = id, count = n or 1, link = "|cffffffff|Hitem:" .. id .. ":0:0:0|h[Item" .. id .. "]|h|r" } end
local function itemMsg(id) return "You receive loot: |cffffffff|Hitem:" .. id .. ":0:0:0|h[Item" .. id .. "]|h|r." end

-- scenario file is loaded after the environment so it can use these helpers
H = { fire = fire, tick = tick, finishScan = finishScan, test = test, eq = eq, item = item, itemMsg = itemMsg,
      S = S, M = M, chat = function() return chat end, AAL = __AAL, ef = ef, setClock = function(v) clock = v end,
      getClock = function() return clock end }
dofile(arg[3] or "scenarios.lua")

for _, r in ipairs(results) do if verbose or r:sub(1,4) == "FAIL" then print(r) end end
print(string.format("%s: %d tests, %d failed", path, #results, failed))
os.exit(failed == 0 and 0 or 1)
