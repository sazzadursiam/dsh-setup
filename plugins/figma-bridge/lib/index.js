/**
 * dsh-figma-bridge — host half.
 *
 * Ships two routes on the web GUI's own origin and a browser row that calls
 * them, so the Figma token can be set from Settings > General instead of a
 * terminal `export`/`setx`:
 *
 *   GET  /figma-bridge/status  → whether a token is saved, masked
 *   POST /figma-bridge/token   → save a new token (also clears it, {token: ""})
 *
 * The token is written into this plugin's own INSTALLED copy of
 * cordis.patch.yml (lib/token-store.js — the same file lib/pin.js already
 * rewrites for version bumps), not the profile's personal one. That file is
 * only read at boot, so saving here does not take effect until dsh is
 * restarted — there is no live-reload for a bundle's own patch file, only for
 * the profile's. The row says so; this module never restarts anything itself.
 *
 * The routes carry no authorization of their own; every request is first put
 * through the Connection Host/Origin fence and browser authentication, the
 * same policy the `/api` bridge and dsh-team-updater's routes use.
 * @module dsh-figma-bridge
 */
import { clearToken, readStatus, TokenStoreError, writeToken } from './token-store.js';

/** Stable Cordis plugin name. */
const name = 'dsh-figma-bridge';
/** Services required before the routes can be claimed. */
const inject = ['webServer', 'connection'];
const ROUTE_BASE = '/figma-bridge';
const BODY_LIMIT_BYTES = 8 * 1024;

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

/**
 * Claim the figma-bridge routes on the web GUI's origin.
 * @param ctx - plugin context carrying the webServer and connection services.
 */
function apply(ctx) {
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
		`figma-bridge: ${method} ${path}`
	);

	route(`${ROUTE_BASE}/status`, 'GET', async (_request, response) => {
		writeJson(response, 200, await readStatus());
	});

	route(`${ROUTE_BASE}/token`, 'POST', async (request, response) => {
		const body = await readJsonBody(request);
		if (body === null || typeof body.token !== 'string') {
			writeJson(response, 400, { error: 'expected a JSON object with a string "token" field' });
			return;
		}
		try {
			if (body.token.trim().length === 0) {
				await clearToken();
			} else {
				await writeToken(body.token);
			}
		} catch (error) {
			const message = error instanceof TokenStoreError ? error.message : `unexpected error: ${error instanceof Error ? error.message : String(error)}`;
			writeJson(response, error instanceof TokenStoreError ? 409 : 502, { error: message });
			return;
		}
		writeJson(response, 200, { ok: true, restartNeeded: true, ...(await readStatus()) });
	});
}

export { apply, inject, name };
export default { apply, inject, name };
