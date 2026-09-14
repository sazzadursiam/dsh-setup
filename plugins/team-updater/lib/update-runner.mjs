/**
 * dsh-team-updater — detached update runner.
 *
 * Spawned by `POST /team-updater/apply` and intentionally outlives the dsh
 * process that started it: it waits for that pid to disappear, installs the
 * requested version with npm, verifies the result, then relaunches dsh with
 * the original arguments. Everything it does is appended to the log file the
 * Settings row reads back through `GET /team-updater/log`.
 *
 * Runs with plain Node and no imports beyond the standard library, so it
 * keeps working even while the installation it is replacing is being changed.
 * @module dsh-team-updater/update-runner
 */
import { spawn } from 'node:child_process';
import { appendFile, mkdir, readFile } from 'node:fs/promises';
import { dirname } from 'node:path';

const WAIT_TIMEOUT_MS = 30 * 60 * 1000;
const WAIT_POLL_MS = 500;
const INSTALL_TIMEOUT_MS = 10 * 60 * 1000;

/** Parse `--key value` pairs, keeping everything after `--` as the relaunch argv. */
function parseArguments(argv) {
	const values = {};
	let index = 0;
	while (index < argv.length) {
		const token = argv[index];
		if (token === '--') return { values, rest: argv.slice(index + 1) };
		if (token.startsWith('--')) {
			values[token.slice(2)] = argv[index + 1];
			index += 2;
			continue;
		}
		index += 1;
	}
	return { values, rest: [] };
}

/** Append one timestamped line to the log file (and to stderr while attached). */
function makeLogger(logPath) {
	return async (message) => {
		const line = `[${new Date().toISOString()}] ${message}\n`;
		try {
			await appendFile(logPath, line, 'utf8');
		} catch {
			/* a log that cannot be written must not abort the update */
		}
		process.stderr.write(`team-updater: ${message}\n`);
	};
}

/** True while a pid still exists. */
function isAlive(pid) {
	try {
		process.kill(pid, 0);
		return true;
	} catch (error) {
		return error?.code === 'EPERM';
	}
}

/** Wait for a process to exit, or give up after the timeout. */
async function waitForExit(pid, log) {
	const deadline = Date.now() + WAIT_TIMEOUT_MS;
	while (isAlive(pid)) {
		if (Date.now() > deadline) {
			await log(`dsh (pid ${pid}) is still running after ${Math.round(WAIT_TIMEOUT_MS / 60000)} minutes; giving up without installing. Run "npm install -g" manually, or click Update again and quit dsh.`);
			return false;
		}
		await new Promise((settle) => setTimeout(settle, WAIT_POLL_MS));
	}
	return true;
}

/** Run one command, capturing both streams into the log. */
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

/**
 * Run npm through the platform shell: npm is a `.cmd` shim on Windows, which
 * `spawn` cannot execute without a shell.
 */
function runNpm(args, cwd, timeout) {
	if (process.platform === 'win32') {
		return run(process.env.ComSpec ?? 'cmd.exe', ['/d', '/s', '/c', `npm ${args.join(' ')}`], { cwd, timeout });
	}
	return run('npm', args, { cwd, timeout });
}

/** Read the installed version from `npm root -g`. */
async function installedVersion(packageName, cwd) {
	const root = await runNpm(['root', '-g'], cwd, 60_000);
	if (root.code !== 0) return null;
	const manifestPath = `${root.output.trim().split(/\r?\n/).pop()}/${packageName}/package.json`;
	try {
		const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
		return typeof manifest.version === 'string' ? manifest.version : null;
	} catch {
		return null;
	}
}

/**
 * Ask the parent dsh to quit so the installation can be replaced. Windows
 * first tries a polite taskkill (which a windowless console process usually
 * refuses) and then escalates to a forced one; POSIX sends SIGTERM.
 * @returns true when the process is gone afterwards.
 */
async function terminate(pid, log) {
	try {
		if (process.platform === 'win32') {
			const shell = process.env.ComSpec ?? 'cmd.exe';
			const polite = await run(shell, ['/d', '/s', '/c', `taskkill /pid ${pid}`], { timeout: 30_000 });
			await log(`taskkill exited ${polite.code}${polite.output.trim().length > 0 ? `: ${polite.output.trim()}` : ''}`);
			const deadline = Date.now() + 5_000;
			while (isAlive(pid) && Date.now() < deadline) await new Promise((settle) => setTimeout(settle, WAIT_POLL_MS));
			if (!isAlive(pid)) return true;
			const forced = await run(shell, ['/d', '/s', '/c', `taskkill /pid ${pid} /f`], { timeout: 30_000 });
			await log(`taskkill /f exited ${forced.code}${forced.output.trim().length > 0 ? `: ${forced.output.trim()}` : ''}`);
		} else {
			process.kill(pid, 'SIGTERM');
			await log('sent SIGTERM to dsh');
		}
	} catch (error) {
		await log(`could not quit dsh automatically (${error?.message ?? String(error)}); waiting for a manual quit instead`);
	}
	return !isAlive(pid);
}

/**
 * Entry point: wait for dsh, install, verify, relaunch.
 */
async function main() {
	const { values, rest } = parseArguments(process.argv.slice(2));
	const logPath = values.log;
	const packageName = values.package;
	const version = values.version;
	const cwd = values.cwd ?? process.cwd();
	const parentPid = Number(values['parent-pid']);
	const restart = values.restart !== 'no';
	const registry = values.registry;
	if (typeof logPath !== 'string' || typeof packageName !== 'string' || typeof version !== 'string') {
		process.stderr.write('team-updater: missing --log, --package, or --version\n');
		process.exit(2);
	}
	await mkdir(dirname(logPath), { recursive: true });
	const log = makeLogger(logPath);
	// npm skips a dependency's install scripts unless its package is named here,
	// which matters on macOS and Linux: node-pty ships spawn-helper without its
	// executable bit and dsh-subprocess-local's postinstall restores it. The host
	// half reads the list from the checkout's DSH_ALLOW_SCRIPTS. Checked before
	// dsh is touched: a host half older than this runner does not pass it, and
	// quitting dsh for an install that cannot be done right would be worse.
	const allowScripts = values['allow-scripts'];
	if (typeof allowScripts !== 'string' || allowScripts.length === 0) {
		await log('no --allow-scripts from the running dsh, which predates this runner; nothing was changed. Restart dsh and click Update again.');
		process.exit(2);
	}
	const quit = values.quit === 'yes';
	await log(`staged: install ${packageName}@${version} (registry ${registry}, restart ${restart ? 'yes' : 'no'}, quit ${quit ? 'yes' : 'no'})`);
	if (quit && Number.isFinite(parentPid) && parentPid > 0) {
		await log(`quitting dsh (pid ${parentPid}) so the install can replace it`);
		await new Promise((settle) => setTimeout(settle, 1_200));
		await terminate(parentPid, log);
	}
	if (Number.isFinite(parentPid) && parentPid > 0) {
		await log(`waiting for dsh (pid ${parentPid}) to exit`);
		if (!await waitForExit(parentPid, log)) process.exit(3);
		// Windows releases mapped addons slightly after the process disappears.
		await new Promise((settle) => setTimeout(settle, 1_500));
	}
	const installArgs = ['install', '-g', `--allow-scripts=${allowScripts}`, `${packageName}@${version}`];
	if (typeof registry === 'string' && registry.length > 0) installArgs.push('--registry', registry);
	const installed = await runNpm(installArgs, cwd, INSTALL_TIMEOUT_MS);
	await log(`npm ${installArgs.join(' ')} exited ${installed.code}`);
	if (installed.output.trim().length > 0) await log(installed.output.trim());
	if (installed.code !== 0) {
		await log('install failed — dsh was NOT updated; the previous version is still installed. Re-run the command above in a terminal to see the full output.');
		process.exit(installed.code ?? 1);
	}
	const verified = await installedVersion(packageName, cwd);
	await log(`installed version now reads ${verified ?? 'unknown'}`);
	if (!restart) {
		await log('restart disabled; start dsh yourself to pick up the update.');
		process.exit(0);
	}
	const relaunch = rest.length > 0 ? ['dsh', ...rest].join(' ') : 'dsh web';
	if (process.platform === 'win32') {
		spawn(process.env.ComSpec ?? 'cmd.exe', ['/d', '/s', '/c', `start "" ${relaunch}`], { cwd, detached: true, stdio: 'ignore', windowsHide: false }).unref();
	} else {
		const [program, ...args] = relaunch.split(' ');
		spawn(program, args, { cwd, detached: true, stdio: 'ignore' }).unref();
	}
	await log(`relaunched: ${relaunch} (cwd ${cwd})`);
	process.exit(0);
}

main().catch((error) => {
	process.stderr.write(`team-updater: ${error?.stack ?? String(error)}\n`);
	process.exit(1);
});
