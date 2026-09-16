/**
 * Local verification for dsh-team-updater — run: node tests/check.mjs
 *
 * Checks the parts that can be verified without a live dsh host: version
 * comparison, and the registry lookup the host half performs (same URL, same
 * Accept header), so the numbers the Settings row shows are known-good before
 * the plugin is ever installed.
 */
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DEFAULT_ALLOW_SCRIPTS, readAllowScripts, readPin } from '../lib/pin.js';
import { isNewer, compareVersions } from '../lib/version.js';

const PACKAGE_NAME = '@deepseek-ai/dsh';
const REGISTRY = 'https://registry.npmjs.org';

let failures = 0;
function check(label, actual, expected) {
	const ok = actual === expected;
	if (!ok) failures += 1;
	console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}: ${actual}${ok ? '' : ` (expected ${expected})`}`);
}

// ── version comparison ──────────────────────────────────────────────────────
check('isNewer 0.1.2-rc.1 → 0.1.5-rc.1', isNewer('0.1.5-rc.1', '0.1.2-rc.1'), true);
check('isNewer same', isNewer('0.1.2-rc.1', '0.1.2-rc.1'), false);
check('release > its prerelease', isNewer('0.1.2', '0.1.2-rc.1'), true);
check('rc.2 > rc.1', isNewer('0.1.2-rc.2', '0.1.2-rc.1'), true);
check('rc.10 > rc.9', isNewer('0.1.2-rc.10', '0.1.2-rc.9'), true);
check('alpha < rc', compareVersions('0.1.5-alpha.2', '0.1.5-rc.1'), -1);
check('garbage is not newer', isNewer('not-a-version', '0.1.2-rc.1'), false);

// ── finding the pin, in both layouts the plugin runs from ───────────────────
// Built in a temp tree so the real checkout's DSH_VERSION never decides a result.
const sandbox = await mkdtemp(join(tmpdir(), 'team-updater-pin-'));
try {
	const checkout = join(sandbox, 'dsh-setup');
	const inCheckout = join(checkout, 'plugins', 'team-updater');
	await mkdir(inCheckout, { recursive: true });
	await writeFile(join(checkout, 'DSH_VERSION'), '0.1.2-rc.1\r\n');
	check('checkout layout reads DSH_VERSION (CRLF tolerated)', (await readPin(null, inCheckout))?.version, '0.1.2-rc.1');

	const profile = join(sandbox, 'profile');
	const inProfile = join(profile, 'node_modules', 'dsh-team-updater');
	await mkdir(inProfile, { recursive: true });
	await writeFile(join(profile, 'package.json'), JSON.stringify({ dependencies: { 'dsh-team-updater': `file:${inCheckout}` } }));
	check('profile copy follows an absolute file: spec', (await readPin(null, inProfile))?.version, '0.1.2-rc.1');
	await writeFile(join(profile, 'package.json'), JSON.stringify({ dependencies: { 'dsh-team-updater': 'file:../dsh-setup/plugins/team-updater' } }));
	check('profile copy follows a relative file: spec', (await readPin(null, inProfile))?.version, '0.1.2-rc.1');

	await writeFile(join(checkout, 'DSH_VERSION'), '\n');
	check('empty DSH_VERSION means unpinned', await readPin(null, inCheckout), null);
	await writeFile(join(checkout, 'DSH_VERSION'), 'latest\n');
	const junk = await readPin(null, inCheckout);
	check('a non-version pin is an error, not a fallback', junk?.version === null && typeof junk?.error === 'string', true);
	await rm(join(checkout, 'DSH_VERSION'));
	check('no DSH_VERSION anywhere means unpinned', await readPin(null, inProfile), null);
	const missing = await readPin(join(sandbox, 'nope', 'DSH_VERSION'), inProfile);
	check('an explicit versionFile that is missing is an error', missing?.version === null && typeof missing?.error === 'string', true);

	// The allowlist is found the same way, beside where DSH_VERSION would be.
	check('no DSH_ALLOW_SCRIPTS falls back to the default', (await readAllowScripts(null, inProfile)).list, DEFAULT_ALLOW_SCRIPTS);
	await writeFile(join(checkout, 'DSH_ALLOW_SCRIPTS'), 'koffi,@scope/native-thing\r\n');
	check('checkout layout reads DSH_ALLOW_SCRIPTS', (await readAllowScripts(null, inCheckout)).list, 'koffi,@scope/native-thing');
	check('profile copy reads DSH_ALLOW_SCRIPTS through the file: spec', (await readAllowScripts(null, inProfile)).list, 'koffi,@scope/native-thing');
	check('an explicit versionFile looks beside itself', (await readAllowScripts(join(checkout, 'DSH_VERSION'), inProfile)).list, 'koffi,@scope/native-thing');
	for (const bad of ['', 'koffi & calc', 'koffi, node-pty', 'koffi,,node-pty']) {
		await writeFile(join(checkout, 'DSH_ALLOW_SCRIPTS'), `${bad}\n`);
		const broken = await readAllowScripts(null, inCheckout);
		check(`malformed allowlist ${JSON.stringify(bad)} is an error`, broken.list === null && typeof broken.error === 'string', true);
	}
} finally {
	await rm(sandbox, { recursive: true, force: true });
}

// ── the checkout this copy ships in ─────────────────────────────────────────
// The pins have one source each, but a few copies cannot read it: the default
// above, and commands in SETUP.md meant for pasting. These fail when a copy drifts.
const repoFile = (name) => readFile(new URL(`../../../${name}`, import.meta.url), 'utf8').catch(() => null);
const allowFile = await repoFile('DSH_ALLOW_SCRIPTS');
const ALLOW_SCRIPTS = allowFile?.trim() ?? DEFAULT_ALLOW_SCRIPTS;
if (allowFile === null) {
	console.log('skip checkout checks: not running from a dsh-setup checkout');
} else {
	check('built-in default matches DSH_ALLOW_SCRIPTS', DEFAULT_ALLOW_SCRIPTS, ALLOW_SCRIPTS);
	const setupDoc = await repoFile('SETUP.md');
	const pin = (await repoFile('DSH_VERSION')).trim();
	const dshCommands = [...setupDoc.matchAll(/npm install -g --allow-scripts=(\S+) @deepseek-ai\/dsh(@[0-9A-Za-z.-]+)?/g)];
	check('SETUP.md has dsh install commands', dshCommands.length > 0, true);
	check('every SETUP.md install command uses DSH_ALLOW_SCRIPTS', dshCommands.every((m) => m[1] === ALLOW_SCRIPTS), true);
	check('every SETUP.md install command uses DSH_VERSION', dshCommands.every((m) => m[2] === `@${pin}`), true);
}

// ── registry lookup, exactly as the host half does it ───────────────────────
const url = `${REGISTRY}/${PACKAGE_NAME.replace('/', '%2f')}`;
const response = await fetch(url, {
	headers: { accept: 'application/vnd.npm.install-v1+json' },
	signal: AbortSignal.timeout(10_000)
});
check('registry status', response.status, 200);
const packument = await response.json();
const distTags = packument['dist-tags'];
console.log('dist-tags:', JSON.stringify(distTags));
check('latest resolves to a version', isNewer(distTags.latest, '0.0.0'), true);

// ── the blocklist the row applies before offering anything ──────────────────
// Read out of the shipped config rather than restated here, so dropping an
// entry by mistake shows up as a failure. Scanned with a regex to keep this
// file dependency-free, like the rest of the package.
const patch = await readFile(new URL('../cordis.patch.yml', import.meta.url), 'utf8');
const blockedVersions = [];
{
	const lines = patch.split(/\r?\n/);
	const start = lines.findIndex((line) => /^\s*blocked:\s*$/.test(line));
	const indent = start === -1 ? 0 : lines[start].search(/\S/);
	for (let i = start + 1; start !== -1 && i < lines.length; i += 1) {
		const line = lines[i];
		if (line.trim().length === 0) continue;
		if (line.search(/\S/) <= indent) break;
		const key = line.match(/^\s+(\S+?):/);
		if (key !== null) blockedVersions.push(key[1]);
	}
}
check('blocklist parsed from cordis.patch.yml', blockedVersions.length > 0, true);
check('0.1.5-rc.1 is blocked', blockedVersions.includes('0.1.5-rc.1'), true);
check('0.1.5-rc.2 is blocked', blockedVersions.includes('0.1.5-rc.2'), true);
check('a later version is not blocked', blockedVersions.includes('0.1.6'), false);
if (blockedVersions.includes(distTags.latest)) {
	console.log(`registry "latest" is ${distTags.latest}, which is blocked - the row offers no update`);
} else {
	console.log(`command the UI would show: npm install -g --allow-scripts=${ALLOW_SCRIPTS} ${PACKAGE_NAME}@${distTags.latest}`);
}

console.log(failures === 0 ? '\nall checks passed' : `\n${failures} check(s) failed`);
// process.exitCode, not process.exit(): exiting with an open fetch handle trips
// a libuv assertion on Windows (same reason the host half never exits itself).
process.exitCode = failures === 0 ? 0 : 1;
