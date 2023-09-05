import path from "path";
import fs from "fs";

// check foundry version
async function checkForgeVersion(throwError = true) {
  let ciVersion = "";
  let localVersion = "";
  let wp = fs.readFileSync(
    path.join(process.cwd(), "./.gitea/workflows/ci.yml"),
    {
      encoding: "utf-8",
      flag: "r",
    }
  );

  let commit = wp.match(/nightly-([\dabcdef]+)/);
  if (commit) {
    ciVersion = commit[1].slice(0, 7);
  } else {
    throw "no foundry version found in preforge.ts";
  }

  const proc = Bun.spawn(["forge", "--version"], {});
  const stdout = await new Response(proc.stdout).text();
  let match = stdout.match(/\(([\dabcdef]{7})/);
  if (match) {
    localVersion = match[1];
    if (ciVersion !== localVersion) {
      console.log(
        `⚙️  forge version is out of date! Please update to version in /scripts/preforge.ts Install with:`
      );
      console.log(`foundryup -v nightly-${commit[1]}`);
      if (throwError) {
        throw "";
      }
    }
  } else {
    throw "cannot find version from `forge --verison`, is it installed?";
  }
}

if (!process.env.CI) {
  (async () => {
    try {
      await checkForgeVersion(true); // throw on error
    } catch (e) {
      process.exit(1);
    }
  })();
}
