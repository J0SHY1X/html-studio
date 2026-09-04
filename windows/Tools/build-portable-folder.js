const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const asar = require("@electron/asar");
const { editWindowsResources } = require("app-builder-lib/out/util/resEdit.js");

const root = path.resolve(__dirname, "..");
const baseDirectory = path.join(root, "dist", "win-unpacked");
const outputDirectory = path.join(
  root,
  "dist",
  "HTML Studio-0.3.8-x64-Portable"
);
const baseAsar = path.join(baseDirectory, "resources", "app.asar");
const outputAsar = path.join(outputDirectory, "resources", "app.asar");
const outputExecutable = path.join(outputDirectory, "HTML Studio.exe");
const iconPath = path.join(root, "build", "icon.ico");

async function exists(target) {
  return fs.access(target).then(() => true).catch(() => false);
}

async function main() {
  if (!(await exists(baseAsar))) {
    throw new Error("Missing dist/win-unpacked/resources/app.asar");
  }
  if (await exists(outputDirectory)) {
    throw new Error(`Output already exists: ${outputDirectory}`);
  }

  const workDirectory = await fs.mkdtemp(
    path.join(os.tmpdir(), "html-studio-windows-portable-")
  );
  const extractedApp = path.join(workDirectory, "app");
  const rebuiltAsar = path.join(workDirectory, "app.asar");

  await fs.cp(baseDirectory, outputDirectory, { recursive: true });
  asar.extractAll(baseAsar, extractedApp);
  await fs.cp(path.join(root, "src"), path.join(extractedApp, "src"), {
    recursive: true,
    force: true
  });
  await fs.copyFile(
    path.join(root, "package.json"),
    path.join(extractedApp, "package.json")
  );
  await asar.createPackage(extractedApp, rebuiltAsar);
  await fs.copyFile(rebuiltAsar, outputAsar);

  await editWindowsResources({
    file: outputExecutable,
    iconPath,
    fileVersion: "0.3.8",
    productVersion: "0.3.8",
    versionStrings: {
      CompanyName: "Codex",
      FileDescription: "HTML Studio",
      InternalName: "HTML Studio",
      OriginalFilename: "HTML Studio.exe",
      ProductName: "HTML Studio",
      LegalCopyright: "Copyright © 2026"
    }
  });

  process.stdout.write(`${outputDirectory}\n`);
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exit(1);
});
