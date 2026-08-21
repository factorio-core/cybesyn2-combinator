import fs from 'fs-extra';
import { execSync, spawn } from 'child_process';
import path from 'path';

const isWatch = process.argv.includes('--watch');
const rootDir = process.cwd();
const staticDir = path.join(rootDir, 'static');
const distDir = path.join(rootDir, 'dist');

async function build() {
  console.log('[Build] Cleaning dist/...');
  await fs.emptyDir(distDir);

  console.log('[Build] Compiling TypeScript using TSTL...');
  try {
    execSync('npx tstl', { stdio: 'inherit' });

    if (await fs.pathExists(staticDir)) {
      console.log('[Build] Copying static/ assets to dist/...');
      await fs.copy(staticDir, distDir);
    }

    console.log('[Build] Success! Compiled mod output is ready in ./dist/');
  } catch (err) {
    console.error('[Build] Error: TSTL compilation failed.');
  }
}

if (isWatch) {
  await build();
  console.log('[Watch] Starting TSTL watch mode...');
  const child = spawn('npx', ['tstl', '--watch'], { stdio: 'inherit', shell: true });
  child.on('close', (code) => {
    console.log(`[Watch] TSTL process exited with code ${code}`);
  });
} else {
  await build();
}
