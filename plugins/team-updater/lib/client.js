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
		const FIGMA_STATUS_URL = "/team-updater/figma-status";
		const FIGMA_INSTALL_URL = "/team-updater/figma-install";

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
			if (status?.pinError) return `update check stopped: ${status.pinError}`;
			if (status?.current === null || status?.current === undefined) return `installed version unknown · registry ${status?.latest ?? '?'}`;
			// Naming the source matters when pinned: without it the row reads as
			// out of date next to a registry that has published something newer.
			const source = status.pinned ? "pinned by dsh-setup" : `registry ${status.tag}`;
			if (status.updateAvailable) return `${status.current} → ${status.latest}, ${source}`;
			if (status.blockedReason) return `${status.current} · holding back ${status.latest}: ${status.blockedReason}`;
			if (status.published === false) return `${status.current} · ${status.latest} is ${source} but not published on the registry`;
			return `${status.current} · up to date, ${source}`;
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

		function FigmaInstallRow() {
			const [phase, setPhase] = useState("checking");
			const [status, setStatus] = useState(null);
			const [message, setMessage] = useState(null);
			const mounted = useRef(true);

			useEffect(() => () => {
				mounted.current = false;
			}, []);

			const check = useCallback(async () => {
				setPhase("checking");
				try {
					const next = await request(FIGMA_STATUS_URL);
					if (!mounted.current) return;
					setStatus(next);
					setPhase(next.installed ? "hidden" : "ready");
				} catch (error) {
					if (!mounted.current) return;
					setPhase("error");
					setMessage(error instanceof Error ? error.message : String(error));
				}
			}, []);

			useEffect(() => {
				check();
			}, [check]);

			const install = useCallback(async () => {
				setPhase("installing");
				setMessage(null);
				try {
					await request(FIGMA_INSTALL_URL, {});
					if (!mounted.current) return;
					setPhase("installed");
					setMessage("Installed — restart dsh (Ctrl+C, then dsh web again), then set your Figma token under Settings > General.");
				} catch (error) {
					if (!mounted.current) return;
					setPhase("error");
					setMessage(error instanceof Error ? error.message : String(error));
				}
			}, []);

			if (phase === "hidden" || phase === "checking") return null;

			const busy = phase === "installing";
			const button = (label, onClick, extra) => h("button", {
				type: "button",
				style: { ...styles.button, ...(busy ? styles.disabled : {}), ...extra },
				disabled: busy,
				onClick
			}, label);

			const parts = [];
			parts.push(h("div", { key: "text", style: styles.text }, [
				h("div", { key: "title", style: styles.title }, "Figma integration"),
				h("div", { key: "meta", style: styles.meta }, phase === "error"
					? `check failed: ${message}`
					: phase === "installed" ? message : "Not installed — adds a Figma MCP server and a Settings token row.")
			]));
			const actions = [];
			if (phase !== "installed") actions.push(button(busy ? "Installing…" : "Add Figma integration", install, styles.primary));
			if (status?.command && phase !== "installed") actions.push(button("Copy command", async () => {
				try {
					await navigator.clipboard.writeText(status.command);
					if (mounted.current) setMessage(`copied: ${status.command}`);
				} catch {
					if (mounted.current) setMessage(status.command);
				}
			}));
			parts.push(h("div", { key: "actions", style: styles.actions }, actions));
			return h("div", { style: styles.row, "data-figma-install": phase }, parts);
		}

		/** Required service: the UI slot registry. */
		const inject = ["slots"];

		/**
		 * Register the updater row and the Figma-install row inside the General
		 * settings section — separate rows with separate state machines, since
		 * dsh-version status and figma-bridge-installed status are unrelated and
		 * one's busy state should never disable the other's button.
		 * @param ctx - client root context.
		 */
		function apply(ctx) {
			ctx.slots.inject("settings.general.item", () => ctx.slots.register({
				name: "settings.general.item",
				id: "team-updater",
				order: 500
			}, UpdaterRow));
			ctx.slots.inject("settings.general.item", () => ctx.slots.register({
				name: "settings.general.item",
				id: "team-updater-figma",
				order: 510
			}, FigmaInstallRow));
		}

		exports.apply = apply;
		exports.inject = inject;
		return module.exports;
	}
});
