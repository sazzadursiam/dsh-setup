/**
 * Version comparison for `dsh-team-updater`.
 *
 * Deliberately dependency-free: a profile plugin has no guaranteed access to
 * the repository's own packages, and the plugin matrix is small (npm versions
 * of one package, compared for ordering only).
 * @module dsh-team-updater/version
 */

/** One parsed version: numeric release triple plus prerelease identifiers. */
export function parseVersion(value) {
	if (typeof value !== 'string') return null;
	const match = /^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$/.exec(value.trim());
	if (match === null) return null;
	return {
		release: [Number(match[1]), Number(match[2]), Number(match[3])],
		prerelease: match[4] === undefined ? [] : match[4].split('.')
	};
}

/** True when `value` is a version this plugin can install and compare. */
export function isVersionLike(value) {
	return parseVersion(value) !== null;
}

/**
 * Compare two prerelease identifier lists per semver: a release outranks any
 * prerelease, numeric identifiers compare numerically, and alphanumerics
 * compare as ASCII strings.
 */
function comparePrerelease(left, right) {
	if (left.length === 0 && right.length === 0) return 0;
	if (left.length === 0) return 1;
	if (right.length === 0) return -1;
	for (let index = 0; index < Math.max(left.length, right.length); index += 1) {
		const a = left[index];
		const b = right[index];
		if (a === undefined) return -1;
		if (b === undefined) return 1;
		const numericA = /^\d+$/.test(a);
		const numericB = /^\d+$/.test(b);
		if (numericA && numericB) {
			const difference = Number(a) - Number(b);
			if (difference !== 0) return difference < 0 ? -1 : 1;
			continue;
		}
		if (numericA !== numericB) return numericA ? -1 : 1;
		if (a !== b) return a < b ? -1 : 1;
	}
	return 0;
}

/**
 * Order two versions.
 * @returns -1, 0, or 1; null when either side is not a version.
 */
export function compareVersions(left, right) {
	const a = parseVersion(left);
	const b = parseVersion(right);
	if (a === null || b === null) return null;
	for (let index = 0; index < 3; index += 1) {
		if (a.release[index] !== b.release[index]) return a.release[index] < b.release[index] ? -1 : 1;
	}
	return comparePrerelease(a.prerelease, b.prerelease);
}

/** True when `candidate` is strictly newer than `current`. */
export function isNewer(candidate, current) {
	const order = compareVersions(candidate, current);
	return order === null ? false : order > 0;
}
