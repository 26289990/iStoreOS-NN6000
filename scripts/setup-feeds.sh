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
# 1. 原有清理
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
# 已移除 daede (kenzok8) feed，不再引入 dae / daed
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
# 3. 更新并安装
# 核心 feed（immortal_luci / immortal_packages）失败则直接退出；
# 可选插件（wechatpush）失败只警告，少装一个插件不影响编译。
# ============================================================
echo "==> feeds update (核心) ..."
./scripts/feeds update immortal_luci immortal_packages

echo "==> feeds update wechatpush (可选) ..."
./scripts/feeds update wechatpush \
	|| echo "!! warning: wechatpush feed update failed, skipped" >&2

echo "==> feeds install immortal_luci ..."
./scripts/feeds install -a -p immortal_luci

echo "==> feeds install immortal_packages ..."
./scripts/feeds install -a -p immortal_packages

echo "==> feeds install wechatpush (可选) ..."
./scripts/feeds install -p wechatpush luci-app-wechatpush \
	|| echo "!! warning: luci-app-wechatpush install failed, skipped" >&2

# ============================================================
# 3.1 移除编译会失败的 smartdns / daed / dae 相关包
# 同时清理 feeds 源目录和 package/feeds 下的软链接，避免被依赖重新拉入
# ============================================================
echo "==> remove smartdns / daed / dae packages ..."
for d in feeds package/feeds; do
	[ -d "$d" ] || continue
	find "$d" -maxdepth 4 \( \
		-name smartdns -o -name luci-app-smartdns -o -name luci-i18n-smartdns-zh-cn \
		-o -name daed -o -name luci-app-daed \
		-o -name dae -o -name luci-app-dae \
		-o -name luci-app-daede \
	\) -prune -exec rm -rf {} +
done

# iStoreOS 源码树自带的 smartdns（日志中失败的 package/luci/smartdns）
rm -rf package/luci/smartdns package/luci/luci-app-smartdns

# ============================================================
# 4. 应用仓库补丁（失败即退出，避免后面出现莫名其妙的编译错误）
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
