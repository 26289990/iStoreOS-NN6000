#!/bin/sh

set -eu

if [ $# -ne 1 ]; then
	echo "usage: $0 <istoreos-dir>" >&2
	exit 1
fi

TREE=$1
cd "$TREE"

OUT=bin/targets/qualcommax/ipq60xx
echo "::group::Artifact listing"
ls -lh "$OUT"
echo "::endgroup::"

find_image() {
	# $1 = device, $2 = kind (factory|sysupgrade|initramfs)
	local dev="$1" kind="$2" pat
	case "$kind" in
		initramfs) pat="-${dev}-initramfs[^/]*$" ;;
		*)         pat="-${dev}-squashfs-${kind}\.bin$" ;;
	esac
	ls "$OUT"/* 2>/dev/null | grep -E -- "$pat" | head -1
}

FAIL=0

SELECTED=$(grep -o '^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_link_nn6000-[a-z0-9_-]*=y' .config | sed 's/.*DEVICE_//; s/=y$//')
if [ -z "$SELECTED" ]; then
	echo "::error::no link_nn6000 device selected in .config"
	exit 1
fi

for DEV in $SELECTED; do
	echo "::group::Verifying $DEV"
	for kind in factory sysupgrade initramfs; do
		IMG=$(find_image "$DEV" "$kind")
		if [ -n "$IMG" ] && [ -f "$IMG" ]; then
			echo "  ok      $DEV $kind -> $(basename "$IMG")"
		else
			echo "::error::missing $kind image for $DEV"
			FAIL=1
		fi
	done
	echo "::endgroup::"
done

exit $FAIL
