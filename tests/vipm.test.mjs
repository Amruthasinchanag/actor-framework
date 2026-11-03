import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import jsonata from 'jsonata';
import { parse as parseToml } from 'smol-toml';
import { parse as parseYaml } from 'yaml';
import { checkLock, compareVersions, exportFeed, isSupportedVersion, updateToml, validate } from '../scripts/vipm.mjs';

const sampleFeed = {
  demo_package: { releases: [{ version: '1.0.0.1' }, { version: '1.0.0.2' }, { version: '1.0.0.10' }] },
};

test('compares VIPM versions numerically and rejects the unsupported hyphen format', () => {
  assert.equal(compareVersions('1.0.0.10', '1.0.0.2'), 1);
  assert.equal(compareVersions('1.0.0', '1.0.0.0'), 0);
  assert.equal(isSupportedVersion('1.1-1'), false);
});

test('updates supported dependencies without touching unsupported VIPM versions', () => {
  const text = '[dependencies]\ndemo_package = "1.0.0.1"\nlegacy_package = "1.1-1"\n';
  const feed = { ...sampleFeed, legacy_package: { releases: [{ version: '1.1-2' }] } };
  const result = parseToml(updateToml(text, feed));
  assert.equal(result.dependencies.demo_package, '1.0.0.10');
  assert.equal(result.dependencies.legacy_package, '1.1-1');
});

test('keeps unchanged TOML byte-for-byte and rejects missing or unknown releases', () => {
  const text = '# preserve this comment\n[dependencies]\ndemo_package = "1.0.0.10"\n';
  assert.equal(updateToml(text, sampleFeed), text);
  assert.throws(() => validate({ dependencies: { missing: '1.0.0' } }, sampleFeed), /Missing releases/);
  assert.throws(() => validate({ dependencies: { demo_package: '9.0.0' } }, sampleFeed), /Unknown version/);
});

test('validates every direct dependency against the lock', () => {
  const manifest = { dependencies: { demo_package: '1.0.0.1', other: '2.0.0' } };
  checkLock(manifest, { package: [{ name: 'demo_package', version: '1.0.0.1' }, { name: 'other', version: '2.0.0' }] });
  assert.throws(() => checkLock(manifest, { package: [{ name: 'demo_package', version: '1.0.0.2' }] }), /does not pin/);
});

test('exports a validated feed while retaining known releases and excluding unsupported versions', () => {
  const baseline = { project: { 'labview-version': 2021 }, dependencies: { demo_package: '1.0.0.1', legacy_package: '1.1-1' } };
  const resolved = { project: baseline.project, dependencies: { demo_package: '1.0.0.10', legacy_package: '1.1-1' } };
  const result = exportFeed(baseline, resolved, sampleFeed);
  assert.deepEqual(result.demo_package.releases.map(release => release.version), ['1.0.0.1', '1.0.0.2', '1.0.0.10']);
  assert.equal(Object.hasOwn(result, 'legacy_package'), false);
  assert.throws(() => exportFeed(baseline, { ...resolved, project: {} }, sampleFeed), /project target/);
});

test('Renovate extracts only numeric dependencies from the production manifest and resolves its local feed', async () => {
  const config = JSON.parse(await readFile(new URL('../renovate.json', import.meta.url), 'utf8'));
  const text = await readFile(new URL('../Tooling/deployment/runner_dependencies.toml', import.meta.url), 'utf8');
  const manager = config.customManagers[0];
  const section = new RegExp(manager.matchStrings[0]).exec(`${text}\n[other]\nignored = "9.9.9.9"`)[0];
  const extracted = [...section.matchAll(new RegExp(manager.matchStrings[1], 'g'))].map(match => [match.groups.depName, match.groups.currentValue]);
  const expected = Object.entries(parseToml(text).dependencies).filter(([, version]) => isSupportedVersion(version));
  assert.deepEqual(extracted.sort(), expected.sort());
  const feedPath = config.customDatasources.vipm.defaultRegistryUrlTemplate.slice('file://'.length);
  const feed = JSON.parse(await readFile(new URL(`../${feedPath}`, import.meta.url), 'utf8'));
  for (const [packageName, versions] of Object.entries(feed)) {
    const expression = config.customDatasources.vipm.transformTemplates[0].replace('{{{packageName}}}', packageName);
    assert.deepEqual(await jsonata(expression).evaluate(feed), versions);
  }
});

test('the lock workflow is restricted to same-repository Renovate pull requests', async () => {
  const workflow = parseYaml(await readFile(new URL('../.github/workflows/vipm-lock.yml', import.meta.url), 'utf8'));
  assert.ok(Object.hasOwn(workflow.on, 'pull_request'));
  assert.ok(workflow.jobs.lock.if.includes("github.event.pull_request.user.login == 'renovate[bot]'"));
  assert.ok(workflow.jobs.lock.if.includes('github.event.pull_request.head.repo.full_name == github.repository'));
  assert.ok(workflow.jobs.lock.steps.at(-1).run.includes('workflow run dependency-check.yml'));
  const refresh = workflow.jobs.lock.steps.find(step => step.uses?.startsWith('ni/open-source/refresh-vipm-lock@'));
  assert.equal(refresh.with.manifest_filename, 'runner_dependencies.toml');
  assert.equal(refresh.with.lock_filename, 'runner_dependencies.lock');
});

test('scheduled NI discovery publishes only its isolated version feed', async () => {
  const workflow = parseYaml(await readFile(new URL('../.github/workflows/discover-vipm.yml', import.meta.url), 'utf8'));
  assert.ok(workflow.on.schedule.length > 0);
  assert.ok(Object.hasOwn(workflow.on, 'workflow_dispatch'));
  assert.ok(!Object.hasOwn(workflow.on, 'pull_request'));
  const steps = workflow.jobs.discover.steps;
  assert.ok(steps.some(step => step.uses === 'ni/open-source/update-vipm-dependencies@8171754ea3d17f9fdcd708d8da45f96916e09c4c'));
  const updater = steps.find(step => step.uses?.startsWith('ni/open-source/update-vipm-dependencies@'));
  assert.equal(updater.with.manifest_filename, '${{ env.MANIFEST_FILENAME }}');
  assert.equal(updater.with.lock_filename, '${{ env.LOCK_FILENAME }}');
  const publication = steps.find(step => step.id === 'feed');
  assert.equal(publication.with['add-paths'], 'Tooling/deployment/vipm-releases.json');
  assert.equal(publication.with.branch, 'automation/vipm-release-feed');
});

test('dependency-check is one hosted job and requires the lock on Renovate PRs', async () => {
  const workflow = parseYaml(await readFile(new URL('../.github/workflows/dependency-check.yml', import.meta.url), 'utf8'));
  assert.deepEqual(Object.keys(workflow.jobs), ['dependency-check']);
  assert.equal(workflow.jobs['dependency-check']['runs-on'], 'ubuntu-latest');
  const check = workflow.jobs['dependency-check'].steps.find(step => step.run === 'npm run check');
  assert.equal(check.env.REQUIRE_VIPM_LOCK, "${{ github.event_name != 'push' && github.head_ref != 'automation/vipm-release-feed' && !inputs.feed_only }}");
  const config = JSON.parse(await readFile(new URL('../renovate.json', import.meta.url), 'utf8'));
  assert.deepEqual(config.baseBranches, ['main']);
  assert.equal(config.platformAutomerge, true);
  assert.equal(config.packageRules[0].automerge, true);
});

test('export CLI accepts custom manifest, lock, and baseline paths without vipm.toml', async context => {
  const directory = await mkdtemp(join(tmpdir(), 'af-custom-vipm-'));
  context.after(() => rm(directory, { recursive: true, force: true }));
  const baseline = '[project]\nlabview-version = 2021\n[dependencies]\ndemo_package = "1.0.0.1"\n';
  await writeFile(join(directory, 'requirements.toml'), baseline);
  await writeFile(join(directory, 'resolved.toml'), baseline.replace('1.0.0.1', '1.0.0.10'));
  await writeFile(join(directory, 'requirements.lock'), '[[package]]\nname = "demo_package"\nversion = "1.0.0.10"\n');
  await writeFile(join(directory, 'releases.json'), JSON.stringify(sampleFeed));
  const script = fileURLToPath(new URL('../scripts/vipm.mjs', import.meta.url));
  const result = spawnSync(process.execPath, [script, 'export-feed', 'resolved.toml', 'releases.json', 'requirements.lock', 'requirements.toml'], { cwd: directory, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(await readFile(join(directory, 'requirements.toml'), 'utf8'), baseline);
  const exported = JSON.parse(await readFile(join(directory, 'releases.json'), 'utf8'));
  assert.equal(exported.demo_package.releases.at(-1).version, '1.0.0.10');
});