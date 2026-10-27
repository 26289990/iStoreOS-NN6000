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

echo "::group::Selected device symbols"
grep -E '^CONFIG_TARGET_(BOARD|SUBTARGET|PROFILE)|DEVICE_link_nn6000' .config || true
echo "::endgroup::"
echo "::group::ccache config"
grep -E '^CONFIG_(DEVEL|CCACHE)' .config || true
echo "::endgroup::"

FAIL=0

SELECTED=$(grep -o '^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_link_nn6000-[a-z0-9_-]*=y' .config | sed 's/.*DEVICE_//; s/=y$//')
if [ -z "$SELECTED" ]; then
	echo "::error::no link_nn6000 device was selected by defconfig"
	grep -o 'TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_[a-z0-9_.-]*' tmp/.config-target.in 2>/dev/null | sort -u || true
	FAIL=1
else
	for d in $SELECTED; do
		echo "::notice::device selected: $d"
	done
fi
if grep -q '^CONFIG_TARGET_MULTI_PROFILE=y' .config; then
	echo "::notice::multi-profile mode enabled"
else
	echo "::error::TARGET_MULTI_PROFILE is not set; cannot build multiple devices"
	FAIL=1
fi
grep -q '^CONFIG_TARGET_ROOTFS_INITRAMFS=y' .config \
	|| { echo "::error::initramfs image is disabled; TFTP first-install image will be missing"; FAIL=1; }

# ------------------------------------------------------------
# 可选插件（来自第三方 feed）：被 defconfig 丢掉只警告，不中断流程。
# 其余在 seed 里写了 =y 的包仍然是必需的，缺失则报错。
# 注意：名字两侧必须保留空格。
# ------------------------------------------------------------
SOFT=" luci-app-passwall luci-i18n-passwall-zh-cn luci-app-openclash luci-app-3cat luci-app-vsftpd luci-app-wechatpush luci-app-dufs "

HARD=$(sed -n 's/^CONFIG_PACKAGE_\([^=]*\)=y$/\1/p' \
	"$REPO_DIR/config/nn6000.seed" \
	"$REPO_DIR/config/devices/"*.seed)
MISSING=""
SOFT_MISSING=""
for p in $HARD; do
	if grep -q "^CONFIG_PACKAGE_${p}=y" .config; then
		echo "  ok      $p"
	else
		case "$SOFT" in
		*" $p "*)
			echo "  OPTIONAL-MISSING $p"
			SOFT_MISSING="$SOFT_MISSING $p"
			;;
		*)
			echo "  MISSING $p"
			MISSING="$MISSING $p"
			;;
		esac
	fi
done
if [ -n "$SOFT_MISSING" ]; then
	echo "::warning::Optional packages dropped by defconfig (build continues):$SOFT_MISSING"
fi
if [ -n "$MISSING" ]; then
	echo "::error::Required packages were dropped by defconfig:$MISSING"
	FAIL=1
fi

# ------------------------------------------------------------
# smartdns / daed 不应出现在最终配置里（仅提示，不中断）
# ------------------------------------------------------------
if grep -qE '^CONFIG_PACKAGE_(daed|luci-app-daed|dae)=y' .config; then
	echo "::warning::daed/dae is still selected in .config; it failed to build before"
	grep -E '^CONFIG_PACKAGE_(daed|luci-app-daed|dae)=y' .config || true
fi

exit $FAIL
