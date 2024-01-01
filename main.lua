NESEmulator = RegisterMod('NES Emulator', 1)
include = include or require
local game = Game();

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
local backupROMLoaded = fals
local _rom_encoded = include('NES ROM')
if type(_rom_encoded) == "string" then
    backupROMLoaded = true
    _rom_encoded = include('NES ROM Default')
end

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

local NESScreenSize = Vector(256, 240)
local ScreenSize = Vector(Isaac.GetScreenWidth(), Isaac.GetScreenHeight())
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
            print("Col"..i..": "..px[1]..", "..px[2]..", "..px[3])
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

    local renderStart = Isaac.GetTime()

    local BGColour = NESEmulator.Nes.cpu.ppu.output_color[1] or {0,0,0}
	if REPENTOGON then
		local colour = KColor(BGColour[1], BGColour[2], BGColour[3], 1)
		Isaac.DrawQuad(
			ScreenSize/2 - NESScreenSize/2,
			ScreenSize/2 + Vector(1,-1)*NESScreenSize/2,
			ScreenSize/2 - Vector(1,-1)*NESScreenSize/2,
			ScreenSize/2 + NESScreenSize/2,
			colour, 0
		)
		for i = 1, pixelCount, 1 do
			local px = pxs[i]
			if px[1] ~= BGColour[1] or px[2] ~= BGColour[2] or px[3] ~= BGColour[3] then
				colour = KColor(px[1], px[2], px[3], 1)
				local pos = ScreenSize - NESScreenSize + Vector(
					(i - 1) % NESScreenSize.X,
					math.floor((i - 1) / NESScreenSize.X) % NESScreenSize.Y
				)
				Isaac.DrawQuad(pos, pos, pos, pos, colour, 0)
			end
		end
	else
		pixel.Scale = NESScreenSize
		pixel.Color = Color(BGColour[1], BGColour[2], BGColour[3], 1)
		pixel:Render(ScreenSize/2 - NESScreenSize/2)

		pixel.Scale = Vector.One
		for i = 1, pixelCount, 1 do
			local px = pxs[i]
			if px[1] ~= BGColour[1] or px[2] ~= BGColour[2] or px[3] ~= BGColour[3] then
				pixel.Color = Color(px[1], px[2], px[3], 1)
				pixel:Render(ScreenSize - NESScreenSize + Vector(
					(i - 1) % NESScreenSize.X,
					math.floor((i - 1) / NESScreenSize.X) % NESScreenSize.Y
				))
			end
		end
	end

    local font = Font()
    font:Load("font/terminus.fnt")
    local h = font:GetLineHeight()
    font:DrawString((Isaac.GetTime() - renderStart) .. 'ms render', 10, h*1, KColor(1, 1, 1, 1))
    font:DrawString(ticktime .. 'ms update', 10, h*2, KColor(1, 1, 1, 1))
    if backupROMLoaded then
        font:DrawString("NO ROM LOADED, REVERTED TO DEFAULT", ScreenSize.X/2-1, h*2, KColor(1, 0, 0, 1), 2, true)
    end
    font:DrawString("D-Pad = Shoot", ScreenSize.X-11, ScreenSize.Y/2+(h*-2), KColor(1, 1, 1, 1), 1)
    font:DrawString("A = Confirm",   ScreenSize.X-11, ScreenSize.Y/2+(h*-1), KColor(1, 1, 1, 1), 1)
    font:DrawString("B = Back",      ScreenSize.X-11, ScreenSize.Y/2+(h* 0), KColor(1, 1, 1, 1), 1)
    font:DrawString("Select = Map",  ScreenSize.X-11, ScreenSize.Y/2+(h* 1), KColor(1, 1, 1, 1), 1)
    font:DrawString("Start = Drop",  ScreenSize.X-11, ScreenSize.Y/2+(h* 2), KColor(1, 1, 1, 1), 1)
end


local NESPlayer
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
        --update()

		ScreenSize = Vector(ScreenSize.X, ScreenSize.Y)

        -- draw shit
        drawPalette()
        drawScreen()
        
        -- update the game (it thinks this comes after rendering actually)
        update()
    end
end)