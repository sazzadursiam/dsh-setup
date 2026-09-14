/**
 * The dsh version this machine is meant to run, as pinned by dsh-setup.
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
const PLUGIN_PACKAGE = 'dsh-team-updater';

async function readText(path) {
	try {
		return await readFile(path, 'utf8');
	} catch {
		return null;
	}
}

/**
 * Candidate locations for DSH_VERSION, most specific first.
 *
 * The package root sits two levels below the directory that matters in both
 * layouts: `<checkout>/plugins/team-updater` and
 * `<profile>/node_modules/dsh-team-updater`. The profile copy is a real copy,
 * not a link, so from there the checkout is only reachable through the `file:`
 * spec the profile recorded when setup added the plugin.
 */
async function candidates(explicit, packageRoot) {
	if (typeof explicit === 'string' && explicit.length > 0) return [resolve(explicit)];
	const above = resolve(packageRoot, '..', '..');
	const found = [resolve(above, PIN_FILE)];
	const manifest = await readText(resolve(above, 'package.json'));
	if (manifest !== null) {
		try {
			const spec = JSON.parse(manifest)?.dependencies?.[PLUGIN_PACKAGE];
			if (typeof spec === 'string' && spec.startsWith('file:')) {
				const source = spec.slice('file:'.length);
				const plugin = isAbsolute(source) ? source : resolve(above, source);
				found.push(resolve(plugin, '..', '..', PIN_FILE));
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
async function readPin(explicit, packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..')) {
	const explicitlySet = typeof explicit === 'string' && explicit.length > 0;
	for (const path of await candidates(explicit, packageRoot)) {
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

export { readPin };
