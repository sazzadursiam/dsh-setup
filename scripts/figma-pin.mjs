#!/usr/bin/env node
/**
 * Keep the dsh profile's figma-console-mcp version in step with this checkout.
 *
 *   node scripts/figma-pin.mjs           rewrite the profile's version if it differs
 *   node scripts/figma-pin.mjs --check   only report
 *
 * The version comes from this repo's cordis.patch.yml. The profile's copy of that
 * file was pasted in by hand and may hold other entries, so nothing else in it
 * is touched: only a quoted "figma-console-mcp" or "figma-console-mcp@<anything>"
 * token has its version replaced. Every outcome prints one line and exits 0 —
 * callers treat this as a step that can be skipped, never one that fails a run.
 */
import { readFile, writeFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..');
const PROFILE_CONFIG = join(process.env.DSH_HOME || join(homedir(), '.dsh'), 'profiles', 'web', 'cordis.patch.yml');
const TOKEN = /(["'])figma-console-mcp(?:@([^"'\s]+))?\1/g;
const EXACT = /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/;

const ok = (text) => console.log(`  [ OK ] ${text}`);
const warn = (text) => console.log(`  [WARN] ${text}`);
const info = (text) => console.log(`  [INFO] ${text}`);

/** Matches outside YAML comment lines, so prose about the token is never read or rewritten. */
const isComment = (line) => /^\s*#/.test(line);
const tokensIn = (text) => text.split('\n').filter((line) => !isComment(line)).flatMap((line) => [...line.matchAll(TOKEN)]);

async function readText(path) {
	try {
		return await readFile(path, 'utf8');
	} catch {
		return null;
	}
}

const checkOnly = process.argv.includes('--check');

const repoConfig = await readText(join(REPO, 'cordis.patch.yml'));
const pinned = repoConfig === null ? undefined : tokensIn(repoConfig)[0]?.[2];
if (pinned === undefined || !EXACT.test(pinned)) {
	info('This checkout does not pin figma-console-mcp - the profile is left alone');
	process.exit(0);
}

const profile = await readText(PROFILE_CONFIG);
if (profile === null) {
	info(`No ${PROFILE_CONFIG} yet - copy cordis.patch.yml there, see SETUP.md`);
	process.exit(0);
}
const found = tokensIn(profile).map((match) => match[2] ?? 'latest');
if (found.length === 0) {
	info('The profile does not run figma-console-mcp - nothing to pin');
	process.exit(0);
}
const differing = [...new Set(found.filter((version) => version !== pinned))];
if (differing.length === 0) {
	ok(`Figma MCP pinned to ${pinned}`);
	process.exit(0);
}

if (checkOnly) {
	warn(`Figma MCP runs ${differing.join(', ')} but this checkout pins ${pinned}`);
	console.log('         Run update to bring the profile in line.');
	process.exit(0);
}

// Split on "\n" and joined back the same way, so CRLF files keep their "\r".
const rewritten = profile.split('\n')
	.map((line) => isComment(line) ? line : line.replace(TOKEN, (_match, quote) => `${quote}figma-console-mcp@${pinned}${quote}`))
	.join('\n');
try {
	await writeFile(PROFILE_CONFIG, rewritten, 'utf8');
} catch (error) {
	warn(`Could not rewrite ${PROFILE_CONFIG}: ${error.message}`);
	process.exit(0);
}
ok(`Figma MCP moved from ${differing.join(', ')} to ${pinned} - restart dsh to use it`);
