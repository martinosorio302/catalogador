const fs = require('fs');
const path = require('path');

function copyJsToCjs(dir) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const ent of entries) {
    const full = path.join(dir, ent.name);
    if (ent.isDirectory()) copyJsToCjs(full);
    else if (ent.isFile() && full.endsWith('.js')) {
      const target = full.replace(/\.js$/, '.cjs');
      // copy file if target missing or source is newer
      let doCopy = true;
      try {
        const sStat = fs.statSync(full);
        const tStat = fs.statSync(target);
        if (tStat.mtimeMs >= sStat.mtimeMs) doCopy = false;
      } catch (e) {
        // target missing — proceed
      }
      if (doCopy) {
        fs.copyFileSync(full, target);
        console.log('copied', full, '→', target);
      }
    }
  }
}

const root = path.resolve(process.cwd(), 'dist');
if (!fs.existsSync(root)) {
  console.error('dist directory not found, build first');
  process.exit(2);
}
copyJsToCjs(root);
console.log('done');
