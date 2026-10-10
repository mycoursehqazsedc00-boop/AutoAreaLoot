local fire, tick, test, eq, M, S = H.fire, H.tick, H.test, H.eq, H.M, H.S
test("PLAYER_ALIVE/UNGHOST with nothing queued is a no-op", function()
  fire("PLAYER_ALIVE"); fire("PLAYER_UNGHOST"); tick(2); eq(M.calls, 0)
end)
test("PLAYER_ALIVE while still ghost keeps request queued, then loots on UNGHOST", function()
  AutoAreaLootDB.lootOnStop = false
  M.dead = true; fire("UNIT_DIED", "0xAAA"); tick(1)
  fire("PLAYER_ALIVE"); tick(1); eq(M.calls, 0, "still ghost -> retained")
  M.dead = false; fire("PLAYER_UNGHOST"); tick(1); eq(M.calls, 1)
end)
