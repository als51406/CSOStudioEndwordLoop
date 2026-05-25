-- UI helper for EndwordLoop
local M = {}

-- These functions are written to be easy to hook into a specific server/mod UI
-- Replace `print` calls with engine-specific HUD/draw calls as needed.

function M.show_start_screen(game)
	print("[EndwordLoop] Game started! Players: " .. tostring(#game.order))
	M.update(game)
end

function M.show_end_screen(game)
	print("[EndwordLoop] Game ended. Scores:")
	for _,id in ipairs(game.order) do
		local p = game.players[id]
		print((p.name or tostring(id)) .. ": " .. tostring(p.score))
	end
end

function M.update(game)
	local pid = game:current_player_id()
	local name = (game.players[pid] and game.players[pid].name) or tostring(pid)
	print(string.format("[EndwordLoop HUD] Now: %s | Word: %s | TimeLeft: %ds | TurnTime: %.1fs",
		name, tostring(game.currentWord or "(start)"), math.max(0, os.difftime(game.turn_end_at or 0, os.time())), game.turn_time))
	-- Also show leaderboard
	print("Scores:")
	for _,id in ipairs(game.order) do
		local p = game.players[id]
		print((p.name or tostring(id)) .. ": " .. tostring(p.score))
	end
end

function M.notify(playerid, text)
	-- Send a short notification to a player; replace with in-game chat API when available
	print(('[EndwordLoop] (to %s) %s'):format(tostring(playerid), text))
end

function M.notify_all(text)
	print('[EndwordLoop] ' .. text)
end

return M