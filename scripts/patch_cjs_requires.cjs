const fs = require('fs');
const path = require('path');

function fixFile(file) {
  let src = fs.readFileSync(file, 'utf8');
  // replace require('./something.js') or require('../x/y.js') with .cjs
  src = src.replace(/require\((['"])(\.\.?[\/][^'"]+?)\.js\1\)/g, (m, q, p) => `require(${q}${p}.cjs${q})`);
  fs.writeFileSync(file, src, 'utf8');
}

function walk(dir) {
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, ent.name);
    if (ent.isDirectory()) walk(full);
    else if (ent.isFile() && full.endsWith('.cjs')) fixFile(full);
  }
}

const root = path.resolve(process.cwd(), 'dist');
if (!fs.existsSync(root)) {
  console.error('dist not found'); process.exit(2);
}
walk(root);
console.log('patched .cjs requires');
