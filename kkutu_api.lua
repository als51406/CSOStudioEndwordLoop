-- kkutu_api.lua
-- Word validation module with offline fallback and simple 두음법칙 handling.

local M = {}

-- Configurable API key (우리말샘 OpenDict)
M.api_key = nil
M.api_base = "https://opendict.korean.go.kr/api/search"

-- Load fallback dictionary from words.txt
local function load_dictionary(path)
    local t = {}
    local f = io.open(path, "r")
    if not f then return t end
    for line in f:lines() do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then t[line] = true end
    end
    f:close()
    return t
end

local dict = load_dictionary("d:/Studio/Script/EndwordLoop/words.txt")

-- try to load HTTP and JSON libraries
local http, ltn12, json
do
    local ok1, socket_http = pcall(require, "socket.http")
    if ok1 then http = socket_http end
    local ok2, ltn = pcall(require, "ltn12")
    if ok2 then ltn12 = ltn end
    local ok3, cjson = pcall(require, "cjson")
    if ok3 then json = {decode = cjson.decode} end
    if not json then
        local ok4, dkjson = pcall(require, "dkjson")
        if ok4 then json = {decode = dkjson.decode} end
    end
end

-- URL encode helper
local function url_encode(str)
    if not str then return "" end
    str = tostring(str)
    str = str:gsub("([^%w_%-%.~])", function(c) return string.format("%%%02X", string.byte(c)) end)
    return str
end

function M.set_api_key(key)
    M.api_key = key
end

-- Remote check via 우리말샘 OpenDict API. Returns (true, nil) or (false, reason)
local function remote_check(word)
    if not M.api_key then return nil, "no api key" end
    if not http or not ltn12 then return nil, "http library not available" end
    if not json then return nil, "json library not available" end

    local q = url_encode(word)
    local url = string.format("%s?key=%s&q=%s&req_type=json", M.api_base, url_encode(M.api_key), q)
    local resp = {}
    local ok, code = http.request{ url = url, sink = ltn12.sink.table(resp) }
    if not ok then return nil, "http error: " .. tostring(code) end
    local body = table.concat(resp)
    local data, pos, err = json.decode(body)
    if not data then return nil, "invalid json: " .. tostring(err) end

    -- OpenDict response contains 'channel'->'total' and 'item' list when matches found
    -- Accept word if total > 0
    local total = nil
    if data.channel and data.channel.total then total = tonumber(data.channel.total) end
    if total and total > 0 then
        return true
    else
        return false, "not found in OpenDict"
    end
end

-- Normalize input: trim and remove non-Korean letters
function M.normalize(s)
    if not s then return "" end
    s = tostring(s):gsub("^%s+",""):gsub("%s+$","")
    -- remove ASCII control and punctuation; keep Hangul syllables
    s = s:gsub("[^\uAC00-\uD7A3]", "")
    return s
end

-- Basic Hangul decomposition helpers
local HANGUL_BASE = 0xAC00
local HANGUL_END = 0xD7A3
local JAMO_INITIAL = {
    "ㄱ","ㄲ","ㄴ","ㄷ","ㄸ","ㄹ","ㅁ","ㅂ","ㅃ","ㅅ","ㅆ","ㅇ","ㅈ","ㅉ","ㅊ","ㅋ","ㅌ","ㅍ","ㅎ"
}
local JAMO_FINAL = {"", "ㄱ","ㄲ","ㄳ","ㄴ","ㄵ","ㄶ","ㄷ","ㄹ","ㄺ","ㄻ","ㄼ","ㄽ","ㄾ","ㄿ","ㅀ","ㅁ","ㅂ","ㅄ","ㅅ","ㅆ","ㅇ","ㅈ","ㅊ","ㅋ","ㅌ","ㅍ","ㅎ"}

local function decompose(ch)
    if not ch or ch == "" then return nil end
    local code = utf8.codepoint(ch)
    if not code then return nil end
    if code < HANGUL_BASE or code > HANGUL_END then return nil end
    local sindex = code - HANGUL_BASE
    local cho = math.floor(sindex / (21*28)) + 1
    local jung = math.floor((sindex % (21*28)) / 28) + 1
    local jong = (sindex % 28) + 1
    return JAMO_INITIAL[cho], jung, JAMO_FINAL[jong]
end

-- Two-eum rule handling: allow some common initial substitutions
local twoeum_map = {
    ["ㄹ"] = {"ㅇ","ㄴ"},
    ["ㄴ"] = {"ㄹ"}
}

local function starts_with_allowed(word, expected_char)
    if not expected_char then return true end
    local first = word:sub(1,1)
    local fcho, fjung, fjong = decompose(first)
    if not fcho then return false end
    if fcho == expected_char then return true end
    local alt = twoeum_map[fcho]
    if alt then
        for _,v in ipairs(alt) do if v == expected_char then return true end end
    end
    return false
end

-- Check word validity: existence and chaining rules
-- prev_word: the previous accepted word (string or nil)
-- used: table of used words (for duplicate checking)
function M.check_word(word, prev_word, used)
    if not word or word == "" then return false, "empty" end
    if used and used[word] then return false, "duplicate" end

    -- existence check: local dict first, then remote OpenDict if api_key set
    if not dict[word] then
        if M.api_key then
            local ok, reason_or_err = remote_check(word)
            if ok == nil then
                -- remote couldn't be checked
                return false, "remote check failed: " .. tostring(reason_or_err)
            end
            if not ok then return false, reason_or_err end
        else
            return false, "unknown word (not in local dict)"
        end
    end

    if not prev_word then return true end
    local last_char = prev_word:sub(-1)
    local last_cho, last_jung, last_jong = decompose(last_char)
    if not last_cho then return false, "previous word invalid" end

    local next_first = word:sub(1,1)
    local next_initial, njung, njong = decompose(next_first)
    if not next_initial then return false, "next word invalid" end

    if last_jong and last_jong ~= "" then
        if next_initial == last_jong then return true end
        if starts_with_allowed(word, last_jong) then return true end
        return false, "doesn't match last letter"
    else
        -- no final consonant: accept broadly
        return true
    end
end

return M
