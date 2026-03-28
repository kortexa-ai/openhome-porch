import { useState, useEffect, Component, type ReactNode } from "react";
import "./rpc";
import JsonRenderView from "./JsonRenderView";

type ViewMode = "idle" | "now-playing" | "display" | "render";

interface NowPlaying {
    title?: string;
    genre?: string;
    type?: string;
}

function App() {
    const [viewMode, setViewMode] = useState<ViewMode>("idle");
    const [nowPlaying, setNowPlaying] = useState<NowPlaying | null>(null);
    const [displayText, setDisplayText] = useState<string | null>(null);
    const [renderSpec, setRenderSpec] = useState<any>(null);
    const [porchConnected, setPorchConnected] = useState(false);

    useEffect(() => {
        positionTopRight();

        const handleMessage = (event: Event) => {
            const msg = (event as CustomEvent).detail;

            switch (msg.type) {
                case "now-playing":
                    setNowPlaying(msg.data);
                    setRenderSpec(null);
                    setDisplayText(null);
                    setViewMode("now-playing");
                    break;
                case "display":
                    setDisplayText(typeof msg.data === "string" ? msg.data : JSON.stringify(msg.data));
                    setRenderSpec(null);
                    setNowPlaying(null);
                    setViewMode("display");
                    break;
                case "render":
                    setRenderSpec(msg.data);
                    setNowPlaying(null);
                    setDisplayText(null);
                    setViewMode("render");
                    break;
                case "clear":
                    setViewMode("idle");
                    setNowPlaying(null);
                    setDisplayText(null);
                    setRenderSpec(null);
                    break;
                case "resize": {
                    const w = msg.data?.width ?? window.outerWidth;
                    const h = msg.data?.height ?? window.outerHeight;
                    window.resizeTo(w, h);
                    if (msg.data?.position === "top-right") positionTopRight();
                    break;
                }
            }
        };

        const handleStatus = (event: Event) => {
            const { connected } = (event as CustomEvent).detail;
            setPorchConnected(connected);
        };

        window.addEventListener("porch-message", handleMessage);
        window.addEventListener("porch-status", handleStatus);
        return () => {
            window.removeEventListener("porch-message", handleMessage);
            window.removeEventListener("porch-status", handleStatus);
        };
    }, []);

    function positionTopRight() {
        const padding = 24;
        const x = window.screen.availWidth - window.outerWidth - padding;
        const y = padding;
        window.moveTo(x, y);
    }

    return (
        <div style={{ minHeight: "100vh", backgroundColor: "#030712", color: "white", display: "flex", flexDirection: "column", userSelect: "none" }}>
            <div style={{ flex: 1, display: "flex", alignItems: "center", justifyContent: "center", padding: "1.5rem" }}>
                {viewMode === "render" && renderSpec ? (
                    <ErrorBoundary>
                        <JsonRenderView spec={renderSpec} />
                    </ErrorBoundary>
                ) : viewMode === "now-playing" && nowPlaying ? (
                    <div style={{ textAlign: "center" }}>
                        <div className="text-xs text-gray-500 font-mono uppercase tracking-widest mb-4">Now Playing</div>
                        <h1 className="text-4xl font-light tracking-wide mb-3">{nowPlaying.title || "Unknown"}</h1>
                        {nowPlaying.genre && <p className="text-lg text-gray-400 mb-2">{nowPlaying.genre}</p>}
                        {nowPlaying.type && <p className="text-sm text-gray-600">{nowPlaying.type}</p>}
                        <div className="mt-8 flex justify-center">
                            <div className="w-3 h-3 rounded-full bg-green-500 animate-pulse" />
                        </div>
                    </div>
                ) : viewMode === "display" && displayText ? (
                    <div style={{ textAlign: "center" }}>
                        <h1 className="text-3xl font-light tracking-wide">{displayText}</h1>
                    </div>
                ) : (
                    <div style={{ textAlign: "center" }}>
                        <h1 className="text-3xl font-light tracking-wide text-gray-600">Window</h1>
                    </div>
                )}
            </div>

            <div style={{ paddingBottom: "0.75rem", display: "flex", justifyContent: "center" }}>
                <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
                    <div style={{
                        width: 6, height: 6, borderRadius: "50%",
                        backgroundColor: porchConnected ? "#22c55e" : "#ef4444",
                    }} />
                    <span style={{ fontSize: 10, color: "#374151", fontFamily: "monospace" }}>
                        {porchConnected ? "porch" : "disconnected"}
                    </span>
                </div>
            </div>
        </div>
    );
}

class ErrorBoundary extends Component<{ children: ReactNode }, { error: string | null }> {
    state = { error: null as string | null };
    static getDerivedStateFromError(error: Error) { return { error: `${error.name}: ${error.message}` }; }
    componentDidCatch(error: Error) { console.error("[ErrorBoundary]", error); }
    render() {
        if (this.state.error) {
            return <div style={{ color: "#ef4444", fontSize: 12, padding: 20, fontFamily: "monospace" }}>{this.state.error}</div>;
        }
        return this.props.children;
    }
}

export default App;
