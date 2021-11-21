local band = function(x, y) return x & y end
local bor = function(x, y) return x | y end
local bxor = function(x, y) return x ~ y end
local bnot = function(x) return ~x end
local lshift = function(x, a) return x * 2 ^ a end
local rshift = function(x, a) return math.floor(x / 2 ^ a) end

NESEmulator.UTILS = {}

function NESEmulator.UTILS.isDefined(v)
    return (v and v ~= NESEmulator.CPU.UNDEFINED) and v or nil
end

function NESEmulator.UTILS.bind(f, param)
    return function(...)
        return f(param, ...)
    end
end

function NESEmulator.UTILS.timeF(f, n)
    local t = os.clock()
    for i = 1, n or 1 do
        f()
    end
    return os.clock() - t
end

function NESEmulator.UTILS.tSetter(t)
    return function(i, v)
        t[i] = v
    end
end
function NESEmulator.UTILS.tGetter(t, offs)
    offs = (offs or 1)
    return function(i)
        return t[i + offs]
    end
end
function NESEmulator.UTILS.map(t, f)
    local tt = {}
    for i = t[0] and 0 or 1, #t do
        tt[i] = f(t[i])
    end
    return tt
end
function NESEmulator.UTILS.fill(t, v, n, step, offs)
    for i = t[0] and 0 or 1, math.max(#t, n or 0), step or 1 do
        t[i + (offs or 0)] = v
    end
    return t
end

function NESEmulator.UTILS.shiftingArray()
    local _t = {}
    local t = {}
    local shift = 0
    setmetatable(
        t,
        {
            __index = function(t, k)
                return _t[NESEmulator.UTILS.rotateIdx(_t, k + shift)]
            end,
            __newindex = function(t, k, v)
                if k > #_t then
                    table.insert(_t, shift + k - #_t - 1, v)
                else
                    _t[NESEmulator.UTILS.rotateIdx(_t, k + shift)] = v
                end
            end
        }
    )
    t.rotate = function(self, newshift)
        shift = NESEmulator.UTILS.rotateIdx(_t, newshift + shift)
    end
    return t
end

function NESEmulator.UTILS.indexRotating(t, idx)
    return t[NESEmulator.UTILS.rotateIdx(t, idx)]
end

function NESEmulator.UTILS.rotatePositiveIdx(t, idx, size)
    size = size or #t
    return ((idx - 1) % size) + 1
end

function NESEmulator.UTILS.rotateIdx(t, idx, size)
    size = size or #t
    if idx > size then
        return NESEmulator.UTILS.rotateIdx(t, idx - size, size)
    elseif idx < 1 then
        return NESEmulator.UTILS.rotateIdx(t, idx + size, size)
    else
        return idx
    end
end

-- In-place
function NESEmulator.UTILS.rotate(array, shift) -- Works for array with consecutive entries
    shift = shift or 1 -- make second arg optional, defaults to 1

    local start = array[0] and 0 or 1
    local size = #array

    if shift > 0 then
        for i = 1, math.abs(shift) do
            table.insert(array, 1, table.remove(array, size))
        end
    else
        for i = 1, math.abs(shift) do
            table.insert(array, size, table.remove(array, 1))
        end
    end
    return array
end
function NESEmulator.UTILS.rotateNew(t, r)
    local rotated = {}
    local size = #t
    local start = t[0] and 0 or 1
    if r >= 0 then
        for i = start, size do
            local idx = i + r
            if idx > size then
                idx = idx - size
            elseif (idx < start) then
                idx = idx + size
            end
            rotated[i] = t[idx]
        end
    else
        for i = 1, size do
            local idx = size - i + r
            if idx > size then
                idx = idx - size
            elseif (idx < start) then
                idx = idx + size
            end
            rotated[i] = t[idx]
        end
    end
    return rotated
end
function NESEmulator.UTILS.nthBitIsSet(n, nth)
    return band(n, nth == 0 and 0x1 or lshift(0x1, nth)) ~= 0
end
function NESEmulator.UTILS.nthBitIsSetInt(n, nth)
    return NESEmulator.UTILS.nthBitIsSet(n, nth) and 1 or 0
end
function NESEmulator.UTILS.transpose(t)
    local tt = {}
    if #t == 0 then
        return tt
    end
    local ttSize = #(t[1])
    for i = t[1][0] and 0 or 1, ttSize do
        local ttt = {}
        tt[i] = ttt
        for j = t[0] and 0 or 1, #t do
            ttt[j] = t[j][i]
        end
    end
    return tt
end
function NESEmulator.UTILS.range(a, b, step)
    local t = {}
    -- is floor right here?
    local qty = (b - a)
    if not step then
        if qty > 0 then
            step = 1
        else
            step = -1
            qty = -qty
        end
    end
    for i = 0, (math.floor(math.abs(qty / step))) do
        t[i] = a + i * step
    end
    return t
end
function NESEmulator.UTILS.printf(...)
    print(string.format(...))
end
function NESEmulator.UTILS.concat0(...)
    local args = {...}
    if type(args[1]) == "table" then
        local ct = {}
        for j = 1, #args do
            local t = args[j]
            for i = 0, #t do
                ct[(not ct[0]) and 0 or (#ct + 1)] = t[i]
            end
        end
        return ct
    else
        return table.concat(...)
    end
end
function NESEmulator.UTILS.concat(...)
    local args = {...}
    if type(args[1]) == "table" then
        local ct = {}
        for j = 1, #args do
            local t = args[j]
            for i = 1, #t do
                ct[#ct + 1] = t[i]
            end
        end
        return ct
    else
        return table.concat(...)
    end
end
function NESEmulator.UTILS.copy(t, n, offset, step)
    local tt = {}
    n = n or #t
    offset = offset or 0
    for i = t[0] and 0 or 1, n, step or 1 do
        tt[i] = t[i + offset]
    end
    return tt
end
function NESEmulator.UTILS.dump(o)
    if type(o) == "table" then
        local s = "{ "
        for k, v in pairs(o) do
            if type(k) ~= "number" then
                k = '"' .. k .. '"'
            end
            s = s .. "[" .. k .. "] = " .. NESEmulator.UTILS.dump(v) .. ","
        end
        return s .. "} "
    else
        return tostring(o)
    end
end
function NESEmulator.UTILS.dumpi(o)
    if type(o) == "table" then
        local s = "{ "
        for k, v in ipairs(o) do
            if type(k) ~= "number" then
                k = '"' .. k .. '"'
            end
            s = s .. NESEmulator.UTILS.dumpi(v) .. ","
        end
        return s .. "} "
    else
        return tostring(o)
    end
end
function NESEmulator.UTILS.all(t, f)
    for i = t[0] and 0 or 1, #t do
        if not f(t[i]) then
            return false
        end
    end
    return true
end
function NESEmulator.UTILS.flat_map(t, f)
    t = NESEmulator.UTILS.map(t, f)
    local tt = {}
    for j = t[0] and 0 or 1, #t do
        local st = t[j]
        for i = t[0] and 0 or 1, #st do
            local v = st[i]
            tt[#tt + 1] = v
        end
    end
    return tt
end
function NESEmulator.UTILS.clear(t)
    for k in pairs(t) do
        t[k] = nil
    end
end
function NESEmulator.UTILS.uniq(t)
    local tt = {}
    local done = {}
    for i = t[0] and 0 or 1, #t do
        local x = t[i]
        if not done[x] then
            tt[#tt + 1] = x
            done[x] = true
        end
    end
    return tt
end
local p = print
local f = nil
function NESEmulator.UTILS.print(x)
    if not f then
        local ff = assert(io.open("logs.txt", "w"))
        ff:write("")
        ff:close()
        f = assert(io.open("logs.txt", "a"))
        asdasdsssasd = f
    end
    local str = NESEmulator.UTILS.dump(x)
    f:write(str .. "\n")
    --f:flush()
    --p(str)
end
function NESEmulator.UTILS.import(t)
    local e = getfenv(2)
    for k, v in pairs(t) do
        e[k] = v
    end
end

function NESEmulator.UTILS.class(parent)
    local class = {}
    if parent then
        setmetatable(class, {__index = parent})
        class._parent = parent
    end
    class._mt = {__index = class}
    function class:new(...)
        local instance = {}
        setmetatable(instance, class._mt)
        if instance.initialize then
            instance:initialize(...)
        end
        return instance
    end
    return class
end
