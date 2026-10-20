# NN6000 分区说明

| 文件 | 适用 eMMC | `rootfs_data` |
| --- | --- | --- |
| [`NN6000V2_2GUBOOT.bin`](https://raw.githubusercontent.com/wzdddyy/iStoreOS-NN6000/main/partition/NN6000V2_2GUBOOT.bin) | 4 GB eMMC | 2 GiB |
| [`NN6000V2_4GUBOOT.bin`](https://raw.githubusercontent.com/wzdddyy/iStoreOS-NN6000/main/partition/NN6000V2_4GUBOOT.bin) | 8 GB eMMC 及以上 | 4 GiB |

GPT 条目数 24（23 个已用，第 24 个为空槽，可直接新建分区）

MAC / UBOOT 修改工具（Windows）：[`M+U修改工具 v1.0.0.exe`](https://raw.githubusercontent.com/wzdddyy/iStoreOS-NN6000/main/partition/M%2BU%E4%BF%AE%E6%94%B9%E5%B7%A5%E5%85%B7%20v1.0.0.exe)

注意：使用此分区镜像，请自行修改MAC地址

## 自动分配剩余空间

下载：[`userdata-autosize`](https://raw.githubusercontent.com/wzdddyy/iStoreOS-NN6000/main/partition/userdata-autosize)

> GitHub 对文本文件默认打开显示内容而不是下载；要保存成文件，右键链接选「将链接另存为」，保存类型选「所有文件」。

自动检测最大空闲区，把 GPT 扩到磁盘末尾，新建 `UserData` 分区、格式化并挂载：


### 用法

放入 /tmp

chmod +x /tmp/userdata-autosize

sh /tmp/userdata-autosize


## 分区表

| # | 分区名称 | 起始 LBA | 结束 LBA | 大小 |
| --- | --- | --- | --- | --- |
| 1 | `0:SBL1` | 34 | 1569 | 768 KiB |
| 2 | `0:BOOTCONFIG` | 1570 | 2081 | 256 KiB |
| 3 | `0:BOOTCONFIG1` | 2082 | 2593 | 256 KiB |
| 4 | `0:QSEE` | 2594 | 6177 | 1792 KiB |
| 5 | `0:QSEE_1` | 6178 | 9761 | 1792 KiB |
| 6 | `0:DEVCFG` | 9762 | 10273 | 256 KiB |
| 7 | `0:DEVCFG_1` | 10274 | 10785 | 256 KiB |
| 8 | `0:RPM` | 10786 | 11297 | 256 KiB |
| 9 | `0:RPM_1` | 11298 | 11809 | 256 KiB |
| 10 | `0:CDT` | 11810 | 12321 | 256 KiB |
| 11 | `0:CDT_1` | 12322 | 12833 | 256 KiB |
| 12 | `0:APPSBLENV` | 12834 | 13345 | 256 KiB |
| 13 | `0:APPSBL` | 13346 | 14625 | 640 KiB |
| 14 | `0:APPSBL_1` | 14626 | 15905 | 640 KiB |
| 15 | `0:ART` | 15906 | 16417 | 256 KiB |
| 16 | `0:HLOS` | 16418 | 81953 | 32 MiB |
| 17 | `0:HLOS_1` | 81954 | 147489 | 32 MiB |
| 18 | `rootfs` | 147490 | 1196065 | 512 MiB |
| 19 | `0:WIFIFW` | 1196066 | 1204257 | 4 MiB |
| 20 | `rootfs_1` | 1204258 | 2252833 | 512 MiB |
| 21 | `0:WIFIFW_1` | 2252834 | 2261025 | 4 MiB |
| 22 | `rootfs_data` | 2263040 | 6457343 | 2 GiB |
| 23 | `0:ETHPHYFW` | 6457344 | 6458367 | 512 KiB |

## 分区作用

| 分区 | 作用 |
| --- | --- |
| `0:SBL1` | 二级引导程序，初始化 DDR 后加载 U-Boot |
| `0:BOOTCONFIG` / `0:BOOTCONFIG1` | U-Boot 启动槽位标志（偏移 148 决定读 `0:HLOS` 还是 `0:HLOS_1`），两份互为备份 |
| `0:QSEE` / `0:QSEE_1` | Qualcomm 安全执行环境固件 |
| `0:DEVCFG` / `0:DEVCFG_1` | 设备配置 |
| `0:RPM` / `0:RPM_1` | 资源与功耗管理固件 |
| `0:CDT` / `0:CDT_1` | 板级配置 |
| `0:APPSBLENV` | U-Boot 环境变量（`bootargs`、`bootcmd`） |
| `0:APPSBL` / `0:APPSBL_1` | U-Boot 本体，A/B 双份 |
| `0:ART` | MAC 地址与 WiFi 校准数据，每台机器唯一 |
| `0:HLOS` / `0:HLOS_1` | Linux 内核，A/B 双槽 |
| `rootfs` / `rootfs_1` | squashfs 只读根文件系统（固件本体），A/B 双槽 |
| `0:WIFIFW` / `0:WIFIFW_1` | WiFi 固件分区 |
| `rootfs_data` | overlay 可写层，存用户配置、插件、数据 |
| `0:ETHPHYFW` | 以太网 PHY 固件分区 |

> 4G 版仅第 22、23 项不同：`rootfs_data` 为 2263040–10651647（4 GiB），`0:ETHPHYFW` 为 10651648–10652671。

## 调整说明

- `0:HLOS` / `0:HLOS_1` 内核分区：统一 32 MiB
- `rootfs` / `rootfs_1` 固件分区：统一 512 MiB
- 两版均已内置chenxin527 26.08.16版uBootKit，刷入分区镜像即可直接进入UBOOT
- `rootfs_data` overlay 分区：2G 版 2 GiB，4G 版 4 GiB
- 没有 `rootfs_data` 分区时，用户数据自动挂载到 `rootfs` 的剩余空间
- 支持此设备的固件源码都可以使用本分区表；其中 OpenWrt / immortalwrt 原生支持，iStoreOS 需配套 `istoreos-boot.sh` 补丁（优先使用 `rootfs_data`）。
- eMMC 剩余空间可自行分配，或使用 `userdata-autosize` 自动分配。