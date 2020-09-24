#!/bin/sh

sh /koolshare/scripts/opsgenie_config.sh stop >/dev/null 2>&1
rm -rf /koolshare/init.d/*opsgenie.sh >/dev/null 2>&1
rm -rf /koolshare/scripts/*opsgenie.sh >/dev/null 2>&1
rm -rf /koolshare/scripts/opsgenie* >/dev/null 2>&1
rm -rf /koolshare/opsgenie >/dev/null 2>&1
rm -rf /koolshare/res/icon-opsgenie.png >/dev/null 2>&1
rm -rf /koolshare/webs/Module_opsgenie.asp >/dev/null 2>&1