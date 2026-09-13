window.__ModuleLoader__.load({
	id: "dsh-team-updater",
	factory: (require) => {
		var module = { exports: {} };
		var exports = module.exports;
		Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });
		const React = require("react");
		const { useCallback, useEffect, useRef, useState } = React;
		const h = React.createElement;

		/**
		 * Browser half of dsh-team-updater: the General-settings row that checks
		 * the registry and hands the install off to the host routes. The row
		 * renders its own copy and chrome, so nothing here edits a shell.
		 */
		const STATUS_URL = "/team-updater/status";
		const APPLY_URL = "/team-updater/apply";
		const LOG_URL = "/team-updater/log";

		const styles = {
			row: {
				display: "flex",
				alignItems: "center",
				justifyContent: "space-between",
				gap: "16px",
				width: "100%",
				padding: "12px 0"
			},
			text: { display: "flex", flexDirection: "column", gap: "2px", minWidth: 0 },
			title: { fontSize: "inherit", lineHeight: "1.4" },
			meta: {
				fontSize: "var(--dsh-content-font-size-secondary, 0.85em)",
				opacity: 0.65,
				lineHeight: "1.4",
				overflowWrap: "anywhere"
			},
			actions: { display: "flex", alignItems: "center", gap: "8px", flexShrink: 0 },
			button: {
				font: "inherit",
				color: "inherit",
				background: "transparent",
				border: "1px solid color-mix(in srgb, currentColor 26%, transparent)",
				borderRadius: "8px",
				padding: "5px 12px",
				cursor: "pointer",
				whiteSpace: "nowrap"
			},
			primary: { fontWeight: 600, borderColor: "color-mix(in srgb, currentColor 55%, transparent)" },
			disabled: { opacity: 0.5, cursor: "default" }
		};

		/** One JSON request; throws a readable Error on any non-2xx answer. */
		async function request(url, body) {
			const response = await fetch(url, body === undefined ? { headers: { accept: "application/json" } } : {
				method: "POST",
				headers: { "content-type": "application/json", accept: "application/json" },
				body: JSON.stringify(body)
			});
			let payload;
			try {
				payload = await response.json();
			} catch {
				throw new Error(`host answered ${response.status} with a non-JSON body`);
			}
			if (!response.ok) throw new Error(payload?.error ?? `host answered ${response.status}`);
			return payload;
		}

		/** A rounded "0.1.2-rc.1 → 0.1.5-rc.1" summary line. */
		function versionLine(status) {
			if (status?.current === null || status?.current === undefined) return `installed version unknown · registry ${status?.latest ?? '?'}`;
			if (status.updateAvailable) return `${status.current} → ${status.latest} (${status.tag})`;
			// Say why the newer version is being withheld, so the row does not
			// look merely out of date next to a registry version it skips.
			if (status.blockedReason) return `${status.current} · holding back ${status.latest}: ${status.blockedReason}`;
			return `${status.current} · registry ${status.latest} (${status.tag})`;
		}

		function UpdaterRow() {
			const [status, setStatus] = useState(null);
			const [phase, setPhase] = useState("checking");
			const [message, setMessage] = useState(null);
			const [logTail, setLogTail] = useState(null);
			const mounted = useRef(true);

			useEffect(() => () => {
				mounted.current = false;
			}, []);

			const check = useCallback(async (refresh) => {
				setPhase("checking");
				setMessage(null);
				try {
					const next = await request(`${STATUS_URL}${refresh ? "?refresh=1" : ""}`);
					if (!mounted.current) return;
					setStatus(next);
					setPhase("ready");
				} catch (error) {
					if (!mounted.current) return;
					setPhase("error");
					setMessage(error instanceof Error ? error.message : String(error));
				}
			}, []);

			useEffect(() => {
				check(false);
			}, [check]);

			// While an update is staged, follow the runner's log until this page
			// loses the host (that is the expected end of the flow).
			useEffect(() => {
				if (phase !== "staged") return undefined;
				let timer;
				const poll = async () => {
					try {
						const payload = await request(LOG_URL);
						if (mounted.current) setLogTail(payload?.text ?? null);
					} catch {
						if (mounted.current) setMessage("host is down — the update is installing; dsh restarts automatically when it finishes.");
					}
					timer = setTimeout(poll, 2000);
				};
				poll();
				return () => clearTimeout(timer);
			}, [phase]);

			const stage = useCallback(async (quit) => {
				setPhase("applying");
				setMessage(null);
				try {
					const payload = await request(APPLY_URL, quit ? { quit: true } : {});
					if (!mounted.current) return;
					setPhase("staged");
					setMessage(quit
						? `Staged ${payload.version}: dsh quits now, the update installs after it exits, then dsh restarts.`
						: `Staged ${payload.version}: quit dsh yourself (Ctrl+C or close the window) — the update installs automatically and dsh restarts.`);
				} catch (error) {
					if (!mounted.current) return;
					setPhase("error");
					setMessage(error instanceof Error ? error.message : String(error));
				}
			}, []);

			const busy = phase === "checking" || phase === "applying";
			const button = (label, onClick, extra) => h("button", {
				type: "button",
				style: { ...styles.button, ...(busy ? styles.disabled : {}), ...extra },
				disabled: busy,
				onClick
			}, label);

			const parts = [];
			parts.push(h("div", { key: "text", style: styles.text }, [
				h("div", { key: "title", style: styles.title }, "dsh updates"),
				h("div", { key: "meta", style: styles.meta }, phase === "error"
					? `check failed: ${message}`
					: status === null ? "checking the registry…" : versionLine(status))
			]));
			const actions = [];
			if (status?.updateAvailable) {
				actions.push(button(busy ? "Working…" : "Update & restart", () => stage(true), styles.primary));
				actions.push(button("Check again", () => check(true)));
			} else {
				actions.push(button(busy ? "Checking…" : "Check for updates", () => check(true)));
			}
			if (status?.command !== undefined) actions.push(button("Copy command", async () => {
				try {
					await navigator.clipboard.writeText(status.command);
					if (mounted.current) setMessage(`copied: ${status.command}`);
				} catch {
					if (mounted.current) setMessage(status.command);
				}
			}));
			parts.push(h("div", { key: "actions", style: styles.actions }, actions));
			const rows = [h("div", { key: "row", style: styles.row }, parts)];
			const detail = logTail ?? (message !== null && status?.updateAvailable === true ? message : null);
			if (detail !== null) {
				rows.push(h("pre", {
					key: "log",
					style: {
						margin: "0 0 12px",
						padding: "8px 10px",
						maxHeight: "8em",
						overflow: "auto",
						fontSize: "var(--dsh-content-font-size-secondary, 0.85em)",
						opacity: 0.8,
						whiteSpace: "pre-wrap",
						overflowWrap: "anywhere"
					}
				}, detail));
			}
			return h("div", { style: { display: "flex", flexDirection: "column", width: "100%" }, "data-team-updater": phase }, rows);
		}

		/** Required service: the UI slot registry. */
		const inject = ["slots"];

		/**
		 * Register the updater row inside the General settings section — a
		 * single preference row, so no settings page of its own is needed.
		 * @param ctx - client root context.
		 */
		function apply(ctx) {
			ctx.slots.inject("settings.general.item", () => ctx.slots.register({
				name: "settings.general.item",
				id: "team-updater",
				order: 500
			}, UpdaterRow));
		}

		exports.apply = apply;
		exports.inject = inject;
		return module.exports;
	}
});
