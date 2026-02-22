--[[
    Mirage Decompiler/Disassembler Loader
    Licensed under NKSOFTWARE Public License
]]

local api = getgenv().MIRAGE_API or "https://api.ninjakernel.dev"
local KEY = getgenv().MIRAGE_KEY
local LUA_RENAMER = getgenv().lua_renamer == true
local LUA_ENHANCER = getgenv().lua_enhancer == true

assert(type(KEY) == "string" and #KEY > 0, "Set your MIRAGE_KEY before loading!")

local getscriptbytecode = getscriptbytecode
local request = request

-- highly optimized local base64 encoder
local base64_encode = (function()
    local a='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return function(c)
        return(c:gsub('.',function(d)local e,a='',d:byte()for f=8,1,-1 do e=e..(a%2^f-a%2^(f-1)>0 and'1'or'0')end;return e end)..'0000'):gsub('%d%d%d?%d?%d?%d?',function(d)if#d<6 then return''end;local g=0;for f=1,6 do g=g+(d:sub(f,f)=='1'and 2^(6-f)or 0)end;return a:sub(g+1,g+1)end)..({'','==','='})[#c%3+1]
    end
end)()

local function build_headers()
    return {
        ["Content-Type"] = "text/plain",
        ["x-api-key"] = KEY
    }
end

local function ai_query()
    local flags = {}
    if LUA_RENAMER then table.insert(flags, "rename") end
    if LUA_ENHANCER then table.insert(flags, "enhance") end
    if #flags == 0 then return "" end
    return "?ai=" .. table.concat(flags, ",")
end

getgenv().decompile = function(s)
    local encoded = base64_encode(getscriptbytecode(s))
    local response = request {
        Url = api .. "/decompile" .. ai_query(),
        Method = "POST",
        Headers = build_headers(),
        Body = encoded,
    }
    if response.StatusCode == 200 then return response.Body end
    if response.StatusCode == 429 then return "-- Rate limited. Please wait." end
    if response.StatusCode == 500 then return "-- Decompilation failed!" end
    if response.StatusCode == 400 then return "-- Invalid request or missing options." end
    return "-- Something went wrong: " .. response.StatusCode
end

getgenv().disassemble = function(s)
    local encoded = base64_encode(getscriptbytecode(s))
    local response = request {
        Url = api .. "/disassemble",
        Method = "POST",
        Headers = build_headers(),
        Body = encoded
    }
    if response.StatusCode == 200 then return response.Body end
    if response.StatusCode == 429 then return "-- Rate limited. Please wait." end
    if response.StatusCode == 500 then return "-- Disassembly failed!" end
    return "-- Something went wrong: " .. response.StatusCode
end
