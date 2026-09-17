/**
 * Read/write the Figma token stored inside the profile's *installed copy* of
 * this plugin's cordis.patch.yml — the same file lib/pin.js already rewrites
 * for version bumps ($DSH_HOME/profiles/web/node_modules/dsh-figma-bridge/
 * cordis.patch.yml). Pure functions, no HTTP/Cordis dependency, so lib/
 * index.js's routes and tests/check.mjs can both call these directly.
 *
 * Restarting dsh is still required after a write: this file is read once at
 * boot by dsh-mcp-client's config closure and is not one of the two files
 * Cordis hot-watches (only the profile's OWN cordis.patch.yml is watched for
 * live reload, never a bundle's installed copy).
 */
import { copyFile, readFile, rename, writeFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';

export const PROFILE_CONFIG = join(process.env.DSH_HOME || join(homedir(), '.dsh'), 'profiles', 'web', 'node_modules', 'dsh-figma-bridge', 'cordis.patch.yml');

export class TokenStoreError extends Error {}

async function readText(path) {
	try {
		return await readFile(path, 'utf8');
	} catch {
		return null;
	}
}

/**
 * `dsh plugin add "file:..."` hardlinks this package's files into the
 * profile's node_modules rather than copying them (confirmed: same inode as
 * the checkout) - at least with pnpm's default store on this setup, and
 * likely elsewhere too, since that is how pnpm's content-addressable store
 * works. Writing in place with writeFile() would truncate the shared inode
 * and silently corrupt the tracked checkout file. Writing to a temp file next
 * to the target and renaming over it replaces the directory entry instead,
 * which breaks the hardlink cleanly without touching the checkout.
 */
async function writeTextAtomic(path, content) {
	const tmp = `${path}.tmp.${process.pid}`;
	await writeFile(tmp, content, 'utf8');
	await rename(tmp, path);
}

function indentOf(line) {
	return /^\s*/.exec(line)[0].length;
}

/** Every top-level "- insert:" (column 0) block, as [start, end) line ranges. */
function topLevelBlocks(lines) {
	const starts = [];
	for (let i = 0; i < lines.length; i += 1) {
		if (/^-\s*insert:\s*\r?$/.test(lines[i])) starts.push(i);
	}
	return starts.map((start, idx) => ({ start, end: idx + 1 < starts.length ? starts[idx + 1] : lines.length }));
}

/** The top-level block whose nested list carries "- id: <id>". */
function findBlockWithId(lines, id) {
	const idPattern = new RegExp(`^\\s+-\\s*id:\\s*${id}\\s*\\r?$`);
	for (const block of topLevelBlocks(lines)) {
		for (let i = block.start; i < block.end; i += 1) {
			if (idPattern.test(lines[i])) return block;
		}
	}
	return null;
}

/** A mapping key's own sub-block: the key line plus every deeper-indented line after it. */
function childBlockRange(lines, keyLineIndex) {
	const indent = indentOf(lines[keyLineIndex]);
	let end = keyLineIndex + 1;
	while (end < lines.length) {
		const line = lines[end];
		if (line.trim().length === 0) { end += 1; continue; }
		if (indentOf(line) <= indent) break;
		end += 1;
	}
	return { start: keyLineIndex, end };
}

/** Where mcp-figma's config: line and (if present) its env: child line are. */
function locateEnvSlot(lines, block) {
	let configLine = -1;
	for (let i = block.start; i < block.end; i += 1) {
		if (/^\s*config:\s*\r?$/.test(lines[i])) { configLine = i; break; }
	}
	if (configLine === -1) return null;
	const childIndent = indentOf(lines[configLine]) + 2;
	let envLine = -1;
	for (let i = configLine + 1; i < block.end; i += 1) {
		const line = lines[i];
		if (line.trim().length === 0) continue;
		if (indentOf(line) < childIndent) break;
		if (indentOf(line) === childIndent && /^\s*env:\s*\r?$/.test(line)) { envLine = i; break; }
	}
	return { configLine, envLine, childIndent };
}

function escapeYamlDouble(value) {
	return value.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
}

function unescapeYamlDouble(value) {
	return value.replace(/\\(.)/g, '$1');
}

function mask(token) {
	if (token.length <= 8) return '*'.repeat(Math.max(token.length, 4));
	return `${token.slice(0, 5)}****${token.slice(-4)}`;
}

/**
 * @returns {Promise<{installed: boolean, tokenSet: boolean, masked: string|null}>}
 */
export async function readStatus() {
	const text = await readText(PROFILE_CONFIG);
	if (text === null) return { installed: false, tokenSet: false, masked: null };
	const lines = text.split('\n');
	const block = findBlockWithId(lines, 'mcp-figma');
	if (block === null) return { installed: true, tokenSet: false, masked: null };
	for (let i = block.start; i < block.end; i += 1) {
		const match = lines[i].match(/^\s*FIGMA_ACCESS_TOKEN:\s*"((?:[^"\\]|\\.)*)"\s*\r?$/);
		if (match !== null) {
			const token = unescapeYamlDouble(match[1]);
			return { installed: true, tokenSet: token.length > 0, masked: token.length > 0 ? mask(token) : null };
		}
	}
	return { installed: true, tokenSet: false, masked: null };
}

/**
 * Sets FIGMA_ACCESS_TOKEN and ENABLE_MCP_APPS together, matching the pair
 * every setup script and doc has always told people to set by hand. Throws
 * TokenStoreError with a message safe to show in the Settings UI.
 */
export async function writeToken(rawToken) {
	const token = typeof rawToken === 'string' ? rawToken.trim() : '';
	if (token.length === 0) throw new TokenStoreError('Token is empty.');
	if (/[\r\n]/.test(token)) throw new TokenStoreError('Token cannot contain a line break - check what you pasted.');

	const text = await readText(PROFILE_CONFIG);
	if (text === null) throw new TokenStoreError('figma-bridge is not installed in this profile yet - run setup.sh/setup.bat or dsh plugin add first.');
	const lines = text.split('\n');
	const block = findBlockWithId(lines, 'mcp-figma');
	if (block === null) throw new TokenStoreError('No mcp-figma entry found in the installed cordis.patch.yml.');
	const slot = locateEnvSlot(lines, block);
	if (slot === null) throw new TokenStoreError('mcp-figma entry has no config: block - this checkout may be corrupted.');

	const crlf = /\r$/.test(lines[slot.configLine]) ? '\r' : '';
	const pad = ' '.repeat(slot.childIndent);
	const pad2 = ' '.repeat(slot.childIndent + 2);
	const newEnvLines = [
		`${pad}env:${crlf}`,
		`${pad2}FIGMA_ACCESS_TOKEN: "${escapeYamlDouble(token)}"${crlf}`,
		`${pad2}ENABLE_MCP_APPS: "true"${crlf}`
	];

	const rewrittenLines = slot.envLine === -1
		? [...lines.slice(0, slot.configLine + 1), ...newEnvLines, ...lines.slice(slot.configLine + 1)]
		: (() => {
			const range = childBlockRange(lines, slot.envLine);
			return [...lines.slice(0, range.start), ...newEnvLines, ...lines.slice(range.end)];
		})();

	try {
		await copyFile(PROFILE_CONFIG, `${PROFILE_CONFIG}.bak`);
		await writeTextAtomic(PROFILE_CONFIG, rewrittenLines.join('\n'));
	} catch (error) {
		throw new TokenStoreError(`Could not write ${PROFILE_CONFIG}: ${error.message}`);
	}
}

/** Removes the env: block entirely, for a "clear token" action in the UI. */
export async function clearToken() {
	const text = await readText(PROFILE_CONFIG);
	if (text === null) return;
	const lines = text.split('\n');
	const block = findBlockWithId(lines, 'mcp-figma');
	if (block === null) return;
	const slot = locateEnvSlot(lines, block);
	if (slot === null || slot.envLine === -1) return;
	const range = childBlockRange(lines, slot.envLine);
	const rewrittenLines = [...lines.slice(0, range.start), ...lines.slice(range.end)];
	try {
		await copyFile(PROFILE_CONFIG, `${PROFILE_CONFIG}.bak`);
		await writeTextAtomic(PROFILE_CONFIG, rewrittenLines.join('\n'));
	} catch (error) {
		throw new TokenStoreError(`Could not write ${PROFILE_CONFIG}: ${error.message}`);
	}
}
