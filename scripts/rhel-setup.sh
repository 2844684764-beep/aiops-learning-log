#!/usr/bin/env bash
# rhel-setup.sh — RHEL 9.x 学习环境初始化（AIOps 三周计划配套）
#
# 用法：sudo bash rhel-setup.sh [选项]
#   --no-docker      跳过 Docker 安装（只用 podman 时）
#   --no-epel        跳过 EPEL 源（htop / stress-ng 装不上）
#   --keep-selinux   保留 SELinux enforcing（默认改成 permissive）
#   --keep-firewall  保留 firewalld（默认关闭，改为按需开端口）
#   -h, --help       显示帮助
#
# 做的事：
#   1. 挂载 DVD 做本地 yum 源（RHEL 无订阅也能装包，reboot 后仍有效）
#   2. 装基础工具（vim/git/tmux/jq/sysstat/strace/python3 等）
#   3. 加 EPEL，装 htop + stress-ng（故障注入要用）
#   4. 装 Docker CE + compose 插件
#   5. 配时区、SELinux、防火墙，把当前用户加进 docker 组
#
# 幂等：重复运行不会出问题（已装的跳过，已配的覆盖）

set -euo pipefail

P="[rhel-setup]"
log()  { printf '\n%s %s\n' "$P" "$*"; }
warn() { printf '%s [警告] %s\n' "$P" "$*" >&2; }
die()  { printf '%s [错误] %s\n' "$P" "$*" >&2; exit 1; }

INSTALL_DOCKER=1
INSTALL_EPEL=1
KEEP_SELINUX=0
KEEP_FIREWALL=0

for arg in "$@"; do
  case "$arg" in
    --no-docker)     INSTALL_DOCKER=0 ;;
    --no-epel)       INSTALL_EPEL=0 ;;
    --keep-selinux)  KEEP_SELINUX=1 ;;
    --keep-firewall) KEEP_FIREWALL=1 ;;
    -h|--help)       sed -n '2,20p' "$0"; exit 0 ;;
    *)               die "未知参数: $arg（用 --help 看用法）" ;;
  esac
done

[ "$(id -u)" -eq 0 ] || die "请用 root 运行：sudo bash $0"

if ! grep -q '^VERSION_ID="9' /etc/os-release 2>/dev/null; then
  warn "当前不是 RHEL 9.x，脚本继续但可能有差异"
fi

DVD_DEV=/dev/sr0
DVD_MNT=/mnt/dvd
GPG_KEY=/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

# ── 1. 本地 DVD 源 ────────────────────────────────────────────────
setup_dvd_repo() {
  if ! blkid "$DVD_DEV" >/dev/null 2>&1; then
    warn "未检测到 $DVD_DEV（VMware 里光驱没挂 ISO？），跳过本地源"
    return 1
  fi

  mkdir -p "$DVD_MNT"
  if ! mountpoint -q "$DVD_MNT"; then
    mount -o ro "$DVD_DEV" "$DVD_MNT" || { warn "挂载 $DVD_DEV 失败"; return 1; }
  fi

  if [ ! -d "$DVD_MNT/BaseOS" ]; then
    warn "$DVD_MNT 下没有 BaseOS 目录，可能不是 DVD 版 ISO"
    return 1
  fi

  local gpg=0
  if [ -f "$GPG_KEY" ]; then
    rpm --import "$GPG_KEY" 2>/dev/null || true
    gpg=1
  fi

  cat > /etc/yum.repos.d/local-dvd.repo <<EOF
[dvd-baseos]
name=RHEL 9 DVD - BaseOS
baseurl=file://$DVD_MNT/BaseOS
enabled=1
gpgcheck=$gpg
gpgkey=file://$GPG_KEY

[dvd-appstream]
name=RHEL 9 DVD - AppStream
baseurl=file://$DVD_MNT/AppStream
enabled=1
gpgcheck=$gpg
gpgkey=file://$GPG_KEY
EOF

  # 开机自动挂载，nofail 防止 ISO 移走后卡在启动
  grep -qs "$DVD_MNT" /etc/fstab || \
    printf '%s %s iso9660 ro,nofail 0 0\n' "$DVD_DEV" "$DVD_MNT" >> /etc/fstab

  log "本地 DVD 源已配置（$DVD_MNT）"
}

# 禁止订阅组件自动写回 redhat.repo，否则每次 dnf 都刷警告
if command -v subscription-manager >/dev/null 2>&1; then
  subscription-manager config --rhsm.manage_repos=0 >/dev/null 2>&1 || true
fi
[ -f /etc/yum.repos.d/redhat.repo ] && \
  mv /etc/yum.repos.d/redhat.repo /etc/yum.repos.d/redhat.repo.disabled

HAVE_DVD=0
if setup_dvd_repo; then HAVE_DVD=1; fi

if [ "$HAVE_DVD" -eq 0 ]; then
  warn "没有本地源，后续 dnf 会失败。请先挂载 ISO 再重跑，或注册 Red Hat 开发者订阅。"
fi

dnf clean all >/dev/null 2>&1 || true
dnf makecache -y >/dev/null 2>&1 || warn "makecache 有警告，继续"

# ── 2. 基础工具 ───────────────────────────────────────────────────
log "安装基础工具"
BASE_PKGS="vim git curl wget tmux jq sysstat tar net-tools lsof strace bind-utils python3 python3-pip bash-completion"
dnf install -y $BASE_PKGS || die "基础工具安装失败，检查本地源是否可用"

# ── 3. EPEL + 故障注入工具 ────────────────────────────────────────
if [ "$INSTALL_EPEL" -eq 1 ]; then
  log "配置 EPEL 源"
  if ! rpm -q epel-release >/dev/null 2>&1; then
    dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm \
      || warn "EPEL 安装失败（大概率是没网），跳过"
  fi
  if rpm -q epel-release >/dev/null 2>&1; then
    dnf install -y htop stress-ng || warn "htop / stress-ng 安装失败"
  fi
fi

# ── 4. Docker CE ──────────────────────────────────────────────────
if [ "$INSTALL_DOCKER" -eq 1 ]; then
  log "安装 Docker CE"
  dnf install -y dnf-plugins-core || warn "dnf-plugins-core 安装失败"

  if [ ! -f /etc/yum.repos.d/docker-ce.repo ]; then
    dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo \
      || warn "Docker 源添加失败（没网？）"
  fi

  if [ -f /etc/yum.repos.d/docker-ce.repo ]; then
    dnf install -y --allowerasing docker-ce docker-ce-cli containerd.io docker-compose-plugin \
      || die "Docker 安装失败（常见原因：没网，或 runc 与 podman 冲突没加 --allowerasing）"
    systemctl enable --now docker
    log "Docker 已启动"
  else
    warn "跳过 Docker：没有可用源。可改用 podman，或先解决网络。"
  fi
fi

# ── 5. 系统配置 ───────────────────────────────────────────────────
log "配置时区"
timedatectl set-timezone Asia/Shanghai

if [ "$KEEP_SELINUX" -eq 0 ]; then
  log "SELinux 改为 permissive（学习环境，避免容器挂载卷被拦）"
  setenforce 0 2>/dev/null || true
  sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
else
  log "保留 SELinux enforcing（--keep-selinux）"
fi

if [ "$KEEP_FIREWALL" -eq 0 ]; then
  log "关闭 firewalld（学习环境）"
  systemctl disable --now firewalld 2>/dev/null || true
else
  log "保留 firewalld，开放 3000/8000/9090/9100"
  for p in 3000 8000 9090 9100; do
    firewall-cmd --permanent --add-port="$p/tcp" >/dev/null 2>&1 || true
  done
  firewall-cmd --reload >/dev/null 2>&1 || true
fi

TARGET_USER="${SUDO_USER:-}"
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
  TARGET_USER=$(awk -F: '$3>=1000 && $3<65534 {print $1; exit}' /etc/passwd)
fi
if [ -n "${TARGET_USER:-}" ] && id "$TARGET_USER" >/dev/null 2>&1; then
  usermod -aG docker "$TARGET_USER" 2>/dev/null && \
    log "已把 $TARGET_USER 加入 docker 组（重新登录后生效）"
fi

# ── 验收 ──────────────────────────────────────────────────────────
log "验收"
printf '  系统      : %s\n' "$(grep PRETTY_NAME /etc/os-release | cut -d= -f2- | tr -d '\"')"
printf '  内核      : %s\n' "$(uname -r)"
printf '  可用仓库  : %s 个\n' "$(dnf repolist 2>/dev/null | tail -n +2 | wc -l)"
printf '  Docker    : %s\n' "$(docker --version 2>/dev/null || echo '未安装')"
printf '  Compose   : %s\n' "$(docker compose version --short 2>/dev/null || echo '未安装')"
printf '  SELinux   : %s\n' "$(getenforce 2>/dev/null || echo 'n/a')"
printf '  firewalld : %s\n' "$(systemctl is-active firewalld 2>/dev/null || echo 'inactive')"
printf '  时区      : %s\n' "$(timedatectl show -p Timezone --value)"
printf '  IP        : %s\n' "$(hostname -I | awk '{print $1}')"

cat <<'EOF'

下一步：
  1. 退出当前 SSH 会话再重连，docker 组才生效（或执行 newgrp docker）
  2. 验证：docker run --rm hello-world
  3. 回到 VMware，给这个虚拟机打快照，命名 base-ready
  4. 开始 D1：写第一个带 /metrics 的 FastAPI 服务
EOF
