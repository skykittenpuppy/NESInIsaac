include "NES/libs/serpent"
include "NES/utils"
include "NES/cpu"
include "NES/ppu"
include "NES/apu"
include "NES/rom"
include "NES/palette"
include "NES/pads"

local band, bor, bxor, bnot, lshift, rshift = NESEmulator.bit.band, NESEmulator.bit.bor, NESEmulator.bit.bxor, NESEmulator.bit.bnot, NESEmulator.bit.lshift, NESEmulator.bit.rshift
local map, rotatePositiveIdx, nthBitIsSet, nthBitIsSetInt =
    NESEmulator.UTILS.map,
    NESEmulator.UTILS.rotatePositiveIdx,
    NESEmulator.UTILS.nthBitIsSet,
    NESEmulator.UTILS.nthBitIsSetInt

NESEmulator.NES = {}
NESEmulator.NES._mt = {__index = NESEmulator.NES}

function NESEmulator.NES:reset()
    self.audio, self.video, self.input = {spec = {}}, {palette = {}}, {}

    local cpu = self.cpu
    cpu:reset()
    cpu.apu:reset(self.audio.spec)
    cpu.ppu:reset()
    self.rom:reset()
    self.pads:reset()
    cpu:boot()
    self.rom:load_battery()
end
function NESEmulator.NES:run_once()
    local startSetup = Isaac.GetTime()
    self.cpu.ppu:setup_frame()
    print('setup', Isaac.GetTime() - startSetup)
    self.cpu:run()
    print('run', Isaac.GetTime() - startSetup)
    self.cpu.ppu:vsync()
    print('ppu vsync', Isaac.GetTime() - startSetup)
    --print "ppu vsync"
    --print(self.cpu.clk)
    --self.cpu.apu:vsync()
    --print "apu vsync"
    --print(self.cpu.clk)
    self.cpu:vsync()
    print('cpu vsync', Isaac.GetTime() - startSetup)
    self.rom:vsync()
    print('rom vsync', Isaac.GetTime() - startSetup)

    self.frame = self.frame + 1
end
function NESEmulator.NES:run(counter)
    self:reset()
    if not counter then
        while true do
            self:run_once()
        end
    end
    local acum = 0
    while acum < counter do
        self:run_once()
        acum = acum + 1
    end
end
function NESEmulator.NES:new(opts)
    Isaac.DebugString('creating new NES instance')
    opts = opts or {}
    local conf = {romfile = opts.file, pc = opts.pc or nil, loglevel = opts.loglevel or 0, blob = opts.blob}
    local nes = {}
    local palette = opts.palette or NESEmulator.PALETTE:defacto_palette()
    setmetatable(nes, NESEmulator.NES._mt)
    Isaac.DebugString('creating CPU')
    nes.cpu = NESEmulator.CPU:new(conf)
    Isaac.DebugString('creating APU')
    nes.cpu.apu = NESEmulator.APU:new(conf, nes.cpu)
    --[[
        clock_dma = function(clk)
        end,
        reset = function()
        end,
        vsync = function()
        end,
        do_clock = function()
            return CPU.CLK[1]
        end
    }
    ]]
    --[[
    nes.cpu.ppu = {
        reset = function()
        end,
        vsync = function()
        end,
        setup_frame = function()
        end,
        sync = function(clk)
        end
    }
    --]]
    Isaac.DebugString('creating PPU')
    nes.cpu.ppu = NESEmulator.PPU:new(conf, nes.cpu, palette)
    nes.pads = {
        reset = function()
        end
    }
    Isaac.DebugString('loading ROM')
    nes.rom = NESEmulator.ROM.load(conf, nes.cpu, nes.cpu.ppu)
    Isaac.DebugString('creating pads')
    nes.pads = NESEmulator.Pads:new(conf, nes.cpu, nes.cpu.apu)

    nes.frame = 0
    nes.frame_target = nil

    Isaac.DebugString('done')

    return nes
end
