EndwordLoop — CS in-game 끝말잇기 (time-attack)

Overview
- Implements a time-attack 끝말잇기 (word-chain) game designed for in-game Lua scripting inside Counter-Strike servers/mods.
- Max 8 players. Chat commands used for joining and submitting words. Time per turn shrinks after each successful pass to increase tempo.

Files
- `game.lua` — core game logic and example hooks (`OnPlayerChat`, `OnServerTick`).
- `ui.lua` — HUD and notification helper functions (use engine HUD calls instead of `print`).
- `kkutu_api.lua` — word validation module. Currently uses a local fallback dictionary in `words.txt`. Placeholder spots show where to call the real kkutu.kr API.
- `words.txt` — sample fallback dictionary.

Usage
1. Copy these files into your server's Lua scripts folder (already placed here).
2. Hook your server/mod chat handler to call `OnPlayerChat(playerid, text)` when players send chat messages.
3. Call `OnServerTick()` regularly (e.g., each server frame) to run turn timers.

Chat commands (in-game)
- `!join` — join the next game (max 8)
- `!start` — start the game once players have joined
- When the game is running, only the current player's chat text is interpreted as the submitted word. Other chat is ignored by the script.

Behavior and notes
- Duplicate words are rejected.
- A small local dictionary is used to validate words. To integrate with the kkutu.kr API, implement an HTTP request in `kkutu_api.lua` where noted.
- 두음법칙: `kkutu_api.lua` contains a simple allowance for common 두음법칙 cases. This is not exhaustive — you may want to replace it with a production-grade Korean morphological checker or the real kkutu API.
- UI: `ui.lua` uses `print()` calls for simplicity. Replace these with your engine's HUD/draw functions for an in-game UI.

Extending
- To call the remote kkutu API, add an HTTP client and replace the existence check in `kkutu_api.lua`.
- Improve Hangul handling by using a full Hangul jamo library or deterministic unicode decomposition functions if available in your Lua environment.

If you'd like, I can:
- Hook the UI functions to a specific CS mod API (specify the mod / server type).
- Add network messages so spectators also see the HUD.
