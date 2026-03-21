# openclash-preset

这个目录用于 **长期维护仓库时，固定预置 OpenClash 核心和规则数据**，让固件产物更稳定、更可复现（刷机后 OpenClash 可直接用，不依赖首次联网下载核心）。

## 目录结构

```text
openclash-preset/
├── core/
│   ├── clash
│   ├── clash_meta
│   └── clash_tun
├── data/
│   ├── GeoIP.dat
│   └── GeoSite.dat
└── VERSIONS.md
```

## 一键更新（推荐）

已提供脚本：`openclash-preset/update-preset.sh`  
它会自动完成：**创建目录 → 下载 → 解压 → 改名 → 写入校验记录**。

```bash
cd openclash-preset
bash update-preset.sh
# 或
chmod +x update-preset.sh && ./update-preset.sh
```

### 可配置参数（用于持续维护更新）

脚本默认以 **兼容性优先** 的方式固定为 `amd64-v1`，并把上游版本写入 `VERSIONS.md`。

你可以用环境变量覆盖默认值：

```bash
# 例：切换 mihomo 版本 & 规则 tag
MIHOMO_VERSION=v1.19.21 MIHOMO_ARCH=amd64-v1 RULES_TAG=202603192222 bash update-preset.sh

# 例：切换 OpenClash core 的“通道”（core 分支下的目录：dev/master）与架构
OPENCLASH_REF=core OPENCLASH_CHANNEL=dev CLASH_ARCH=amd64-v1 bash update-preset.sh
```

> 提醒：如果你选了 `*v3*`，在部分机器上会出现  
> `This program can only be run on AMD64 processors with v3 microarchitecture support.`  
> 遇到该报错请改回 `amd64-v1`。

## 关键修复点（为什么你会 404）

你之前用的这些地址已经不再存在/已迁移：

- `https://raw.githubusercontent.com/vernesong/OpenClash/core/premium/clash-linux-amd64-v1.gz` → 现在同类文件在 `core` 分支的 `dev/smart/`，并且是 `.tar.gz` 形式（例如 `clash-linux-amd64-v1.tar.gz`）。  
- `https://raw.githubusercontent.com/vernesong/OpenClash/core/dev/clash-linux-amd64.tar.gz` → 现在同类文件在 `core` 分支的 `dev/meta/`，并且同样是 `.tar.gz` 形式。

脚本已按当前目录结构修正为：

- `.../OpenClash/core/dev/smart/clash-linux-<arch>.tar.gz`
- `.../OpenClash/core/dev/meta/clash-linux-<arch>.tar.gz`

（你可以在 OpenClash 的 `core` 分支目录里看到 `smart/`、`meta/` 下的文件列表。）

## 与构建脚本的关系

仓库根目录下的 `preset-clash-core.sh` 会直接读取：

- `openclash-preset/core/clash`
- `openclash-preset/core/clash_meta`
- `openclash-preset/core/clash_tun`
- `openclash-preset/data/GeoIP.dat`
- `openclash-preset/data/GeoSite.dat`

然后复制到：

```text
feeds/luci/applications/luci-app-openclash/root/etc/openclash/
```

所以你日常维护只需要：

1. 跑 `update-preset.sh` 更新文件
2. 提交 `openclash-preset/` 的变更
3. 编译固件

## 维护建议

- 不频繁追新；只有确认兼容/修复/安全更新时再升级
- 每次升级后请在目标机器上验证核心能运行
- `VERSIONS.md` 会记录 sha256，方便回滚与排查
