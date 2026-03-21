import { useState, useEffect, useRef } from "react";

const PORCH_WS_PORT = 9830;

type ConnectionStatus = "connecting" | "connected" | "disconnected";

interface NowPlaying {
    title?: string;
    genre?: string;
    type?: string;
    prompt?: string;
}

function App() {
    const [status, setStatus] = useState<ConnectionStatus>("disconnected");
    const [nowPlaying, setNowPlaying] = useState<NowPlaying | null>(null);
    const [displayText, setDisplayText] = useState<string | null>(null);
    const wsRef = useRef<WebSocket | null>(null);
    const reconnectTimer = useRef<ReturnType<typeof setTimeout>>();

    useEffect(() => {
        connect();
        return () => {
            if (reconnectTimer.current) clearTimeout(reconnectTimer.current);
            wsRef.current?.close();
        };
    }, []);

    function connect() {
        setStatus("connecting");
        const ws = new WebSocket(`ws://localhost:${PORCH_WS_PORT}`);

        ws.onopen = () => {
            setStatus("connected");
            console.log("[Window] Connected to Porch");
        };

        ws.onmessage = (event) => {
            try {
                const msg = JSON.parse(event.data);
                console.log("[Window] Message:", msg);

                switch (msg.type) {
                    case "now-playing":
                        setNowPlaying(msg.data);
                        setDisplayText(null);
                        break;
                    case "display":
                        setDisplayText(typeof msg.data === "string" ? msg.data : JSON.stringify(msg.data));
                        break;
                    case "clear":
                        setNowPlaying(null);
                        setDisplayText(null);
                        break;
                    case "quit":
                        window.close();
                        break;
                }
            } catch {
                console.log("[Window] Raw:", event.data);
            }
        };

        ws.onclose = () => {
            setStatus("disconnected");
            wsRef.current = null;
            reconnectTimer.current = setTimeout(connect, 3000);
        };

        ws.onerror = () => ws.close();
        wsRef.current = ws;
    }

    return (
        <div className="min-h-screen bg-gray-950 text-white flex flex-col items-center justify-center p-8 select-none">
            {/* Now Playing */}
            {nowPlaying ? (
                <div className="text-center">
                    <div className="text-xs text-gray-500 font-mono uppercase tracking-widest mb-4">
                        Now Playing
                    </div>
                    <h1 className="text-4xl font-light tracking-wide mb-3">
                        {nowPlaying.title || "Unknown"}
                    </h1>
                    {nowPlaying.genre && (
                        <p className="text-lg text-gray-400 mb-2">
                            {nowPlaying.genre}
                        </p>
                    )}
                    {nowPlaying.type && (
                        <p className="text-sm text-gray-600">
                            {nowPlaying.type}
                        </p>
                    )}
                    <div className="mt-8 flex justify-center">
                        <div className="w-3 h-3 rounded-full bg-green-500 animate-pulse" />
                    </div>
                </div>
            ) : displayText ? (
                <div className="text-center">
                    <h1 className="text-3xl font-light tracking-wide">
                        {displayText}
                    </h1>
                </div>
            ) : (
                <div className="text-center">
                    <h1 className="text-3xl font-light tracking-wide text-gray-600">
                        Window
                    </h1>
                </div>
            )}

            {/* Status bar */}
            <div className="absolute bottom-4 left-0 right-0 flex justify-center">
                <div className="flex items-center gap-2">
                    <div
                        className={`w-1.5 h-1.5 rounded-full ${
                            status === "connected"
                                ? "bg-green-500"
                                : status === "connecting"
                                  ? "bg-yellow-500 animate-pulse"
                                  : "bg-red-500"
                        }`}
                    />
                    <span className="text-[10px] text-gray-700 font-mono">
                        {status === "connected" ? "porch" : status}
                    </span>
                </div>
            </div>
        </div>
    );
}

export default App;
