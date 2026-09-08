#!/usr/bin/env bash
# Machine report: a compact one-screen summary of the host.
# Run with --help for options.

set -u

MARKER="# machine_report"                   # tags the line --install adds to the shell rc file
LINE_RE="^\\[ -t 1 \\] && \".*\" $MARKER\$" # matches only that exact line shape, anywhere the script lives

usage() {
    cat <<EOF
Usage: ${0##*/} [--install | --uninstall]

Print a compact one-screen summary of this machine.

Options:
  --install     Run the report at the start of every interactive shell
                (adds one line to your shell's rc file)
  --uninstall   Remove the line added by --install
  -h, --help    Show this help

Environment:
  MR_TITLE      header text            (default: MACHINE REPORT)
  MR_WIDTH      total box width        (default: 64)
  MR_BAR_ON     filled bar glyph       (default: ▮)
  MR_BAR_OFF    empty bar glyph        (default: ▯)
  NO_COLOR      disable colour output
EOF
}

rc_file() { # startup file for the user's login shell
    case "${SHELL##*/}" in
    zsh) printf '%s' "${ZDOTDIR:-$HOME}/.zshrc" ;;
    bash)
        if [ "$(uname -s)" = Darwin ]; then printf '%s' "$HOME/.bash_profile"; else printf '%s' "$HOME/.bashrc"; fi
        ;;
    *)
        printf 'error: unsupported shell "%s" (expected bash or zsh)\n' "${SHELL:-unset}" >&2
        printf 'Add this line to your shell startup file by hand:\n  [ -t 1 ] && "%s"\n' "$(self_path)" >&2
        return 1
        ;;
    esac
}

self_path() { # absolute path of this script
    printf '%s/%s' "$(cd "$(dirname "$0")" && pwd -P)" "${0##*/}"
}

install_rc() {
    local rc line
    rc=$(rc_file) || exit 1
    line="[ -t 1 ] && \"$(self_path)\" $MARKER"
    if [ -f "$rc" ] && grep -q "$LINE_RE" "$rc"; then
        printf 'Already installed in %s\n' "$rc" >&2
        return 0
    fi
    # Make sure we start on a fresh line without adding a blank one.
    if [ -s "$rc" ] && [ -n "$(tail -c 1 "$rc")" ]; then printf '\n' >>"$rc"; fi
    printf '%s\n' "$line" >>"$rc" || {
        printf 'error: could not write to %s\n' "$rc" >&2
        exit 1
    }
    printf 'Added to %s:\n  %s\nOpen a new shell to see it, or run: source %s\n' "$rc" "$line" "$rc" >&2
}

uninstall_rc() {
    local rc tmp
    rc=$(rc_file) || exit 1
    if ! [ -f "$rc" ] || ! grep -q "$LINE_RE" "$rc"; then
        printf 'Nothing to remove: not installed in %s\n' "$rc" >&2
        return 0
    fi
    # Filter into a temp file, then write back through the rc path so a
    # symlinked rc (dotfile managers) stays a symlink. Keep the temp copy if
    # the write-back fails, since by then the rc has been truncated.
    tmp=$(mktemp) || exit 1
    grep -v "$LINE_RE" "$rc" >"$tmp" # exits 1 when nothing is left, which is fine
    if ! cat "$tmp" >"$rc"; then
        printf 'error: could not write %s; your filtered rc is saved at %s\n' "$rc" "$tmp" >&2
        exit 1
    fi
    rm -f "$tmp"
    printf 'Removed from %s\n' "$rc" >&2
}

case "${1:-}" in
"") ;;
--install)
    install_rc
    exit
    ;;
--uninstall)
    uninstall_rc
    exit
    ;;
-h | --help)
    usage
    exit
    ;;
*)
    printf 'error: unknown option "%s"\n\n' "$1" >&2
    usage >&2
    exit 2
    ;;
esac

TITLE="${MR_TITLE:-MACHINE REPORT}"
WIDTH="${MR_WIDTH:-64}"
LABEL_W=11
BAR_W=20
BAR_ON="${MR_BAR_ON:-▮}" # other pairs that fit one cell: ■□  ●○  ━─  █░
BAR_OFF="${MR_BAR_OFF:-▯}"
VAL_W=$((WIDTH - LABEL_W - 7)) # "│ " + label + " │ " + value + " │"

# Make sure ${#str} counts characters, not bytes, so box drawing lines up.
_probe="$BAR_ON"
if [ "${#_probe}" -ne 1 ]; then
    for loc in C.UTF-8 en_US.UTF-8; do
        if locale -a 2>/dev/null | grep -qx "$loc"; then
            export LC_ALL="$loc"
            [ "${#_probe}" -eq 1 ] && break
        fi
    done
fi

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RESET=$'\e[0m'
    C_BOLD=$'\e[1m'
    C_DIM=$'\e[2m'
    C_OK=$'\e[32m'
    C_WARN=$'\e[33m'
    C_BAD=$'\e[31m'
else
    C_RESET=""
    C_BOLD=""
    C_DIM=""
    C_OK=""
    C_WARN=""
    C_BAD=""
fi

# ---------------------------------------------------------------- drawing

rep() { # rep <char> <count>
    local out="" i
    for ((i = 0; i < $2; i++)); do out+="$1"; done
    printf '%s' "$out"
}

vlen() { # visible length, ignoring SGR escapes (no extglob: bash 3.2 safe)
    local s="$1" tail
    while [[ $s == *$'\e['*m* ]]; do
        tail="${s#*$'\e['}"
        s="${s%%$'\e['*}${tail#*m}"
    done
    printf '%s' "${#s}"
}

header() { # header <title> <meta>   title left, meta right
    local title="$1" meta="$2" gap
    gap=$((WIDTH - 4 - ${#title} - ${#meta}))
    if ((gap < 2)); then
        meta="${meta:0:WIDTH-6-${#title}}"
        gap=2
    fi
    printf '%s┌%s┐%s\n' "$C_DIM" "$(rep ─ $((WIDTH - 2)))" "$C_RESET"
    printf '%s│%s %s%s%s%*s%s%s%s %s│%s\n' "$C_DIM" "$C_RESET" "$C_BOLD" "$title" "$C_RESET" "$gap" "" \
        "$C_DIM" "$meta" "$C_RESET" "$C_DIM" "$C_RESET"
}

section() { # section <NAME> [first]   divider with the section name inset
    local name="$1" mid="┼"
    [ "${2:-}" = "first" ] && mid="┬"
    local left=$((LABEL_W + 2 - 3 - ${#name}))
    printf '%s├─ %s%s%s %s%s%s┤%s\n' "$C_DIM" "$C_RESET$C_BOLD" "$name" "$C_RESET$C_DIM" \
        "$(rep ─ "$left")" "$mid" "$(rep ─ $((VAL_W + 2)))" "$C_RESET"
}

bottom() {
    printf '%s└%s┴%s┘%s\n' "$C_DIM" "$(rep ─ $((LABEL_W + 2)))" "$(rep ─ $((VAL_W + 2)))" "$C_RESET"
}

row() { # row <label> <value>
    local label="$1" value="$2" vis
    vis=$(vlen "$value")
    if ((vis > VAL_W)) && [ "$vis" -eq "${#value}" ]; then
        value="${value:0:VAL_W-1}…"
        vis=$VAL_W
    fi
    printf '%s│%s %-*s %s│%s %s%*s %s│%s\n' "$C_DIM" "$C_RESET" "$LABEL_W" "$label" \
        "$C_DIM" "$C_RESET" "$value" $((VAL_W - vis)) "" "$C_DIM" "$C_RESET"
}

bar() { # bar <used> <total> <caption>  ->  ████░░░░  caption   NN%
    local pct filled colour
    pct=$(awk -v u="$1" -v t="$2" 'BEGIN { if (t <= 0) print 0; else printf "%d", (u / t) * 100 + 0.5 }')
    filled=$(((pct * BAR_W + 50) / 100))
    ((filled > BAR_W)) && filled=$BAR_W
    if ((pct >= 90)); then
        colour=$C_BAD
    elif ((pct >= 70)); then
        colour=$C_WARN
    else
        colour=$C_OK
    fi
    printf '%s%s%s%s%s  %-16s %4s' "$colour" "$(rep "$BAR_ON" "$filled")" "$C_DIM" "$(rep "$BAR_OFF" $((BAR_W - filled)))" "$C_RESET" "$3" "${pct}%"
}

# ---------------------------------------------------------------- helpers

human_secs() { # 123456 -> 1d 10h 17m
    awk -v s="$1" 'BEGIN {
        d = int(s / 86400); h = int(s % 86400 / 3600); m = int(s % 3600 / 60)
        out = ""
        if (d) out = d "d "
        if (d || h) out = out h "h "
        printf "%s%dm", out, m
    }'
}

gib() { awk -v k="$1" 'BEGIN { printf "%.1f", k / 1048576 }'; } # KiB -> GiB
gb() { awk -v k="$1" 'BEGIN { printf "%.0f", k / 1000000 }'; }  # KiB -> GB (decimal, like df -H)

relative() { # seconds -> "3d 2h" / "2h 15m" / "34m"
    awk -v s="$1" 'BEGIN {
        d = int(s / 86400); h = int(s % 86400 / 3600); m = int(s % 3600 / 60)
        if (d)      printf "%dd %dh", d, h
        else if (h) printf "%dh %dm", h, m
        else        printf "%dm", m
    }'
}

last_login() { # previous login for the current user, skipping the live session
    local rec date host tty ts diff rel
    rec=$(last -n 5 "$USER" 2>/dev/null | awk -v u="$USER" '
        $1 != u { next }
        { lines[++n] = $0; if (n == 2) exit }
        END {
            if (n == 0) exit
            line = (n == 2 && lines[1] ~ /still logged in/) ? lines[2] : lines[1]
            nf = split(line, f, " ")
            host = ""; date = ""
            for (i = 3; i <= nf; i++) {
                if (f[i] ~ /^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)$/) {
                    date = f[i+1] " " f[i+2] " " f[i+3]; break     # "Sep 8 16:12"
                }
                host = f[i]
            }
            if (date == "") print line "||"
            else            print date "|" host "|" f[2]
        }')
    [ -z "$rec" ] && {
        printf 'never'
        return
    }
    IFS='|' read -r date host tty <<<"$rec"

    case "$(uname -s)" in
    Darwin) ts=$(date -j -f '%b %d %H:%M' "$date" +%s 2>/dev/null || true) ;;
    *) ts=$(date -d "$date" +%s 2>/dev/null || true) ;;
    esac
    if [ -z "$ts" ]; then # unparseable, show as is
        printf '%s' "$date"
        return
    fi

    diff=$(($(date +%s) - ts))
    ((diff < 0)) && diff=$((diff + 365 * 86400)) # no year in `last`: crossed New Year
    if ((diff < 60)); then rel="just now"; else rel="$(relative "$diff") ago"; fi
    if [ -n "$host" ]; then printf '%s from %s' "$rel" "$host"; else printf '%s on %s' "$rel" "$tty"; fi
}

# ---------------------------------------------------------------- data

os_kernel="$(uname -sr) $(uname -m)"
short_host=$(hostname -s 2>/dev/null || uname -n)
fqdn=$(hostname -f 2>/dev/null || printf '%s' "$short_host")
user="$USER"
now=$(date '+%Y-%m-%d %H:%M %Z')

case "$(uname -s)" in
Darwin)
    os_name="$(sw_vers -productName) $(sw_vers -productVersion)"
    case "$(sw_vers -productVersion | cut -d. -f1)" in
    26) os_name+=" Tahoe" ;; 15) os_name+=" Sequoia" ;; 14) os_name+=" Sonoma" ;;
    13) os_name+=" Ventura" ;; 12) os_name+=" Monterey" ;; 11) os_name+=" Big Sur" ;;
    esac

    machine=$(sysctl -n hw.model 2>/dev/null)
    if [ "$(sysctl -n kern.hv_vmm_present 2>/dev/null)" = "1" ]; then virt="Virtual machine"; else virt="Bare metal"; fi

    boot=$(sysctl -n kern.boottime | sed -E 's/^\{ sec = ([0-9]+).*/\1/')
    uptime_s=$(($(date +%s) - boot))

    cpu_model=$(sysctl -n machdep.cpu.brand_string)
    cpu_logical=$(sysctl -n hw.logicalcpu)
    cpu_physical=$(sysctl -n hw.physicalcpu)
    cpu_hz=$(sysctl -n hw.cpufrequency 2>/dev/null || true)
    [ -n "$cpu_hz" ] && cpu_freq=$(awk -v h="$cpu_hz" 'BEGIN { printf "%.2f GHz", h / 1e9 }') || cpu_freq=""

    read -r load1 load5 load15 <<<"$(sysctl -n vm.loadavg | awk '{print $2, $3, $4}')"

    mem_total_k=$(($(sysctl -n hw.memsize) / 1024))
    mem_used_k=$(vm_stat | awk '
        /page size of/           { ps = $8 }
        /Pages active/           { a = $3 }
        /Pages wired down/       { w = $4 }
        /Pages occupied by compressor/ { c = $5 }
        END { gsub(/\./, "", a); gsub(/\./, "", w); gsub(/\./, "", c); printf "%d", (a + w + c) * ps / 1024 }')

    disk_path=/
    [ -d /System/Volumes/Data ] && disk_path=/System/Volumes/Data
    ip_iface=$(route -n get default 2>/dev/null | awk '/interface:/ { print $2 }')
    ip_addr=""
    if [ -n "$ip_iface" ]; then
        ip_addr=$(ipconfig getifaddr "$ip_iface" 2>/dev/null || true)
        [ -z "$ip_addr" ] && ip_addr=$(ifconfig "$ip_iface" 2>/dev/null | awk '/inet / { print $2; exit }')
    fi
    # Core tiers on Apple Silicon, e.g. "6S + 12P" or "10P + 4E"
    cpu_topology=""
    for i in 0 1 2 3; do
        tier_name=$(sysctl -n "hw.perflevel$i.name" 2>/dev/null) || break
        tier_count=$(sysctl -n "hw.perflevel$i.logicalcpu" 2>/dev/null) || break
        cpu_topology+="${cpu_topology:+ + }${tier_count}${tier_name:0:1}"
    done
    ;;
Linux)
    # shellcheck source=/dev/null
    os_name=$(. /etc/os-release 2>/dev/null && printf '%s' "${PRETTY_NAME:-$NAME}")
    [ -z "$os_name" ] && os_name="Linux"

    machine=$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || true)
    if [ -z "$machine" ] && [ -r /proc/device-tree/model ]; then machine=$(tr -d '\0' </proc/device-tree/model); fi
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        virt=$(systemd-detect-virt 2>/dev/null || true)
    else
        virt=$(lscpu 2>/dev/null | awk -F': *' '/Hypervisor vendor/ { print tolower($2) }')
    fi
    case "$virt" in "" | none) virt="Bare metal" ;; *) virt="$virt guest" ;; esac

    uptime_s=$(awk '{ printf "%d", $1 }' /proc/uptime)

    cpu_model=$(lscpu 2>/dev/null | awk -F': *' '/^Model name/ { print $2; exit }')
    [ -z "$cpu_model" ] && cpu_model=$(awk -F': ' '/model name/ { print $2; exit }' /proc/cpuinfo)
    cpu_logical=$(nproc --all 2>/dev/null || getconf _NPROCESSORS_ONLN)
    cpu_physical=$(lscpu 2>/dev/null | awk -F': *' '
        /^Core\(s\) per socket/ { c = $2 } /^Socket\(s\)/ { s = $2 } END { if (c && s) print c * s }')
    cpu_mhz=$(lscpu 2>/dev/null | awk -F': *' '/^CPU max MHz/ { print $2; exit }')
    [ -z "$cpu_mhz" ] && cpu_mhz=$(awk -F': ' '/cpu MHz/ { print $2; exit }' /proc/cpuinfo)
    [ -n "$cpu_mhz" ] && cpu_freq=$(awk -v m="$cpu_mhz" 'BEGIN { printf "%.2f GHz", m / 1000 }') || cpu_freq=""

    read -r load1 load5 load15 _ </proc/loadavg

    mem_total_k=$(awk '/^MemTotal/ { print $2 }' /proc/meminfo)
    mem_avail_k=$(awk '/^MemAvailable/ { print $2 }' /proc/meminfo)
    mem_used_k=$((mem_total_k - mem_avail_k))

    disk_path=/
    read -r ip_iface ip_addr <<<"$(ip -o route get 1.1.1.1 2>/dev/null | awk '
        { for (i = 1; i <= NF; i++) { if ($i == "dev") d = $(i+1); if ($i == "src") s = $(i+1) } print d, s }')"
    ;;
*)
    os_name="$(uname -s)"
    machine=""
    virt=""
    uptime_s=0
    cpu_model="unknown"
    cpu_logical=""
    cpu_physical=""
    cpu_freq=""
    load1=0
    load5=0
    load15=0
    mem_total_k=0
    mem_used_k=0
    disk_path=/
    ip_iface=""
    ip_addr=""
    ;;
esac

read -r disk_total_k disk_avail_k <<<"$(df -k "$disk_path" | awk 'NR == 2 { print $2, $4 }')"
disk_used_k=$((disk_total_k - disk_avail_k))

dns=$(awk '/^nameserver/ { print $2 }' /etc/resolv.conf 2>/dev/null | head -n 3 | paste -sd ',' - | sed 's/,/, /g')

client=""
if [ -n "${SSH_CONNECTION:-}" ]; then
    client="${SSH_CONNECTION%% *}"
else
    client=$(who -m 2>/dev/null | awk '$NF ~ /^\(.+\)$/ { h = $NF; gsub(/[()]/, "", h); print h }')
fi
[ -z "$client" ] && client="local"

sessions=$(who 2>/dev/null | wc -l | tr -d ' ')

# Assemble composed values.
machine_line="${machine:+$machine · }$virt"
cores_line="$cpu_logical"
if [ -n "${cpu_topology:-}" ]; then
    cores_line+=" ($cpu_topology)"
elif [ -n "$cpu_physical" ] && [ "$cpu_physical" != "$cpu_logical" ]; then
    cores_line+=" logical · $cpu_physical physical"
fi
[ -n "$cpu_freq" ] && cores_line+=" · $cpu_freq"
user_line="$user"
[ "$sessions" -gt 1 ] 2>/dev/null && user_line+=" · $sessions sessions"

# ---------------------------------------------------------------- report

header "$TITLE" "$short_host · $now"

section "SYSTEM" first
row "OS" "$os_name"
row "Kernel" "$os_kernel"
row "Machine" "$machine_line"
row "Uptime" "$(human_secs "$uptime_s")"

section "NETWORK"
[ "$fqdn" != "$short_host" ] && row "Host" "$fqdn"
row "IP" "${ip_addr:-none}${ip_iface:+ ($ip_iface)}"
row "DNS" "${dns:-none}"

section "RESOURCES"
row "CPU" "$cpu_model"
row "Cores" "$cores_line"
row "Load" "$(bar "$load1" "$cpu_logical" "$load1 $load5 $load15")"
row "Memory" "$(bar "$mem_used_k" "$mem_total_k" "$(gib "$mem_used_k")/$(gib "$mem_total_k") GiB")"
row "Disk" "$(bar "$disk_used_k" "$disk_total_k" "$(gb "$disk_used_k")/$(gb "$disk_total_k") GB")"

section "SESSION"
row "User" "$user_line"
row "Client" "$client"
row "Last login" "$(last_login)"
bottom
