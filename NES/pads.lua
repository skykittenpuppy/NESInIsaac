local band, bor, bxor, bnot, lshift, rshift = NESEmulator.bit.band, NESEmulator.bit.bor, NESEmulator.bit.bxor, NESEmulator.bit.bnot, NESEmulator.bit.lshift, NESEmulator.bit.rshift
local map, rotatePositiveIdx, nthBitIsSet, nthBitIsSetInt =
  NESEmulator.UTILS.map,
  NESEmulator.UTILS.rotatePositiveIdx,
  NESEmulator.UTILS.nthBitIsSet,
  NESEmulator.UTILS.nthBitIsSetInt

NESEmulator.Pads = {}
NESEmulator.Pads._mt = {__index = NESEmulator.Pads}
function NESEmulator.Pads:new(conf, cpu, apu)
  local pads = {}
  setmetatable(pads, NESEmulator.Pads._mt)
  pads:initialize(conf, cpu, apu)
  return pads
end
function NESEmulator.Pads:initialize(conf, cpu, apu)
  self.conf = conf
  self.cpu = cpu
  self.apu = apu
  self.pads = {NESEmulator.Pad:new(), NESEmulator.Pad:new()}
end

function NESEmulator.Pads:reset()
  self.cpu:add_mappings(0x4016, NESEmulator.UTILS.bind(self.peek_401x, self), NESEmulator.UTILS.bind(self.poke_4016, self))
  self.cpu:add_mappings(0x4017, NESEmulator.UTILS.bind(self.peek_401x, self), NESEmulator.UTILS.bind(self.apu.poke_4017, self.apu)) -- delegate 4017H to APU
  self.pads[1]:reset()
  self.pads[2]:reset()
end

function NESEmulator.Pads:peek_401x(addr)
  self.cpu:update()
  return bor(self.pads[addr - 0x4016 + 1]:peek(), 0x40)
end

function NESEmulator.Pads:poke_4016(_addr, data)
  self.pads[1]:poke(data)
  self.pads[2]:poke(data)
end

-- APIs

function NESEmulator.Pads:keydown(pad, btn)
  self.pads[pad].buttons = bor(self.pads[pad].buttons, lshift(1, btn))
end

function NESEmulator.Pads:keyup(pad, btn)
  self.pads[pad].buttons = band(self.pads[pad].buttons, bnot(lshift(1, btn)))
end

-- each pad
NESEmulator.Pad = NESEmulator.UTILS.class()
NESEmulator.Pad.A = 0
NESEmulator.Pad.B = 1
NESEmulator.Pad.SELECT = 2
NESEmulator.Pad.START = 3
NESEmulator.Pad.UP = 4
NESEmulator.Pad.DOWN = 5
NESEmulator.Pad.LEFT = 6
NESEmulator.Pad.RIGHT = 7

function NESEmulator.Pad:initialize()
  self:reset()
end

function NESEmulator.Pad:reset()
  self.strobe = false
  self.buttons = 0
  self.stream = 0
end

function NESEmulator.Pad:poke(data)
  local prev = self.strobe
  self.strobe = nthBitIsSetInt(data, 0) == 1
  if prev and not self.strobe then
    self.stream = bxor(lshift(self:poll_state(), 1), -512)
  end
end

function NESEmulator.Pad:peek()
  if self.strobe then
    return band(self:poll_state(), 1)
  end
  self.stream = rshift(self.stream, 1)
  return nthBitIsSetInt(self.stream, 0)
end

function NESEmulator.Pad:poll_state()
  local state = self.buttons

  -- prohibit impossible simultaneous keydown (right and left, up and down)
  -- 0b00110000
  if band(state, 0x30) == 0x30 then
    state = band(state, 0xff - 0x30)
  end
  --0b00111111
  if band(state, 0xc0) == 0xc0 then
    state = band(state, 0xff - 0xc0)
  end

  return state
end
