#!/bin/bash
set -euo pipefail

#=================================================
# File name: preset-clash-core.sh
# System Required: Linux / bash
# Description: 预置本地 OpenClash 核心与规则数据，不再依赖在线下载
# Usage: 在仓库根目录执行，要求 openclash-preset/ 下已放好最终文件
#=================================================

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

SRC_BASE="${SCRIPT_DIR}/openclash-preset"
SRC_CORE="${SRC_BASE}/core"
SRC_DATA="${SRC_BASE}/data"

OPENCLASH_ROOT="feeds/luci/applications/luci-app-openclash/root/etc/openclash"
CORE_DST="${OPENCLASH_ROOT}/core"
DATA_DST="${OPENCLASH_ROOT}"

REQUIRED_CORE_FILES=(
  "clash"
  "clash_meta"
  "clash_tun"
)

REQUIRED_DATA_FILES=(
  "GeoIP.dat"
  "GeoSite.dat"
)

check_file() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "[ERROR] 缺少文件: $file" >&2
    exit 1
  fi
}

echo "[INFO] 开始预置 OpenClash 本地核心与规则文件..."

echo "[INFO] 检查源文件完整性..."
for f in "${REQUIRED_CORE_FILES[@]}"; do
  check_file "${SRC_CORE}/${f}"
done
for f in "${REQUIRED_DATA_FILES[@]}"; do
  check_file "${SRC_DATA}/${f}"
done

mkdir -p "${CORE_DST}" "${DATA_DST}"

echo "[INFO] 复制核心文件到 ${CORE_DST}"
install -m 0755 "${SRC_CORE}/clash"      "${CORE_DST}/clash"
install -m 0755 "${SRC_CORE}/clash_meta" "${CORE_DST}/clash_meta"
install -m 0755 "${SRC_CORE}/clash_tun"  "${CORE_DST}/clash_tun"

echo "[INFO] 复制规则数据到 ${DATA_DST}"
install -m 0644 "${SRC_DATA}/GeoIP.dat"   "${DATA_DST}/GeoIP.dat"
install -m 0644 "${SRC_DATA}/GeoSite.dat" "${DATA_DST}/GeoSite.dat"

echo "[INFO] 校验目标文件..."
ls -lh "${CORE_DST}" "${DATA_DST}"

echo "[INFO] OpenClash 本地核心预置完成。"
