local fire, tick, finishScan, test, eq = H.fire, H.tick, H.finishScan, H.test, H.eq
local item, itemMsg, S, M = H.item, H.itemMsg, H.S, H.M

test("S1 idle death -> one scan after ~0.25s, loot logged", function()
  fire("UNIT_DIED", "0xAAA")
  tick(0.1); eq(M.calls, 0, "too early")
  tick(0.3); eq(M.calls, 1, "scan started")
  finishScan({ { guid = "0xAAA", coin = 0, items = { item(2589, 1) } } })
  fire("CHAT_MSG_LOOT", itemMsg(2589))
  eq(S.lootEventCount, 1, "loot event logged")
end)

test("S2 death while moving is deferred until stop (+grace)", function()
  M.speed = 7; tick(0.2)
  fire("UNIT_DIED", "0xAAA")
  tick(0.5); eq(M.calls, 0, "no scan while moving")
  M.speed = 0; tick(0.1); eq(M.calls, 0, "still in stop grace")
  tick(0.6); eq(M.calls, 1, "scan after stop")
end)

test("S3 death during active walk queues exactly one follow-up", function()
  fire("UNIT_DIED", "0xAAA"); tick(0.4); eq(M.calls, 1)
  fire("UNIT_DIED", "0xBBB"); fire("UNIT_DIED", "0xCCC"); tick(0.3); eq(M.calls, 1, "no overlap")
  finishScan({}); tick(2.0)
  eq(M.calls, 2, "single follow-up")
  finishScan({}); tick(3.0); eq(M.calls, 2, "no extra")
end)

test("S4 manual loot window defers scan until closed", function()
  fire("LOOT_OPENED"); fire("UNIT_DIED", "0xAAA"); tick(1.0)
  eq(M.calls, 0, "deferred")
  fire("LOOT_CLOSED"); tick(0.6); eq(M.calls, 1, "serviced")
end)

test("S5 spellcast blocks loot until cast ends", function()
  fire("SPELLCAST_START"); fire("UNIT_DIED", "0xAAA"); tick(1.0); eq(M.calls, 0)
  fire("SPELLCAST_STOP"); tick(0.6); eq(M.calls, 1)
end)

test("S6 combat looting off defers until combat ends", function()
  AutoAreaLootDB.lootInCombat = false
  M.combat = true; fire("UNIT_DIED", "0xAAA"); tick(1.0); eq(M.calls, 0)
  M.combat = false; fire("PLAYER_REGEN_ENABLED"); tick(0.6); eq(M.calls, 1)
end)

test("S7 far-away death is ignored", function()
  M.dist["0xFAR"] = 30; fire("UNIT_DIED", "0xFAR"); tick(1.0); eq(M.calls, 0)
  M.dist["0xNEAR"] = 3; fire("UNIT_DIED", "0xNEAR"); tick(0.4); eq(M.calls, 1)
end)

test("S8 missed completion event recovers after timeout", function()
  fire("UNIT_DIED", "0xAAA"); tick(0.4); eq(M.calls, 1)
  M.scan = false          -- API went idle but the event was never delivered
  tick(7.0)
  fire("UNIT_DIED", "0xBBB"); tick(1.5); eq(M.calls, 2, "walk recovered, new scan allowed")
end)

test("S9 disabled addon never scans", function()
  H.fire("UNIT_DIED", "0xAAA")
  AutoAreaLootDB.enabled = false
  tick(1.0); eq(M.calls, 0)
end)

test("S10 death trigger off but stop trigger on: stop loots", function()
  AutoAreaLootDB.lootOnDeath = false
  fire("UNIT_DIED", "0xAAA"); tick(1.0); eq(M.calls, 0)
  M.speed = 7; tick(0.2); M.speed = 0; tick(0.8); eq(M.calls, 1)
end)

test("S11 money confirmation is logged against scan", function()
  fire("UNIT_DIED", "0xAAA"); tick(0.4)
  finishScan({ { guid = "0xAAA", coin = 250, items = {} } })
  M.money = M.money + 250; fire("PLAYER_MONEY")
  eq(S.lootMoney, 250, "money total")
end)

test("S12 unrelated item pickup is NOT logged", function()
  fire("UNIT_DIED", "0xAAA"); tick(0.4)
  finishScan({ { guid = "0xAAA", coin = 0, items = { item(111) } } })
  fire("CHAT_MSG_LOOT", itemMsg(999))
  eq(S.lootEventCount, 0)
end)

test("S13 duplicate corpse GUID in second scan not double-counted", function()
  fire("UNIT_DIED", "0xAAA"); tick(0.4)
  finishScan({ { guid = "0xAAA", coin = 0, items = { item(5, 1) } } })
  fire("UNIT_DIED", "0xBBB"); tick(2.0)
  finishScan({ { guid = "0xAAA", coin = 0, items = { item(5, 1) } } })
  fire("CHAT_MSG_LOOT", itemMsg(5))
  eq(S.lootEventCount, 1, "one item logged once")
end)

test("S14 stable-stop: movement resumes within grace cancels scan", function()
  M.speed = 7; tick(0.2); M.speed = 0; tick(0.06); M.speed = 7; tick(0.3)
  eq(M.calls, 0)
  M.speed = 0; tick(0.8); eq(M.calls, 1)
end)

test("S15 leaving world clears pending state", function()
  M.speed = 7; tick(0.2); fire("UNIT_DIED", "0xAAA"); fire("PLAYER_LEAVING_WORLD")
  eq(S.pendingLootReason, nil); M.speed = 0; fire("PLAYER_ENTERING_WORLD"); tick(1.0); eq(M.calls, 0)
end)
