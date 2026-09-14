/**
 * The dsh version this machine is meant to run, as pinned by dsh-setup, and
 * the install-script allowlist that goes with it.
 *
 * setup and update install whatever the checkout's DSH_VERSION names. The row
 * follows the same file, so a click can never take a machine somewhere the next
 * `update` would move it back from, and a version nobody has reviewed is never
 * offered just because the registry published it.
 * @module dsh-team-updater/pin
 */
import { readFile } from 'node:fs/promises';
import { dirname, isAbsolute, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { isVersionLike } from './version.js';

const PIN_FILE = 'DSH_VERSION';
const ALLOW_FILE = 'DSH_ALLOW_SCRIPTS';
const PLUGIN_PACKAGE = 'dsh-team-updater';
/**
 * Used only when no DSH_ALLOW_SCRIPTS can be found — a plugin copy installed
 * from outside any checkout. tests/check.mjs fails when it drifts from the file.
 */
const DEFAULT_ALLOW_SCRIPTS = '@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs';
/**
 * Comma-separated package names. Checked because the runner hands the list to
 * npm through cmd.exe on Windows, where anything else would be shell syntax.
 */
const PACKAGE_NAME = '(?:@[a-z0-9][a-z0-9._~-]*\\/)?[a-z0-9][a-z0-9._~-]*';
const ALLOW_LIST = new RegExp(`^${PACKAGE_NAME}(?:,${PACKAGE_NAME})*$`, 'i');

const PACKAGE_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');

async function readText(path) {
	try {
		return await readFile(path, 'utf8');
	} catch {
		return null;
	}
}

/**
 * Candidate locations for a checkout-root file, most specific first.
 *
 * The package root sits two levels below the directory that matters in both
 * layouts: `<checkout>/plugins/team-updater` and
 * `<profile>/node_modules/dsh-team-updater`. The profile copy is a real copy,
 * not a link, so from there the checkout is only reachable through the `file:`
 * spec the profile recorded when setup added the plugin.
 */
async function candidates(packageRoot, fileName) {
	const above = resolve(packageRoot, '..', '..');
	const found = [resolve(above, fileName)];
	const manifest = await readText(resolve(above, 'package.json'));
	if (manifest !== null) {
		try {
			const spec = JSON.parse(manifest)?.dependencies?.[PLUGIN_PACKAGE];
			if (typeof spec === 'string' && spec.startsWith('file:')) {
				const source = spec.slice('file:'.length);
				const plugin = isAbsolute(source) ? source : resolve(above, source);
				found.push(resolve(plugin, '..', '..', fileName));
			}
		} catch {
			/* not a readable profile manifest: only the checkout candidate applies */
		}
	}
	return found;
}

/**
 * Find and read the pin.
 * @param explicit - optional path from the plugin config, which wins outright.
 * @param packageRoot - this package's root; overridable for tests.
 * @returns null when no pin file exists (or it is empty) — the same "unpinned"
 *   the setup scripts fall back to; otherwise `{ path, version }`, or
 *   `{ path, version: null, error }` when the file holds something that is not a
 *   version. That last case must not fall back to the registry: a broken pin
 *   quietly turning into "latest" is the failure the pin exists to prevent.
 */
async function readPin(explicit, packageRoot = PACKAGE_ROOT) {
	const explicitlySet = typeof explicit === 'string' && explicit.length > 0;
	const paths = explicitlySet ? [resolve(explicit)] : await candidates(packageRoot, PIN_FILE);
	for (const path of paths) {
		const text = await readText(path);
		if (text === null) {
			if (explicitlySet) return { path, version: null, error: `versionFile ${path} cannot be read` };
			continue;
		}
		const version = text.trim();
		if (version.length === 0) return null;
		if (!isVersionLike(version)) return { path, version: null, error: `${path} does not hold a version: ${JSON.stringify(version.slice(0, 40))}` };
		return { path, version };
	}
	return null;
}

/**
 * Find and read the install-script allowlist that goes with the pin.
 * @param explicitVersionFile - the configured versionFile; the list is looked for beside it.
 * @param packageRoot - this package's root; overridable for tests.
 * @returns `{ path, list }` from DSH_ALLOW_SCRIPTS; `{ path: null, list }` with the
 *   built-in default when no such file exists; or `{ path, list: null, error }`
 *   when the file is empty or malformed. An install without the right list
 *   leaves native modules unprepared, so a broken file refuses rather than
 *   quietly falling back.
 */
async function readAllowScripts(explicitVersionFile, packageRoot = PACKAGE_ROOT) {
	const paths = typeof explicitVersionFile === 'string' && explicitVersionFile.length > 0
		? [resolve(dirname(resolve(explicitVersionFile)), ALLOW_FILE)]
		: await candidates(packageRoot, ALLOW_FILE);
	for (const path of paths) {
		const text = await readText(path);
		if (text === null) continue;
		const list = text.trim();
		if (!ALLOW_LIST.test(list)) return { path, list: null, error: `${path} does not hold a comma-separated package list: ${JSON.stringify(list.slice(0, 40))}` };
		return { path, list };
	}
	return { path: null, list: DEFAULT_ALLOW_SCRIPTS };
}

export { DEFAULT_ALLOW_SCRIPTS, readAllowScripts, readPin };
