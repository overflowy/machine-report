# machine-report

A compact one-screen summary of the machine you just logged into. Single bash script, no dependencies beyond what macOS and Linux ship with.

```
┌──────────────────────────────────────────────────────────────┐
│ MACHINE REPORT                   nyx · 2026-09-08 19:29 CEST │
├─ SYSTEM ────┬────────────────────────────────────────────────┤
│ OS          │ macOS 26.6.2 Tahoe                             │
│ Kernel      │ Darwin 25.6.0 arm64                            │
│ Machine     │ Mac17,9 · Bare metal                           │
│ Uptime      │ 1d 8h 31m                                      │
├─ NETWORK ───┼────────────────────────────────────────────────┤
│ Host        │ nyx.local                                      │
│ IP          │ 10.66.66.2 (utun4)                             │
│ DNS         │ 1.1.1.1, 1.0.0.1                               │
├─ RESOURCES ─┼────────────────────────────────────────────────┤
│ CPU         │ Apple M5 Pro                                   │
│ Cores       │ 18 (6S + 12P)                                  │
│ Load        │ ▮▮▮▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯  2.72 2.91 2.72    15%    │
│ Memory      │ ▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▯▯▯▯▯  18.5/24.0 GiB     77%    │
│ Disk        │ ▮▮▮▮▮▮▯▯▯▯▯▯▯▯▯▯▯▯▯▯  291/971 GB        30%    │
├─ SESSION ───┼────────────────────────────────────────────────┤
│ User        │ overflowy · 8 sessions                         │
│ Client      │ local                                          │
│ Last login  │ 2h 8m ago on ttys016                           │
└─────────────┴────────────────────────────────────────────────┘
```

Bars turn yellow at 70% and red at 90%. Load is the 1 minute average as a share of logical cores, with the 1, 5 and 15 minute values alongside.

## Install

Downloads the script to `~/.local/bin/machine_report` and adds one line to your shell rc file (`~/.zshrc`, or `~/.bashrc` / `~/.bash_profile` for bash) so it runs at the start of every interactive shell:

```sh
mkdir -p ~/.local/bin \
  && curl -fsSL https://raw.githubusercontent.com/overflowy/machine-report/main/machine_report.sh -o ~/.local/bin/machine_report \
  && chmod +x ~/.local/bin/machine_report \
  && ~/.local/bin/machine_report --install
```

To try it once without installing anything:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/overflowy/machine-report/main/machine_report.sh)
```

## Uninstall

Removes the installed copy and the rc line, nothing else:

```sh
~/.local/bin/machine_report --uninstall
```

## Options

```
Usage: machine_report [--install | --uninstall]

Options:
  --install     Copy this script to ~/.local/bin/machine_report
                and run it at the start of every interactive shell
  --uninstall   Remove the installed copy and the rc line
  -h, --help    Show this help

Environment:
  MR_INSTALL_DIR  where --install puts the script (default: ~/.local/bin)
  MR_TITLE        header text            (default: MACHINE REPORT)
  MR_WIDTH        total box width        (default: 64)
  MR_BAR_ON       filled bar glyph       (default: ▮)
  MR_BAR_OFF      empty bar glyph        (default: ▯)
  NO_COLOR        disable colour output
```

Colour is switched off automatically when output is not a terminal.

## Requirements

- bash 3.2 or newer (the one that ships with macOS is fine)
- macOS, or Linux with `procps` and `iproute2`; `lscpu`, `last` and `systemd-detect-virt` are used when present

## License

MIT, see [LICENSE](LICENSE).
