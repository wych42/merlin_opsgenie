#!/bin/sh
source /koolshare/scripts/base.sh
eval `dbus export opsgenie`
/koolshare/scripts/opsgenie_check.sh task
