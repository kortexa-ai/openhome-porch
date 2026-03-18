# Porch

**A lightweight macOS menubar app that bridges [OpenHome](https://openhome.com) voice AI to your local machine.**

Porch sits in your system tray, maintains a persistent WebSocket connection to your OpenHome device, and lets OpenHome [Abilities](https://github.com/openhome-dev/abilities) execute commands on your Mac — no inbound ports, no tunnels, no config.

## Status

Early development. Not yet functional.

## How It Works

```
OpenHome Device                         Your Mac
───────────────                         ────────
Ability (main.py)  ←── WebSocket ───→   Porch.app (menubar)
                   (outbound from Mac)      │
                                        Process / API / AppleScript
```

OpenHome Abilities run in the cloud but can't access your local network. Porch solves this by connecting **outward** to OpenHome and receiving commands through that tunnel. No firewall holes, no port forwarding.

## Planned Features

- Native Swift menubar app (~5MB, ~15MB RAM)
- Persistent WebSocket connection to OpenHome
- Command execution via `exec_local_command()` protocol
- Launch at login
- Connection status indicator
- Configurable command allowlists

## Related

- [OpenHome](https://openhome.com) — Voice AI platform
- [OpenHome Docs](https://docs.openhome.com) — Platform documentation
- [OpenHome Abilities](https://github.com/openhome-dev/abilities) — Open-source voice AI plugins
- [OpenHome Abilities SDK Reference](https://github.com/openhome-dev/abilities/blob/dev/docs/OpenHome_SDK_Reference.md) — Complete SDK docs
- [Local Template](https://github.com/openhome-dev/abilities/tree/dev/templates/Local) — The Python-based local client this project replaces

## Requirements

- macOS 14.0+ (Sonoma)
- An OpenHome account and API key

## License

[MIT](LICENSE)
