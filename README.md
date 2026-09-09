# corne-endgame-lol

ZMK config for a wireless Corne (2x nice!nano v2 + nice!view), with ZMK Studio enabled.

Firmware can be built two ways: **GitHub Actions** (push and download the artifact) or
**locally with Docker** (~2 min per half, no cloud round-trip).

## Local build

### Prerequisites

- Docker Desktop, running. `docker info` must succeed.
- ~5 GB free disk (Zephyr's source tree) + ~2 GB for the Docker image.
- No host toolchain needed — the compiler, CMake, and west all live in the container.

### Build

```bash
./build.sh          # all three targets
./build.sh left     # just one: left | right | reset
./build.sh all --pristine
```

Output lands in `firmware/`:

| file | what | flash use |
|---|---|---|
| `left.uf2` | left half (central, ZMK Studio, USB logging) | ~61% |
| `right.uf2` | right half (peripheral) | ~45% |
| `reset.uf2` | settings_reset — clears BLE bonds | ~7% |

The first run also initializes the west workspace (`west init` + `west update`), which clones
Zephyr and every ZMK module — a few minutes and ~4 GB. Subsequent runs skip straight to
compiling. The image is `linux/amd64`, so on Apple Silicon it runs under emulation; that's
why builds take minutes rather than seconds.

Use `--pristine` after changing `config/west.yml`, shields, or snippets. Plain keymap and
`.conf` edits don't need it — incremental rebuilds pick those up.

### Flashing

1. Double-tap the reset button on a half. It mounts as a `NICENANO` USB volume.
2. Copy the matching `.uf2` onto it. The board reboots and unmounts itself.
3. Repeat for the other half.

If the halves won't pair (usually after reflashing only one side), flash `reset.uf2` to
**both** halves first, then flash `left.uf2` / `right.uf2` again.

## How the build is wired

`./build.sh` runs, per target, inside the `zmkfirmware/zmk-build-arm:stable` container:

```bash
west zephyr-export
west build -s zmk/app -d build/left -b 'nice_nano//zmk' \
  -S studio-rpc-usb-uart -S zmk-usb-logging \
  -- -DZMK_CONFIG=/workspace/config -DSHIELD='corne_left nice_view_adapter nice_view'
```

Notes on the non-obvious parts:

- **`west zephyr-export` runs on every build, not once.** It writes a CMake package registry
  entry to `~/.cmake` inside the container, which is thrown away when the container exits.
  Skip it and CMake fails with `Could not find a package configuration file provided by "Zephyr"`.
- **`-S zmk-usb-logging` is mandatory while `CONFIG_ZMK_USB_LOGGING=y`** is set in
  `config/corne.conf`. The Kconfig alone doesn't create a console device; without the snippet
  the build dies on an undefined `__device_dts_ord_DT_CHOSEN_zephyr_console_ORD`.
  USB logging also costs noticeable battery — comment it out in `corne.conf` when you're not
  debugging (and drop the snippet from `build.sh` / `build.yaml` if you want).
- **`-S studio-rpc-usb-uart` is left-half only.** ZMK Studio talks to the central half.
- **`board: nice_nano//zmk`** (double slash) is the Zephyr board/revision syntax ZMK now uses;
  it is not a typo.
- USB logging only works on the left half. The right half emits
  `ZMK_USB ... was assigned the value 'y' but got the value 'n'` because ZMK force-disables
  USB on split peripherals. Harmless.

`build.yaml` drives the GitHub Actions matrix and mirrors the same board/shield/snippet
combinations — keep the two in sync when you change one.

## Layout

```
config/
  corne.keymap    keymap, combos, layers
  corne.conf      Kconfig options (sleep, BLE, Studio, logging)
  west.yml        ZMK + module versions (urob's modules, pinned to v0.1)
build.yaml        GitHub Actions build matrix
build.sh          local Docker build
firmware/         build output (gitignored)
```

The west workspace (`zmk/`, `zephyr/`, `modules/`, `optional/`, `.west/`, `build/`) is
gitignored. Delete those directories to reclaim ~5 GB; `./build.sh` re-creates them.
