// converts a regular NES rom to lua format

const fs = require('fs');
const rom = fs.readFileSync(process.argv[0] || 'roms/Super Mario Bros (E).nes');
const ints = [];

for (const byte of rom) {
  ints.push(byte);
}

fs.writeFileSync('NES ROM.lua', 'return {' + ints.join(',') + '}');
