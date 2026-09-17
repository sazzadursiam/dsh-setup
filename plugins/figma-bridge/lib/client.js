window.__ModuleLoader__.load({
	id: "dsh-figma-bridge",
	factory: (require) => {
		var module = { exports: {} };
		var exports = module.exports;
		Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });
		const React = require("react");
		const { useCallback, useEffect, useRef, useState } = React;
		const h = React.createElement;

		/**
		 * Browser half of dsh-figma-bridge: the General-settings row that saves a
		 * Figma token without a terminal. The row renders its own copy and chrome,
		 * so nothing here edits a shell config or rc file.
		 */
		const STATUS_URL = "/figma-bridge/status";
		const TOKEN_URL = "/figma-bridge/token";

		const styles = {
			row: {
				display: "flex",
				flexDirection: "column",
				gap: "8px",
				width: "100%",
				padding: "12px 0"
			},
			head: {
				display: "flex",
				alignItems: "center",
				justifyContent: "space-between",
				gap: "16px",
				width: "100%"
			},
			text: { display: "flex", flexDirection: "column", gap: "2px", minWidth: 0 },
			title: { fontSize: "inherit", lineHeight: "1.4" },
			meta: {
				fontSize: "var(--dsh-content-font-size-secondary, 0.85em)",
				opacity: 0.65,
				lineHeight: "1.4",
				overflowWrap: "anywhere"
			},
			form: { display: "flex", alignItems: "center", gap: "8px", flexWrap: "wrap" },
			input: {
				font: "inherit",
				color: "inherit",
				background: "transparent",
				border: "1px solid color-mix(in srgb, currentColor 26%, transparent)",
				borderRadius: "8px",
				padding: "5px 10px",
				minWidth: "220px",
				flex: "1 1 220px"
			},
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

		function FigmaTokenRow() {
			const [status, setStatus] = useState(null);
			const [phase, setPhase] = useState("loading");
			const [message, setMessage] = useState(null);
			const [value, setValue] = useState("");
			const mounted = useRef(true);

			useEffect(() => () => {
				mounted.current = false;
			}, []);

			const load = useCallback(async () => {
				setPhase("loading");
				try {
					const next = await request(STATUS_URL);
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
				load();
			}, [load]);

			const save = useCallback(async (token) => {
				setPhase("saving");
				setMessage(null);
				try {
					const payload = await request(TOKEN_URL, { token });
					if (!mounted.current) return;
					setStatus(payload);
					setValue("");
					setPhase("saved");
					setMessage(token.trim().length === 0
						? "Token cleared. Restart dsh (Ctrl+C, then run dsh web again) for MCP tools to stop using it."
						: "Saved. Restart dsh (Ctrl+C, then run dsh web again) to use it.");
				} catch (error) {
					if (!mounted.current) return;
					setPhase("error");
					setMessage(error instanceof Error ? error.message : String(error));
				}
			}, []);

			const busy = phase === "loading" || phase === "saving";
			const meta = phase === "error"
				? `error: ${message}`
				: status === null ? "checking…" : status.tokenSet ? `set (${status.masked})` : "not set";

			const parts = [];
			parts.push(h("div", { key: "head", style: styles.head }, [
				h("div", { key: "text", style: styles.text }, [
					h("div", { key: "title", style: styles.title }, "Figma token"),
					h("div", { key: "meta", style: styles.meta }, meta)
				])
			]));
			parts.push(h("div", { key: "form", style: styles.form }, [
				h("input", {
					key: "input",
					type: "password",
					placeholder: "figd_...",
					value,
					disabled: busy,
					style: styles.input,
					onChange: (event) => setValue(event.target.value)
				}),
				h("button", {
					key: "save",
					type: "button",
					style: { ...styles.button, ...styles.primary, ...(busy || value.trim().length === 0 ? styles.disabled : {}) },
					disabled: busy || value.trim().length === 0,
					onClick: () => save(value)
				}, busy ? "Working…" : "Save"),
				status?.tokenSet ? h("button", {
					key: "clear",
					type: "button",
					style: { ...styles.button, ...(busy ? styles.disabled : {}) },
					disabled: busy,
					onClick: () => save("")
				}, "Clear") : null
			]));
			if (phase === "saved" && message !== null) {
				parts.push(h("div", { key: "note", style: styles.meta }, message));
			}
			return h("div", { style: { display: "flex", flexDirection: "column", width: "100%" }, "data-figma-bridge": phase }, parts);
		}

		/** Required service: the UI slot registry. */
		const inject = ["slots"];

		/**
		 * Register the token row inside the General settings section — a single
		 * preference row, so no settings page of its own is needed.
		 * @param ctx - client root context.
		 */
		function apply(ctx) {
			ctx.slots.inject("settings.general.item", () => ctx.slots.register({
				name: "settings.general.item",
				id: "figma-bridge",
				order: 501
			}, FigmaTokenRow));
		}

		exports.apply = apply;
		exports.inject = inject;
		return module.exports;
	}
});
