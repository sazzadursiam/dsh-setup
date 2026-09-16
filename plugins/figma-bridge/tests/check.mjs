/**
 * Local verification for dsh-figma-bridge — run: node tests/check.mjs
 *
 * Checks the parts that can be verified without a live dsh host: the pinned
 * version stays in step across this package and SETUP.md's embedded example,
 * and lib/pin.js / lib/migrate.js behave correctly against a sandboxed profile
 * (dependency-free, like plugins/team-updater/tests/check.mjs).
 */
import { execFileSync } from 'node:child_process';
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

let failures = 0;
function check(label, actual, expected) {
	const ok = actual === expected;
	if (!ok) failures += 1;
	console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}: ${actual}${ok ? '' : ` (expected ${expected})`}`);
}

const PACKAGE_ROOT = new URL('..', import.meta.url);
const readOwn = (name) => readFile(new URL(name, PACKAGE_ROOT), 'utf8');

const figmaPin = (text) => [...text.matchAll(/["']figma-console-mcp(?:@([^"'\s]+))?["']/g)].map((m) => m[1] ?? 'latest');

// ── self-consistency: pinned version, package.json shape ───────────────────
const patch = await readOwn('cordis.patch.yml');
const ownVersions = figmaPin(patch);
check('cordis.patch.yml pins an exact figma-console-mcp', /^\d+\.\d+\.\d+/.test(ownVersions[0] ?? ''), true);

const pkg = JSON.parse(await readOwn('package.json'));
check('package.json name', pkg.name, 'dsh-figma-bridge');
check('package.json.dsh.bundle.patch points at cordis.patch.yml', pkg.dsh?.bundle?.patch, './cordis.patch.yml');

// ── the checkout this copy ships in ─────────────────────────────────────────
const repoFile = (name) => readFile(new URL(`../../../${name}`, import.meta.url), 'utf8').catch(() => null);
const setupDoc = await repoFile('SETUP.md');
if (setupDoc === null) {
	console.log('skip checkout checks: not running from a dsh-setup checkout');
} else {
	check('SETUP.md shows the same figma-console-mcp version', figmaPin(setupDoc).every((v) => v === ownVersions[0]), true);
}

// ── lib/pin.js, driven as a subprocess against a sandboxed DSH_HOME ────────
const PIN_SCRIPT = fileURLToPath(new URL('../lib/pin.js', import.meta.url));
const MIGRATE_SCRIPT = fileURLToPath(new URL('../lib/migrate.js', import.meta.url));

function run(script, { dshHome, args = [] }) {
	try {
		const stdout = execFileSync(process.execPath, [script, ...args], {
			env: { ...process.env, DSH_HOME: dshHome },
			encoding: 'utf8'
		});
		return { stdout, status: 0 };
	} catch (error) {
		return { stdout: error.stdout ?? '', status: error.status ?? 1 };
	}
}

const installedProfileDir = (dshHome) => join(dshHome, 'profiles', 'web', 'node_modules', 'dsh-figma-bridge');

{
	const sandbox = await mkdtemp(join(tmpdir(), 'figma-bridge-pin-'));
	try {
		const installed = installedProfileDir(sandbox);
		await mkdir(installed, { recursive: true });
		await writeFile(join(installed, 'cordis.patch.yml'), 'args: ["-y", "figma-console-mcp@0.0.1"]\n');

		const checkResult = run(PIN_SCRIPT, { dshHome: sandbox, args: ['--check'] });
		check('pin --check reports a mismatch without writing', /WARN/.test(checkResult.stdout), true);
		const afterCheck = await readFile(join(installed, 'cordis.patch.yml'), 'utf8');
		check('pin --check does not rewrite the file', afterCheck.includes('0.0.1'), true);

		const rewrite = run(PIN_SCRIPT, { dshHome: sandbox });
		check('pin rewrite reports success', /OK/.test(rewrite.stdout), true);
		const afterRewrite = await readFile(join(installed, 'cordis.patch.yml'), 'utf8');
		check('pin rewrite updates the installed copy to the pinned version', afterRewrite.includes(`figma-console-mcp@${ownVersions[0]}`), true);

		const again = run(PIN_SCRIPT, { dshHome: sandbox, args: ['--check'] });
		check('pin --check reports up to date after a rewrite', /OK/.test(again.stdout), true);
	} finally {
		await rm(sandbox, { recursive: true, force: true });
	}
}

{
	const sandbox = await mkdtemp(join(tmpdir(), 'figma-bridge-pin-missing-'));
	try {
		const result = run(PIN_SCRIPT, { dshHome: sandbox });
		check('pin exits 0 with no installed profile', result.status, 0);
		check('pin reports nothing installed yet', /INFO/.test(result.stdout), true);
	} finally {
		await rm(sandbox, { recursive: true, force: true });
	}
}

// ── lib/migrate.js, the three cases a legacy profile can be in ─────────────
const LEGACY_BLOCK = `# Your patch layer for this dsh profile, applied after every bundle layer:
# a top-level YAML array of loader patch entries (id-targeted config
# overrides, disables, and insert lists; \`!!js\` expressions allowed).
- insert:
    - id: mcp-figma
      name: '@deepseek-ai/dsh-mcp-client'
      config:
        serverName: figma
        transport: stdio
        command: npx
        args: ['-y', 'figma-console-mcp@latest']
`;

{
	const sandbox = await mkdtemp(join(tmpdir(), 'figma-bridge-migrate-legacy-'));
	try {
		const profileDir = join(sandbox, 'profiles', 'web');
		await mkdir(profileDir, { recursive: true });
		await writeFile(join(profileDir, 'cordis.patch.yml'), LEGACY_BLOCK);

		const result = run(MIGRATE_SCRIPT, { dshHome: sandbox });
		check('migrate reports removal for a single-entry legacy block', /OK/.test(result.stdout), true);

		const rewritten = await readFile(join(profileDir, 'cordis.patch.yml'), 'utf8');
		check('migrate removes the figma entry', /serverName:\s*figma/.test(rewritten), false);
		check('migrate leaves an empty patch layer as []', rewritten.trimEnd().endsWith('[]'), true);

		const backup = await readFile(join(profileDir, 'cordis.patch.yml.bak'), 'utf8');
		check('migrate writes a .bak with the original content', backup, LEGACY_BLOCK);

		const again = run(MIGRATE_SCRIPT, { dshHome: sandbox });
		check('migrate is a clean no-op on a second run', /no legacy entry found/.test(again.stdout), true);
	} finally {
		await rm(sandbox, { recursive: true, force: true });
	}
}

{
	const sandbox = await mkdtemp(join(tmpdir(), 'figma-bridge-migrate-managed-'));
	try {
		const profileDir = join(sandbox, 'profiles', 'web');
		await mkdir(profileDir, { recursive: true });
		await writeFile(join(profileDir, 'package.json'), JSON.stringify({ dependencies: { 'dsh-figma-bridge': 'file:../plugins/figma-bridge' } }));
		await writeFile(join(profileDir, 'cordis.patch.yml'), LEGACY_BLOCK);

		const result = run(MIGRATE_SCRIPT, { dshHome: sandbox });
		check('migrate no-ops when already plugin-managed', /already plugin-managed/.test(result.stdout), true);

		const untouched = await readFile(join(profileDir, 'cordis.patch.yml'), 'utf8');
		check('migrate leaves an already-managed profile untouched', untouched, LEGACY_BLOCK);
	} finally {
		await rm(sandbox, { recursive: true, force: true });
	}
}

{
	const sandbox = await mkdtemp(join(tmpdir(), 'figma-bridge-migrate-merged-'));
	try {
		const profileDir = join(sandbox, 'profiles', 'web');
		await mkdir(profileDir, { recursive: true });
		const merged = `- insert:
    - id: mcp-other
      name: '@deepseek-ai/dsh-mcp-client'
      config:
        serverName: other
    - id: mcp-figma
      name: '@deepseek-ai/dsh-mcp-client'
      config:
        serverName: figma
`;
		await writeFile(join(profileDir, 'cordis.patch.yml'), merged);

		const result = run(MIGRATE_SCRIPT, { dshHome: sandbox });
		check('migrate warns and leaves a merged block alone', /WARN/.test(result.stdout), true);

		const untouched = await readFile(join(profileDir, 'cordis.patch.yml'), 'utf8');
		check('migrate does not modify a merged block', untouched, merged);
	} finally {
		await rm(sandbox, { recursive: true, force: true });
	}
}

console.log(failures === 0 ? '\nall checks passed' : `\n${failures} check(s) failed`);
// process.exitCode, not process.exit(): matches plugins/team-updater/tests/check.mjs.
process.exitCode = failures === 0 ? 0 : 1;
