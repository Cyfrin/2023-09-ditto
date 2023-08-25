import { promises as fs } from "fs";
import path, { dirname as getDirName } from "path";

type StringDict = {
  [key: string]: string;
};

async function extractJSON(dir: string, key: string, json: StringDict) {
  try {
    let files = await fs.readdir(dir);
    files = files.filter((f) => !f.endsWith("t.sol"));
    for (const file of files) {
      const filePath = path.join(dir, file);
      const stat = await fs.stat(filePath);

      if (stat && stat.isDirectory()) {
        await extractJSON(filePath, key, json);
      } else {
        const content = await fs.readFile(filePath, "utf-8");
        const parsed = JSON.parse(content);
        json = Object.assign(json, parsed[key]);
      }
    }
  } catch (err) {
    console.error(err);
  }
}

async function getSignatures() {
  const ARTIFACTS_DIR = "./foundry/artifacts";
  let signatures: StringDict = {};
  try {
    let methodIdentifiers: StringDict = {};
    await extractJSON(ARTIFACTS_DIR, "methodIdentifiers", methodIdentifiers);
    Object.entries(methodIdentifiers).forEach(([method, sig]) => {
      if (signatures[sig]) {
        console.log("WARN: same sig -", sig, signatures[sig], method);
      }
      signatures[sig] = method;
    });
    await fs.writeFile(".signatures.json", JSON.stringify(signatures, null, 2));
  } catch (err) {
    console.error(err);
  }
}

try {
  (async () => {
    await getSignatures();
    process.exit(0);
  })();
} catch {
  process.exit(1);
}
