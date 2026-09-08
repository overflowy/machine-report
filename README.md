# machine-report

A compact one-screen summary of the machine you just logged into. Single bash script, no dependencies beyond what macOS and Linux ship with.

<img width="1319" height="920" alt="hello" src="https://github.com/user-attachments/assets/048714fc-a736-4671-818c-dedd6c8a343c" />

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

MIT
