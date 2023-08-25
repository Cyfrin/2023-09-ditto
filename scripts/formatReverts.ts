import { promises as fs } from "fs";
import path, { dirname as getDirName } from "path";

async function writeFile(path: string, contents: string) {
  await fs.mkdir(getDirName(path), { recursive: true });
  await fs.writeFile(path, contents);
}

async function formatReverts() {
  const SNAPSHOTS_DIR = ".forge-snapshots";
  const REVERTS_DIR = `${SNAPSHOTS_DIR}/reverts`;
  let dirPath = path.join(process.cwd(), REVERTS_DIR);
  let folderPath = path.join(process.cwd(), SNAPSHOTS_DIR);
  let snapshot;

  try {
    snapshot = (await fs.readdir(dirPath))[0];
  } catch (e) {
    console.log(`${REVERTS_DIR}/ is empty`);
    return;
  }

  if (!snapshot) {
    return;
  }

  let revertPath = path.join(process.cwd(), ".revert.json");
  let newRevert: any;
  let oldRevert: any;
  let oldString: any;
  try {
    let file = await fs.readFile(revertPath);
    oldString = file.toString();
    newRevert = oldRevert = JSON.parse(oldString);
  } catch (e) {}

  let revertDiff: {
    [key: string]: [number, number, number];
  } = {};

  let filePath = path.join(dirPath, snapshot);
  let ext = ".snap";
  if (!filePath.endsWith(ext)) {
    return;
  }

  let parsed;
  try {
    let file = await fs.readFile(filePath);
    parsed = file.toString();
  } catch (e) {
    throw e;
  }

  //leave this console here
  console.log(parsed);
  let parsedArray = parsed.split(/\r?\n/);
  parsedArray = parsedArray.filter((line) => line.includes("statefulFuzz"));
  parsedArray.forEach((line) => {
    let testName = line.match(/statefulFuzz_.*?\(\)/);
    let calls = line.match(/(?<=calls: )\d*[^,]/);
    let reverts = line.match(/(?<=reverts: )\d*[^)]/);
    if (testName?.length && calls?.length && reverts?.length) {
      let percent = (Number(reverts[0]) / Number(calls[0])) * 100;
      let old = +newRevert[testName[0]];
      if (Number.isNaN(old)) {
        old = 0;
      }
      newRevert[testName[0]] = percent;
      let diff = percent - +old;
      if (diff !== 0) {
        revertDiff[testName[0]] = [old, percent, diff];
      }
    }
  });

  let sorted = Object.entries(revertDiff)
    .sort(([, [, , a]], [, [, , b]]) => b - a)
    .reduce((r, [k, v]) => ({ ...r, [k]: v[2] }), {});

  try {
    await fs.rm(folderPath, { recursive: true, force: true });

    if (Object.keys(sorted).length > 0) {
      console.log("Revert Rates in %");
      console.log(sorted);
      const ordered = Object.keys(newRevert)
        .sort()
        .reduce((obj: any, key) => {
          obj[key] = newRevert[key];
          return obj;
        }, {});
      let newString = JSON.stringify(ordered, null, 2);
      await writeFile(revertPath, newString);
      console.log(`wrote to ${revertPath}`);
    }
  } catch {}
}

try {
  (async () => {
    await formatReverts();
    process.exit(0);
  })();
} catch {
  process.exit(1);
}
