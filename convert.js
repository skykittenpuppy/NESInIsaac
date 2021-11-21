// converts a regular NES rom to lua format

const fs = require('fs');
const rom = fs.readFileSync('roms/Super Mario Bros (E).nes');
const ints = [];

for (const byte of rom) {
  ints.push(byte);
}

fs.writeFileSync('_rom.lua', 'return {' + ints.join(',') + '}');