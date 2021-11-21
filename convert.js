// converts a regular NES rom to lua format

const infile = __dirname + '/' + (process.argv[2] || 'roms/Super Mario Bros (E).nes');
const outfile = __dirname + '/NES ROM.lua';

const fs = require('fs');
if (fs.existsSync(outfile)) fs.unlinkSync(outfile);
const out = fs.createWriteStream(outfile);

out.on('open', () => {
  const rom = fs.createReadStream(infile, {
    highWaterMark: 1024
  });

  out.write('return {');

  rom.on('data', chunk => {
    for (const byte of chunk) {
      out.write(`${byte}, `);
    }
  });

  rom.on('close', () => {
    out.write('}');
    out.close();
  });
});
