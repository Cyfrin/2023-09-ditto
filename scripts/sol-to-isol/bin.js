const path = require("path");
const fs = require("fs");
const { readdir } = require("fs/promises");
const MD5 = require("crypto-js/md5");
const generateInterface = require("./");

const myArgs = process.argv.slice(2);
let dirname = path.join(process.cwd(), "interfaces");
let force = myArgs.find((a) => a === "--force");
let quiet = myArgs.find((a) => a === "--quiet");
let clear = myArgs.find((a) => a === "--clear");

async function getContracts(folder) {
  let contracts = [];

  const files = await readdir(folder, { withFileTypes: true });
  for (const file of files) {
    const nestedPath = path.join(folder, file.name);

    if (file.isDirectory()) {
      const nestedContracts = await getContracts(nestedPath);
      contracts.push(...nestedContracts);
    } else {
      contracts.push(nestedPath);
    }
  }

  return contracts;
}

function isCached(file) {
  if (force) return true;

  try {
    let absFile = path.join(process.cwd(), file);
    let fileContent = fs.readFileSync(absFile, {
      encoding: "utf-8",
      flag: "r",
    });
    let md5 = MD5.hash(fileContent, "hex");

    let cache = fs.readFileSync(
      path.join(process.cwd(), "/foundry/cache/solidity-files-cache.json"),
      {
        encoding: "utf-8",
        flag: "r",
      }
    );

    if (cache) {
      if (JSON.parse(cache).files[file].contentHash === md5) {
        return false;
      } else {
        // console.log(file);
      }
    }
  } catch (e) {}

  return true;
}

if (clear) {
  fs.rmSync(dirname, { recursive: true, force: true });
}

// if folder is deleted, force generate anyway
if (!fs.existsSync(dirname)) {
  force = true;
}

let options = {
  facets: [],
};

(async function run() {
  let files = await getContracts("contracts");

  files.push("test/utils/OBFixture.sol");

  files
    .filter((f) => {
      return !(
        path.basename(f).endsWith("Interface.sol") ||
        path.basename(f).startsWith("I") ||
        path.basename(f).includes(".t.sol") ||
        f.includes("contracts/governance/") ||
        (f.includes("contracts/libraries/") &&
          !path.basename(f).endsWith("console.sol"))
      );
    })
    .filter(isCached)
    .sort((a, b) => {
      // last
      if (path.basename(b).endsWith("Diamond.sol")) {
        return -1;
      } else {
        return a - b;
      }
    })
    .forEach((file) => {
      let absFile = path.join(process.cwd(), file);
      let src = fs.readFileSync(absFile, {
        encoding: "utf-8",
        flag: "r",
      });
      options.path = file;
      options.allStructs = [];
      options.addedStructs = new Set();
      options.addedImports = new Set();
      let interfaceNew = generateInterface(src, options);

      // no interface for abstract contracts
      if (
        interfaceNew &&
        !src.includes(`abstract contract ${path.basename(file).slice(0, -4)}`)
      ) {
        if (!fs.existsSync(dirname)) {
          fs.mkdirSync(dirname);
        }

        let interfacePath = path.join(dirname, `I${path.basename(file)}`);

        if (fs.existsSync(interfacePath)) {
          let interfaceSrc = fs.readFileSync(interfacePath, {
            encoding: "utf-8",
            flag: "r",
          });

          if (interfaceNew !== interfaceSrc) {
            fs.writeFileSync(interfacePath, interfaceNew);
            if (!quiet) console.log("edit:", file);
          }
        } else {
          fs.writeFileSync(interfacePath, interfaceNew);
          if (!quiet) console.log("+new:", file);
        }
      }
    });
})();
