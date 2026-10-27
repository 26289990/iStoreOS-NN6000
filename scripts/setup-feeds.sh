#!/bin/sh

set -eu

if [ $# -ne 1 ]; then
	echo "usage: $0 <istoreos-dir>" >&2
	exit 1
fi

TREE=$1
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

cd "$TREE"

# ============================================================
# 1. 原有清理（与原始脚本一致）
# ============================================================
rm -rf feeds/luci/applications/luci-app-dockerman \
	feeds/luci/libs/luci-lib-docker \
	feeds/luci/applications/luci-app-ttyd \
	feeds/luci/applications/luci-app-hd-idle \
	feeds/luci/applications/luci-app-samba4 \
	feeds/luci/applications/luci-app-smartdns \
	feeds/luci/applications/luci-app-adguardhome

rm -rf feeds/packages/net/tailscale \
	feeds/packages/lang/golang/golang1.26 \
	feeds/packages/lang/golang/golang1.27

if [ -d package/lang/golang/golang1.27 ]; then
	mv package/lang/golang/golang1.27 feeds/packages/lang/golang/
fi

# ============================================================
# 2. 追加第三方 feeds（幂等）
# 注意：本仓库基于 iStoreOS 25.12，ImmortalWrt 必须用 openwrt-25.12
# 不引入 daede (kenzok8)，即不引入 dae / daed
# ============================================================
if ! grep -q 'src-git immortal_luci' feeds.conf.default 2>/dev/null; then
	cat >> feeds.conf.default << 'EOF'

# ---------- 第三方 feeds（由 setup-feeds.sh 自动追加） ----------
# ImmortalWrt luci（25.12）：passwall / openclash / 3cat / vsftpd / dufs 等
src-git immortal_luci https://github.com/immortalwrt/luci.git;openwrt-25.12

# ImmortalWrt packages（25.12）：passwall 依赖的 xray / sing-box 等
src-git immortal_packages https://github.com/immortalwrt/packages.git;openwrt-25.12

# wechatpush
src-git wechatpush https://github.com/tty228/luci-app-wechatpush.git;master
EOF
fi

# ============================================================
# 3. 更新 feeds
# 核心 feed 失败则退出；可选插件（wechatpush）失败只警告。
# ============================================================
echo "==> feeds update (核心) ..."
./scripts/feeds update immortal_luci immortal_packages

echo "==> feeds update wechatpush (可选) ..."
./scripts/feeds update wechatpush \
	|| echo "!! warning: wechatpush feed update failed, skipped" >&2

# ============================================================
# 3.1 在安装之前，从 ImmortalWrt 两个 feed 里剔除会和 iStoreOS 自带包冲突的包
#
# 原始脚本特意从 iStoreOS 自带 feed 里删掉了 dockerman / ttyd / hd-idle /
# samba4 / smartdns / adguardhome / tailscale，改用 iStoreOS 自己的版本。
# 现在加了 ImmortalWrt feed 并且 install -a，会把这些同名包又装回来，造成
# 重复定义。这里只删 ImmortalWrt feed 里的那份，iStoreOS 自带的（包括
# package/luci/smartdns 和 feeds/packages 里的 smartdns）一律保留。
#
# daed / dae：编译失败，不要。
# ============================================================
echo "==> prune conflicting packages from immortal feeds ..."
for f in feeds/immortal_luci feeds/immortal_packages; do
	[ -d "$f" ] || continue
	find "$f" -maxdepth 3 \( \
		-name luci-app-dockerman -o -name luci-lib-docker \
		-o -name luci-app-ttyd -o -name luci-app-hd-idle \
		-o -name luci-app-samba4 -o -name luci-app-adguardhome \
		-o -name luci-app-smartdns -o -name smartdns \
		-o -name tailscale \
		-o -name daed -o -name luci-app-daed \
		-o -name dae -o -name luci-app-dae \
	\) -prune -exec rm -rf {} +
done

# ============================================================
# 3.2 安装
# ============================================================
echo "==> feeds install immortal_luci ..."
./scripts/feeds install -a -p immortal_luci

echo "==> feeds install immortal_packages ..."
./scripts/feeds install -a -p immortal_packages

echo "==> feeds install wechatpush (可选) ..."
./scripts/feeds install -p wechatpush luci-app-wechatpush \
	|| echo "!! warning: luci-app-wechatpush install failed, skipped" >&2

# ============================================================
# 4. 应用仓库补丁（失败即退出，与原始脚本行为一致）
# ============================================================
for p in "$REPO_DIR"/patches/*.patch; do
	[ -f "$p" ] || continue
	echo "==> patch: $p"
	if ! patch -p1 -i "$p"; then
		echo "!! patch failed: $p" >&2
		exit 1
	fi
done

echo "==> setup-feeds.sh 完成"
