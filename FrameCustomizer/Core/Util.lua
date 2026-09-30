local _, FC = ...
FC.VERSION = "0.1.0"
FC.REVISION = "first-build-1"
FC.LIMITS = { rules = 128, depth = 12, minInterval = 0.25, maxInterval = 60,
    verify = 2, resolve = 3, jobs = 12, scan = 24, nodes = 6000, children = 256 }
local U = {}
FC.Util = U
-- The native adapter supplies this before saved data is inspected. Offline tests
-- supply their own value-access predicate; they do not emulate native secrets.
U.access = function() return true end
function U.safe(v) return U.access(v) end
function U.field(t, k)
    if not U.safe(t) or type(t) ~= "table" then return nil end
    local v = rawget(t, k)
    if U.safe(v) then return v end
end
function U.number(v, lo, hi)
    return U.safe(v) and type(v) == "number" and v == v and v >= lo and v <= hi
end
function U.string(v, max)
    return U.safe(v) and type(v) == "string" and #v <= (max or 240) and not v:find("[%z\1-\31]")
end
function U.identifier(v)
    return U.string(v, 120) and v:match("^[%a_][%w_]*$") ~= nil
end
function U.copy(v, depth)
    depth = depth or 0
    if not U.safe(v) or depth > 16 then return nil end
    if type(v) ~= "table" then
        if type(v) == "number" or type(v) == "boolean" or type(v) == "string" then return v end
        return nil
    end
    local out, count = {}, 0
    for k, x in pairs(v) do
        count = count + 1
        if count > 512 then break end
        if U.safe(k) and (type(k) == "string" or type(k) == "number") then out[k] = U.copy(x, depth + 1) end
    end
    return out
end
function U.equal(a, b)
    if a == b then return true end
    if type(a) ~= type(b) then return false end
    if type(a) == "number" then return math.abs(a - b) < 0.0005 end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not U.equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
function U.clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end
function U.cleanLabel(s)
    if not U.string(s, 512) then return "unavailable" end
    return s:gsub("|", "||"):sub(1, 180)
end
function U.joinTarget(t)
    if not t then return "unidentified" end
    return t.root .. (#t.keys > 0 and ("." .. table.concat(t.keys, ".")) or "")
end

