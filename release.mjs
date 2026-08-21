import fs from 'fs-extra';
import path from 'path';
import { execSync } from 'child_process';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function release() {
  console.log('[Release] Reading package.json...');
  const pkgPath = path.join(__dirname, 'package.json');
  const pkgInfo = await fs.readJson(pkgPath);
  const version = pkgInfo.version;
  const modName = pkgInfo.name;
  
  if (!version) {
    console.error('No version found in package.json');
    process.exit(1);
  }

  console.log(`[Release] Version: ${version}`);
  console.log('[Release] Updating static/info.json...');
  const infoPath = path.join(__dirname, 'static', 'info.json');
  const infoJson = await fs.readJson(infoPath);
  infoJson.version = version;
  await fs.writeJson(infoPath, infoJson, { spaces: 2 });

  console.log('[Release] Building mod...');
  execSync('npm run build', { stdio: 'inherit', cwd: __dirname });

  const releaseFolderName = `${modName}_${version}`;
  const distPath = path.join(__dirname, 'dist');
  const tempDir = path.join(__dirname, 'dist_temp_release');
  const releaseFolderPath = path.join(tempDir, releaseFolderName);
  const releasesDir = path.join(__dirname, 'releases');
  const zipName = `${releaseFolderName}.zip`;
  const zipPath = path.join(releasesDir, zipName);

  await fs.ensureDir(releasesDir);

  console.log(`[Release] Preparing release folder: ${releaseFolderName}...`);
  if (await fs.pathExists(tempDir)) {
    await fs.remove(tempDir);
  }
  await fs.ensureDir(releaseFolderPath);
  await fs.copy(distPath, releaseFolderPath);

  // Remove typescript declaration and map files from factorio mod zip
  const cleanFiles = async (dir) => {
    const entries = await fs.readdir(dir, { withFileTypes: true });
    for (const entry of entries) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        await cleanFiles(full);
      } else if (entry.isFile() && (entry.name.endsWith('.d.ts') || entry.name.endsWith('.tsbuildinfo') || entry.name.endsWith('.js.map'))) {
        await fs.remove(full);
      }
    }
  };
  await cleanFiles(releaseFolderPath);

  if (await fs.pathExists(zipPath)) {
    await fs.remove(zipPath);
  }

  console.log(`[Release] Zipping to releases/${zipName}...`);
  // Use PowerShell Compress-Archive on Windows
  const psCommand = `Compress-Archive -Path "${releaseFolderPath}" -DestinationPath "${zipPath}" -Force`;
  execSync(`powershell -Command "${psCommand}"`, { stdio: 'inherit' });

  // Clean up the temporary release folder
  console.log('[Release] Cleaning up temporary folder...');
  await fs.remove(tempDir);

  console.log(`[Release] Done! Archive created at: ${zipPath}`);
}

release().catch(err => {
  console.error(err);
  process.exit(1);
});
