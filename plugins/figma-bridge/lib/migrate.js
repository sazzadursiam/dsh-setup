#!/usr/bin/env node
/**
 * One-time cleanup for a profile that got its Figma MCP entry the old way:
 * hand-copied into the profile's own cordis.patch.yml, before this plugin
 * existed. Removes that entry so dsh plugin add can install the plugin-managed
 * one without ending up with two "serverName: figma" rows.
 *
 *   node plugins/figma-bridge/lib/migrate.js
 *
 * Every outcome prints one line and exits 0 - this must never fail a
 * setup/update run. Run this BEFORE `dsh plugin --profile web add
 * ".../figma-bridge"`, not after.
 */
import { copyFile, readFile, writeFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';

const DSH_HOME = process.env.DSH_HOME || join(homedir(), '.dsh');
const PROFILE_DIR = join(DSH_HOME, 'profiles', 'web');
const PROFILE_PACKAGE = join(PROFILE_DIR, 'package.json');
const PROFILE_CONFIG = join(PROFILE_DIR, 'cordis.patch.yml');
const PLUGIN_PACKAGE = 'dsh-figma-bridge';

const ok = (text) => console.log(`  [ OK ] ${text}`);
const warn = (text) => console.log(`  [WARN] ${text}`);
const info = (text) => console.log(`  [INFO] ${text}`);

async function readText(path) {
	try {
		return await readFile(path, 'utf8');
	} catch {
		return null;
	}
}

const manifest = await readText(PROFILE_PACKAGE);
if (manifest !== null) {
	try {
		if (JSON.parse(manifest)?.dependencies?.[PLUGIN_PACKAGE] !== undefined) {
			info('already plugin-managed - nothing to migrate');
			process.exit(0);
		}
	} catch {
		/* unreadable profile manifest: fall through and inspect cordis.patch.yml directly */
	}
}

const profile = await readText(PROFILE_CONFIG);
if (profile === null || !/serverName:\s*figma\b/.test(profile)) {
	info('no legacy entry found');
	process.exit(0);
}

// Walk the top-level "- insert:" blocks (column 0) and find the one holding
// "id: mcp-figma", counting how many nested "- id:" entries share that block.
const lines = profile.split('\n');
let blockStart = -1;
let blockEnd = lines.length;
let idsInBlock = 0;
let hasTarget = false;
for (let i = 0; i < lines.length; i += 1) {
	if (/^-\s*insert:\s*\r?$/.test(lines[i])) {
		if (blockStart !== -1) {
			blockEnd = i;
			break;
		}
		blockStart = i;
		continue;
	}
	if (blockStart !== -1 && /^\S/.test(lines[i])) {
		blockEnd = i;
		break;
	}
	if (blockStart !== -1 && /^\s+-\s*id:\s*(\S+)/.test(lines[i])) {
		idsInBlock += 1;
		if (/^\s+-\s*id:\s*mcp-figma\s*\r?$/.test(lines[i])) hasTarget = true;
	}
}

if (blockStart === -1 || !hasTarget) {
	warn('found "serverName: figma" but not in a recognizable insert block - leaving it alone');
	console.log(`         Remove the figma entry from ${PROFILE_CONFIG} by hand, then re-run.`);
	process.exit(0);
}

if (idsInBlock > 1) {
	warn('the figma entry is merged with other config in the same block - leaving it alone');
	console.log(`         Remove it from ${PROFILE_CONFIG} by hand, then re-run.`);
	process.exit(0);
}

const remaining = [...lines.slice(0, blockStart), ...lines.slice(blockEnd)];
// An empty patch layer is written as "[]", not as no array at all - that is
// the convention dsh itself uses for a freshly created, entry-less file.
const hasOtherEntries = remaining.some((line) => /^-\s/.test(line));
const rewritten = hasOtherEntries ? remaining.join('\n') : `${[...remaining, '[]'].join('\n')}\n`;
try {
	await copyFile(PROFILE_CONFIG, `${PROFILE_CONFIG}.bak`);
	await writeFile(PROFILE_CONFIG, rewritten, 'utf8');
} catch (error) {
	warn(`Could not rewrite ${PROFILE_CONFIG}: ${error.message}`);
	process.exit(0);
}
ok(`removed the hand-copied figma entry from ${PROFILE_CONFIG} (backup: ${PROFILE_CONFIG}.bak)`);
