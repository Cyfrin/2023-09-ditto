import path from "path";
import { promises as fs } from "fs";

async function extractJSON(
  dir: string,
  key: string,
  json: { [key: string]: string } = {}
) {
  let ret: { [key: string]: string } = {};
  try {
    let files = await fs.readdir(dir);
    // only facet contracts for now
    files = files.filter(
      (f) => f.endsWith("Facet.sol") || f.endsWith("Facet.json")
    );
    // files = files.filter((f) => !f.endsWith("t.sol"));
    for (const file of files) {
      const filePath = path.join(dir, file);
      const stat = await fs.stat(filePath);

      if (stat && stat.isDirectory()) {
        ret = Object.assign(await extractJSON(filePath, key, json), ret);
      } else {
        const content = await fs.readFile(filePath, "utf-8");
        const parsed = JSON.parse(content);
        ret = Object.assign(ret, parsed[key]);
      }
    }
  } catch (err) {
    console.error(err);
  }
  return ret;
}

const ARTIFACTS_DIR = "./foundry/artifacts";
const GENERATED_WAGMI_PATH = "nextjs/abi/generated.ts";
const SIGNATURES_PATH = "nextjs/abi/signatures.ts";
const ABI_PATH = "nextjs/abi/abi.ts";
let str = `export const signatures: { [key: string]: string } = `;

// create object of 4bytes signatures against interface def
// e.g. "70a08231": "balanceOf(address)"
async function writeSignatures() {
  let signatures: {
    [key: string]: string;
  } = {};

  try {
    let methodIdentifiers = await extractJSON(
      ARTIFACTS_DIR,
      "methodIdentifiers"
    );
    Object.entries(methodIdentifiers).forEach(([method, sig]) => {
      if (signatures[sig]) {
        console.log("WARN: same sig -", sig, signatures[sig], method);
      }
      signatures[sig] = method;
    });
    await fs.writeFile(
      SIGNATURES_PATH,
      str + JSON.stringify(signatures, null, 2)
    );
  } catch (err) {
    console.error(err);
  }
}

async function copyABI() {
  const content = await fs.readFile(GENERATED_WAGMI_PATH, "utf-8");
  const sliceStart = content.indexOf("export const");
  const sliceEnd = content.indexOf("export function");
  return content.slice(sliceStart, sliceEnd);
}

try {
  (async () => {
    await writeSignatures();
    await fs.writeFile(ABI_PATH, await copyABI());
    process.exit(0);
  })();
} catch {
  process.exit(1);
}
