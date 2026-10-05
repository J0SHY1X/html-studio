const path = require("node:path");

const supportedExtensions = new Set([".html", ".htm", ".md", ".markdown"]);

function filePathsFromArguments(argumentsList, workingDirectory = process.cwd()) {
  return [...new Set(argumentsList.filter((argument) => (
    typeof argument === "string" && !argument.startsWith("-") &&
    supportedExtensions.has(path.extname(argument).toLowerCase())
  )).map((argument) => path.resolve(workingDirectory, argument)))];
}

module.exports = { filePathsFromArguments };
