/**
 * The checkout root(s) this installed copy of dsh-team-updater could have
 * come from, most specific first.
 *
 * The package root sits two levels below the checkout root in both layouts:
 * `<checkout>/plugins/team-updater` and `<profile>/node_modules/dsh-team-updater`.
 * The profile copy is a real copy, not a link, so from there the checkout is
 * only reachable through the `file:` spec the profile recorded when setup
 * added the plugin.
 *
 * Extracted out of pin.js's `candidates()` so a route that needs the checkout
 * root itself (to reach plugins/figma-bridge, for the "Add Figma integration"
 * button) can reuse the same resolution without pin.js's file-specific concerns.
 * @module dsh-team-updater/checkout
 */
import { readFile } from 'node:fs/promises';
import { dirname, isAbsolute, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const PLUGIN_PACKAGE = 'dsh-team-updater';
const PACKAGE_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');

async function readText(path) {
	try {
		return await readFile(path, 'utf8');
	} catch {
		return null;
	}
}

/**
 * @param packageRoot - this package's root; overridable for tests.
 * @returns candidate checkout-root directories, most specific first, deduped.
 */
async function checkoutRoots(packageRoot = PACKAGE_ROOT) {
	const above = resolve(packageRoot, '..', '..');
	const roots = [above];
	const manifest = await readText(resolve(above, 'package.json'));
	if (manifest !== null) {
		try {
			const spec = JSON.parse(manifest)?.dependencies?.[PLUGIN_PACKAGE];
			if (typeof spec === 'string' && spec.startsWith('file:')) {
				const source = spec.slice('file:'.length);
				const plugin = isAbsolute(source) ? source : resolve(above, source);
				roots.push(resolve(plugin, '..', '..'));
			}
		} catch {
			/* not a readable profile manifest: only the checkout candidate applies */
		}
	}
	const seen = new Set();
	return roots.filter((root) => (seen.has(root) ? false : (seen.add(root), true)));
}

export { checkoutRoots, PACKAGE_ROOT };
