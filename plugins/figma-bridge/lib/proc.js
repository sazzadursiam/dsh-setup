/**
 * Run one child command, capturing both streams and enforcing a timeout.
 * Used by index.js's remove route (`dsh plugin remove`).
 *
 * A near-identical copy lives in plugins/team-updater/lib/proc.js. Not shared:
 * the two plugins are each independently add/removable via `dsh plugin add`,
 * so neither reaches into the other's internals (authorize()/writeJson() are
 * duplicated the same way in plugins/team-updater/lib/index.js). Keep the two
 * copies in sync by hand if this changes.
 * @module dsh-figma-bridge/proc
 */
import { spawn } from 'node:child_process';

/**
 * @param command - executable to spawn.
 * @param args - its arguments.
 * @param options.cwd - working directory.
 * @param options.timeout - milliseconds before the child is killed.
 * @returns `{ code, output }` — code is null when the child could not be spawned or was killed.
 */
function run(command, args, { cwd, timeout }) {
	return new Promise((settle) => {
		const child = spawn(command, args, { cwd, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
		let output = '';
		const collect = (chunk) => {
			output += chunk.toString('utf8');
			if (output.length > 64_000) output = output.slice(output.length - 32_000);
		};
		child.stdout.on('data', collect);
		child.stderr.on('data', collect);
		const timer = setTimeout(() => child.kill(), timeout);
		child.on('error', (error) => {
			clearTimeout(timer);
			settle({ code: null, output: `${output}\n${error.message}` });
		});
		child.on('close', (code) => {
			clearTimeout(timer);
			settle({ code, output });
		});
	});
}

export { run };
