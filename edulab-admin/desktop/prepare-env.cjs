const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const target = path.join(__dirname, "runtime.env");
const candidates = [
  path.join(root, ".env"),
  path.join(root, ".env.local"),
  path.join(root, ".env.production"),
];

const source = candidates.find((file) => fs.existsSync(file));
if (!source) {
  fs.writeFileSync(
    target,
    [
      "# Runtime env was not found during packaging.",
      "# Create ~/Library/Application Support/LabProof Admin/admin.env",
      "# with the same keys as .env.example if the packaged app needs config.",
      "",
    ].join("\n"),
  );
  console.warn("No .env file found. Created an empty desktop/runtime.env.");
  process.exit(0);
}

fs.copyFileSync(source, target);
console.log(`Copied ${path.basename(source)} to desktop/runtime.env for packaging.`);
