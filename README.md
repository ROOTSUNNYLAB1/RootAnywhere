<div align="center">

# RootAnywhere

**A full Linux system, without root. One command.**

Ubuntu · Debian · Kali · Alpine · Arch — on `amd64` and `arm64`, powered by [PRoot](https://proot-me.github.io/).

```bash
bash <(curl -s https://raw.githubusercontent.com/ROOTSUNNYLAB1/RootAnywhere/main/rootanywhere.sh)
```

`rootless` · `proot` · `no sudo` · `no docker` · `no VM`

*Made by **ROOTSUNNY** · **ROOTSUNNY LAB***

</div>

---

## What it does

Run the command above on any Linux machine — even as a normal user with no `sudo` — and RootAnywhere:

1. Creates a **`RootAnywhere/`** folder in the current directory. Everything lives there: the `proot` binary, the root filesystems, state and logs. Delete the folder and it is all gone.
2. Downloads the newest **PRoot** build for your CPU (`amd64` or `arm64`).
3. Shows an animated, centred, arrow-key menu to pick a system.
4. Downloads the **official rootfs** for it, unpacks it, and drops you into a root shell as `root@RootAnywhere`.

It re-centres itself to your terminal size, and uses a muted sand / sage palette — no neon.

## Systems

| System | Source | Notes |
|---|---|---|
| **Ubuntu 24.04 LTS** | Canonical `ubuntu-base` | recommended |
| **Debian 13** (Trixie) | Debian `debuerreotype` rootfs | |
| Ubuntu 22.04 LTS | Canonical `ubuntu-base` | |
| Debian 12 (Bookworm) | Debian `debuerreotype` rootfs | |
| Kali Linux | `kali.download` | |
| Alpine Linux | `alpinelinux.org` minirootfs | tiny |
| Arch Linux | `archlinux.org` bootstrap / Arch Linux ARM | amd64 needs `zstd` on the host |

If an official source is unreachable, the script falls back to the community images at `images.linuxcontainers.org`
(override with `RA_MIRROR=<url>`).

> **Tested so far:** Ubuntu 24.04 on `amd64` (install, `apt update`, `apt install`).
> The other systems use the same code path but have not all been verified yet — issues and reports are welcome.

## Features

- **Truly rootless** — works as a normal user; no `sudo`, no kernel modules, no Docker.
- **Looks like a real machine** — hostname `RootAnywhere` is applied everywhere (`hostname`, `hostnamectl`, `uname -n`, `/etc/hostname`, `/etc/hosts`, the prompt, `/proc/sys/kernel/hostname`).
- **cgroup v2 view** — `/sys/fs/cgroup` shows real host CPU and memory limits when the host exposes cgroup v2, otherwise a live-filled cgroup v2 tree.
- **Fake kernel string** — `uname -r` reports `6.8.0-rootanywhere`.
- **systemd lock** — real systemd cannot run under PRoot, so it is sealed off: `systemctl`, `journalctl`, `loginctl`, `timedatectl` and `hostnamectl` are safe stubs, `policy-rc.d` blocks service starts, and systemd entry points are diverted. Installing packages never crashes on systemd.
- **Smart hardlink handling** — the installer probes `dpkg`'s own write path and picks the link mode that works on your filesystem.
- **Packages are your choice** — nothing is installed by default. Pick presets or your own list (below).
- **Optional Tailscale** — userspace networking, only when you ask for it.
- **Backup / restore / remove** built in.

## Usage

After installing, use the `ra` command inside the `RootAnywhere/` folder:

```bash
./RootAnywhere/ra                      # enter the first installed system
./RootAnywhere/ra start ubuntu24       # enter a specific one
./RootAnywhere/ra list                 # installed systems
./RootAnywhere/ra status               # disk usage per system
./RootAnywhere/ra doctor ubuntu24      # health check
./RootAnywhere/ra backup ubuntu24      # tar.gz into RootAnywhere/backups
./RootAnywhere/ra remove ubuntu24      # delete a system
```

System names: `ubuntu24` · `ubuntu22` · `debian13` · `debian12` · `kali` · `alpine` · `arch`

### Packages (optional)

```bash
./RootAnywhere/ra setup ubuntu24                    # menu
./RootAnywhere/ra setup ubuntu24 essentials         # curl wget sudo nano lsof procps
./RootAnywhere/ra setup ubuntu24 network            # iproute2 ping net-tools dig ssh traceroute
./RootAnywhere/ra setup ubuntu24 dev                # git build tools python vim zip
./RootAnywhere/ra setup ubuntu24 full               # everything above + htop, less …
./RootAnywhere/ra setup ubuntu24 curl git htop      # your own list
```

### Tailscale (optional)

```bash
./RootAnywhere/ra tailscale-install ubuntu24
./RootAnywhere/ra tailscale ubuntu24 --ssh
```

Runs in userspace-networking mode (no TUN device needed). Use `ALL_PROXY=socks5://localhost:1055` or
`HTTP_PROXY=http://localhost:1056` inside the system.

### Launch flags

```bash
./RootAnywhere/ra start ubuntu24 [flags] [-- command]
```

| Flag | Meaning |
|---|---|
| `-b src:dst` | bind-mount a host path |
| `-w dir` | working directory |
| `-s shell` | shell to start |
| `-e KEY=VAL` | set an environment variable |
| `--home-bind` | mount your host `$HOME` at `/mnt/host-home` |
| `--no-seccomp` | disable PRoot's seccomp acceleration (try this if something misbehaves) |
| `--no-fake-kernel` | do not fake the kernel string |
| `--quiet` | skip the boot animation |
| `--relink` | re-test the hardlink mode |

### Environment variables

| Variable | Default | Use |
|---|---|---|
| `RA_HOME` | `./RootAnywhere` | where everything is stored |
| `RA_MIRROR` | `https://images.linuxcontainers.org` | fallback image mirror |
| `RA_PROOT_URL` | — | use your own PRoot binary |

## Requirements

- Linux, `x86_64` or `aarch64`
- `bash`, `curl`, `tar`, `xz`, `awk`, `grep`, `sed`
- `zstd` (only for Arch on amd64)
- Outbound internet access

## How it works

```
RootAnywhere/
├── proot            # the PRoot binary
├── ra               # the CLI
├── start-<name>.sh  # one-shot launcher per system
├── rootfs/<name>/   # the unpacked root filesystems
├── .core/           # launcher, package and Tailscale helpers
├── .state/<name>/   # fake cgroup tree, hostname, link mode
├── .cache/          # downloaded images
└── .logs/run.log    # log of the last install step
```

## Limits — read this

RootAnywhere is **not a VM**. PRoot intercepts system calls in userspace, so:

- **No real systemd.** It is stubbed on purpose (see above); services are not supervised.
- **No kernel features** — no real namespaces, no loading modules, no raw device access.
- **No real firewalling / `iptables`**, no mounting filesystems.
- Performance is a little lower than native because of syscall interception.
- The cgroup view and the kernel string are cosmetic.
- Only the host's own CPU architecture is supported (no `amd64` on `arm64` emulation).

## Troubleshooting

| Problem | Try |
|---|---|
| Something crashes or hangs | `./RootAnywhere/ra start <name> --no-seccomp` |
| `dpkg` errors about `status-old` | `./RootAnywhere/ra relink <name>`, then `./RootAnywhere/ra doctor <name>` |
| Broken or partial install | `./RootAnywhere/ra remove <name>` and run the installer again (the image is cached) |
| Download fails | check the network, or set `RA_MIRROR` / `RA_PROOT_URL` |
| Install log | `RootAnywhere/.logs/run.log` |

## Credits

- [PRoot](https://github.com/proot-me/proot) — the engine that makes all of this possible.
- Rootfs images from Canonical, Debian, Alpine, Arch Linux and Kali.
- [Tailscale](https://tailscale.com/) (optional).

## License

[MIT](LICENSE) © ROOTSUNNY LAB

<div align="center"><sub>RootAnywhere · ROOTSUNNY LAB · made by ROOTSUNNY</sub></div>
