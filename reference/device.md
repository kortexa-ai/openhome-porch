# OpenHome Device Protocol Reference

Discovered by probing an OpenHome DevKit on the local network.

## Network Services

| Port | Protocol | Purpose | Auth |
|------|----------|---------|------|
| 3000 | HTTP | DevKit web UI (nginx + Vite SPA) | None |
| 3030 | WebSocket | Local config/control socket | None |
| 1883 | MQTT | Local message broker (hardware control) | Username: `openhome_devkit_user`, Password: `admin123` |

## Device Discovery

The device advertises itself as `openhome.local` via mDNS/Bonjour.
Can also be found by scanning the LAN for port 3030.

## Port 3030 — Local WebSocket

On connection, the device immediately sends a single JSON frame containing
the full device configuration. No authentication required.

### Connection

```
ws://openhome.local:3030/
```

Plain WebSocket, no auth, no query params.

### Config payload (sent on connect)

```json
{
    "API_KEY": "...",
    "WS_URL": "wss://app.openhome.com",
    "API_URL": "https://app.openhome.com/",
    "DEFAULT_PERSONALITY": "0",
    "INTERACTIVE_INTERRUPT": "false",
    "AUTO_INTERRUPT": "true",
    "BROWSER_RELOAD": "false",
    "MIC_SENSITIVITY": "100",
    "INTERRUPTION_SENSITIVITY": "0.1",
    "SPEAKER_VOLUME": "34",
    "MQTT_BROKER": "127.0.0.1",
    "MQTT_PORT": "1883",
    "MQTT_CLIENT_ID": "openhome_client",
    "MQTT_USERNAME": "openhome_devkit_user",
    "MAC_ADDRESS": "88:a2:9e:17:39:74"
}
```

### Key fields

| Field | Description |
|-------|-------------|
| `API_KEY` | OpenHome API key — used to authenticate with the cloud |
| `WS_URL` | Cloud WebSocket base URL (for voice stream) |
| `API_URL` | Cloud API base URL |
| `DEFAULT_PERSONALITY` | Active agent/personality ID |
| `MAC_ADDRESS` | Device hardware MAC address |
| `SPEAKER_VOLUME` | Current volume (0-100) |
| `MIC_SENSITIVITY` | Microphone sensitivity (0-100) |

## Cloud Connection (for abilities / exec_local_command)

The `local_client.py` reference client connects to the cloud:

```
ws://{host}:{port}/?api_key={API_KEY}&client_id={CLIENT_ID}&role=agent
```

Default host/port from the reference client is `localhost:8765`, but this is
a relay server endpoint — likely needs to be pointed at the cloud or a local
relay. The actual cloud voice stream URL is:

```
wss://app.openhome.com/websocket/voice-stream/{API_KEY}/{PERSONALITY}?chat_only=false&reconnect={bool}&ai_twin_mode=false&mac={MAC}&devkit=true
```

## DevKit Web UI (port 3000)

The web UI at `http://openhome.local:3000/` connects to:
- `ws://localhost:3030` for local config updates
- `wss://app.openhome.com/websocket/voice-stream/...` for cloud voice

It also sends `{"type": "service-action", "action": "restart", "service": "openhome-dashboard"}`
style messages over the local WebSocket for service management.

## Local Link Relay (Cloud)

Extracted from the official `LocalLink.app` (PyInstaller binary):

```
URL: wss://app.openhome.com/ws/local_link//?api_key={API_KEY}&client_id={ID}&role=agent
```

Default values from LocalLink.app:
- Host: `app.openhome.com`
- Port: `8769`
- Client ID: `laptop`
- Role: `agent`

Protocol is identical to `local_client_terminal.py`:
- Receives: `{"type": "command", "data": {"cmd": "..."}}` or `{"type": "relay", "data": "..."}`
- Sends back: `{"type": "response", "data": {"ok": true, "stdout": "...", ...}}`
- Ping/pong: `{"type": "ping"}` → `{"type": "pong"}`

**Status**: Port 8769 currently appears firewalled from external networks.
May be dynamically opened, or may have been relocated. Needs further investigation.

## MQTT (port 1883)

Used for hardware control (LEDs, buttons, etc.) on the DevKit.
Topic structure and message format not yet explored.
The DevKit UI sends `{"type": "devkit-action-mqtt", "data": ...}` over the
local WebSocket, which presumably gets bridged to MQTT.
