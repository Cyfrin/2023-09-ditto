import { promises as fs } from "fs";
import path, { dirname as getDirName } from "path";

async function writeFile(path: string, contents: string) {
  await fs.mkdir(getDirName(path), { recursive: true });
  await fs.writeFile(path, contents);
}

// write gas test values to json to diff
async function combineGasSnapshots() {
  const SNAPSHOTS_DIR = ".forge-snapshots";
  let dirPath = path.join(process.cwd(), SNAPSHOTS_DIR);
  let ext = ".snap";
  let snapshots;

  try {
    snapshots = await fs.readdir(dirPath);
  } catch (e) {
    console.log(`${SNAPSHOTS_DIR}/ is empty`);
    return;
  }

  if (!snapshots) {
    return;
  }

  let gasDiff: {
    [key: string]: [number, number, number];
  } = {};

  let gasPath = path.join(process.cwd(), ".gas.json");

  let newGas: any;
  let oldGas: any;
  let oldString: any;
  try {
    let file = await fs.readFile(gasPath);
    oldString = file.toString();
    newGas = oldGas = JSON.parse(oldString);
  } catch (e) {}

  for (let snapshot of snapshots) {
    // console.log(`reading ${snapshot}`);
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
    if (baseName) {
      let old = +newGas[baseName];
      newGas[baseName] = +parsed;

      let diff = +parsed - +old;
      if (diff !== 0) {
        gasDiff[baseName] = [old, +parsed, diff];
      }
    }
  }

  let sorted = Object.entries(gasDiff)
    .sort(([, [, , a]], [, [, , b]]) => b - a)
    .reduce((r, [k, v]) => ({ ...r, [k]: v[2] }), {});

  try {
    await fs.rm(dirPath, { recursive: true, force: true });

    if (Object.keys(sorted).length > 0) {
      console.log(sorted);
      const ordered = Object.keys(newGas)
        .sort()
        .reduce((obj: any, key) => {
          obj[key] = newGas[key];
          return obj;
        }, {});
      let newString = JSON.stringify(ordered, null, 2);
      await writeFile(gasPath, newString);
      console.log(`wrote to ${gasPath}`);
    }
  } catch {}
}

try {
  (async () => {
    await combineGasSnapshots();
    process.exit(0);
  })();
} catch {
  process.exit(1);
}
