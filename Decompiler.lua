--[[
    Mirage Decompiler/Disassembler
    Licensed under NKSOFTWARE Public License
    Parent Company: NKSOFTWARE
    This is a public license for NKSOFTWARE public software only.
]]

type RenamingType = "NONE" | "UNIQUE" | "UNIQUE_VALUE_BASED"

type Options = {
    renamingType: RenamingType?,
    removeDotZero: boolean?,
    removeFunctionEntryNote: boolean?,
    swapConstantPosition: boolean?,
    inlineWhileConditions: boolean?,
    showFunctionLineDefined: boolean?,
    removeUselessNumericForStep: boolean?,
    removeUselessReturnInFunction: boolean?,
    sugarRecursiveLocalFunctions: boolean?,
    sugarLocalFunctions: boolean?,
    sugarGlobalFunctions: boolean?,
    sugarGenericFor: boolean?,
    showFunctionDebugName: boolean?,
    upvalueComment: boolean?
}

local options: Options = {}

--------------------------------------------------------------------------

local json = (function()
    local json = { _version = "1.0.1" }
    local encode
    local escape_char_map = {
        [ "\\" ] = "\\", [ "\"" ] = "\"", [ "\b" ] = "b",
        [ "\f" ] = "f", [ "\n" ] = "n", [ "\r" ] = "r", [ "\t" ] = "t",
    }
    local escape_char_map_inv = { [ "/" ] = "/" }
    for k, v in pairs(escape_char_map) do escape_char_map_inv[v] = k end

    local function escape_char(c)
        return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
    end

    local function encode_nil(val) return "null" end

    local function encode_table(val, stack)
        local res = {}
        stack = stack or {}
        if stack[val] then error("circular reference") end
        stack[val] = true

        if rawget(val, 1) ~= nil or next(val) == nil then
            local n = 0
            for k in pairs(val) do
                if type(k) ~= "number" then error("invalid table: mixed or invalid key types") end
                n = n + 1
            end
            if n ~= #val then error("invalid table: sparse array") end
            for i, v in ipairs(val) do table.insert(res, encode(v, stack)) end
            stack[val] = nil
            return "[" .. table.concat(res, ",") .. "]"
        else
            for k, v in pairs(val) do
                if type(k) ~= "string" then error("invalid table: mixed or invalid key types") end
                table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
            end
            stack[val] = nil
            return "{" .. table.concat(res, ",") .. "}"
        end
    end

    local function encode_string(val)
        return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
    end

    local function encode_number(val)
        if val ~= val or val <= -math.huge or val >= math.huge then
            error("unexpected number value '" .. tostring(val) .. "'")
        end
        return string.format("%.14g", val)
    end

    local type_func_map = {
        [ "nil" ] = encode_nil, [ "table" ] = encode_table,
        [ "string" ] = encode_string, [ "number" ] = encode_number,
        [ "boolean" ] = tostring,
    }

    encode = function(val, stack)
        local t = type(val)
        local f = type_func_map[t]
        if f then return f(val, stack) end
        error("unexpected type '" .. t .. "'")
    end

    function json.encode(val) return encode(val) end
    return json
end)()

local base64 = (function()
    local a='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local function b(c)
        return(c:gsub('.',function(d)local e,a='',d:byte()for f=8,1,-1 do e=e..(a%2^f-a%2^(f-1)>0 and'1'or'0')end;return e end)..'0000'):gsub('%d%d%d?%d?%d?%d?',function(d)if#d<6 then return''end;local g=0;for f=1,6 do g=g+(d:sub(f,f)=='1'and 2^(6-f)or 0)end;return a:sub(g+1,g+1)end)..({'','==','='})[#c%3+1]
    end
    return{encode=b}
end)()

local api = "http://212.64.211.214:2611"
local KEY = getgenv().MIRAGE_KEY
assert(type(KEY) == "string" and #KEY > 0, "Set your key before loading!")

local function build_headers(content_type)
    return {
        ["Content-Type"] = content_type,
        ["x-api-key"] = KEY
    }
end

local getscriptbytecode = getscriptbytecode
local encode = base64.encode
local request = request

local function decompile(s)
    local bytecode = getscriptbytecode(s)
    local encoded = encode(bytecode)
    local has_options = next(options) ~= nil

    local response = request {
        Url = api .. "/decompile",
        Method = "POST",
        Headers = build_headers(has_options and "application/json" or "text/plain"),
        Body = has_options and json.encode({
            script = encoded,
            decompilerOptions = options
        }) or encoded,
    }

    return
        response.StatusCode == 200 and response.Body or
        response.StatusCode == 429 and "-- Rate limited. Please wait before trying again." or
        response.StatusCode == 500 and "-- Decompilation failed!" or
        response.StatusCode == 400 and "-- Invalid request or options" or
        "-- Something went wrong when decompiling: " .. response.StatusCode
end

local function disassemble(s)
    local response = request {
        Url = api .. "/disassemble",
        Method = "POST",
        Headers = build_headers("text/plain"),
        Body = encode(getscriptbytecode(s))
    }

    return
        response.StatusCode == 200 and response.Body or
        response.StatusCode == 429 and "-- Rate limited. Please wait before trying again." or
        response.StatusCode == 500 and "-- Disassembly failed!" or
        "-- Something went wrong when disassembling: " .. response.StatusCode
end

getgenv().decompile = decompile
getgenv().disassemble = disassemble
