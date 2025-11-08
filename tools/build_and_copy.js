#!/usr/bin/env node
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

function run(cmd) {
  console.log('[build_and_copy]>', cmd);
  execSync(cmd, { stdio: 'inherit' });
}

const repoRoot = path.resolve(__dirname, '..');
const srcDir = path.join(repoRoot, 'src');
const srcDist = path.join(srcDir, 'dist');
const dest = path.join(repoRoot, 'dist', 'web');

try {
  // install deps in src and build
  run('npm --prefix "' + srcDir + '" ci');
  run('npm --prefix "' + srcDir + '" run build');

  // remove dest if exists
  if (fs.existsSync(dest)) {
    fs.rmSync(dest, { recursive: true, force: true });
  }
  fs.mkdirSync(dest, { recursive: true });

  // copy files recursively
  const copyRecursive = (src, dst) => {
    const entries = fs.readdirSync(src, { withFileTypes: true });
    for (const e of entries) {
      const srcPath = path.join(src, e.name);
      const dstPath = path.join(dst, e.name);
      if (e.isDirectory()) {
        fs.mkdirSync(dstPath, { recursive: true });
        copyRecursive(srcPath, dstPath);
      } else if (e.isFile()) {
        fs.copyFileSync(srcPath, dstPath);
      }
    }
  };

  if (fs.existsSync(srcDist)) {
    copyRecursive(srcDist, dest);
    console.log('[build_and_copy] copied', srcDist, '->', dest);
  } else {
    console.error('[build_and_copy] ERROR: src/dist does not exist. Run the build step in src and check output.');
    process.exit(2);
  }

  console.log('[build_and_copy] Done');
} catch (err) {
  console.error('[build_and_copy] FAILED', err);
  process.exit(1);
}
