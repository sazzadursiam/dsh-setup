/**
 * Local verification for dsh-team-updater — run: node tests/check.mjs
 *
 * Checks the parts that can be verified without a live dsh host: version
 * comparison, and the registry lookup the host half performs (same URL, same
 * Accept header), so the numbers the Settings row shows are known-good before
 * the plugin is ever installed.
 */
import { readFile } from 'node:fs/promises';
import { isNewer, compareVersions } from '../lib/version.js';

const PACKAGE_NAME = '@deepseek-ai/dsh';
const REGISTRY = 'https://registry.npmjs.org';
const ALLOW_SCRIPTS = '@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs';

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
