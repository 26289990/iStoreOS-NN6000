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

# daede（kenzok8，已集成 dae + daed）
src-git daede https://github.com/kenzok8/openwrt-daede.git;main
EOF
fi

# ============================================================
# 3. 更新并安装
# ============================================================
echo "==> feeds update (第三方) ..."
./scripts/feeds update immortal_luci immortal_packages wechatpush daede

echo "==> feeds install immortal_luci ..."
./scripts/feeds install -a -p immortal_luci

echo "==> feeds install immortal_packages ..."
./scripts/feeds install -a -p immortal_packages

echo "==> feeds install wechatpush ..."
./scripts/feeds install luci-app-wechatpush -p wechatpush

echo "==> feeds install daede (kenzok8) ..."
./scripts/feeds install luci-app-daede -p daede || true
./scripts/feeds install dae daed -p daede || true

# ============================================================
# 4. 应用仓库补丁
# ============================================================
for p in "$REPO_DIR"/patches/*.patch; do
	[ -f "$p" ] || continue
	echo "==> patch: $p"
	patch -p1 -i "$p" || true
done

echo "==> setup-feeds.sh 完成"
