import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

// A conservative source inventory, not a claim that every build dependency ships.
const root = fileURLToPath(new URL("../", import.meta.url));
const output = path.join(root, "output", "release-license-audit");
const fetchUpstream = process.argv.includes("--fetch-upstream");
const upstreamCache = new Map();
async function githubJson(url) {
  const response = await fetch(url, { headers: { "User-Agent": "heni-license-audit" }, signal: AbortSignal.timeout(30000) });
  if (!response.ok) throw new Error(`GitHub ${response.status}: ${url}`);
  return response.json();
}
async function upstreamLicenses(pkg) {
  const repository = typeof pkg.repository === "string" ? pkg.repository.replace(/\.git\/?$/, "").replace(/\/$/, "") : "";
  const revision = pkg.revision?.git?.sha1;
  if (!/^https:\/\/github\.com\/[\w.-]+\/[\w.-]+$/.test(repository) || !/^[a-f0-9]{40}$/.test(revision ?? "")) return [];
  const key = `${repository}@${revision}`;
  if (upstreamCache.has(key)) return upstreamCache.get(key);
  const repo = repository.slice("https://github.com/".length);
  const tree = await githubJson(`https://api.github.com/repos/${repo}/git/trees/${revision}`);
  const files = [];
  for (const entry of tree.tree) {
    if (entry.type !== "blob" || !/^(licen[sc]e|copying|copyright|notice)([._-]|$)/i.test(entry.path)) continue;
    const blob = await githubJson(`https://api.github.com/repos/${repo}/git/blobs/${entry.sha}`);
    if (blob.encoding !== "base64") throw new Error(`Unsupported blob encoding: ${key}`);
    const bytes = Buffer.from(blob.content, "base64");
    const hash = createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex");
    if (hash !== entry.sha) throw new Error(`Source blob checksum mismatch: ${key}/${entry.path}`);
    files.push({ bytes, path: `upstream/${entry.path}`, source: `${repository}/blob/${revision}/${entry.path}`, gitBlob: hash });
  }
  upstreamCache.set(key, files);
  return files;
}
const runJson = (command, args) => JSON.parse(execFileSync(command, args, {
  cwd: root, encoding: "utf8", maxBuffer: 32 * 1024 * 1024,
}));
const pnpm = process.env.npm_execpath;
if (!pnpm) throw new Error("Run with pnpm audit:licenses.");
const cargo = runJson("cargo", ["metadata", "--manifest-path", "src-tauri/Cargo.toml",
  "--offline", "--locked", "--format-version", "1", "--filter-platform", "x86_64-pc-windows-msvc"]);
const npm = runJson(process.execPath, [pnpm, "list", "--prod", "--depth", "Infinity", "--json"]);
const resolved = new Set(cargo.resolve.nodes.map((node) => node.id));
const packages = new Map();
for (const pkg of cargo.packages) {
  if (!resolved.has(pkg.id) || pkg.id === cargo.resolve.root) continue;
  let revision = null;
  try {
    revision = JSON.parse(await readFile(path.join(path.dirname(pkg.manifest_path), ".cargo_vcs_info.json"), "utf8"));
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
  packages.set(`cargo:${pkg.name}@${pkg.version}`, {
    name: pkg.name, version: pkg.version, ecosystem: "cargo", license: pkg.license,
    source: pkg.source, repository: pkg.repository, revision, directory: path.dirname(pkg.manifest_path),
  });
}
async function addNpm(dependencies) {
  for (const [name, dependency] of Object.entries(dependencies ?? {})) {
    const key = `npm:${name}@${dependency.version}`;
    if (packages.has(key)) continue;
    const manifest = JSON.parse(await readFile(path.join(dependency.path, "package.json"), "utf8"));
    if (manifest.name !== name || manifest.version !== dependency.version) throw new Error(`Package mismatch: ${key}`);
    packages.set(key, { name, version: manifest.version, ecosystem: "npm", license: manifest.license,
      source: dependency.resolved, repository: manifest.repository, directory: dependency.path });
    await addNpm(dependency.dependencies);
  }
}
for (const project of npm) await addNpm(project.dependencies);

async function licenseFiles(directory, relative = "") {
  const result = [];
  for (const entry of await readdir(path.join(directory, relative), { withFileTypes: true })) {
    const name = path.join(relative, entry.name);
    if (entry.isDirectory() && !["node_modules", ".git", "target"].includes(entry.name)) {
      result.push(...await licenseFiles(directory, name));
    } else if (entry.isFile() && /^(licen[sc]e|copying|copyright|notice)([._-]|$)/i.test(entry.name)) {
      result.push(name);
    }
  }
  return result.sort();
}
const inventory = [];
const notices = ["Heni third-party source license inventory — REVIEW CANDIDATE",
  "Includes Windows-resolved Rust build dependencies and installed npm production dependencies.",
  "Not a legal clearance or a binary linkage report. Vendored components require review.",
  "No FFmpeg/ffprobe executable is bundled by this inventory."];
for (const [id, pkg] of [...packages].sort(([a], [b]) => a.localeCompare(b, "en"))) {
  const files = [];
  notices.push(`\n${"=".repeat(72)}\n${id}\nDeclared license: ${pkg.license ?? "MISSING"}`,
    `Source: ${pkg.source ?? "MISSING"}\nRepository: ${JSON.stringify(pkg.repository ?? null)}`);
  for (const file of await licenseFiles(pkg.directory)) {
    const bytes = await readFile(path.join(pkg.directory, file));
    files.push({ path: file.replaceAll("\\", "/"), sha256: createHash("sha256").update(bytes).digest("hex") });
    notices.push(`\n--- ${files.at(-1).path} ---\n${bytes.toString("utf8").trimEnd()}`);
  }
  if (files.length === 0 && fetchUpstream) {
    try {
      for (const { bytes, ...source } of await upstreamLicenses(pkg)) {
        files.push({ ...source, sha256: createHash("sha256").update(bytes).digest("hex") });
        notices.push(`\n--- ${source.source} ---\n${bytes.toString("utf8").trimEnd()}`);
      }
    } catch (error) {
      console.error(`Upstream source unavailable for ${id}: ${error.message}`);
    }
  }
  const { directory, ...metadata } = pkg;
  inventory.push({ ...metadata, files });
}
const missing = inventory.filter((pkg) => !pkg.license || pkg.files.length === 0)
  .map((pkg) => `${pkg.ecosystem}:${pkg.name}@${pkg.version}`);
const inputHashes = {};
for (const file of ["scripts/license-audit.mjs", "package.json", "pnpm-lock.yaml", "src-tauri/Cargo.toml", "src-tauri/Cargo.lock"]) {
  inputHashes[file] = createHash("sha256").update(await readFile(path.join(root, file))).digest("hex");
}
await mkdir(output, { recursive: true });
await writeFile(path.join(output, "inventory.json"), JSON.stringify({ inputHashes, missing, packages: inventory }, null, 2) + "\n");
await writeFile(path.join(output, "THIRD_PARTY_NOTICES.txt"), notices.join("\n") + "\n");
console.log(`${inventory.length} packages inventoried; ${missing.length} require missing-license review. Output: ${output}`);
if (missing.length) {
  console.error(missing.join("\n"));
  process.exitCode = 1;
}
