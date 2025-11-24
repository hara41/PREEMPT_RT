# Sample: Native C development on Raspberry Pi

This folder contains small examples and helpers to get started with C development directly on a Raspberry Pi.

Files:
- `hello.c` : simple hello world
- `blink.c` : LED blink example using `libgpiod` (BCM17)
- `Makefile` : build targets `make` / `make blink` / `make install`
- `myapp.service` : example `systemd` unit (for `hello`)

Quick start (on Raspberry Pi):

1. Install required packages:

```bash
sudo apt update
sudo apt install -y build-essential pkg-config git libgpiod-dev
```

2. Build:

```bash
cd ~/PREEMPT_RT/sample
make
```

3. Run examples:

Hello:
```bash
./hello
```

Blink (requires root to access GPIO, or configure udev rules):
```bash
sudo ./blink
```

4. Install and run as service (optional):

```bash
sudo make install
sudo cp myapp.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now myapp.service
sudo systemctl status myapp.service
```

Notes:
- `blink.c` uses `libgpiod` and references BCM17. Change `line_num` if you use a different pin.
- If you prefer not to run as root, add udev rules to grant gpio access to a specific user.

If you want, I can also add VSCode `launch.json` / debugger config or a Remote-SSH quickstart snippet.
