#!/bin/sh
eval `dbus export opsgenie_`
source /koolshare/scripts/base.sh
logger "[软件中心]: 正在卸载opsgenie..."
MODULE=opsgenie
cd /
sh /koolshare/scripts/opsgenie_config.sh stop >/dev/null 2>&1
rm -rf /koolshare/init.d/*opsgenie.sh >/dev/null 2>&1
rm -rf /koolshare/scripts/*opsgenie.sh >/dev/null 2>&1
rm -rf /koolshare/scripts/opsgenie* >/dev/null 2>&1
rm -rf /koolshare/opsgenie >/dev/null 2>&1
rm -rf /koolshare/res/icon-opsgenie.png >/dev/null 2>&1
rm -rf /koolshare/webs/Module_opsgenie.asp >/dev/null 2>&1
rm -rf /tmp/opsgenie* >/dev/null 2>&1

values=`dbus list opsgenie | cut -d "=" -f 1`
for value in $values
do
dbus remove $value 
done

cru d opsgenie_check >/dev/null 2>&1
logger "[软件中心]: 完成opsgenie卸载"
rm -f /koolshare/scripts/uninstall_opsgenie.sh