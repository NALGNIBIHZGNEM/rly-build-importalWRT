\
#!/usr/bin/env bash
set -euo pipefail

#=================================================
# File name: update-preset.sh
# System Required: Linux / macOS (bash)
# Description: 下载/解压/整理 OpenClash 预置核心与 Geo 数据到本仓库 openclash-preset/
# Usage:
#   cd openclash-preset
#   bash update-preset.sh
#
# 可通过环境变量覆盖默认版本：
#   MIHOMO_VERSION=v1.19.21 MIHOMO_ARCH=amd64-v1 \
#   OPENCLASH_REF=core OPENCLASH_CHANNEL=dev CLASH_ARCH=amd64-v1 \
#   RULES_TAG=202603192222 \
#   bash update-preset.sh
#=================================================

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="${ROOT_DIR}/core"
DATA_DIR="${ROOT_DIR}/data"
mkdir -p "${CORE_DIR}" "${DATA_DIR}"

# ---------------------------
# 可维护配置（默认值）
# ---------------------------
MIHOMO_VERSION="${MIHOMO_VERSION:-v1.19.21}"
# mihomo 架构后缀示例：amd64-v1 / amd64-v2 / amd64-v3
MIHOMO_ARCH="${MIHOMO_ARCH:-amd64-v1}"

# OpenClash 仓库的 ref（branch/commit/tag），默认用 core 分支
OPENCLASH_REF="${OPENCLASH_REF:-core}"
# OpenClash core 分支下的目录：dev / master 等（你想跟随哪条“通道”）
OPENCLASH_CHANNEL="${OPENCLASH_CHANNEL:-dev}"
# clash 核心架构后缀示例：amd64 / amd64-v1 / amd64-v2 / amd64-v3
# 兼容性优先建议使用 amd64-v1（避免 x86-64-v3 指令集不兼容）
CLASH_ARCH="${CLASH_ARCH:-amd64-v1}"

# Loyalsoldier 规则数据 release tag（建议固定）
RULES_TAG="${RULES_TAG:-202603192222}"

# ---------------------------
# 工具函数
# ---------------------------
has_cmd() { command -v "$1" >/dev/null 2>&1; }

download() {
  local url="$1"
  local out="$2"

  echo "[INFO] Download: ${url}"
  if has_cmd curl; then
    curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 0 "${url}" -o "${out}"
  elif has_cmd wget; then
    wget -O "${out}" "${url}"
  else
    echo "[ERROR] 需要 curl 或 wget 其中之一用于下载。" >&2
    exit 1
  fi
}

sha256_file() {
  local f="$1"
  if has_cmd sha256sum; then
    sha256sum "$f" | awk '{print $1}'
  elif has_cmd shasum; then
    shasum -a 256 "$f" | awk '{print $1}'
  else
    echo "N/A"
  fi
}

extract_tar_clash() {
  local tarball="$1"
  local dst="$2"
  local tmpdir="$3"

  mkdir -p "${tmpdir}"
  tar -xzf "${tarball}" -C "${tmpdir}"

  # 通常 tar 内部只有一个 clash 文件；这里做一下容错查找
  local bin=""
  if [ -f "${tmpdir}/clash" ]; then
    bin="${tmpdir}/clash"
  else
    bin="$(find "${tmpdir}" -maxdepth 2 -type f -name 'clash' 2>/dev/null | head -n 1 || true)"
  fi

  if [ -z "${bin}" ] || [ ! -f "${bin}" ]; then
    echo "[ERROR] 解压后未找到 clash 二进制（tar 结构可能变了）：${tarball}" >&2
    echo "[INFO] tar 内容预览：" >&2
    tar -tzf "${tarball}" | head -n 50 >&2 || true
    exit 1
  fi

  install -m 0755 "${bin}" "${dst}"
}

warn_if_v3() {
  local arch="$1"
  if [[ "${arch}" == *"v3"* ]]; then
    cat >&2 <<'EOF'
[WARN] 你选择了 v3 架构（x86-64-v3），部分机器会报：
       "This program can only be run on AMD64 processors with v3 microarchitecture support."
       如果遇到该报错，请把 CLASH_ARCH/MIHOMO_ARCH 改成 amd64-v1。
EOF
  fi
}

# ---------------------------
# 主流程
# ---------------------------
echo "[INFO] 开始更新 openclash-preset 资源..."
warn_if_v3 "${CLASH_ARCH}"
warn_if_v3 "${MIHOMO_ARCH}"

TMP="$(mktemp -d)"
cleanup() { rm -rf "${TMP}"; }
trap cleanup EXIT

# 1) mihomo -> core/clash_meta
MIHOMO_ASSET="mihomo-linux-${MIHOMO_ARCH}-${MIHOMO_VERSION}.gz"
MIHOMO_URL="https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/${MIHOMO_ASSET}"
download "${MIHOMO_URL}" "${TMP}/mihomo.gz"
gunzip -c "${TMP}/mihomo.gz" > "${CORE_DIR}/clash_meta"
chmod +x "${CORE_DIR}/clash_meta"

# 2) clash_tun -> core/clash_tun（OpenClash core 分支 smart 目录）
TUN_ASSET="clash-linux-${CLASH_ARCH}.tar.gz"
TUN_URL="https://raw.githubusercontent.com/vernesong/OpenClash/${OPENCLASH_REF}/${OPENCLASH_CHANNEL}/smart/${TUN_ASSET}"
download "${TUN_URL}" "${TMP}/clash_tun.tar.gz"
extract_tar_clash "${TMP}/clash_tun.tar.gz" "${CORE_DIR}/clash_tun" "${TMP}/tun"

# 3) clash -> core/clash（OpenClash core 分支 meta 目录）
CLASH_ASSET="clash-linux-${CLASH_ARCH}.tar.gz"
CLASH_URL="https://raw.githubusercontent.com/vernesong/OpenClash/${OPENCLASH_REF}/${OPENCLASH_CHANNEL}/meta/${CLASH_ASSET}"
download "${CLASH_URL}" "${TMP}/clash.tar.gz"
extract_tar_clash "${TMP}/clash.tar.gz" "${CORE_DIR}/clash" "${TMP}/clash"

# 4) Geo 数据（固定 tag）
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${RULES_TAG}/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${RULES_TAG}/geosite.dat"
download "${GEOIP_URL}" "${DATA_DIR}/GeoIP.dat"
download "${GEOSITE_URL}" "${DATA_DIR}/GeoSite.dat"

# 5) 生成版本记录（便于持续维护）
VERSIONS_FILE="${ROOT_DIR}/VERSIONS.md"
{
  echo "# OpenClash Preset Versions"
  echo
  echo "- Generated at: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo
  echo "## Sources (pinned by variables)"
  echo
  echo "- mihomo: MetaCubeX/mihomo ${MIHOMO_VERSION} (linux-${MIHOMO_ARCH})"
  echo "- OpenClash core: vernesong/OpenClash ref=${OPENCLASH_REF} channel=${OPENCLASH_CHANNEL} arch=${CLASH_ARCH}"
  echo "- rules-dat: Loyalsoldier/v2ray-rules-dat tag=${RULES_TAG}"
  echo
  echo "## Files"
  echo
  echo "| File | Size | SHA256 |"
  echo "|---|---:|---|"
  for f in "${CORE_DIR}/clash" "${CORE_DIR}/clash_meta" "${CORE_DIR}/clash_tun" "${DATA_DIR}/GeoIP.dat" "${DATA_DIR}/GeoSite.dat"; do
    sz="$(ls -lh "$f" | awk '{print $5}')"
    sha="$(sha256_file "$f")"
    echo "| $(basename "$f") | ${sz} | ${sha} |"
  done
} > "${VERSIONS_FILE}"

echo "[INFO] 完成。当前文件如下："
echo "=== core ==="
ls -lh "${CORE_DIR}"
echo "=== data ==="
ls -lh "${DATA_DIR}"
echo
echo "[INFO] 版本记录已写入: ${VERSIONS_FILE}"
