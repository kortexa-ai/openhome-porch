import { BrowserWindow, ApplicationMenu, Updater } from "electrobun/bun";

const DEV_SERVER_PORT = 5173;
const DEV_SERVER_URL = `http://localhost:${DEV_SERVER_PORT}`;

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

const url = await getMainViewUrl();

const mainWindow = new BrowserWindow({
	title: "Window",
	url,
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

console.log("Window started");
