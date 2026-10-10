local fire, tick, finishScan, test, eq = H.fire, H.tick, H.finishScan, H.test, H.eq
local item, itemMsg, S, M = H.item, H.itemMsg, H.S, H.M

test("E1 stuck SPELLCAST_START (stop event lost) must self-heal", function()
  fire("SPELLCAST_START")           -- cast begins ...
  -- ... stop/fail event is never delivered (lag, addon conflict, UI reload edge)
  tick(60)                          -- a minute passes, nothing is casting
  fire("UNIT_DIED", "0xAAA"); tick(1.0)
  eq(M.calls, 1, "looting still blocked by stale cast flag")
end)

test("E2 real long channel (bandage) is NOT interrupted by watchdog", function()
  fire("SPELLCAST_CHANNEL_START"); M.channel = "Heavy Linen Bandage"
  tick(8); fire("UNIT_DIED", "0xAAA"); tick(1.0)
  eq(M.calls, 0, "must not loot during a real channel")
  M.channel = nil; fire("SPELLCAST_CHANNEL_STOP"); tick(0.6); eq(M.calls, 1)
end)

test("E3a stuck PLAYER_CONTROL_LOST, no HasFullControl API: heals after 90s", function()
  fire("PLAYER_CONTROL_LOST")
  tick(60); fire("UNIT_DIED", "0xAAA"); tick(1.0); eq(M.calls, 0, "still blocked at 60s (conservative)")
  tick(40); fire("UNIT_DIED", "0xBBB"); tick(1.0); eq(M.calls, 1, "healed after 90s")
end)

test("E3b lost CONTROL_GAINED with HasFullControl()=true heals quickly", function()
  HasFullControl = function() return true end
  fire("PLAYER_CONTROL_LOST"); tick(3)
  fire("UNIT_DIED", "0xAAA"); tick(1.0); HasFullControl = nil
  eq(M.calls, 1)
end)

test("E3c genuinely stunned player (HasFullControl=false) stays blocked", function()
  HasFullControl = function() return false end
  fire("PLAYER_CONTROL_LOST"); tick(20)
  fire("UNIT_DIED", "0xAAA"); tick(1.0); HasFullControl = nil
  eq(M.calls, 0, "must not loot while stunned/feared")
end)

test("E7 cast flag younger than 30s is never expired", function()
  fire("SPELLCAST_START"); tick(10)
  fire("UNIT_DIED", "0xAAA"); tick(1.0); eq(M.calls, 0)
end)

test("E8 cast flag with a real CASTING api still blocks after 40s", function()
  fire("SPELLCAST_START"); M.casting = "Hearthstone"; tick(40)
  fire("UNIT_DIED", "0xAAA"); tick(1.0); M.casting = nil
  eq(M.calls, 0)
end)

test("E4 death while dead, then rez: pending request serviced without needing a stop", function()
  AutoAreaLootDB.lootOnStop = false
  M.dead = true; fire("UNIT_DIED", "0xAAA"); tick(1.0); eq(M.calls, 0)
  M.dead = false; fire("PLAYER_ALIVE"); tick(1.0)
  eq(M.calls, 1, "pending loot after resurrection")
end)

test("E5 disable then re-enable leaves no stale pending/captures", function()
  fire("UNIT_DIED", "0xAAA"); tick(0.4)
  finishScan({ { guid = "0xAAA", coin = 0, items = { item(7, 1) } } })
  AutoAreaLootDB.enabled = false; H.AAL.state.pendingCaptures = H.AAL.state.pendingCaptures
  SlashCmdList["AUTOAREA_LOOT"]("off"); SlashCmdList["AUTOAREA_LOOT"]("on")
  eq(S.pendingLootReason, nil)
end)

test("E6 slash: help / clear / status do not error", function()
  SlashCmdList["AUTOAREA_LOOT"]("status"); SlashCmdList["AUTOAREA_LOOT"]("help")
  SlashCmdList["AUTOAREA_LOOT"]("clear")
end)

test("E9 /aal death|stop|combat on|off toggles the setting", function()
  SlashCmdList["AUTOAREA_LOOT"]("death off"); eq(AutoAreaLootDB.lootOnDeath, false)
  SlashCmdList["AUTOAREA_LOOT"]("death on");  eq(AutoAreaLootDB.lootOnDeath, true)
  SlashCmdList["AUTOAREA_LOOT"]("stop off");  eq(AutoAreaLootDB.lootOnStop, false)
  SlashCmdList["AUTOAREA_LOOT"]("combat off"); eq(AutoAreaLootDB.lootInCombat, false)
  SlashCmdList["AUTOAREA_LOOT"]("death off"); fire("UNIT_DIED", "0xAAA"); tick(1.0)
  eq(M.calls, 0, "toggle actually changes behaviour")
end)

test("E10 /aal clear empties the loot log data", function()
  fire("UNIT_DIED", "0xAAA"); tick(0.4)
  finishScan({ { guid = "0xAAA", coin = 0, items = { item(9, 1) } } })
  fire("CHAT_MSG_LOOT", itemMsg(9)); eq(S.lootEventCount, 1)
  SlashCmdList["AUTOAREA_LOOT"]("clear"); eq(S.lootEventCount, 0); eq(S.lootMoney, 0)
end)

test("E11 /aal help and status print to chat, unknown word still opens panel", function()
  local before = #H.chat()
  SlashCmdList["AUTOAREA_LOOT"]("help"); SlashCmdList["AUTOAREA_LOOT"]("status")
  assert(#H.chat() > before + 3, "help/status produced output")
  SlashCmdList["AUTOAREA_LOOT"]("")   -- opens settings panel, no error
end)

test("E12 /aal on|off still works (regression)", function()
  SlashCmdList["AUTOAREA_LOOT"]("off"); eq(AutoAreaLootDB.enabled, false)
  SlashCmdList["AUTOAREA_LOOT"]("on");  eq(AutoAreaLootDB.enabled, true)
end)
