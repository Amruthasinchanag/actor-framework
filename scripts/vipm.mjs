import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { parse, stringify } from 'smol-toml';

const defaultManifest = 'Tooling/deployment/runner_dependencies.toml';
const defaultFeed = 'Tooling/deployment/vipm-releases.json';
const defaultLock = 'Tooling/deployment/runner_dependencies.lock';

export function isSupportedVersion(version) {
  return typeof version === 'string' && /^\d+\.\d+\.\d+(?:\.\d+)?$/.test(version);
}

export function versionParts(version) {
  assert.ok(isSupportedVersion(version), 'Expected a numeric 3- or 4-part VIPM version');
  const parts = version.split('.').map(BigInt);
  return parts.length === 3 ? [...parts, 0n] : parts;
}

export function compareVersions(left, right) {
  const rightParts = versionParts(right);
  for (const [index, part] of versionParts(left).entries()) {
    if (part !== rightParts[index]) return part > rightParts[index] ? 1 : -1;
  }
  return 0;
}

export function validate(document, feed) {
  assert.ok(document.dependencies && typeof document.dependencies === 'object', 'Missing [dependencies] table');
  const supported = Object.entries(document.dependencies).filter(([, version]) => isSupportedVersion(version));
  assert.ok(supported.length > 0, 'No supported numeric VIPM dependencies');
  for (const [name, version] of supported) {
    versionParts(version);
    assert.ok(Array.isArray(feed[name]?.releases) && feed[name].releases.length > 0, `Missing releases for ${name}`);
    for (const release of feed[name].releases) versionParts(release.version);
    assert.ok(feed[name].releases.some(release => compareVersions(release.version, version) === 0), `Unknown version ${name}@${version}`);
  }
}

export function updateToml(text, feed) {
  const document = parse(text);
  validate(document, feed);
  let changed = false;
  for (const [name, current] of Object.entries(document.dependencies)) {
    if (!feed[name] || !isSupportedVersion(current)) continue;
    const latest = feed[name].releases.reduce((best, release) =>
      compareVersions(release.version, best) > 0 ? release.version : best, current);
    if (latest !== current) {
      document.dependencies[name] = latest;
      changed = true;
    }
  }
  return changed ? stringify(document) : text;
}

export function checkLock(manifest, lock) {
  const locked = new Map((lock.package ?? []).map(entry => [entry.name, entry.version]));
  for (const [name, version] of Object.entries(manifest.dependencies)) {
    assert.equal(locked.get(name), version, `Lock file does not pin ${name}@${version}`);
  }
}

export function exportFeed(baseline, resolved, previous = {}) {
  assert.ok(baseline.dependencies && Object.keys(baseline.dependencies).length > 0, 'No baseline dependencies');
  assert.deepEqual(resolved.project, baseline.project, 'Discovery changed the LabVIEW project target');
  assert.deepEqual(Object.keys(resolved.dependencies ?? {}).sort(), Object.keys(baseline.dependencies).sort(), 'Discovery changed the package set');
  const result = {};
  for (const [name, baselineVersion] of Object.entries(baseline.dependencies).sort(([left], [right]) => left.localeCompare(right))) {
    if (!isSupportedVersion(baselineVersion)) continue;
    const versions = [
      ...(previous[name]?.releases ?? []).map(release => release.version),
      baselineVersion,
      resolved.dependencies[name],
    ];
    for (const version of versions) versionParts(version);
    result[name] = {
      releases: [...new Set(versions)].sort(compareVersions).map(version => ({ version })),
    };
  }
  validate(baseline, result);
  validate(resolved, result);
  return result;
}

async function main() {
  const [command, manifest = defaultManifest, source = defaultFeed, lockPath = defaultLock, baselinePath = defaultManifest] = process.argv.slice(2);
  assert.ok(['check', 'export-feed'].includes(command), 'Usage: node scripts/vipm.mjs <check|export-feed> [manifest] [feed] [lock] [baseline]');
  const text = await readFile(manifest, 'utf8');
  const feedText = await readFile(source, 'utf8');
  const feed = JSON.parse(feedText);
  if (command === 'export-feed') {
    const resolved = parse(text);
    checkLock(resolved, parse(await readFile(lockPath, 'utf8')));
    const baseline = parse(await readFile(baselinePath, 'utf8'));
    const updated = `${JSON.stringify(exportFeed(baseline, resolved, feed), null, 2)}\n`;
    if (updated !== feedText) await writeFile(source, updated);
    console.log(`Exported VIPM releases to ${source}`);
  } else {
    const document = parse(text);
    validate(document, feed);
    if (existsSync(lockPath)) {
      checkLock(document, parse(await readFile(lockPath, 'utf8')));
      console.log(`${lockPath} matches ${manifest}`);
    } else {
      assert.notEqual(process.env.REQUIRE_VIPM_LOCK, 'true', `${lockPath} is required but missing`);
    }
    console.log('VIPM manifest and release feed are valid');
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  await main();
}