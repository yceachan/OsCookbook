>  - 适用 OS：Ubuntu 22.04 LTS（Jammy），amd64；当前环境为 WSL2
>  - Docker Engine：docker-ce
>  - Docker CLI：docker-ce-cli
>  - Compose：docker-compose-plugin
>  - 必需运行时：containerd.io
>  - 内置 APT/curl 代理：127.0.0.1:7897
```bash
#!/usr/bin/env bash
# Clean installation of Docker Engine + Docker CLI + Docker Compose plugin.
# Target host: Ubuntu 22.04 LTS (jammy), amd64, including WSL2 with systemd.
# The proxy below is used only by curl/APT, not by the Docker daemon.
# Docker data under /var/lib/docker is preserved.
set -Eeuo pipefail

if ((EUID != 0)); then
  echo "错误：请使用 sudo 运行此脚本"
  exit 1
fi

LOG=/var/log/docker-engine-cli-compose-install.log
PROXY="${DOCKER_INSTALL_PROXY:-http://127.0.0.1:7897}"
APT=(
  apt-get
  -o "Acquire::http::Proxy=$PROXY"
  -o "Acquire::https::Proxy=$PROXY"
)

exec > >(tee -a "$LOG") 2>&1
trap 'rc=$?; echo "FAILED: line $LINENO, exit $rc"; exit "$rc"' ERR

. /etc/os-release
codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
architecture="$(dpkg --print-architecture)"

if [[ "${ID:-}" != "ubuntu" || "$codename" != "jammy" || "$architecture" != "amd64" ]]; then
  echo "错误：此脚本仅适用于 Ubuntu 22.04 LTS (jammy), amd64"
  echo "当前主机：ID=${ID:-unknown}, VERSION_ID=${VERSION_ID:-unknown}, CODENAME=${codename:-unknown}, ARCH=$architecture"
  exit 1
fi

echo "=== Docker stack installation started: $(date -Is) ==="
echo "Host: ${PRETTY_NAME}; codename=$codename; arch=$architecture"
echo "Components: Docker Engine + CLI + Compose plugin"
echo "APT/curl proxy: $PROXY"

echo "=== 1. 清除旧版、冲突及此前安装的 Docker 软件包 ==="
packages=(
  docker-engine
  docker.io
  docker-doc
  docker-compose
  docker-compose-v2
  podman-docker
  containerd
  containerd.io
  runc
  docker-ce
  docker-ce-cli
  docker-buildx-plugin
  docker-compose-plugin
  docker-ce-rootless-extras
)

installed=()
for pkg in "${packages[@]}"; do
  if dpkg-query -W -f='${db:Status-Status}' "$pkg" 2>/dev/null | grep -qx installed; then
    installed+=("$pkg")
  fi
done

if ((${#installed[@]})); then
  printf '正在清除：%s\n' "${installed[*]}"
  "${APT[@]}" purge -y "${installed[@]}"
else
  echo "没有发现已安装的 Docker/冲突软件包"
fi

echo "=== 2. 清除旧仓库、密钥及手动安装残留 ==="
rm -f \
  /etc/apt/sources.list.d/docker.list \
  /etc/apt/sources.list.d/docker.sources \
  /etc/apt/keyrings/docker.asc \
  /etc/apt/keyrings/docker.gpg \
  /usr/share/keyrings/docker-archive-keyring.gpg \
  /usr/local/bin/docker \
  /usr/local/bin/dockerd \
  /usr/local/bin/docker-compose

"${APT[@]}" clean
"${APT[@]}" update
"${APT[@]}" install -y ca-certificates curl gnupg

echo "=== 3. 下载并验证 Docker 官方 GPG 密钥 ==="
tmp_key="$(mktemp)"
trap 'rm -f "$tmp_key"' EXIT

curl \
  --proxy "$PROXY" \
  -4 \
  --http1.1 \
  --retry 8 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 15 \
  -fsSL \
  https://download.docker.com/linux/ubuntu/gpg \
  -o "$tmp_key"

fingerprint="$(
  gpg --batch --show-keys --with-colons "$tmp_key" |
    awk -F: '$1 == "fpr" {print $10; exit}'
)"
expected_fingerprint="9DC858229FC7DD38854AE2D88D81803C0EBFCD88"

if [[ "$fingerprint" != "$expected_fingerprint" ]]; then
  echo "错误：Docker GPG 密钥指纹不匹配"
  echo "期望：$expected_fingerprint"
  echo "实际：$fingerprint"
  exit 1
fi

echo "GPG 指纹验证通过：$fingerprint"
install -m 0755 -d /etc/apt/keyrings
install -m 0644 "$tmp_key" /etc/apt/keyrings/docker.asc

echo "=== 4. 创建 Docker 官方 APT 仓库 ==="
printf '%s\n' \
  'Types: deb' \
  'URIs: https://download.docker.com/linux/ubuntu' \
  "Suites: $codename" \
  'Components: stable' \
  "Architectures: $architecture" \
  'Signed-By: /etc/apt/keyrings/docker.asc' \
  > /etc/apt/sources.list.d/docker.sources

"${APT[@]}" update

echo "=== 5. 显示候选版本 ==="
for pkg in docker-ce docker-ce-cli containerd.io docker-compose-plugin; do
  candidate="$(apt-cache policy "$pkg" | awk '/Candidate:/ {print $2}')"
  if [[ -z "$candidate" || "$candidate" == "(none)" ]]; then
    echo "错误：官方仓库中未找到 $pkg"
    exit 1
  fi
  printf '%-24s %s\n' "$pkg" "$candidate"
done

echo "=== 6. 安装 Engine、CLI、containerd 依赖及 Compose 插件 ==="
"${APT[@]}" install -y --no-install-recommends \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-compose-plugin

echo "=== 7. 启用并启动 Docker Engine ==="
if [[ "$(ps -p 1 -o comm= | tr -d '[:space:]')" == "systemd" ]]; then
  systemctl enable --now docker
  systemctl is-active --quiet docker
else
  service docker start
fi

echo "=== 8. 最终验证 ==="
docker --version
docker compose version
docker version
docker info --format 'Server={{.ServerVersion}} StorageDriver={{.Driver}} CgroupDriver={{.CgroupDriver}}'

echo "--- 已安装的软件包 ---"
dpkg-query -W \
  -f='${binary:Package}\t${Version}\t${db:Status-Status}\n' \
  docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "=== Docker Engine + CLI + Compose installation completed successfully ==="
echo "Log: $LOG"
echo "提示：普通用户直接运行 docker 需要单独配置 docker 用户组；该用户组等同于 root 权限。"

```

