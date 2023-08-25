const fs = require("fs").promises;
const path = require("path");
const getDirName = path.dirname;

const fileExists = async (path) => !!(await fs.stat(path).catch((e) => false));

async function writeFile(path, contents) {
  await fs.mkdir(getDirName(path), { recursive: true });
  await fs.writeFile(path, contents);
}

async function copyAddress() {
  const DEPLOY_DIR = ".deploy-snapshots";
  let dirPath = path.join(process.cwd(), DEPLOY_DIR);
  let ext = ".snap";
  let snapshots;

  let filePath = "nextjs/abi/addresses.ts";
  let exists = await fileExists(filePath);
  let addresses;
  if (exists) {
    let file = await fs.readFile(filePath);

    try {
      let temp = file.toString().substring(15);
      addresses = JSON.parse(temp);
    } catch (e) {
      throw e;
    }
  } else {
    addresses = {
      1: {},
      31337: {},
    };
  }

  try {
    snapshots = await fs.readdir(dirPath);
  } catch (e) {
    console.log(`nothing in ${DEPLOY_DIR}/ to copy`);
    return;
  }
  if (!snapshots) {
    return;
  }

  for (let snapshot of snapshots) {
    let filePath = path.join(dirPath, snapshot);
    if (!filePath.endsWith(ext)) {
      continue;
    }

    let parsed;
    try {
      let file = await fs.readFile(filePath);
      parsed = file.toString();
    } catch (e) {
      throw e;
    }

    let baseName = path.basename(snapshot).slice(0, -1 * +ext.length);
    let contract = baseName.split("-")[0];
    let chainId = Number(baseName.split("-")[1]);

    if (chainId == 1 || chainId == 31337) {
      addresses[chainId][contract] = parsed;
    }
  }

  let deployPath = path.join(process.cwd(), filePath);
  try {
    await fs.rm(dirPath, { recursive: true, force: true });
    let newString = `export default ${JSON.stringify(addresses, null, 2)}`;
    await writeFile(deployPath, newString);
  } catch {}

  console.log(`Contract Addresses Copied to ${deployPath}`);
}

try {
  (async () => {
    await copyAddress();
    process.exit(0);
  })();
} catch {
  process.exit(1);
}
