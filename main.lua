NESEmulator = RegisterMod('NES Emulator', 1)
include = include or require

--[[local temp = {}
for i, var in pairs(_G) do
    temp[#temp+1] = i
end]]

local PLAYER_NES = Isaac.GetPlayerTypeByName("NES")
local PLAYER_GB = Isaac.GetPlayerTypeByName("Gameboy", true)

-- literally stole all of this lol
local MOD = 2^32
local MODM = MOD-1

local function memoize(f)

    local mt = {}
    local t = setmetatable({}, mt)
  
    function mt:__index(k)
        local v = f(k)
        t[k] = v
        return v
    end
  
    return t
end
  
local function make_bitop_uncached(t, m)
    local function bitop(a, b)
        local res,p = 0,1
        while a ~= 0 and b ~= 0 do
            local am, bm = a%m, b%m
            res = res + t[am][bm]*p
            a = (a - am) / m
            b = (b - bm) / m
            p = p*m
        end
        res = res + (a+b) * p
        return res
    end
    return bitop
end

local function make_bitop(t)
    local op1 = make_bitop_uncached(t, 2^1)
    local op2 = memoize(function(a)
        return memoize(function(b)
            return op1(a, b)
        end)
    end)
    return make_bitop_uncached(op2, 2^(t.n or 1))
end

local bxor = make_bitop {[0]={[0]=0,[1]=1},[1]={[0]=1,[1]=0}, n=4}
local band = function(a,b) return ((a+b) - bxor(a,b))/2 end
local bor = function(a,b)  return MODM - band(MODM - a, MODM - b) end

NESEmulator.bit = {}
NESEmulator.bit.band = function(a, b, c, ...)
    local z
    if b then
      a = a % MOD
      b = b % MOD
      z = ((a+b) - bxor(a,b)) / 2
      if c then
        z = NESEmulator.bit.band(z, c, ...)
      end
      return z
    elseif a then
      return a % MOD
    else
      return MODM
    end
  end
NESEmulator.bit.bor = function(a, b, c, ...)
    local z
    if b then
      a = a % MOD
      b = b % MOD
      z = MODM - band(MODM - a, MODM - b)
      if c then
        z = NESEmulator.bit.bor(z, c, ...)
      end
      return z
    elseif a then
      return a % MOD
    else
      return 0
    end
  end
NESEmulator.bit.bxor = function(a, b, c, ...)
    local z
    if b then
        a = a % MOD
        b = b % MOD
        z = bxor(a, b)
        if c then
            z = NESEmulator.bit.bxor(z, c, ...)
        end
        return z
    elseif a then
        return a % MOD
    else
        return 0
    end
end
NESEmulator.bit.bnot = function(x) return MODM - x end
local lshifts = {}
local rshifts = {}
NESEmulator.bit.lshift = function(x, a) if lshifts[x] and lshifts[x][a] then return lshifts[x][a] end lshifts[x] = lshifts[x] or {} lshifts[x][a] = x * 2 ^ a return lshifts[x][a] end
NESEmulator.bit.rshift = function(x, a) if rshifts[x] and rshifts[x][a] then return rshifts[x][a] end rshifts[x] = rshifts[x] or {} rshifts[x][a] = math.floor(x / 2 ^ a) return rshifts[x][a] end

--Isaac = {}
--Isaac.DebugString = print

local _rom_encoded = include('NES ROM') or include('NES ROM Default')

-- process rom
local _rom = ''
for _, v in ipairs(_rom_encoded) do
    _rom = _rom .. string.char(v)
end

include "NES/nes"
NESEmulator.Nes = nil

local pixel = Sprite()
pixel:Load('gfx/a_single_fucking_pixel.anm2')
pixel:Play('Idle')

local width = 256
local height = 240
local pixSize = 1
local lastSource
local sound = false
local DEBUG = false

function NESEmulator.init()
    local loglvl = 0
    --NESEmulator.Nes = NES:new({file="tests/hello.nes", loglevel=5})
    NESEmulator.Nes =
        NESEmulator.NES:new(
        {
            file = _rom,
            blob = _rom_encoded,
            loglevel = 1,
            pc = nil,
            palette = NESEmulator.UTILS.map(
                NESEmulator.PALETTE:defacto_palette(),
                function(c)
                    return {c[1]/255, c[2]/255, c[3]/255}
                end
            )
        }
    )
    --NESEmulator.Nes:run()
    NESEmulator.Nes:reset()
end
local keyEvents = {}
local keyButtons = {
    [ButtonAction.ACTION_SHOOTUP] = NESEmulator.Pad.UP,
    [ButtonAction.ACTION_SHOOTLEFT] = NESEmulator.Pad.LEFT,
    [ButtonAction.ACTION_SHOOTDOWN] = NESEmulator.Pad.DOWN,
    [ButtonAction.ACTION_SHOOTRIGHT] = NESEmulator.Pad.RIGHT,
    [ButtonAction.ACTION_MENUCONFIRM] = NESEmulator.Pad.A,
    [ButtonAction.ACTION_MENUBACK] = NESEmulator.Pad.B,
    [ButtonAction.ACTION_MAP] = NESEmulator.Pad.SELECT,
    [ButtonAction.ACTION_DROP] = NESEmulator.Pad.START
}
local isDown = {}

local ticktime = 0
local time = 0
local timeTwo = 0
local rate = 1 / 59.94
local fps = 0
local tickRate = 0
local tickRatetmp = 0
local pixelCount = NESEmulator.PPU.SCREEN_HEIGHT * NESEmulator.PPU.SCREEN_WIDTH
local function update()
    local tickstart = Isaac.GetTime()
    drawn = true
    tickRatetmp = tickRatetmp + 1
    for i, v in ipairs(keyEvents) do
        NESEmulator.Nes.pads[v[1]](NESEmulator.Nes.pads, 1, v[2])
    end
    keyEvents = {}
    NESEmulator.Nes:run_once()
    ticktime = Isaac.GetTime() - tickstart
end

NESEmulator.init()

local function drawPalette()
    local palette = NESEmulator.Nes.cpu.ppu.output_color
    local w, h = 10, 10
    local x, y = 0, 50
    local row, column = 4, 8
    for i = 1, #palette do
        local px = palette[i]
        if px then
            local r = px[1]
            local g = px[2]
            local b = px[3]
            pixel.Color = Color(r, g, b, 1)
            pixel.Scale = Vector(w, h)
            pixel:Render(Vector(x + ((i - 1) % row) * w, y + math.floor((i - 1) / 4) * h))
        end
    end
end

local function drawScreen()
    local pxs = NESEmulator.Nes.cpu.ppu.output_pixels

    local filterStart = Isaac.GetTime()

    -- get every color's frequency
    local max = 0
    local colorsfreq = {}
    local colors = {}
    for i = 1, pixelCount, 6 do --Hacky fix for speed lol -Hannah
        local px = pxs[i]
        local s = px[1] + px[2] + px[3] -- this is a HACK and will BREAK but its okay shhh shh its okay
        colorsfreq[s] = (colorsfreq[s] or 0) + 1
        colors[s] = px
        max = math.max(colorsfreq[s], max)
    end

    -- find the most frequent
    local mostfrequent
    for i, c in pairs(colorsfreq) do
        if c == max then mostfrequent = colors[i] break end
    end

    -- render the most frequent color as the bg
    if mostfrequent then
        pixel.Color = Color(mostfrequent[1], mostfrequent[2], mostfrequent[3], 1)
        pixel.Scale = Vector(width, height)
        pixel:Render(Vector(Isaac.GetScreenWidth()/2 - width/2, Isaac.GetScreenHeight()/2 - height/2))
    end

    pixel.Scale = Vector.One * 1--2.85

    local filterDur = Isaac.GetTime() - filterStart

    local renderStart = Isaac.GetTime()
    for i = 1, pixelCount, 1 do
        local px = pxs[i]
        --if px[1] == 0 then goto continue end
        if px[1] == mostfrequent[1] and px[2] == mostfrequent[2] and px[3] == mostfrequent[3] then goto continue end
        local x = (i - 1) % width
        local y = math.floor((i - 1) / width) % height
        pixel.Color = Color(px[1], px[2], px[3], 1)
        pixel:Render(Vector(Isaac.GetScreenWidth()/2 + x - width/2, Isaac.GetScreenHeight()/2 + y - height/2))
        ::continue::
    end

    Isaac.RenderText(filterDur .. 'ms filter', 0, 0, 1, 1, 1, 1)
    Isaac.RenderText((Isaac.GetTime() - renderStart) .. 'ms render', 0, 12, 1, 1, 1, 1)
    Isaac.RenderText(ticktime .. 'ms update', 0, 24, 1, 1, 1, 1)
end


--[[local string = "NES Global Check: "
for i, var in pairs(_G) do
    local thing = true
    for i2, var2 in pairs(temp) do
        if i == var2 then
            thing = false
        end
    end
    if thing then
        string = string..i..", "
    end
end
print(string)]]


NESPlayer = false
NESEmulator:AddCallback(ModCallbacks.MC_POST_RENDER, function()
    if Game():IsPaused() then return end


    -- handle input
    for i, v in pairs(keyButtons) do
        local down = Input.IsActionPressed(i, 0)
        if down and not isDown[i] then
            print('key down', v)
            table.insert(keyEvents, {'keydown', v})
            isDown[i] = true
        end
        if not down and isDown[i] then
            print('key up', v)
            table.insert(keyEvents, {'keyup', v})
            isDown[i] = false
        end
    end
    
	NESPlayer = false
	for i=0, game:GetNumPlayers() do
		if game:GetPlayer(i):GetPlayerType() == PLAYER_NES then
			NESPlayer = true
		elseif game:GetPlayer(i):GetPlayerType() == PLAYER_GB then
			game:Fadeout(100, 1)
		end
	end
	if NESPlayer and game:GetNumPlayers() > 1 then
		game:Fadeout(100, 1)
	elseif NESPlayer then
        for i=0, game:GetNumPlayers() do
    		game:GetPlayer(i).ControlsEnabled = false
        end
        
        Game():GetHUD():SetVisible(false)
        
        -- update the game
        update()

        -- draw shit
        drawPalette()
        --drawScreen()
        
    end
end)
NESEmulator:AddCallback(ModCallbacks.MC_GET_SHADER_PARAMS, function(shaderName)
    if Game():IsPaused() then return end
    
    if NESPlayer and shaderName == "NES Shader" then
        local palette = NESEmulator.Nes.cpu.ppu.output_color
        local pxs = NESEmulator.Nes.cpu.ppu.output_pixels
        local params = {Palette = palette,--{},
                        Pixels = {},
                        test = {1.0,0.5,1.0}
        }
        for i=1, #palette do
            params.Palette = {palette[i][1], palette[i][2], palette[i][3],}
        end
        for i=1, #pxs do
            params.Pixels[i] = i<#palette and i or 0
        end
        return params
    end
end)