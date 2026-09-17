/**
 * Run one child command, capturing both streams and enforcing a timeout.
 * Used by index.js's figma-install route (dsh plugin add).
 *
 * update-runner.mjs has its own private copy of this same function instead of
 * importing it from here — deliberately: that runner is spawned detached and
 * must keep working even while the dsh package it is replacing (and this
 * package alongside it) is mid-install, so it depends on nothing beyond the
 * Node standard library. Keep the two copies in sync by hand if this changes.
 * @module dsh-team-updater/proc
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
