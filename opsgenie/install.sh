#!/bin/sh
source /koolshare/scripts/base.sh
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'
DIR=$(
	cd $(dirname $0)
	pwd
)

# 判断路由架构和平台
case $(uname -m) in
armv7l)
	if [ "$(uname -o | grep Merlin)" ] && [ -d "/koolshare" ] && [ -n "$(nvram get buildno | grep 384)" ]; then
		echo_date 固件平台【koolshare merlin armv7l 384】符合安装要求，开始安装插件！
	else
		echo_date 本插件适用于【koolshare merlin armv7l 384】固件平台，你的固件平台不能安装！！！
		echo_date 退出安装！
		rm -rf /tmp/opsgenie* >/dev/null 2>&1
		exit 1
	fi
	;;
*)
	echo_date 本插件适用于【koolshare merlin armv7l 384】固件平台，你的平台：$(uname -m)不能安装！！！
	echo_date 退出安装！
	rm -rf /tmp/opsgenie* >/dev/null 2>&1
	exit 1
	;;
esac

# stop opsgenie first
enable=$(dbus get opsgenie_enable)
if [ "$enable" == "1" ] && [ -f "/koolshare/scripts/opsgenie_config.sh" ]; then
	/koolshare/scripts/opsgenie_config.sh stop >/dev/null 2>&1
fi

# 安装
echo_date "开始安装opsgenie通知..."
cd /tmp
if [[ ! -x /koolshare/bin/jq ]]; then
	cp -f /tmp/opsgenie/bin/jq /koolshare/bin/jq
	chmod +x /koolshare/bin/jq
fi
rm -rf /koolshare/init.d/*opsgenie.sh
rm -rf /koolshare/opsgenie >/dev/null 2>&1
rm -rf /koolshare/scripts/opsgenie_*
cp -rf /tmp/opsgenie/res/icon-opsgenie.png /koolshare/res/
cp -rf /tmp/opsgenie/scripts/* /koolshare/scripts/
cp -rf /tmp/opsgenie/webs/Module_opsgenie.asp /koolshare/webs/
chmod +x /koolshare/scripts/*
# 安装重启自动启动功能
[ ! -L "/koolshare/init.d/S99CRUopsgenie.sh" ] && ln -sf /koolshare/scripts/opsgenie_config.sh /koolshare/init.d/S99CRUopsgenie.sh

# 设置默认值
router_name=$(echo $(nvram get model) | base64_encode)
router_name_get=$(dbus get opsgenie_config_name)
if [ -z "${router_name_get}" ]; then
	dbus set opsgenie_config_name="${router_name}"
fi
router_ntp_get=$(dbus get opsgenie_config_ntp)
if [ -z "${router_ntp_get}" ]; then
	dbus set opsgenie_config_ntp="ntp1.aliyun.com"
fi
bwlist_en_get=$(dbus get opsgenie_dhcp_bwlist_en)
if [ -z "${bwlist_en_get}" ]; then
	dbus set opsgenie_dhcp_bwlist_en="1"
fi
_sckey=$(dbus get opsgenie_config_sckey)
if [ -n "${_sckey}" ]; then
	dbus set opsgenie_config_sckey_1=$(dbus get opsgenie_config_sckey)
	dbus remove opsgenie_config_sckey
fi
[ -z "$(dbus get opsgenie_info_lan_macoff)" ] && dbus set opsgenie_info_lan_macoff="1"
[ -z "$(dbus get opsgenie_info_dhcp_macoff)" ] && dbus set opsgenie_info_dhcp_macoff="1"
[ -z "$(dbus get opsgenie_trigger_dhcp_macoff)" ] && dbus set opsgenie_trigger_dhcp_macoff="1"

# 离线安装用
dbus set opsgenie_version="$(cat $DIR/version)"
dbus set softcenter_module_opsgenie_version="$(cat $DIR/version)"
dbus set softcenter_module_opsgenie_install="1"
dbus set softcenter_module_opsgenie_name="opsgenie"
dbus set softcenter_module_opsgenie_title="opsgenie推送"
dbus set softcenter_module_opsgenie_description="从路由器推送状态及通知的工具。"

# re-enable opsgenie
if [ "$enable" == "1" ] && [ -f "/koolshare/scripts/opsgenie_config.sh" ]; then
	/koolshare/scripts/opsgenie_config.sh start >/dev/null 2>&1
fi

# 完成
rm -rf /tmp/opsgenie* >/dev/null 2>&1
echo_date "opsgenie通知插件安装完毕！"
exit 0
