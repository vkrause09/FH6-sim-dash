# Forza Horizon 6 Sim Dashboard

Racing telemetry dashboard for **Forza Horizon 6** (Zig 0.16.0).

![Alt Text](./pictures/v1.0.0.png)


## Setup

1. Install latest release
2. In FH6: **Settings → HUD and Gameplay → Data Out**
   - IP: `127.0.0.1`
   - Port: `20067`

NOTE: If using another application is using UDP, the port will have to be configured



## Options
Zig v0.16.0 is required to compile and run from source

To compile and run exe:
```bash
zig build run
```

First build downloads and compiles raylib (may take a few minutes).

```bash
zig build run -- --help
zig build run -- --imperial          # default
zig build run -- --metric            # km/h, kW, Nm, °C
zig build run -- --pos 1242,1440     # window position
zig build run -- --font C:/Windows/Fonts/arialbd.ttf
zig build run -- --terminal          # text-only fallback
zig build run -- --only-racing
```
