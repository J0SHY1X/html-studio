const { spawnSync } = require("node:child_process");

const cli = require.resolve("electron-builder/cli.js");

for (const target of ["nsis", "portable"]) {
  const result = spawnSync(
    process.execPath,
    [cli, "--win", target, "--x64"],
    { stdio: "inherit" }
  );

  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status || 1);
}
