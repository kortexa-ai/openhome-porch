# Porch & Window — Developer Guide

Porch and Window extend the [OpenHome](https://docs.openhome.com/introduction) platform by bridging your OpenHome device to your desktop. Abilities running on OpenHome can send commands to your Mac through Porch, and display rich UI through Window.

**Prerequisites:** An OpenHome DevKit, an API key from [app.openhome.com](https://app.openhome.com), and familiarity with building [OpenHome Abilities](https://github.com/openhome-dev/abilities).

---

## Architecture

```
OpenHome Device
    │
    ├── ws:3030 ──── config broadcast ──── Porch (device status, agent online)
    │
    └── cloud ──── voice stream ──── wss://app.openhome.com/websocket/voice-stream/...
                       │
                  Ability runtime
                       │
                  exec_local_command()
                       │
                  wss://app.openhome.com/ws/local_link/ (LocalLink relay)
                       │
                  Porch (receives commands, executes or forwards)
                       │
                  ws://localhost:9830 (local WebSocket)
                       │
                  Window (renders UI)
```

### Components

| Component | Tech | Purpose |
|-----------|------|---------|
| **Porch** | Swift, macOS menubar app | Device discovery, cloud relay connection, command execution, Window management |
| **Window** | Electrobun (Bun + webview) | Display companion — renders UI sent from abilities via Porch |
| **LocalLink relay** | OpenHome cloud (port 8769) | Routes `exec_local_command()` calls from abilities to Porch |
| **Device socket** | WebSocket on port 3030 | Broadcasts device config (API key, volume, mic, personality) |

---

## Porch

### What it does

- Sits in the macOS menubar (no dock icon)
- Discovers OpenHome device on the LAN via `openhome.local` mDNS
- Maintains persistent WebSocket to device port 3030 (config updates, agent online status)
- Connects to the LocalLink cloud relay on `ws://app.openhome.com:8769` (falls back to `wss://`)
- Receives and executes commands from abilities via `exec_local_command()`
- Manages the Window companion app (launch, stop, forward messages)
- Auto-grabs API key from device config on first run
- Stores settings in `~/.config/porch/settings.json`

### Popover UI

| Element | Description |
|---------|-------------|
| Device dot (left) | Green = agent online, Orange = device found but agent off, Red = no device |
| Device IP | Clickable — expands to show device info (MAC, cloud URL, personality, volume, mic) |
| Auto-reconnect (⟲) | Blue = on, Gray = off. Reconnects with exponential backoff (10s, 30s, 60s) |
| Play/Stop (▶/⏹) | Green play to connect, Red stop to disconnect |
| Connection bolt (⚡) | Yellow = connected to relay, Gray = disconnected |
| Window toggle (📺) | Blue = Window running, Gray = off |
| Gear (⚙) | Opens Settings (API key configuration) |
| About / Quit | Footer |

### Settings

Stored in `~/.config/porch/settings.json`:

```json
{
  "apiKey": "your-openhome-api-key",
  "autoReconnect": true
}
```

If a device is discovered on the LAN before an API key is configured, Porch auto-grabs it from the device's config broadcast.

---

## Window

### What it does

- Lightweight desktop window (~14MB) powered by Electrobun
- Connects to Porch via WebSocket on `localhost:9830`
- Renders UI based on JSON messages from Porch
- Positions in upper-right corner of screen on launch
- Auto-reconnects to Porch if connection drops

### Default states

| State | What's shown |
|-------|-------------|
| Idle | "Window" in gray text |
| Display text | Large centered text |
| Now Playing | Track title, genre, type, pulsing green dot |

---

## Sending Commands from Abilities

Abilities communicate with Porch using the OpenHome SDK's `exec_local_command()` method. This sends a command string through the LocalLink cloud relay to Porch.

```python
await self.capability_worker.exec_local_command("your command here", timeout=10.0)
```

For full `exec_local_command()` documentation, see the [OpenHome Ability SDK Reference](https://github.com/openhome-dev/abilities/blob/dev/docs/OpenHome_SDK_Reference.md).

### Shell commands

Any command without a `window:` prefix is executed as a shell command on the user's Mac:

```python
# Open a URL in the default browser
await self.capability_worker.exec_local_command("open https://example.com")

# Run any shell command
await self.capability_worker.exec_local_command("say 'Hello from OpenHome'")
```

Porch returns the result:

```json
{"type": "response", "data": {"ok": true, "returncode": 0, "stdout": "...", "stderr": ""}}
```

### Window management commands

| Command | Description |
|---------|-------------|
| `window:open` | Launch Window if not running |
| `window:close` | Close Window |

```python
# Open Window before sending display commands
await self.capability_worker.exec_local_command("window:open")

# Close Window when done
await self.capability_worker.exec_local_command("window:close")
```

### Window display commands

Commands prefixed with `window:` followed by a JSON object are forwarded to Window's WebSocket:

#### Display text

```python
import json

msg = json.dumps({"type": "display", "data": "Hello from OpenHome!"})
await self.capability_worker.exec_local_command(f"window:{msg}")
```

#### Now Playing

```python
import json

msg = json.dumps({
    "type": "now-playing",
    "data": {
        "title": "Midnight Echoes",
        "genre": "Synthwave",
        "type": "AI-Generated"
    }
})
await self.capability_worker.exec_local_command(f"window:{msg}")
```

#### Resize

```python
import json

# Resize Window
msg = json.dumps({"type": "resize", "data": {"width": 800, "height": 600}})
await self.capability_worker.exec_local_command(f"window:{msg}")

# Resize and reposition to top-right corner
msg = json.dumps({"type": "resize", "data": {"width": 800, "height": 600, "position": "top-right"}})
await self.capability_worker.exec_local_command(f"window:{msg}")
```

#### Clear

```python
import json

msg = json.dumps({"type": "clear"})
await self.capability_worker.exec_local_command(f"window:{msg}")
```

### Window message reference

| Message type | Data | Effect |
|-------------|------|--------|
| `display` | `string` | Shows centered text |
| `now-playing` | `{title, genre?, type?}` | Shows now-playing card with pulsing indicator |
| `render` | json-render spec | Renders 2D UI from a json-render spec (see below) |
| `render-3d` | json-render spec | Renders a Three.js 3D scene from a json-render spec |
| `resize` | `{width?, height?, position?}` | Resizes window. `position: "top-right"` repositions |
| `clear` | — | Clears display back to idle state |
| `quit` | — | Closes Window |

---

## Complete Ability Example

A minimal ability that opens Window, displays a message, waits, then cleans up:

```python
import json
from src.agent.capability import MatchingCapability
from src.main import AgentWorker
from src.agent.capability_worker import CapabilityWorker


class HelloWindowCapability(MatchingCapability):
    worker: AgentWorker = None
    capability_worker: CapabilityWorker = None

    #{{register capability}}

    def call(self, worker: AgentWorker):
        self.worker = worker
        self.capability_worker = CapabilityWorker(self.worker)
        self.worker.session_tasks.create(self.run())

    async def run(self):
        try:
            await self.capability_worker.speak("Let me show you something.")

            # Open Window
            await self._window("window:open")

            # Display a message
            await self._window_msg({"type": "display", "data": "Hello from OpenHome!"})

            await self.worker.session_tasks.sleep(5)

            # Show now-playing style card
            await self._window_msg({
                "type": "now-playing",
                "data": {"title": "Demo Track", "genre": "Electronic"}
            })

            await self.worker.session_tasks.sleep(5)

            # Clear and close
            await self._window_msg({"type": "clear"})
            await self._window("window:close")

            await self.capability_worker.speak("Done!")
        except Exception as e:
            self.worker.editor_logging_handler.error(f"Error: {e}")
        finally:
            self.capability_worker.resume_normal_flow()

    async def _window(self, cmd):
        try:
            await self.capability_worker.exec_local_command(cmd, timeout=5.0)
        except Exception:
            pass

    async def _window_msg(self, msg):
        try:
            await self.capability_worker.exec_local_command(
                "window:" + json.dumps(msg), timeout=5.0
            )
        except Exception:
            pass
```

---

## json-render — Dynamic UI from JSON

Window integrates [json-render](https://github.com/vercel-labs/json-render) by Vercel, allowing abilities to send arbitrary UI as JSON specs. The spec defines which components to render, their props, and their layout — Window renders them as React components.

This means abilities (or an LLM) can generate rich UI without any Window code changes.

### 2D UI components (shadcn/ui)

Send a `render` message with a json-render spec:

```python
import json

spec = {
    "elements": [
        {
            "component": "Card",
            "props": {"title": "Weather", "description": "Current conditions"},
            "children": [
                {
                    "component": "Stack",
                    "props": {"direction": "vertical", "gap": "md"},
                    "children": [
                        {"component": "Heading", "props": {"content": "72°F", "level": 1}},
                        {"component": "Text", "props": {"content": "Sunny, light breeze"}},
                        {"component": "Progress", "props": {"value": 65, "label": "Humidity"}},
                        {
                            "component": "Badge",
                            "props": {"label": "UV Index: Low", "variant": "success"}
                        }
                    ]
                }
            ]
        }
    ]
}

msg = json.dumps({"type": "render", "data": spec})
await self.capability_worker.exec_local_command(f"window:{msg}")
```

**Available 2D components (36):**

| Layout | Content | Input | Feedback | Overlay |
|--------|---------|-------|----------|---------|
| Card | Heading | Input | Alert | Dialog |
| Stack | Text | Textarea | Badge | Drawer |
| Grid | Image | Select | Progress | Popover |
| Separator | Avatar | Checkbox | Skeleton | Tooltip |
| Tabs | Link | Radio | Spinner | DropdownMenu |
| Accordion | Table | Switch | | |
| Collapsible | Carousel | Slider | | |
| | | Toggle | | |
| | | ToggleGroup | | |
| | | Button | | |
| | | ButtonGroup | | |
| | | Pagination | | |

### 3D scenes (Three.js)

Send a `render-3d` message for Three.js scenes via React Three Fiber:

```python
import json

spec = {
    "elements": [
        {"component": "PerspectiveCamera", "props": {"position": [0, 2, 5]}},
        {"component": "OrbitControls", "props": {"autoRotate": True}},
        {"component": "AmbientLight", "props": {"intensity": 0.5}},
        {"component": "DirectionalLight", "props": {"position": [5, 5, 5], "intensity": 1}},
        {
            "component": "Float",
            "props": {"speed": 2},
            "children": [
                {"component": "Sphere", "props": {"radius": 1, "color": "#ff6b35"}}
            ]
        },
        {"component": "Stars", "props": {"count": 1000}},
        {"component": "ContactShadows", "props": {"opacity": 0.4}}
    ]
}

msg = json.dumps({"type": "render-3d", "data": spec})
await self.capability_worker.exec_local_command(f"window:{msg}")
```

**Available 3D components (42):**

| Primitives | Lighting | Effects | Environment | Animation |
|-----------|----------|---------|-------------|-----------|
| Box | AmbientLight | Bloom | Sky | Float |
| Sphere | DirectionalLight | Glitch | Stars | Spin |
| Cylinder | PointLight | Vignette | Cloud | Pulse |
| Cone | SpotLight | EffectComposer | Fog | CameraShake |
| Torus | | ContactShadows | Environment | |
| TorusKnot | | ReflectorPlane | Backdrop | |
| Capsule | | | GridHelper | |
| Plane | | | Sparkles | |
| RoundedBox | | | WarpTunnel | |
| GlassBox | | | | |
| GlassSphere | | | | |
| DistortSphere | | | | |

Plus: Group, HtmlLabel, MeshPortalMaterial, Model, Orbit, OrbitControls, PerspectiveCamera.

### json-render spec format

The spec follows the [json-render specification](https://github.com/vercel-labs/json-render). Each element has:

```json
{
    "component": "ComponentName",
    "props": { ... },
    "children": [ ... ]
}
```

A spec is an object with an `elements` array at the top level:

```json
{
    "elements": [
        { "component": "...", "props": { ... }, "children": [ ... ] }
    ]
}
```

For full component prop schemas, see the [json-render documentation](https://json-render.dev/).

---

## Extending Window

Window is a React app rendered inside Electrobun. To add new message types beyond what json-render provides:

1. Add a handler in `Window/src/mainview/App.tsx`:

```tsx
case "my-custom-type":
    setMyState(msg.data);
    break;
```

2. Send from your ability:

```python
msg = json.dumps({"type": "my-custom-type", "data": {"key": "value"}})
await self.capability_worker.exec_local_command(f"window:{msg}")
```

For most use cases, the `render` and `render-3d` message types with json-render specs are sufficient — no Window code changes needed.

---

## Extending Porch

To add new command handlers in Porch, edit `PorchApp/Services/ConnectionManager.swift` in the `handleCommand()` method:

```swift
// Add before the shell command fallback
if command.hasPrefix("myprefix:") {
    let payload = String(command.dropFirst("myprefix:".count))
    // Handle your custom command
    sendToRelay(["type": "response", "data": ["ok": true, "stdout": "handled"]])
    return
}
```

---

## Graceful degradation

Porch and Window are optional. If they're not running:

- `exec_local_command()` will timeout or error — wrap calls in try/except
- The ability continues to function normally (audio, speech, etc.)
- No crash, no side effects — just silent failure on the desktop commands

```python
async def _send_to_window(self, msg):
    """Fire and forget — works with or without Porch/Window."""
    try:
        await self.capability_worker.exec_local_command(
            "window:" + json.dumps(msg), timeout=5.0
        )
    except Exception:
        pass  # Porch not running, that's fine
```

---

## Network ports reference

| Port | Host | Protocol | Purpose |
|------|------|----------|---------|
| 3030 | openhome.local | WebSocket | Device config broadcast (no auth) |
| 443 | app.openhome.com | WSS | LocalLink relay at /ws/local_link/ (API key auth) |
| 9830 | localhost | WebSocket | Porch → Window communication |
| 1883 | openhome.local | MQTT | Device hardware control (auth required) |

---

## Links

- [OpenHome Documentation](https://docs.openhome.com/introduction)
- [OpenHome Abilities SDK Reference](https://github.com/openhome-dev/abilities/blob/dev/docs/OpenHome_SDK_Reference.md)
- [OpenHome Abilities Repository](https://github.com/openhome-dev/abilities)
- [Porch Repository](https://github.com/kortexa-ai/openhome-porch)
- [Kortexa Radio — Example Ability](https://github.com/kortexa-ai/openhome-porch) (community/kortexa-radio)
