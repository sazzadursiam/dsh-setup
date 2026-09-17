/**
 * dsh-team-updater — host half.
 *
 * Ships routes on the web GUI's own origin and a browser row that calls them,
 * so a dsh install can be updated from its own Settings panel:
 *
 *   GET  /team-updater/status        → installed vs registry version, update flag
 *   GET  /team-updater/log           → tail of the update runner's log file
 *   POST /team-updater/apply         → stage the update and hand off to the runner
 *   GET  /team-updater/figma-status  → whether plugins/figma-bridge is installed
 *   POST /team-updater/figma-install → install it (opt-in, added later from Settings)
 *
 * Why staging instead of `npm install -g` in place: the running dsh process
 * keeps native addons (node-pty, koffi, sharp) mapped, and Windows refuses to
 * replace a mapped DLL. So `apply` spawns a detached runner that waits for
 * this process to exit, installs the requested version, then relaunches dsh
 * with the same arguments. Nothing in the running process is replaced.
 *
 * figma-install does not need any of that: adding a new plugin bundle to the
 * profile's node_modules does not touch the running dsh process at all (only
 * loading it does, which happens on the next boot) - so it runs `dsh plugin
 * add` synchronously in this request and just reports that a restart is
 * needed, no detached runner.
 *
 * The routes carry no authorization of their own; every request is first put
 * through the Connection Host/Origin fence and browser authentication, the
 * same policy the `/api` bridge uses.
 * @module dsh-team-updater
 */
import { spawn } from 'node:child_process';
import { access, mkdir, readFile } from 'node:fs/promises';
import { homedir, tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { checkoutRoots } from './checkout.js';
import { readAllowScripts, readPin } from './pin.js';
import { run } from './proc.js';
import { isNewer, isVersionLike } from './version.js';

/** Stable Cordis plugin name. */
const name = 'team-updater';
/** Services required before the routes can be claimed. */
const inject = ['webServer', 'connection'];
/** Route namespace; exact paths, so nothing else on the origin is shadowed. */
const ROUTE_BASE = '/team-updater';
/** The package this plugin updates. */
const PACKAGE_NAME = '@deepseek-ai/dsh';
const DEFAULT_REGISTRY = 'https://registry.npmjs.org';
const DEFAULT_TAG = 'latest';
/** A registry answer is reused for this long before `status` refetches. */
const CHECK_TTL_MS = 30_000;
const REGISTRY_TIMEOUT_MS = 10_000;
const LOG_TAIL_BYTES = 8_192;
const BODY_LIMIT_BYTES = 64 * 1024;
/** The package figma-install adds; matches plugins/figma-bridge/package.json's "name". */
const FIGMA_PACKAGE = 'dsh-figma-bridge';
/** dsh plugin add shells out to pnpm, which may need to resolve/build a native module. */
const FIGMA_INSTALL_TIMEOUT_MS = 10 * 60 * 1000;

/** Turn plugin config into the effective options, ignoring anything malformed. */
function resolveOptions(config) {
	const raw = config !== null && typeof config === 'object' ? config : {};
	const tag = typeof raw.tag === 'string' && raw.tag.length > 0 ? raw.tag : DEFAULT_TAG;
	const registry = typeof raw.registry === 'string' && raw.registry.length > 0 ? raw.registry : DEFAULT_REGISTRY;
	const blocked = new Map();
	if (raw.blocked !== null && typeof raw.blocked === 'object') {
		for (const [version, reason] of Object.entries(raw.blocked)) {
			if (isVersionLike(version) && typeof reason === 'string' && reason.length > 0) blocked.set(version, reason);
		}
	}
	return {
		tag,
		registry: registry.replace(/\/+$/, ''),
		restart: raw.restart !== false,
		versionFile: typeof raw.versionFile === 'string' && raw.versionFile.length > 0 ? raw.versionFile : null,
		blocked
	};
}

/**
 * Why a version must not be installed, or null when it is fine.
 *
 * A released version can turn out to break the installs it lands on — dsh
 * 0.1.5-rc.1 cannot resume any session written by an earlier version — and the
 * registry keeps offering it. Config, not code, so the entry can be dropped
 * when a fixed version ships.
 */
function blockedReasonFor(version, blocked) {
	return blocked.get(version) ?? null;
}

/**
 * Read the version of the dsh installation this process booted from by walking
 * outward from the launcher script in `process.argv[1]`.
 * @returns the installed version, or null when the entry point is not a dsh install.
 */
async function readInstalledVersion() {
	const entry = process.argv[1];
	const candidates = [];
	if (typeof entry === 'string' && entry.length > 0) {
		candidates.push(resolve(dirname(entry), '..', 'package.json'));
		candidates.push(resolve(dirname(entry), 'package.json'));
	}
	if (typeof process.env.DSH_TEAM_UPDATER_VERSION === 'string' && process.env.DSH_TEAM_UPDATER_VERSION.length > 0) return process.env.DSH_TEAM_UPDATER_VERSION;
	for (const candidate of candidates) {
		try {
			const manifest = JSON.parse(await readFile(candidate, 'utf8'));
			if (manifest !== null && typeof manifest === 'object' && manifest.name === PACKAGE_NAME && typeof manifest.version === 'string') return manifest.version;
		} catch {
			/* not this candidate: keep walking */
		}
	}
	return null;
}

/**
 * Ask the registry for the version the configured tag points at.
 * @returns the resolved version plus the packument's dist-tags.
 */
async function fetchRegistryVersion(options) {
	const url = `${options.registry}/${PACKAGE_NAME.replace('/', '%2f')}`;
	const response = await fetch(url, {
		headers: { accept: 'application/vnd.npm.install-v1+json' },
		signal: AbortSignal.timeout(REGISTRY_TIMEOUT_MS)
	});
	if (!response.ok) throw new Error(`registry responded ${response.status} ${response.statusText}`);
	const packument = await response.json();
	const distTags = packument !== null && typeof packument === 'object' && packument['dist-tags'] !== null && typeof packument['dist-tags'] === 'object' ? packument['dist-tags'] : {};
	// An exact version in `tag` skips the tag table entirely. It is checked
	// against the published list because the runner quits dsh before npm runs:
	// a typo'd version would otherwise leave dsh stopped with nothing installed.
	if (isVersionLike(options.tag)) {
		const versions = packument?.versions;
		const published = versions !== null && typeof versions === 'object' ? Object.hasOwn(versions, options.tag) : null;
		return { latest: options.tag, tag: options.tag, distTags, exact: true, published };
	}
	const resolved = distTags[options.tag];
	if (typeof resolved !== 'string') throw new Error(`registry advertises no dist-tag ${JSON.stringify(options.tag)}`);
	return { latest: resolved, tag: options.tag, distTags, exact: false, published: true };
}

/**
 * The update command shown as the manual fallback in the UI. The allowlist
 * comes from the checkout's DSH_ALLOW_SCRIPTS, the same file setup and update
 * install with, since it changes along with the pinned version.
 */
function manualCommand(version, allowScripts) {
	return `npm install -g --allow-scripts=${allowScripts} ${PACKAGE_NAME}@${version}`;
}

/** Log file and its directory for one process. */
function logPaths() {
	const directory = join(tmpdir(), 'dsh-team-updater');
	return { directory, logPath: join(directory, 'update.log') };
}

/** Read the tail of the runner's log, or null when nothing has run yet. */
async function readLogTail(logPath) {
	try {
		const text = await readFile(logPath, 'utf8');
		return text.length > LOG_TAIL_BYTES ? text.slice(text.length - LOG_TAIL_BYTES) : text;
	} catch {
		return null;
	}
}

/** Write one JSON response. */
function writeJson(response, status, body) {
	const payload = JSON.stringify(body);
	response.writeHead(status, {
		'content-type': 'application/json; charset=utf-8',
		'cache-control': 'no-store',
		'content-length': Buffer.byteLength(payload)
	});
	response.end(payload);
}

/**
 * Apply Connection's Host/Origin fence and browser authentication to one of
 * this plugin's routes, falling back to a loopback-socket check when the
 * Connection service is not composed.
 * @returns true when the request may proceed; a rejection is already written otherwise.
 */
function authorize(ctx, request, response) {
	const connection = ctx.connection;
	if (connection !== undefined && typeof connection.requestRejection === 'function') {
		const rejection = connection.requestRejection({ headers: request.headers });
		if (rejection !== undefined) {
			response.writeHead(rejection);
			response.end();
			return false;
		}
		return true;
	}
	const address = request.socket?.remoteAddress ?? '';
	const loopback = address === '127.0.0.1' || address === '::1' || address === 'ffff:127.0.0.1' || address === '::ffff:127.0.0.1';
	if (!loopback) {
		response.writeHead(403);
		response.end();
		return false;
	}
	return true;
}

/** Read a bounded JSON request body, or null when it is absent or malformed. */
async function readJsonBody(request) {
	const chunks = [];
	let size = 0;
	for await (const chunk of request) {
		size += chunk.length;
		if (size > BODY_LIMIT_BYTES) return null;
		chunks.push(chunk);
	}
	if (size === 0) return {};
	try {
		const parsed = JSON.parse(Buffer.concat(chunks).toString('utf8'));
		return parsed !== null && typeof parsed === 'object' ? parsed : null;
	} catch {
		return null;
	}
}

async function pathExists(path) {
	try {
		await access(path);
		return true;
	} catch {
		return false;
	}
}

/** $DSH_HOME/profiles/web - where `dsh plugin add` installs bundles. */
function webProfileDir() {
	return join(process.env.DSH_HOME || join(homedir(), '.dsh'), 'profiles', 'web');
}

/**
 * Whether the profile already depends on dsh-figma-bridge - i.e. it is
 * plugin-managed, the same check plugins/figma-bridge/lib/migrate.js uses.
 * Duplicated rather than imported: team-updater and figma-bridge are each
 * independently add/removable via `dsh plugin add`, so neither reaches into
 * the other's internals (authorize()/writeJson() are duplicated the same way
 * in plugins/figma-bridge/lib/index.js).
 */
async function isFigmaBridgeInstalled() {
	try {
		const manifest = JSON.parse(await readFile(join(webProfileDir(), 'package.json'), 'utf8'));
		return manifest?.dependencies?.[FIGMA_PACKAGE] !== undefined;
	} catch {
		return false;
	}
}

/**
 * The checkout root that actually contains plugins/figma-bridge, or null when
 * none of the candidates do (the checkout may have moved or been deleted
 * since this plugin was installed).
 */
async function findCheckoutRoot() {
	for (const root of await checkoutRoots()) {
		if (await pathExists(join(root, 'plugins', 'figma-bridge', 'package.json'))) return root;
	}
	return null;
}

/**
 * Run `dsh` through the platform shell on Windows, for the same reason
 * update-runner.mjs wraps npm: an npm-global install is a `.cmd` shim that
 * spawn() cannot execute directly without a shell.
 */
function runDsh(args, cwd, timeout) {
	if (process.platform === 'win32') {
		const quoted = args.map((arg) => (/[\s"]/.test(arg) ? `"${arg.replace(/"/g, '""')}"` : arg)).join(' ');
		return run(process.env.ComSpec ?? 'cmd.exe', ['/d', '/s', '/c', `dsh ${quoted}`], { cwd, timeout });
	}
	return run('dsh', args, { cwd, timeout });
}

/**
 * Stage an update: spawn the detached runner, which optionally quits this
 * process, waits for it to disappear, installs the version, and relaunches
 * dsh.
 *
 * Quitting is the runner's job, not this process's: exiting in-process while
 * fetch handles are open trips a libuv assertion on Windows, and an external
 * terminator is what an installer would do anyway.
 * @returns the runner's pid and the log path.
 */
async function startUpdate({ options, version, allowScripts, parentPid, argv, quit }) {
	const { directory, logPath } = logPaths();
	await mkdir(directory, { recursive: true });
	const runner = fileURLToPath(new URL('./update-runner.mjs', import.meta.url));
	const args = [
		runner,
		'--parent-pid', String(parentPid),
		'--package', PACKAGE_NAME,
		'--version', version,
		'--allow-scripts', allowScripts,
		'--cwd', process.cwd(),
		'--log', logPath,
		'--registry', options.registry,
		'--restart', options.restart ? 'yes' : 'no',
		'--quit', quit ? 'yes' : 'no',
		'--',
		...argv
	];
	const child = spawn(process.execPath, args, { detached: true, stdio: 'ignore', windowsHide: true });
	child.unref();
	return { logPath, runnerPid: child.pid };
}

/**
 * Claim the updater routes on the web GUI's origin.
 * @param ctx - plugin context carrying the webServer and connection services.
 * @param config - optional `{ tag, registry, restart, versionFile, blocked }`.
 */
function apply(ctx, config) {
	const options = resolveOptions(config);
	/** Last registry answer, reused inside {@link CHECK_TTL_MS}. */
	let cached;
	const status = async (refresh) => {
		const now = Date.now();
		if (!refresh && cached !== undefined && now - cached.at < CHECK_TTL_MS) return cached.value;
		const current = await readInstalledVersion();
		const pin = await readPin(options.versionFile);
		const pinned = pin?.version ?? null;
		const allow = await readAllowScripts(options.versionFile);
		// Either file being unreadable stops the row: both decide what gets installed.
		const pinError = pin?.error ?? allow.error ?? null;
		const registry = await fetchRegistryVersion(pinned === null ? options : { ...options, tag: pinned });
		const blockedReason = blockedReasonFor(registry.latest, options.blocked);
		// Pinned, the row converges on the pin in either direction: a machine that
		// took a newer release than the checkout names is offered its way back,
		// which is the same move `update` makes. Unpinned, it only goes forward.
		const wanted = pinned === null
			? isNewer(registry.latest, current ?? registry.latest)
			: current !== pinned;
		const updateAvailable = current !== null && pinError === null && wanted
			&& blockedReason === null && registry.published !== false;
		const value = {
			current,
			latest: registry.latest,
			tag: registry.tag,
			updateAvailable,
			blockedReason,
			pinned,
			pinFile: pin?.path ?? null,
			pinError,
			allowScripts: allow.list,
			allowScriptsFile: allow.path,
			published: registry.published,
			exact: registry.exact,
			distTags: registry.distTags,
			registry: options.registry,
			restart: options.restart,
			checkedAt: new Date(now).toISOString(),
			// No copyable command while the pin is unreadable: the only version to
			// hand would be the registry's, which is exactly what must not be offered.
			command: pinError === null ? manualCommand(registry.latest, allow.list) : undefined,
			logPath: logPaths().logPath
		};
		cached = { at: now, value };
		return value;
	};
	const route = (path, method, handler) => ctx.effect(
		() => ctx.webServer.register({
			kind: 'exact',
			path,
			handler: async (request, response) => {
				if (!authorize(ctx, request, response)) return;
				if (request.method !== method) {
					response.writeHead(405, { allow: method });
					response.end();
					return;
				}
				try {
					await handler(request, response);
				} catch (error) {
					writeJson(response, 502, { error: error instanceof Error ? error.message : String(error) });
				}
			}
		}),
		`team-updater: ${method} ${path}`
	);
	route(`${ROUTE_BASE}/status`, 'GET', async (request, response) => {
		const refresh = new URL(request.url ?? '/', 'http://localhost').searchParams.has('refresh');
		writeJson(response, 200, await status(refresh));
	});
	route(`${ROUTE_BASE}/log`, 'GET', async (_request, response) => {
		const { logPath } = logPaths();
		writeJson(response, 200, { path: logPath, text: await readLogTail(logPath) });
	});
	route(`${ROUTE_BASE}/apply`, 'POST', async (request, response) => {
		const body = await readJsonBody(request);
		if (body === null) {
			writeJson(response, 400, { error: 'expected a JSON object body' });
			return;
		}
		const current = await status(true);
		const version = typeof body.version === 'string' && isVersionLike(body.version) ? body.version : current.latest;
		if (!isVersionLike(version)) {
			writeJson(response, 400, { error: `not a version: ${JSON.stringify(version)}` });
			return;
		}
		// Everything below is checked here as well as in status: a request body
		// can name a version directly, without ever passing through the row.
		if (current.pinError !== null) {
			writeJson(response, 409, { error: `refusing to update: ${current.pinError}` });
			return;
		}
		if (current.pinned !== null && version !== current.pinned) {
			writeJson(response, 409, { error: `${version} is not the pinned version — ${current.pinFile} names ${current.pinned}`, version, pinned: current.pinned });
			return;
		}
		const refusal = blockedReasonFor(version, options.blocked);
		if (refusal !== null) {
			writeJson(response, 409, { error: `${version} is blocked: ${refusal}`, version, blockedReason: refusal });
			return;
		}
		if (version === current.latest && current.published === false) {
			writeJson(response, 409, { error: `${version} is not published on ${options.registry}`, version });
			return;
		}
		const quit = body.quit === true;
		const argv = process.argv.slice(2);
		const started = await startUpdate({ options, version, allowScripts: current.allowScripts, parentPid: process.pid, argv, quit });
		writeJson(response, 202, {
			started: true,
			version,
			restart: options.restart,
			quit,
			command: manualCommand(version, current.allowScripts),
			...started
		});
	});
	route(`${ROUTE_BASE}/figma-status`, 'GET', async (_request, response) => {
		const installed = await isFigmaBridgeInstalled();
		const root = await findCheckoutRoot();
		writeJson(response, 200, {
			installed,
			command: root !== null ? `dsh plugin --profile web add "file:${root}/plugins/figma-bridge"` : null
		});
	});
	route(`${ROUTE_BASE}/figma-install`, 'POST', async (_request, response) => {
		const root = await findCheckoutRoot();
		if (root === null) {
			writeJson(response, 404, { error: 'could not find the dsh-setup checkout this plugin was installed from - it may have moved or been deleted' });
			return;
		}
		// pnpm uses brackets in lockfile keys and fails with "Mismatch parenthesis".
		if (/[()]/.test(root)) {
			writeJson(response, 409, { error: 'checkout path contains ( or ) - pnpm cannot install a plugin from it. Move the checkout and try again.' });
			return;
		}
		const spec = `file:${root}/plugins/figma-bridge`;
		const result = await runDsh(['plugin', '--profile', 'web', 'add', spec], root, FIGMA_INSTALL_TIMEOUT_MS);
		if (result.code !== 0) {
			writeJson(response, 502, {
				error: `dsh plugin add failed (exit ${result.code ?? 'timeout'})`,
				output: result.output,
				command: `dsh plugin --profile web add "${spec}"`
			});
			return;
		}
		writeJson(response, 200, { ok: true, installed: true, restartNeeded: true });
	});
	if (typeof ctx.logger?.info === 'function') {
		readPin(options.versionFile).then((pin) => ctx.logger.info(pin?.version
			? `team-updater: following ${PACKAGE_NAME}@${pin.version} pinned by ${pin.path}`
			: `team-updater: no pin found; following ${PACKAGE_NAME} tag ${options.tag} on ${options.registry}`));
	}
}

export { apply, inject, name };
export default { apply, inject, name };
