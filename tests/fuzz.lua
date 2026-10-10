local fire, tick, finishScan, test = H.fire, H.tick, H.finishScan, H.test
local item, itemMsg, S, M = H.item, H.itemMsg, H.S, H.M
local out = {}
local VIOL = 0
local SPEED = os.getenv("SPEED")
local SEEDS = tonumber(os.getenv("SEEDS") or "300")
for seed = 1, SEEDS do
  test("fuzz " .. seed, function()
    if SPEED then SlashCmdList["AUTOAREA_LOOT"]("speed " .. SPEED) end
    math.randomseed(seed)
    local t0 = H.getClock()
    local spell = false
    local guids = { "0xA1", "0xA2", "0xA3", "0xFAR" }
    M.dist["0xFAR"] = 40
    for step = 1, 90 do
      if H.getClock() - t0 > 25 then break end
      local r = math.random(1, 16)
      if r <= 3 then fire("UNIT_DIED", guids[math.random(1, 4)])
      elseif r == 4 then M.speed = 7
      elseif r == 5 or r == 6 then M.speed = 0
      elseif r == 7 then fire("SPELLCAST_START"); spell = true
      elseif r == 8 then fire("SPELLCAST_STOP"); spell = false
      elseif r == 9 then fire("LOOT_OPENED")
      elseif r == 10 then fire("LOOT_CLOSED")
      elseif r == 11 then M.combat = not M.combat; if not M.combat then fire("PLAYER_REGEN_ENABLED") end
      elseif r == 12 then
        if M.scan then
          local id = math.random(1, 4)
          finishScan({ { guid = "0xC" .. math.random(1, 3), coin = math.random(0, 1) * 100, items = { item(id, math.random(1, 3)) } } })
        end
      elseif r == 13 then fire("CHAT_MSG_LOOT", itemMsg(math.random(1, 4)))
      elseif r == 14 then M.money = M.money + 100; fire("PLAYER_MONEY")
      elseif r == 15 then AutoAreaLootDB.lootInCombat = not AutoAreaLootDB.lootInCombat
      else AutoAreaLootDB.lootOnStop = not AutoAreaLootDB.lootOnStop end
      tick(math.random(1, 12) * 0.05)
      VIOL = VIOL + (M.violations or 0); M.violations = 0
      out[#out + 1] = string.format("%d:%d calls=%d ev=%d money=%d pend=%s walk=%s", seed, step, M.calls,
        S.lootEventCount, S.lootMoney, tostring(S.pendingLootReason), tostring(S.lootWalkActive))
    end
  end)
end
for _, l in ipairs(out) do print(l) end
print('TOTAL invariant violations: ' .. VIOL)
