#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────
#  RootAnywhere v1.0 — made by ROOTSUNNY · ROOTSUNNY LAB
#  © ROOTSUNNY LAB · MIT License
#  Rootless Linux anywhere, powered by PRoot.
#  Run:  bash <(curl -s https://raw.githubusercontent.com/ROOTSUNNYLAB1/RootAnywhere/main/rootanywhere.sh)
# ──────────────────────────────────────────────────────────────────────────

RA_VERSION="1.0"
WM_NAME="ROOTSUNNY"
WM_LAB="ROOTSUNNY LAB"
RA_HOME="${RA_HOME:-$PWD/RootAnywhere}"
MIRROR="${RA_MIRROR:-https://images.linuxcontainers.org}"

# keep alignment maths correct: we need a UTF-8 locale for ${#str}
case "${LC_ALL:-}${LANG:-}" in *UTF-8*|*utf8*|*UTF8*) ;; *) export LC_ALL=C.UTF-8 ;; esac

# ── palette (soft, muted — no neon) ───────────────────────────────────────
SAND=$'\e[38;5;180m'; SAGE=$'\e[38;5;108m'; SLATE=$'\e[38;5;110m'
ROSE=$'\e[38;5;174m'; DIM=$'\e[38;5;244m'; TXT=$'\e[38;5;252m'
B=$'\e[1m'; Z=$'\e[0m'
SPIN=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
GRAD=(95 101 137 138 144 180 186)

hide() { printf '\e[?25l'; }
show() { printf '\e[?25h'; }

# ── responsive layout: everything is centred for the current terminal ────
# W = content width (<=64), M = left margin that centres it.
layout() {
  local sz; sz=$({ stty size </dev/tty; } 2>/dev/null)
  rows=${sz% *}; cols=${sz#* }
  [[ $cols =~ ^[0-9]+$ ]] || cols=$(tput cols 2>/dev/null || echo 80)
  [[ $rows =~ ^[0-9]+$ ]] || rows=$(tput lines 2>/dev/null || echo 24)
  W=$((cols-4)); [ "$W" -gt 64 ] && W=64
  [ "$W" -lt 34 ] && W=$cols
  local pad=$(( (cols-W)/2 )); [ "$pad" -lt 0 ] && pad=0
  printf -v M '%*s' "$pad" ''
}
layout
trap layout WINCH
trap 'show; printf "%s\n" "$Z"' EXIT
trap 'show; printf "\n%s%sInterrupted.%s\n" "$M" "$ROSE" "$Z"; exit 130' INT TERM

# centred single line:  cline <colour> <plain text>
cline() { local c=$1 t=$2 l; l=$(( (W-${#t})/2 )); [ "$l" -lt 0 ] && l=0; printf '%s%*s%s%s%s\n' "$M" "$l" '' "$c" "$t" "$Z"; }
# box row inside a W-wide box:  boxrow <colour> <plain text> <border colour>
boxrow() { local t=${2:0:$((W-4))} bc=${3:-$SAGE}; printf '%s%s│%s %s%s%s%*s %s│%s\n' "$M" "$bc" "$Z" "$1" "$t" "$Z" "$((W-4-${#t}))" '' "$bc" "$Z"; }
boxedge() { local bar; printf -v bar '%*s' "$((W-2))" ''; bar=${bar// /─}; printf '%s%s%s%s%s%s\n' "$M" "${3:-$SAGE}" "$1" "$bar" "$2" "$Z"; }

die()   { show; printf '\n%s%s✘ %s%s\n\n' "$M" "$ROSE" "$*" "$Z"; exit 1; }
hs()    { awk -v b="$1" 'BEGIN{split("B KB MB GB",u);i=1;while(b>=1024&&i<4){b/=1024;i++}printf "%.1f%s",b,u[i]}'; }
put()   { mkdir -p "$(dirname "$1")"; cat >"$1"; chmod "${2:-644}" "$1"; }

# ── banner ────────────────────────────────────────────────────────────────
banner() {
  layout
  local top=$(( (rows-17)/3 )); [ "$top" -lt 1 ] && top=1
  local t="R O O T   A N Y W H E R E" tag="rootless · proot · any linux · any arch" f i c bar
  local pal=(95 101 137 138 144 180 186 187 223 187 186 180 144 138 137 101)
  local bw=$((W-2)) lp rp
  [ ${#tag} -gt $((bw-2)) ] && tag="rootless · any linux"
  clear; for ((i=0;i<top;i++)); do echo; done
  boxedge ╭ ╮ "$DIM"
  lp=$(( (bw-${#t})/2 )); rp=$(( bw-${#t}-lp ))
  hide
  for f in $(seq 0 34); do
    printf '\r%s%s│%s%*s' "$M" "$DIM" "$Z" "$lp" ''
    for ((i=0;i<${#t};i++)); do
      c=${pal[(i+f)%${#pal[@]}]}
      printf '\e[1;38;5;%sm%s' "$c" "${t:i:1}"
    done
    printf '%s%*s%s│%s' "$Z" "$rp" '' "$DIM" "$Z"
    sleep 0.045
  done
  printf '\n'
  lp=$(( (bw-${#tag})/2 )); rp=$(( bw-${#tag}-lp ))
  printf '%s%s│%s%*s%s%s%s%*s%s│%s\n' "$M" "$DIM" "$Z" "$lp" '' "$DIM" "$tag" "$Z" "$rp" '' "$DIM" "$Z"
  boxedge ╰ ╯ "$DIM"
  cline "$SAND" "$WM_LAB · by $WM_NAME · v$RA_VERSION"
  echo
  show
}

step() { printf '%s%s◆%s %s%s%s\n' "$M" "$SAND" "$Z" "$B$TXT" "$*" "$Z"; }
ok()   { printf '\r\033[K%s%s✔%s %s\n' "$M" "$SAGE" "$Z" "$*"; }
bad()  { printf '\r\033[K%s%s✘%s %s\n' "$M" "$ROSE" "$Z" "$*"; }
note() { local t="$*"; printf '%s  %s%s%s\n' "$M" "$DIM" "${t:0:$((W-4))}" "$Z"; }

# ── animated task runner ──────────────────────────────────────────────────
task() {
  local msg=$1; shift
  local log="$RA_HOME/.logs/run.log"; mkdir -p "$RA_HOME/.logs"; : >"$log"
  "$@" >>"$log" 2>&1 &
  local pid=$! i=0 t0=$SECONDS last max
  hide; layout
  while kill -0 "$pid" 2>/dev/null; do
    max=$((W - ${#msg} - 12)); [ "$max" -lt 4 ] && max=4
    last=$(tail -n1 "$log" 2>/dev/null | tr -d '\r\t' | cut -c1-"$max")
    printf '\r\033[K%s%s%s%s %s%s%s %s(%ds)%s %s%s%s' "$M" "$SLATE" "${SPIN[i%10]}" "$Z" "$TXT" "$msg" "$Z" "$DIM" "$((SECONDS-t0))" "$Z" "$DIM" "$last" "$Z"
    i=$((i+1)); sleep 0.08
  done
  wait "$pid"; local rc=$?
  show
  if [ $rc -eq 0 ]; then ok "$msg ${DIM}($((SECONDS-t0))s)${Z}"; else bad "$msg"; tail -n 8 "$log" | sed "s/^/${M}    ${DIM}/;s/\$/${Z}/"; fi
  return $rc
}

# ── animated download bar ─────────────────────────────────────────────────
dl() {
  local url=$1 out=$2 label=$3 total cur=0 pid i=0 w f e pct t0=$SECONDS g k sp
  mkdir -p "$(dirname "$out")"
  total=$(curl -sIL --max-time 20 "$url" 2>/dev/null | tr -d '\r' | awk 'tolower($1)=="content-length:"{v=$2+0} END{print v+0}')
  rm -f "$out.part"
  curl -fL --retry 3 -s "$url" -o "$out.part" 2>/dev/null &
  pid=$!
  hide
  while kill -0 "$pid" 2>/dev/null; do
    layout; w=$((W-42)); [ "$w" -lt 8 ] && w=8
    cur=$(stat -c %s "$out.part" 2>/dev/null || echo 0)
    local bar=""
    if [ "$total" -gt 0 ]; then
      pct=$((cur*100/total)); [ $pct -gt 100 ] && pct=100
      f=$((w*pct/100)); e=$((w-f))
      for ((k=0;k<f;k++)); do g=${GRAD[k*${#GRAD[@]}/w]}; bar+=$'\e[38;5;'"$g"'m█'; done
      bar+="$DIM"; for ((k=0;k<e;k++)); do bar+="░"; done
      printf '\r\033[K%s%s%s%s %s%-16.16s%s %s%s %s%3d%%%s %s%s%s' "$M" "$SLATE" "${SPIN[i%10]}" "$Z" "$TXT" "$label" "$Z" "$bar" "$Z" "$SAND" "$pct" "$Z" "$DIM" "$(hs "$cur")/$(hs "$total")" "$Z"
    else
      sp=$((i%(w-6)))
      for ((k=0;k<w;k++)); do if [ $k -ge $sp ] && [ $k -lt $((sp+6)) ]; then bar+=$'\e[38;5;108m█'; else bar+=$'\e[38;5;238m░'; fi; done
      printf '\r\033[K%s%s%s%s %s%-16.16s%s %s%s %s%s%s' "$M" "$SLATE" "${SPIN[i%10]}" "$Z" "$TXT" "$label" "$Z" "$bar" "$Z" "$DIM" "$(hs "$cur")" "$Z"
    fi
    i=$((i+1)); sleep 0.08
  done
  wait "$pid"; local rc=$?
  show
  if [ $rc -eq 0 ] && [ -s "$out.part" ]; then
    mv -f "$out.part" "$out"; ok "$label ${DIM}$(hs "$(stat -c %s "$out")") in $((SECONDS-t0))s${Z}"; return 0
  fi
  rm -f "$out.part"; bad "$label download failed"; return 1
}

# ── arrow-key menu (centred) ──────────────────────────────────────────────
menu() {
  local title=$1; shift
  local items=("$@") n=$# sel=0 i k k2 lbl desc lw dw
  layout
  local maxl=0; for i in "${!items[@]}"; do lbl=${items[$i]%%|*}; [ ${#lbl} -gt $maxl ] && maxl=${#lbl}; done
  printf '\n%s%s%s%s\n%s%s↑/↓ move · enter select%s\n\n' "$M" "$B" "$SAND$title" "$Z" "$M" "$DIM" "$Z"
  hide
  while :; do
    layout; lw=$maxl; [ $lw -gt $((W-14)) ] && lw=$((W-14)); [ $lw -lt 8 ] && lw=8; dw=$((W-lw-4)); [ $dw -lt 4 ] && dw=4
    for i in "${!items[@]}"; do
      lbl=${items[$i]%%|*}; desc=${items[$i]#*|}; desc=${desc:0:$dw}
      if [ "$i" -eq "$sel" ]; then
        printf '%s%s▸ %s%-*.*s%s %s%s%s\033[K\n' "$M" "$SAGE" "$B$TXT" "$lw" "$lw" "$lbl" "$Z" "$SLATE" "$desc" "$Z"
      else
        printf '%s  %s%-*.*s %s%s\033[K\n' "$M" "$DIM" "$lw" "$lw" "$lbl" "$desc" "$Z"
      fi
    done
    IFS= read -rsn1 k </dev/tty
    if [[ $k == $'\e' ]]; then read -rsn2 -t 0.05 k2 </dev/tty; k+=$k2; fi
    case "$k" in
      $'\e[A'|k) sel=$(( (sel-1+n) % n ));;
      $'\e[B'|j) sel=$(( (sel+1) % n ));;
      '') break;;
    esac
    printf '\033[%dA' "$n"
  done
  show; MENU_SEL=$sel; echo
}

# ── distro catalogue ─────────────────────────────────────────────────────
ORDER=(ubuntu24 debian13 ubuntu22 debian12 kali alpine arch)
declare -A SRC=([ubuntu24]="ubuntu/noble" [debian13]="debian/trixie" [ubuntu22]="ubuntu/jammy" [debian12]="debian/bookworm" [kali]="kali/current" [alpine]="alpine/edge" [arch]="archlinux/current")
declare -A LBL=([ubuntu24]="Ubuntu 24.04 LTS|Noble Numbat · recommended" [debian13]="Debian 13|Trixie · stable" [ubuntu22]="Ubuntu 22.04 LTS|Jammy Jellyfish" [debian12]="Debian 12|Bookworm" [kali]="Kali Linux|rolling" [alpine]="Alpine Linux|tiny · latest stable" [arch]="Arch Linux|rolling")

declare -A OFFVER=([ubuntu24]=24.04 [ubuntu22]=22.04)
declare -A CODENAME=([debian13]=trixie [debian12]=bookworm)

resolve_latest() { ok "${LBL[$1]%%|*} ${DIM}→ official rootfs${Z}"; }

# Official rootfs sources first, images.linuxcontainers.org only as the last fallback.
# Writes one candidate URL per line to .cache/urls.<id>
find_official() {
  local id=$1 out="$RA_HOME/.cache/urls.$1" an dn base f ver c
  : > "$out"
  case $ARCH in amd64) an=x86_64; dn=amd64;; *) an=aarch64; dn=arm64v8;; esac
  case $id in
    ubuntu24|ubuntu22)   # Canonical: ubuntu-base
      ver=${OFFVER[$id]}; base="https://cdimage.ubuntu.com/ubuntu-base/releases/$ver/release/"
      f=$(curl -fsSL --max-time 25 "$base" 2>/dev/null | grep -oE "ubuntu-base-${ver/./[.]}([.][0-9]+)?-base-${ARCH}[.]tar[.]gz" | sort -uV | tail -n1)
      [ -n "$f" ] && echo "$base$f" >> "$out" ;;
    debian13|debian12)   # Debian's own build tool (debuerreotype) — the official Docker rootfs
      c=${CODENAME[$id]}
      echo "https://raw.githubusercontent.com/debuerreotype/docker-debian-artifacts/dist-$dn/$c/rootfs.tar.xz" >> "$out"
      echo "https://raw.githubusercontent.com/debuerreotype/docker-debian-artifacts/dist-$dn/$c/slim/rootfs.tar.xz" >> "$out" ;;
    alpine)              # alpinelinux.org minirootfs
      base="https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/$an/"
      f=$(curl -fsSL --max-time 25 "$base" 2>/dev/null | grep -oE "alpine-minirootfs-[0-9]+[.][0-9]+[.][0-9]+-${an}[.]tar[.]gz" | sort -uV | tail -n1)
      [ -n "$f" ] && echo "$base$f" >> "$out" ;;
    arch)                # archlinux.org bootstrap / Arch Linux ARM
      if [ "$ARCH" = amd64 ]; then command -v zstd >/dev/null 2>&1 && echo "https://geo.mirror.pkgbuild.com/iso/latest/archlinux-bootstrap-x86_64.tar.zst" >> "$out"
      else echo "http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz" >> "$out"; fi ;;
    kali)                # kali.org
      echo "https://kali.download/nethunter-images/current/rootfs/kali-nethunter-rootfs-minimal-$ARCH.tar.xz" >> "$out" ;;
  esac
  # last-resort fallback mirror
  base="$MIRROR/images/${SRC[$id]}/$ARCH/default/"
  f=$(curl -fsSL --max-time 25 "$base" 2>/dev/null | grep -oE '[0-9]{8}_[0-9]{2}(:|%3A)[0-9]{2}' | sort -u | tail -n1)
  [ -n "$f" ] && echo "${base}${f}/rootfs.tar.xz" >> "$out"
  [ -s "$out" ] || { echo "no download source reachable for $id"; return 1; }
  cat "$out"
}

# ── preflight ────────────────────────────────────────────────────────────
preflight() {
  for c in curl tar xz awk grep sed; do command -v "$c" >/dev/null 2>&1 || die "missing tool: $c (please install it first)"; done
  case "$(uname -m)" in
    x86_64|amd64)  ARCH=amd64 ;;
    aarch64|arm64) ARCH=arm64 ;;
    *) die "unsupported CPU: $(uname -m) (amd64 / arm64 only)" ;;
  esac
  [ "$(uname -s)" = Linux ] || die "RootAnywhere needs a Linux host"
}

get_proot() {
  if [ -x "$RA_HOME/proot" ] && "$RA_HOME/proot" --version >/dev/null 2>&1; then ok "PRoot engine ${DIM}ready${Z}"; return 0; fi
  local urls=() u latest
  [ -n "${RA_PROOT_URL:-}" ] && urls+=("$RA_PROOT_URL")
  latest=$(curl -fsSL --max-time 15 https://api.github.com/repos/proot-me/proot/releases/latest 2>/dev/null | grep -oE 'https://[^"]+' | grep -E "$([ "$ARCH" = amd64 ] && echo x86_64 || echo aarch64)-static" | head -n1)
  [ -n "$latest" ] && urls+=("$latest")
  if [ "$ARCH" = amd64 ]; then
    urls+=(https://proot.gitlab.io/proot/bin/proot https://github.com/proot-me/proot/releases/download/v5.3.0/proot-v5.3.0-x86_64-static)
  else
    urls+=(https://github.com/proot-me/proot/releases/download/v5.3.0/proot-v5.3.0-aarch64-static https://proot.gitlab.io/proot/bin/proot)
  fi
  for u in "${urls[@]}"; do
    dl "$u" "$RA_HOME/proot" "PRoot engine" || continue
    chmod +x "$RA_HOME/proot"
    "$RA_HOME/proot" --version >/dev/null 2>&1 && return 0
    bad "that proot binary does not run here, trying next"
  done
  return 1
}

# ── launcher scripts (written into RootAnywhere/.core) ───────────────────
write_core() {
  mkdir -p "$RA_HOME"/{.core,.state,.tmp,.cache,.logs,rootfs}

  put "$RA_HOME/.core/enter.sh" 755 <<'ENTER'
#!/usr/bin/env bash
# RootAnywhere · ROOTSUNNY LAB · made by ROOTSUNNY
# launcher:  enter.sh <system> [flags] [-- command...]
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
RA_HOME="$(cd "$(dirname "$SELF")/.." && pwd)"
PROOT="$RA_HOME/proot"
name="${1:-}"
if [ -z "$name" ] || [ ! -d "$RA_HOME/rootfs/$name" ]; then echo "RootAnywhere: unknown system '$name'" >&2; exit 1; fi
shift
binds=(); envs=(); wd=/root; shell=""; noseccomp=0; nokernel=0; quiet=0; relink=0
while [ $# -gt 0 ]; do case "$1" in
  -b|--bind) binds+=(-b "$2"); shift 2;;
  -w|--workdir) wd="$2"; shift 2;;
  -s|--shell) shell="$2"; shift 2;;
  -e|--env) envs+=("$2"); shift 2;;
  --home-bind) binds+=(-b "$HOME:/mnt/host-home"); shift;;
  --no-seccomp) noseccomp=1; shift;;
  --no-fake-kernel) nokernel=1; shift;;
  --quiet) quiet=1; shift;;
  --relink) relink=1; shift;;
  --) shift; break;;
  *) break;;
esac; done

root="$RA_HOME/rootfs/$name"; state="$RA_HOME/.state/$name"
mkdir -p "$state/cgroup" "$state/shm" "$RA_HOME/.tmp"
export PROOT_TMP_DIR="$RA_HOME/.tmp"
[ "$noseccomp" = 1 ] && export PROOT_NO_SECCOMP=1

# DNS
rm -f "$root/etc/resolv.conf"
{ grep -E '^nameserver' /etc/resolv.conf 2>/dev/null; echo "nameserver 1.1.1.1"; echo "nameserver 8.8.8.8"; } > "$root/etc/resolv.conf"

# hostname everywhere
echo RootAnywhere > "$state/hostname"
# plain (no colour) prompt — refreshed on every start so old installs update too
if [ -d "$root/etc/profile.d" ]; then
  printf '%s\n' 'export HOSTNAME=RootAnywhere' 'if [ -n "$BASH_VERSION" ]; then' "  PS1='root@RootAnywhere:\\w\\\$ '" 'else' "  PS1='root@RootAnywhere:\$PWD# '" 'fi' > "$root/etc/profile.d/00-rootanywhere.sh"
fi

# cgroup v2 view (real host cgroup2 if present, otherwise a live-filled fake)
memtotal=$(awk '/MemTotal/{print $2*1024}' /proc/meminfo)
memused=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{print (t-a)*1024}' /proc/meminfo)
ncpu=$(nproc 2>/dev/null || echo 1)
cg="$state/cgroup"
echo "cpuset cpu io memory hugetlb pids" > "$cg/cgroup.controllers"
echo "cpuset cpu io memory hugetlb pids" > "$cg/cgroup.subtree_control"
echo "domain" > "$cg/cgroup.type"
: > "$cg/cgroup.procs"
echo "$memtotal" > "$cg/memory.max"; echo "$memused" > "$cg/memory.current"; echo max > "$cg/memory.swap.max"
echo "max 100000" > "$cg/cpu.max"; echo 100 > "$cg/cpu.weight"; echo "0-$((ncpu-1))" > "$cg/cpuset.cpus.effective"
echo max > "$cg/pids.max"; echo 1 > "$cg/pids.current"; : > "$cg/io.max"
printf 'usage_usec 0\nuser_usec 0\nsystem_usec 0\n' > "$cg/cpu.stat"

pargs=(-0 --kill-on-exit -r "$root" -b /dev -b /proc -b /sys -b "$state/shm:/dev/shm")
[ -e /proc/sys/kernel/hostname ] && pargs+=(-b "$state/hostname:/proc/sys/kernel/hostname")
[ -f /sys/fs/cgroup/cgroup.controllers ] || pargs+=(-b "$cg:/sys/fs/cgroup")
# hardlink mode: dpkg needs link() ("status-old"). Test what works on THIS host, remember it.
lm="$state/linkmode"; [ "$relink" = 1 ] && rm -f "$lm"
if [ ! -s "$lm" ]; then
  ld=/var/lib/dpkg; [ -d "$root$ld" ] || ld=/tmp
  lt='cd '"$ld"' && rm -f .ra1 .ra2 && echo x > .ra1 && ln .ra1 .ra2 && rm -f .ra1 .ra2'
  mode=""
  for m in native l2s; do
    la=(); [ "$m" = l2s ] && la=(--link2symlink)
    if "$PROOT" -0 "${la[@]}" --kill-on-exit -r "$root" -b /dev -b /proc /bin/sh -c "$lt" >/dev/null 2>&1; then mode=$m; break; fi
  done
  [ -n "$mode" ] || mode=l2s-untested
  echo "$mode" > "$lm"
fi
case "$(cat "$lm")" in l2s*) pargs+=(--link2symlink);; esac
pargs+=("${binds[@]}" -w "$wd")

kargs=()
[ "$nokernel" = 0 ] && kargs=(-k "\\Linux\\RootAnywhere\\6.8.0-rootanywhere\\#1 SMP PREEMPT_DYNAMIC RootAnywhere\\$(uname -m)\\(none)\\-1\\")
if ! "$PROOT" "${pargs[@]}" "${kargs[@]}" /bin/true >/dev/null 2>&1; then
  kargs=()
  "$PROOT" "${pargs[@]}" /bin/true >/dev/null 2>&1 || export PROOT_NO_SECCOMP=1
fi

if [ -z "$shell" ]; then
  for s in /bin/bash /usr/bin/bash /bin/sh; do
    if [ -x "$root$s" ] || [ -L "$root$s" ]; then shell=$s; break; fi
  done
fi

if [ $# -eq 0 ] && [ "$quiet" = 0 ] && [ -t 1 ]; then
  d=$'\e[38;5;244m'; g=$'\e[38;5;108m'; z=$'\e[0m'
  tc=$(stty size 2>/dev/null | awk '{print $2}'); [ -n "$tc" ] || tc=$(tput cols 2>/dev/null || echo 80)
  bw=$((tc-4)); [ "$bw" -gt 64 ] && bw=64; [ "$bw" -lt 34 ] && bw=$tc
  p=$(( (tc-bw)/2 )); [ "$p" -lt 0 ] && p=0; m=$(printf '%*s' "$p" '')
  for s in "mounting /proc /sys /dev" "cgroup v2 view" "hostname → RootAnywhere" "systemd lock engaged" "dropping into shell"; do
    printf '%s%s◆%s %s' "$m" "$g" "$z" "$s"; sleep 0.12; printf '  %s✔%s\n' "$g" "$z"
  done
  printf '%s%sRootAnywhere · ROOTSUNNY LAB · made by ROOTSUNNY%s\n\n' "$m" "$d" "$z"
fi

genv=(HOME=/root USER=root LOGNAME=root SHELL="$shell" TERM="${TERM:-xterm-256color}" LANG=C.UTF-8 HOSTNAME=RootAnywhere container=proot PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin "${envs[@]}")
if [ $# -gt 0 ]; then
  exec "$PROOT" "${pargs[@]}" "${kargs[@]}" /usr/bin/env -i "${genv[@]}" "$@"
else
  exec "$PROOT" "${pargs[@]}" "${kargs[@]}" /usr/bin/env -i "${genv[@]}" "$shell" -l
fi
ENTER

  { declare -p SAND SAGE SLATE ROSE DIM TXT B Z SPIN GRAD; declare -f layout hide show cline step ok bad note task hs menu
    echo 'layout'; echo 'trap layout WINCH'; echo 'trap "show" EXIT'; } > "$RA_HOME/.core/ui.sh"

  put "$RA_HOME/.core/pkg.sh" 755 <<'PKG'
#!/usr/bin/env bash
# RootAnywhere · ROOTSUNNY LAB · made by ROOTSUNNY
# optional package installer:  pkg.sh <system> [essentials|network|dev|full | pkg1 pkg2 ...]
RA_HOME="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
. "$RA_HOME/.core/ui.sh"
name="${1:-}"; shift
[ -d "$RA_HOME/rootfs/$name" ] || { echo "RootAnywhere: unknown system '$name'"; exit 1; }
preset=""; pkgs=""
if [ $# -eq 0 ]; then
  menu "Install packages into $name" \
    "Essentials|curl wget sudo nano lsof procps" \
    "Network tools|ip ping net-tools dig ssh traceroute" \
    "Developer|git build tools python vim zip" \
    "Everything|all of the above + htop, less …" \
    "Custom list|type exactly what you want" \
    "Skip|install nothing"
  case $MENU_SEL in
    0) preset=essentials;; 1) preset=network;; 2) preset=dev;; 3) preset=full;;
    4) printf '%s%spackages (space separated): %s' "$M" "$SAND" "$Z"; read -r pkgs </dev/tty; preset=custom;;
    *) exit 0;;
  esac
else
  case "$1" in essentials|network|dev|full) preset=$1;; *) preset=custom; pkgs="$*";; esac
fi
[ "$preset" = custom ] && [ -z "$pkgs" ] && exit 0

cat > "$RA_HOME/rootfs/$name/root/.ra-pkg.sh" <<'GUEST'
#!/bin/sh
export DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
if command -v apt-get >/dev/null 2>&1; then pm=apt
elif command -v apk >/dev/null 2>&1; then pm=apk
elif command -v pacman >/dev/null 2>&1; then pm=pacman
else echo "no supported package manager"; exit 1; fi
case "$pm:$RA_PRESET" in
  apt:essentials)  L="curl wget sudo nano lsof ca-certificates procps";;
  apt:network)     L="iproute2 iputils-ping net-tools dnsutils openssh-client traceroute";;
  apt:dev)         L="git build-essential python3 python3-pip vim-tiny unzip zip xz-utils tar gnupg";;
  apt:full)        L="curl wget sudo nano lsof ca-certificates procps iproute2 iputils-ping net-tools dnsutils openssh-client traceroute git build-essential python3 python3-pip vim-tiny unzip zip xz-utils tar gnupg htop less bash-completion locales tzdata psmisc";;
  apk:essentials)  L="curl wget sudo nano lsof ca-certificates procps bash";;
  apk:network)     L="iproute2 iputils net-tools bind-tools openssh-client traceroute";;
  apk:dev)         L="git build-base python3 py3-pip vim unzip zip xz tar gnupg";;
  apk:full)        L="curl wget sudo nano lsof ca-certificates procps bash iproute2 iputils net-tools bind-tools openssh-client traceroute git build-base python3 py3-pip vim unzip zip xz tar gnupg htop less bash-completion shadow coreutils util-linux";;
  pacman:essentials) L="curl wget sudo nano lsof procps-ng";;
  pacman:network)  L="iproute2 iputils net-tools bind openssh traceroute";;
  pacman:dev)      L="git base-devel python python-pip vim unzip zip xz tar gnupg";;
  pacman:full)     L="curl wget sudo nano lsof procps-ng iproute2 iputils net-tools bind openssh traceroute git base-devel python python-pip vim unzip zip xz tar gnupg htop less bash-completion";;
  *:custom)        L="$RA_PKGS";;
esac
case "$pm" in
  apt)    apt-get update -y; apt-get install -y $L || for p in $L; do apt-get install -y "$p" || true; done
          for p in systemd systemd-sysv libpam-systemd udev; do dpkg -s "$p" >/dev/null 2>&1 && apt-mark hold "$p"; done
          apt-get clean ;;
  apk)    apk update; apk add $L ;;
  pacman) O=""; pacman --help 2>&1 | grep -q disable-sandbox && O="--disable-sandbox"; pacman -Sy --noconfirm $O $L ;;
esac
rm -f /root/.ra-pkg.sh
exit 0
GUEST
chmod 755 "$RA_HOME/rootfs/$name/root/.ra-pkg.sh"
task "Installing packages ($preset)" "$RA_HOME/.core/enter.sh" "$name" --quiet -e "RA_PRESET=$preset" -e "RA_PKGS=$pkgs" -- /bin/sh /root/.ra-pkg.sh || { note "log: $RA_HOME/.logs/run.log"; exit 1; }
note "done — enter with:  ra start $name"
PKG

  put "$RA_HOME/.core/tailscale.sh" 755 <<'TSI'
#!/usr/bin/env bash
# ROOTSUNNY LAB · RootAnywhere — Optional: install Tailscale into a RootAnywhere system.  usage: tailscale.sh <name>
RA_HOME="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
name="$1"; root="$RA_HOME/rootfs/$name"
[ -d "$root" ] || { echo "unknown system '$name'"; exit 1; }
case "$(uname -m)" in x86_64|amd64) A=amd64;; aarch64|arm64) A=arm64;; *) echo "unsupported arch"; exit 1;; esac
tgz=$(curl -fsSL https://pkgs.tailscale.com/stable/ | grep -oE "tailscale_[0-9]+\.[0-9]+\.[0-9]+_${A}\.tgz" | sort -uV | tail -n1)
[ -n "$tgz" ] || { echo "could not find tailscale release"; exit 1; }
tmp="$RA_HOME/.cache/ts"; rm -rf "$tmp"; mkdir -p "$tmp"
curl -fsSL "https://pkgs.tailscale.com/stable/$tgz" -o "$RA_HOME/.cache/ts.tgz" || exit 1
tar -xzf "$RA_HOME/.cache/ts.tgz" -C "$tmp" || exit 1
mkdir -p "$root/usr/local/bin" "$root/var/lib/tailscale" "$root/var/run/tailscale"
cp "$tmp"/*/tailscale "$tmp"/*/tailscaled "$root/usr/local/bin/" && chmod 755 "$root/usr/local/bin/tailscale" "$root/usr/local/bin/tailscaled"
cat > "$root/usr/local/bin/ra-tailscale" <<'X'
#!/bin/sh
# usage: ra-tailscale [up args]   e.g.  ra-tailscale --ssh
mkdir -p /var/run/tailscale /var/lib/tailscale
if ! pidof tailscaled >/dev/null 2>&1; then
  nohup tailscaled --tun=userspace-networking --state=/var/lib/tailscale/tailscaled.state \
    --socket=/var/run/tailscale/tailscaled.sock --socks5-server=localhost:1055 \
    --outbound-http-proxy-listen=localhost:1056 >/var/log/tailscaled.log 2>&1 &
  sleep 2
fi
tailscale up --hostname=RootAnywhere "$@"
echo "  userspace mode: ALL_PROXY=socks5://localhost:1055  or  HTTP_PROXY=http://localhost:1056"
X
chmod 755 "$root/usr/local/bin/ra-tailscale"
echo "installed $tgz"
TSI

  put "$RA_HOME/ra" 755 <<'RACLI'
#!/usr/bin/env bash
# RootAnywhere CLI · ROOTSUNNY LAB · made by ROOTSUNNY
RA_HOME="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
installed() { ls -1 "$RA_HOME/rootfs" 2>/dev/null; }
usage() {
cat <<EOF
RootAnywhere CLI  ·  ROOTSUNNY LAB  ·  made by ROOTSUNNY
  ra                       enter the only/first installed system
  ra start <name> [flags] [-- cmd]   flags: -b src:dst  -w dir  -s shell  -e K=V
                                     --home-bind  --no-seccomp  --no-fake-kernel  --quiet
  ra list                  installed systems
  ra relink <name>         re-test hardlink mode (fixes dpkg 'status-old' errors)
  ra doctor [name]         health check (hardlinks, dpkg database, proot, apt state)
  ra status                disk usage per system
  ra setup <name> [preset|pkgs]   (optional) install packages: menu, or essentials|network|dev|full,
                                     or your own list:  ra setup ubuntu24 curl git htop
  ra tailscale-install <name>     (optional) install Tailscale into a system
  ra tailscale <name> [up args]   start tailscaled + 'tailscale up' inside a system
  ra backup <name>         tar.gz backup into RootAnywhere/backups
  ra restore <file> <name> restore a backup
  ra remove <name>         delete a system
  (add another system:  run the install one-liner again)
  — ROOTSUNNY LAB —
EOF
}
case "${1:-}" in
  list) installed ;;
  relink) rm -f "$RA_HOME/.state/$2/linkmode"; exec "$RA_HOME/.core/enter.sh" "$2" --relink --quiet -- /bin/true ;;
  doctor) n="${2:-$(installed | head -n1)}"; [ -n "$n" ] || { echo "nothing installed"; exit 1; }
    d="$RA_HOME/.tmp"; mkdir -p "$d"; : > "$d/.hl1"
    if ln "$d/.hl1" "$d/.hl2" 2>/dev/null; then echo "[ok]   filesystem supports hardlinks"; else echo "[warn] filesystem has NO hardlinks (PRoot emulation required)"; fi; rm -f "$d/.hl1" "$d/.hl2"
    echo "[info] proot: $("$RA_HOME/proot" --version 2>&1 | grep -oE 'v[0-9]+\.[0-9]+[^ ]*' | head -n1)"
    "$RA_HOME/.core/enter.sh" "$n" --quiet -- /bin/true; echo "[info] link mode: $(cat "$RA_HOME/.state/$n/linkmode" 2>/dev/null)"
    c=$(ls "$RA_HOME/rootfs/$n"/var/lib/dpkg/info/*.list 2>/dev/null | wc -l)
    if [ "$c" -ge 50 ] || [ ! -d "$RA_HOME/rootfs/$n/var/lib/dpkg" ]; then echo "[ok]   package database: $c packages"; else echo "[BAD]  package database only $c packages -> broken install. Fix:  ra remove $n   then run the installer again (image is cached)"; fi
    "$RA_HOME/.core/enter.sh" "$n" --quiet -- /bin/sh -c 'command -v dpkg >/dev/null && dpkg --audit | head -n 5; echo "[info] hostname: $(hostname)  kernel: $(uname -r)"' ;;
  start|enter) shift; exec "$RA_HOME/.core/enter.sh" "$@" ;;
  status) for n in $(installed); do printf '%-12s %s\n' "$n" "$(du -sh "$RA_HOME/rootfs/$n" 2>/dev/null | cut -f1)"; done ;;
  setup|pkg) shift; exec "$RA_HOME/.core/pkg.sh" "$@" ;;
  tailscale-install) exec "$RA_HOME/.core/tailscale.sh" "$2" ;;
  tailscale) shift; n=$1; shift; exec "$RA_HOME/.core/enter.sh" "$n" -- ra-tailscale "$@" ;;
  backup) mkdir -p "$RA_HOME/backups"; f="$RA_HOME/backups/$2-$(date +%Y%m%d-%H%M).tar.gz"; tar -czf "$f" -C "$RA_HOME/rootfs" "$2" && echo "$f" ;;
  restore) mkdir -p "$RA_HOME/rootfs/$3" && tar -xzf "$2" -C "$RA_HOME/rootfs" && echo restored ;;
  remove) chmod -R u+rwx "$RA_HOME/rootfs/$2" 2>/dev/null; rm -rf "$RA_HOME/rootfs/$2" "$RA_HOME/.state/$2" "$RA_HOME/start-$2.sh" && echo removed "$2" ;;
  -h|--help|help) usage ;;
  "") n=$(installed | head -n1); [ -n "$n" ] && exec "$RA_HOME/.core/enter.sh" "$n" || usage ;;
  *) usage ;;
esac
RACLI
}

# ── image lookup / extract / configure ───────────────────────────────────
# hardlinks that tar could not create (filesystem forbids link()) become plain copies
fix_hardlinks() {
  local img=$1 root=$2 dst src n=0
  tar -tvf "$img" 2>/dev/null | sed -nE 's/^h[^ ]+ +[^ ]+ +[0-9]+ +[^ ]+ +[^ ]+ +(.*) link to (.*)$/\1\t\2/p' |
  while IFS=$'\t' read -r dst src; do
    dst=${dst#./}; src=${src#./}
    [ -e "$root/$dst" ] || [ -L "$root/$dst" ] && continue
    mkdir -p "$root/$(dirname "$dst")"; cp -p "$root/$src" "$root/$dst" 2>/dev/null && n=$((n+1))
  done
}

extract_rootfs() {
  local id=$1 root="$RA_HOME/rootfs/$1" img="$RA_HOME/.cache/$1.img" rc top n
  chmod -R u+rwx "$root" 2>/dev/null; rm -rf "$root"; mkdir -p "$root"
  # plain tar, no proot: real hardlinks, and nothing rewritten into host-absolute symlinks
  tar -xf "$img" -C "$root" --anchored --no-wildcards-match-slash --exclude='./dev/*' --exclude='dev/*' --exclude='root.*/dev/*' --exclude='kali-*/dev/*' --no-same-owner 2>&1 | tail -n 5
  rc=${PIPESTATUS[0]}
  if [ "$rc" -ne 0 ]; then
    echo "tar returned $rc — repairing hardlinks"
    chmod -R u+rwx "$root" 2>/dev/null; fix_hardlinks "$img" "$root"
  fi
  # image with one top-level folder (arch root.x86_64, kali-arm64 …)
  if [ ! -d "$root/usr" ]; then
    top=$(ls -A "$root"); if [ "$(echo "$top" | wc -l)" = 1 ] && [ -d "$root/$top" ]; then
      ( shopt -s dotglob nullglob; mv "$root/$top"/* "$root"/ ); rmdir "$root/$top" 2>/dev/null
    fi
  fi
  [ -d "$root/usr" ] || { echo "extraction produced no rootfs (bad download?) — run again"; rm -f "$img"; return 1; }
  [ -e "$root/bin/sh" ] || [ -L "$root/bin/sh" ] || [ -e "$root/usr/bin/sh" ] || { echo "no /bin/sh in rootfs — incomplete extraction"; rm -f "$img"; return 1; }
  if [ -d "$root/var/lib/dpkg/info" ]; then
    n=$(ls "$root"/var/lib/dpkg/info/*.list 2>/dev/null | wc -l)
    [ "$n" -ge 20 ] || { echo "dpkg database looks incomplete ($n packages)"; rm -f "$img"; return 1; }
    echo "dpkg database ok ($n packages)"
  fi
  find "$root" -type d -exec chmod u+rwx {} + 2>/dev/null
  return 0
}

configure_guest() {
  local id=$1 root="$RA_HOME/rootfs/$1"
  mkdir -p "$root"/{etc/profile.d,usr/local/bin,usr/sbin,root,tmp}
  chmod 1777 "$root/tmp"

  # hostname, everywhere
  echo RootAnywhere > "$root/etc/hostname"
  printf '127.0.0.1\tlocalhost RootAnywhere\n::1\t\tlocalhost RootAnywhere\n' > "$root/etc/hosts"
  printf 'RootAnywhere \\n \\l\nROOTSUNNY LAB — made by ROOTSUNNY\n\n' > "$root/etc/issue"
  printf 'RootAnywhere — ROOTSUNNY LAB\n' > "$root/etc/issue.net"
  printf '\n  RootAnywhere · rootless Linux via PRoot\n  ROOTSUNNY LAB — made by ROOTSUNNY\n\n' > "$root/etc/motd"
  printf 'NAME=RootAnywhere\nVERSION=%s\nVENDOR=ROOTSUNNY LAB\nAUTHOR=ROOTSUNNY\n' "$RA_VERSION" > "$root/etc/rootanywhere-release"
  printf 'RootAnywhere — ROOTSUNNY LAB (made by ROOTSUNNY)\nEnter: ra start <name>\n' > "$root/root/README-RootAnywhere.txt"

  # ── systemd LOCK: stubs that make every service/postinst call harmless ──
  put "$root/usr/local/bin/systemctl" 755 <<'X'
#!/bin/sh
# RootAnywhere systemd-lock: systemd is sealed off; installs can never crash on it.
cmd=""; unit=""
for a in "$@"; do case "$a" in -*) ;; *) if [ -z "$cmd" ]; then cmd=$a; elif [ -z "$unit" ]; then unit=${a%.service}; fi;; esac; done
case "$cmd" in
  start|stop|restart|reload|try-restart|reload-or-restart|try-reload-or-restart)
    case "$cmd" in start|stop|restart) act=$cmd;; *) act=restart;; esac
    if [ -n "$unit" ] && [ -x "/etc/init.d/$unit" ]; then "/etc/init.d/$unit" "$act" >/dev/null 2>&1; fi
    exit 0;;
  is-active)  echo active;  exit 0;;
  is-enabled) echo enabled; exit 0;;
  is-failed)  echo active;  exit 1;;
  is-system-running) echo running; exit 0;;
  status) printf '● %s - managed by RootAnywhere systemd-lock\n     Loaded: loaded (locked)\n     Active: active\n' "${unit:-RootAnywhere}"; exit 0;;
  *) exit 0;;
esac
X
  put "$root/usr/local/bin/journalctl"  755 <<'X'
#!/bin/sh
echo "-- RootAnywhere: journald is locked out --"; exit 0
X
  put "$root/usr/local/bin/loginctl"    755 <<'X'
#!/bin/sh
exit 0
X
  put "$root/usr/local/bin/timedatectl" 755 <<'X'
#!/bin/sh
printf '               Local time: %s\n  Time zone: %s\nSystem clock synchronized: yes\n' "$(date)" "$(cat /etc/timezone 2>/dev/null || echo UTC)"
X
  put "$root/usr/local/bin/hostnamectl" 755 <<'X'
#!/bin/sh
. /etc/os-release 2>/dev/null
printf '   Static hostname: RootAnywhere\n         Icon name: computer-container\n           Chassis: container\n  Operating System: %s\n            Kernel: Linux %s\n      Architecture: %s\n' "$PRETTY_NAME" "$(uname -r)" "$(uname -m)"
X
  put "$root/usr/local/bin/hostname" 755 <<'X'
#!/bin/sh
case "$1" in -h|--help) echo "hostname [-s|-f|-d|-I]"; exit 0;; esac
case "$1" in -d|--domain) echo "(none)";; -I|--all-ip-addresses) echo "127.0.0.1";; *) echo RootAnywhere;; esac
X

  # ── shell look: prompt + system card ──
  put "$root/etc/profile.d/00-rootanywhere.sh" 644 <<'X'
export HOSTNAME=RootAnywhere
if [ -n "$BASH_VERSION" ]; then
  PS1='root@RootAnywhere:\w\$ '
else
  PS1='root@RootAnywhere:$PWD# '
fi
X
  put "$root/etc/profile.d/10-rootanywhere-card.sh" 644 <<'X'
case $- in *i*) ;; *) return 0 2>/dev/null;; esac
[ -n "$RA_CARD" ] && return 0
export RA_CARD=1
os=$(. /etc/os-release 2>/dev/null; echo "$PRETTY_NAME")
cpu=$(awk -F: '/model name|^Model|Hardware/{print $2; exit}' /proc/cpuinfo 2>/dev/null | sed 's/^ *//')
[ -n "$cpu" ] || cpu=$(uname -m)
cores=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null)
mem=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf "%.0f / %.0f MiB",(t-a)/1024,t/1024}' /proc/meminfo)
disk=$(df -h / 2>/dev/null | awk 'NR==2{print $3" / "$2" ("$5")"}')
up=$(awk '{printf "%dd %dh %dm",int($1/86400),int(($1%86400)/3600),int(($1%3600)/60)}' /proc/uptime)
cg="v1"; [ -f /sys/fs/cgroup/cgroup.controllers ] && cg="v2 ($(wc -w < /sys/fs/cgroup/cgroup.controllers) controllers)"
s=$(printf '\033[38;5;180m'); d=$(printf '\033[38;5;244m'); t=$(printf '\033[38;5;252m'); z=$(printf '\033[0m')
tc=$(stty size 2>/dev/null | awk '{print $2}'); [ -n "$tc" ] || tc=$(tput cols 2>/dev/null); [ -n "$tc" ] || tc=${COLUMNS:-80}
bw=$((tc-4)); [ "$bw" -gt 64 ] && bw=64; [ "$bw" -lt 34 ] && bw=$tc
p=$(( (tc-bw)/2 )); [ "$p" -lt 0 ] && p=0; m=$(printf '%*s' "$p" '')
printf '\n%s%sRootAnywhere%s  %s· rootless · proot · ROOTSUNNY LAB%s\n' "$m" "$s" "$z" "$d" "$z"
for l in "OS|$os" "Host|RootAnywhere" "Kernel|$(uname -r) $(uname -m)" "CPU|$cpu ×$cores" "Memory|$mem" "Disk|$disk" "cgroup|$cg" "systemd|locked (stub)" "Uptime|$up"; do
  printf '%s%s%-8s%s %s%s%s\n' "$m" "$d" "${l%%|*}" "$z" "$t" "${l#*|}" "$z"
  sleep 0.03 2>/dev/null
done
printf '%s%stip: apt install anything — systemd cannot crash it%s\n%s%smade by ROOTSUNNY · ROOTSUNNY LAB%s\n\n' "$m" "$d" "$z" "$m" "$d" "$z"
X
  # make prompt win over distro .bashrc
  for f in "$root/root/.bashrc" "$root/etc/bash.bashrc"; do
    [ -e "$(dirname "$f")" ] && printf '\n# RootAnywhere\n. /etc/profile.d/00-rootanywhere.sh\n' >> "$f"
  done
  echo "[ -f /etc/profile.d/00-rootanywhere.sh ] && . /etc/profile.d/00-rootanywhere.sh" >> "$root/root/.profile"

  # ── in-guest bootstrap ──
  put "$root/root/.ra-setup.sh" 755 <<'X'
#!/bin/sh
export DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
if command -v apt-get >/dev/null 2>&1; then
  printf 'APT::Sandbox::User "root";\nAPT::Install-Recommends "false";\nDpkg::Options { "--force-confold"; "--force-unsafe-io"; };\n' > /etc/apt/apt.conf.d/99rootanywhere
  printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d; chmod 755 /usr/sbin/policy-rc.d
  rm -f /etc/apt/apt.conf.d/70debconf
  mkdir -p /etc/dpkg/dpkg.cfg.d; printf 'force-unsafe-io\nno-debsig\n' > /etc/dpkg/dpkg.cfg.d/99rootanywhere
  # systemd lock: divert every systemd entry point so no package can bring it back
  for f in /usr/bin/deb-systemd-helper /usr/bin/deb-systemd-invoke /usr/bin/systemctl /usr/bin/systemd-tmpfiles /usr/bin/systemd-machine-id-setup; do
    dpkg-divert --local --rename --add "$f" >/dev/null 2>&1
    case "$f" in */systemctl) ln -sf /usr/local/bin/systemctl "$f";; *) ln -sf /bin/true "$f";; esac
  done
  for p in systemd systemd-sysv libpam-systemd udev; do
    dpkg -s "$p" >/dev/null 2>&1 && apt-mark hold "$p"
  done
elif command -v apk >/dev/null 2>&1; then
  :
elif command -v pacman >/dev/null 2>&1; then
  sed -i 's/^SigLevel.*/SigLevel = Never/;s/^CheckSpace/#CheckSpace/' /etc/pacman.conf
  sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist 2>/dev/null
fi
rm -f /root/.ra-setup.sh
exit 0
X
}

# ── install one system ───────────────────────────────────────────────────
install_distro() {
  local id=$1 label=${LBL[$1]%%|*} url root="$RA_HOME/rootfs/$1"
  echo; step "Installing $label"
  if [ -d "$root/usr" ] && [ -x "$root/bin/sh" -o -L "$root/bin/sh" ]; then ok "$label already installed"; return 0; fi
  resolve_latest "$id"
  local img="$RA_HOME/.cache/$id.img" got=0 u h
  if [ -s "$img" ]; then ok "Using cached image"; got=1
  else
    task "Finding official $label rootfs" find_official "$id" || { note "no source reachable (mirror: $MIRROR)"; return 1; }
    while read -r u <&3; do
      h=${u#*://}; h=${h%%/*}
      dl "$u" "$img" "$label" && { note "source: $h"; got=1; break; }
      note "$h failed — trying next source"
    done 3< "$RA_HOME/.cache/urls.$id"
  fi
  [ "$got" = 1 ] || return 1
  task "Unpacking root filesystem" extract_rootfs "$id" || { note "log: $RA_HOME/.logs/run.log"; return 1; }
  task "Wiring hostname · systemd lock · prompt" configure_guest "$id" || return 1
  task "Locking systemd · base config" "$RA_HOME/.core/enter.sh" "$id" --quiet -- /bin/sh /root/.ra-setup.sh || { note "log: $RA_HOME/.logs/run.log"; return 1; }
  probe_dpkg "$id" || note "dpkg cannot create hardlinks here — apt installs will fail. Run: ra doctor $id"
  printf '#!/usr/bin/env bash\nexec "$(cd "$(dirname "$0")" && pwd)/.core/enter.sh" %s "$@"\n' "$id" > "$RA_HOME/start-$id.sh"; chmod +x "$RA_HOME/start-$id.sh"
  echo
  boxedge ╭ ╮
  boxrow "$B$TXT" "$label — ready"
  boxrow "$DIM" "enter    ./RootAnywhere/ra start $id"
  boxrow "$DIM" "packages ./RootAnywhere/ra setup $id   (optional)"
  boxrow "$DIM" "$WM_LAB · made by $WM_NAME"
  boxedge ╰ ╯
  return 0
}

# tries link modes until dpkg's own write path (status-old / diversions-old) works
probe_dpkg() {
  local id=$1 m
  command -v dpkg >/dev/null 2>&1 || [ -x "$RA_HOME/rootfs/$id/usr/bin/dpkg" ] || return 0
  mkdir -p "$RA_HOME/.state/$id"
  for m in native l2s; do
    echo "$m" > "$RA_HOME/.state/$id/linkmode"
    if "$RA_HOME/.core/enter.sh" "$id" --quiet -- /bin/sh -c 'dpkg-divert --local --add /usr/bin/ra-probe >/dev/null 2>&1 && dpkg-divert --local --remove /usr/bin/ra-probe >/dev/null 2>&1' >/dev/null 2>&1; then
      ok "dpkg write test passed ${DIM}(link mode: $m)${Z}"; return 0
    fi
  done
  rm -f "$RA_HOME/.state/$id/linkmode"; return 1
}

pick_distro() {
  local items=() id
  for id in "${ORDER[@]}"; do items+=("${LBL[$id]}"); done
  menu "Choose a system to install ($ARCH)" "${items[@]}"
  PICKED=${ORDER[$MENU_SEL]}
}

installed_list() { ls -1 "$RA_HOME/rootfs" 2>/dev/null; }

# ── main ─────────────────────────────────────────────────────────────────
main() {
  preflight
  banner
  local wp=$RA_HOME wm=$((W-16)); [ ${#wp} -gt $wm ] && wp="…${wp: -$((wm-1))}"
  step "Workspace  ${DIM}$wp${Z}"
  mkdir -p "$RA_HOME"; write_core; ok "RootAnywhere folder ready"
  local d="$RA_HOME/.tmp"; mkdir -p "$d"; : > "$d/.hl1"
  if ln "$d/.hl1" "$d/.hl2" 2>/dev/null; then ok "Filesystem ${DIM}hardlinks ok${Z}"; else note "no hardlink support here → using PRoot link emulation"; fi
  rm -f "$d/.hl1" "$d/.hl2"
  get_proot || die "could not get a working proot (set RA_PROOT_URL=<url> and retry)"
  ok "Host ${DIM}$(uname -m) → $ARCH${Z}"

  while :; do
    local have; have=$(installed_list)
    local act
    if [ -n "$have" ]; then
      menu "What now?" "Enter a system|open a shell" "Install another system|ubuntu · debian · kali · alpine · arch" "Install packages (optional)|curl wget sudo nano lsof …" "Add Tailscale (optional)|into an installed system" "Remove a system|delete its rootfs" "Quit|"
      act=$MENU_SEL
    else
      act=1
    fi
    case $act in
      0) local arr=($have) items=() n
         for n in "${arr[@]}"; do items+=("$n|${LBL[$n]#*|}"); done
         menu "Enter which system?" "${items[@]}"
         exec "$RA_HOME/.core/enter.sh" "${arr[$MENU_SEL]}" ;;
      1) pick_distro
         if install_distro "$PICKED"; then
           menu "Next step" "Enter now|" "Choose packages (optional)|curl wget sudo nano lsof …" "Not now|"
           case $MENU_SEL in
             0) exec "$RA_HOME/.core/enter.sh" "$PICKED" ;;
             1) "$RA_HOME/.core/pkg.sh" "$PICKED"
                menu "Enter ${LBL[$PICKED]%%|*} now?" "Yes, enter now|" "Not now|"
                [ "$MENU_SEL" = 0 ] && exec "$RA_HOME/.core/enter.sh" "$PICKED"
                exit 0 ;;
             *) exit 0 ;;
           esac
         else
           die "install failed — see $RA_HOME/.logs/run.log"
         fi ;;
      2) local arr4=($have) items4=() n4
         for n4 in "${arr4[@]}"; do items4+=("$n4|${LBL[$n4]#*|}"); done
         menu "Install packages into which system?" "${items4[@]}"
         "$RA_HOME/.core/pkg.sh" "${arr4[$MENU_SEL]}" ;;
      3) local arr3=($have) items3=() n3
         for n3 in "${arr3[@]}"; do items3+=("$n3|${LBL[$n3]#*|}"); done
         menu "Install Tailscale into which system?" "${items3[@]}"
         task "Installing Tailscale" "$RA_HOME/.core/tailscale.sh" "${arr3[$MENU_SEL]}"
         note "then inside the system run:  ra-tailscale --ssh" ;;
      4) local arr2=($have) items2=() n2
         for n2 in "${arr2[@]}"; do items2+=("$n2|${LBL[$n2]#*|}"); done
         menu "Remove which system?" "${items2[@]}"
         "$RA_HOME/ra" remove "${arr2[$MENU_SEL]}" ;;
      *) exit 0 ;;
    esac
  done
}

main "$@"
