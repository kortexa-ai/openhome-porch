import { BrowserWindow, BrowserView, ApplicationMenu, Updater } from "electrobun/bun";
import type { WindowRPC } from "../shared/types";

const DEV_SERVER_PORT = 5173;
const DEV_SERVER_URL = `http://localhost:${DEV_SERVER_PORT}`;
const PORCH_WS_PORT = 9830;

async function getMainViewUrl(): Promise<string> {
	const channel = await Updater.localInfo.channel();
	if (channel === "dev") {
		try {
			await fetch(DEV_SERVER_URL, { method: "HEAD" });
			console.log(`HMR enabled: Using Vite dev server at ${DEV_SERVER_URL}`);
			return DEV_SERVER_URL;
		} catch {
			console.log("Vite dev server not running.");
		}
	}
	return "views://mainview/index.html";
}

// RPC bridge to webview
const rpc = BrowserView.defineRPC<WindowRPC>({
	handlers: {
		requests: {},
		messages: {},
	},
});

const url = await getMainViewUrl();

const mainWindow = new BrowserWindow({
	title: "Window",
	url,
	rpc,
	frame: {
		width: 480,
		height: 360,
		x: 100,
		y: 100,
	},
});

// Application menu
ApplicationMenu.setApplicationMenu([
	{
		label: "Window",
		submenu: [
			{ label: "About Window", role: "about" },
			{ type: "separator" },
			{ label: "Hide", role: "hide", accelerator: "h" },
			{ label: "Hide Others", role: "hideOthers", accelerator: "Alt+h" },
			{ label: "Show All", role: "showAll" },
			{ type: "separator" },
			{ label: "Quit", role: "quit", accelerator: "q" },
		],
	},
	{
		label: "Edit",
		submenu: [
			{ role: "undo" },
			{ role: "redo" },
			{ type: "separator" },
			{ role: "cut" },
			{ role: "copy" },
			{ role: "paste" },
			{ role: "selectAll" },
		],
	},
]);

// Connect to Porch WebSocket — single connection, bun-side only
function connectToPorch() {
	try {
		const ws = new WebSocket(`ws://localhost:${PORCH_WS_PORT}`);

		ws.onopen = () => {
			console.log("[Window:bun] Connected to Porch");
			// Send immediately and again after 1s (webview may not have mounted yet)
			mainWindow.webview.rpc.send.porchStatus({ connected: true });
			setTimeout(() => mainWindow.webview.rpc.send.porchStatus({ connected: true }), 1000);
		};

		ws.onmessage = (event) => {
			try {
				const msg = JSON.parse(event.data as string);
				console.log("[Window:bun] Message:", msg.type);

				if (msg.type === "quit") {
					console.log("[Window:bun] Quit received");
					process.exit(0);
				}

				// Forward everything else to webview via RPC
				mainWindow.webview.rpc.send.porchMessage(msg);
			} catch (e) {
				console.error("[Window:bun] Parse error:", e);
			}
		};

		ws.onclose = () => {
			console.log("[Window:bun] Disconnected from Porch");
			mainWindow.webview.rpc.send.porchStatus({ connected: false });
			// If Porch closed the server, exit. Otherwise reconnect.
			setTimeout(() => {
				// Try to connect — if it fails, Porch is gone, so exit
				const probe = new WebSocket(`ws://localhost:${PORCH_WS_PORT}`);
				probe.onopen = () => {
					probe.close();
					connectToPorch();
				};
				probe.onerror = () => {
					console.log("[Window:bun] Porch is gone, exiting");
					process.exit(0);
				};
			}, 2000);
		};

		ws.onerror = () => ws.close();
	} catch (e) {
		console.error("[Window:bun] Connection error:", e);
		setTimeout(connectToPorch, 3000);
	}
}
connectToPorch();

// Handle SIGTERM gracefully (sent by Porch to close Window)
process.on("SIGTERM", () => {
	console.log("[Window:bun] SIGTERM received, exiting");
	process.exit(0);
});

console.log("Window started");
