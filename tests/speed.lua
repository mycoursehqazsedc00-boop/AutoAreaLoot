local fire, tick, finishScan, test, eq = H.fire, H.tick, H.finishScan, H.test, H.eq
local item, S, M = H.item, H.S, H.M
local function setSpeed(name) SlashCmdList["AUTOAREA_LOOT"]("speed " .. name) end
local function near(v, lo, hi, msg) if v < lo or v > hi then error((msg or "") .. string.format(" %.3f not in [%.2f, %.2f]", v, lo, hi), 2) end end

-- time from a death event to the scan call, per preset
local function deathToScan()
  local t0 = H.getClock(); fire("UNIT_DIED", "0xAAA")
  for _ = 1, 40 do tick(0.05); if M.calls > 0 then break end end
  return M.callTimes[1] - t0
end
test("SP1 normal preset == original timing (death -> scan ~0.25s)", function() setSpeed("normal"); near(deathToScan(), 0.25, 0.31) end)
test("SP2 fast preset: death -> scan ~0.10s", function() setSpeed("fast"); near(deathToScan(), 0.10, 0.16) end)
test("SP3 safe preset: death -> scan ~0.35s", function() setSpeed("safe"); near(deathToScan(), 0.35, 0.41) end)

-- time from stopping to the scan call
local function stopToScan()
  M.speed = 7; tick(0.3); M.speed = 0
  local t0 = H.getClock()
  for _ = 1, 40 do tick(0.05); if M.calls > 0 then break end end
  return M.callTimes[1] - t0
end
test("SP4 normal stop grace ~0.15s", function() AutoAreaLootDB.lootOnDeath = false; setSpeed("normal"); near(stopToScan(), 0.10, 0.25) end)
test("SP5 fast stop grace is shorter than normal", function() AutoAreaLootDB.lootOnDeath = false; setSpeed("fast"); near(stopToScan(), 0.0, 0.15) end)

-- back-to-back AoE: a death right after a successful scan must wait out the settle window
local function secondScanDelay()
  fire("UNIT_DIED", "0xA1"); tick(0.5)
  finishScan({ { guid = "0xA1", coin = 0, items = { item(1, 1) } } })
  local t0 = H.getClock(); fire("UNIT_DIED", "0xA2")
  for _ = 1, 60 do tick(0.05); if M.calls > 1 then break end end
  return M.callTimes[2] - t0
end
test("SP6 fast AoE follow-up is quicker than normal, safe slowest", function()
  setSpeed("fast");   local f = secondScanDelay()
  H.fire("PLAYER_LEAVING_WORLD"); M.scan = false; M.calls = 0; M.callTimes = {}; H.setClock(H.getClock() + 50); fire("PLAYER_ENTERING_WORLD"); tick(0.5)
  setSpeed("normal"); local n = secondScanDelay()
  H.fire("PLAYER_LEAVING_WORLD"); M.scan = false; M.calls = 0; M.callTimes = {}; H.setClock(H.getClock() + 50); fire("PLAYER_ENTERING_WORLD"); tick(0.5)
  setSpeed("safe");   local sf = secondScanDelay()
  assert(f < n and n < sf, string.format("fast %.2f < normal %.2f < safe %.2f", f, n, sf))
end)

test("SP7 /aal speed shows current, rejects unknown name (no change)", function()
  setSpeed("fast"); eq(AutoAreaLootDB.lootSpeed, "fast")
  SlashCmdList["AUTOAREA_LOOT"]("speed warp"); eq(AutoAreaLootDB.lootSpeed, "fast")
  SlashCmdList["AUTOAREA_LOOT"]("speed")  -- prints, no error
end)

test("SP8 corrupt saved speed falls back to normal on load", function()
  AutoAreaLootDB.lootSpeed = "bogus"; fire("ADDON_LOADED", "AutoAreaLoot")
  eq(AutoAreaLootDB.lootSpeed, "normal"); near(deathToScan(), 0.25, 0.31)
end)

test("SP9 settings-panel button cycles safe -> normal -> fast -> safe", function()
  local btn = AutoAreaLootConfigFrame.speedButton
  setSpeed("safe"); btn._scripts.OnClick(); eq(AutoAreaLootDB.lootSpeed, "normal")
  btn._scripts.OnClick(); eq(AutoAreaLootDB.lootSpeed, "fast")
  btn._scripts.OnClick(); eq(AutoAreaLootDB.lootSpeed, "safe")
  eq(btn.label._text, "Speed: Safe")
end)

test("SP10 fast preset never scans while moving/casting/dead/manual-loot (invariants)", function()
  setSpeed("fast")
  M.speed = 7; fire("UNIT_DIED", "0xAAA"); tick(0.5)
  fire("SPELLCAST_START"); M.casting = "x"; M.speed = 0; tick(0.5)
  M.casting = nil; fire("SPELLCAST_STOP"); fire("LOOT_OPENED"); tick(0.5)
  fire("LOOT_CLOSED"); tick(0.5)
  eq(M.violations or 0, 0, "violations")
end)
