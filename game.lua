-- EndwordLoop: time-attack 끝말잇기 core logic
local kkutu = require("kkutu_api")
local ui = require("ui")

-- 우리말샘 API 키 설정
kkutu.set_api_key("B0BBB556EC6EA7118F1088AC1F3A0118")

local WordChain = {}
WordChain.__index = WordChain

function WordChain.new()
	local self = setmetatable({}, WordChain)
	self.players = {} -- {id={name=..., score=..., active=true}}
	self.order = {}
	self.maxPlayers = 8
	self.started = false
	self.currentIndex = 1
	self.currentWord = nil
	self.usedWords = {}
	self.base_time = 10 -- seconds
	self.time_decrement = 0.5 -- seconds removed per successful pass
	self.min_time = 2 -- minimum allowed per turn
	self.turn_time = self.base_time
	self.turn_end_at = nil
	self.scores = {}
	return self
end

function WordChain:add_player(id, name)
	if #self.order >= self.maxPlayers then
		return false, "Server is full (max " .. self.maxPlayers .. ")"
	end
	if self.players[id] then return false, "Already joined" end
	self.players[id] = {name = name, score = 0}
	table.insert(self.order, id)
	return true
end

function WordChain:remove_player(id)
	if not self.players[id] then return end
	self.players[id] = nil
	for i,v in ipairs(self.order) do
		if v == id then table.remove(self.order, i); break end
	end
	if #self.order == 0 then self:stop() end
end

function WordChain:start()
	if self.started then return end
	if #self.order < 1 then return end
	self.started = true
	self.currentIndex = 1
	self.currentWord = nil
	self.usedWords = {}
	for _,id in ipairs(self.order) do self.players[id].score = 0 end
	self.turn_time = self.base_time
	self.turn_end_at = os.time() + self.turn_time
	ui.show_start_screen(self)
end

function WordChain:stop()
	self.started = false
	ui.show_end_screen(self)
end

function WordChain:current_player_id()
	return self.order[self.currentIndex]
end

function WordChain:advance_turn()
	self.currentIndex = self.currentIndex % #self.order + 1
	self.turn_time = math.max(self.min_time, self.turn_time - self.time_decrement)
	self.turn_end_at = os.time() + self.turn_time
	ui.update(self)
end

function WordChain:handle_chat(playerid, text)
	if not self.started then
		-- accept chat command to join or start
		local cmd = string.lower(text)
		if cmd == "!join" then
			local ok, err = self:add_player(playerid, "Player"..tostring(playerid))
			return ok and ui.notify(playerid, "Joined the game") or ui.notify(playerid, err)
		elseif cmd == "!start" then
			if #self.order >= 1 then self:start(); return end
			return ui.notify(playerid, "Not enough players to start")
		else
			return -- ignore other chat while not started
		end
	end

	-- Only current player can submit a word
	if playerid ~= self:current_player_id() then
		return ui.notify(playerid, "It's not your turn")
	end

	local word = kkutu.normalize(text)
	if word == "" then return ui.notify(playerid, "Invalid input") end

	-- Validate
	local ok, reason = kkutu.check_word(word, self.currentWord, self.usedWords)
	if not ok then
		ui.notify(playerid, "Rejected: " .. reason)
		-- penalty: skip to next player
		self:advance_turn()
		return
	end

	-- Accept
	self.currentWord = word
	self.usedWords[word] = true
	self.players[playerid].score = self.players[playerid].score + 1
	ui.notify_all(self.players[playerid].name .. " passed: " .. word)
	-- speed up next turn
	self:advance_turn()
end

function WordChain:tick()
	if not self.started then return end
	if not self.turn_end_at then return end
	if os.time() >= self.turn_end_at then
		local pid = self:current_player_id()
		ui.notify_all((self.players[pid].name or tostring(pid)) .. " timed out")
		-- no points for timeouts, advance
		self:advance_turn()
	end
end

-- Expose a global singleton for easy hooking
_G.EndwordLoop = _G.EndwordLoop or WordChain.new()

-- Example hooks for the game/mod environment
function OnPlayerChat(playerid, text)
	EndwordLoop:handle_chat(playerid, text)
end

-- Call this regularly from the server tick
function OnServerTick()
	EndwordLoop:tick()
end

return WordChain