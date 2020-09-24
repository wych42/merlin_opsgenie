#!/bin/sh

source /koolshare/scripts/base.sh
eval `dbus export opsgenie_`
# for long message job remove
remove_cron_job(){
    echo 关闭自动发送状态消息...
    cru d opsgenie_check >/dev/null 2>&1
}

# for long message job creat
creat_cron_job(){
    echo 启动自动发送状态消息...
    if [[ "${opsgenie_status_check}" == "1" ]]; then
        cru a opsgenie_check ${opsgenie_check_time_min} ${opsgenie_check_time_hour}" * * * /koolshare/scripts/opsgenie_check_task.sh"
    elif [[ "${opsgenie_status_check}" == "2" ]]; then
        cru a opsgenie_check ${opsgenie_check_time_min} ${opsgenie_check_time_hour}" * * "${opsgenie_check_week}" /koolshare/scripts/opsgenie_check_task.sh"
    elif [[ "${opsgenie_status_check}" == "3" ]]; then
        cru a opsgenie_check ${opsgenie_check_time_min} ${opsgenie_check_time_hour} ${opsgenie_check_day}" * * /koolshare/scripts/opsgenie_check_task.sh"
    elif [[ "${opsgenie_status_check}" == "4" ]]; then
        if [[ "${opsgenie_check_inter_pre}" == "1" ]]; then
            cru a opsgenie_check "*/"${opsgenie_check_inter_min}" * * * * /koolshare/scripts/opsgenie_check_task.sh"
        elif [[ "${opsgenie_check_inter_pre}" == "2" ]]; then
            cru a opsgenie_check "0 */"${opsgenie_check_inter_hour}" * * * /koolshare/scripts/opsgenie_check_task.sh"
        elif [[ "${opsgenie_check_inter_pre}" == "3" ]]; then
            cru a opsgenie_check ${opsgenie_check_time_min} ${opsgenie_check_time_hour}" */"${opsgenie_check_inter_day} " * * /koolshare/scripts/opsgenie_check_task.sh"
        fi
    elif [[ "${opsgenie_status_check}" == "5" ]]; then
        check_custom_time=`dbus get opsgenie_check_custom | base64_decode`
        cru a opsgenie_check ${opsgenie_check_time_min} ${check_custom_time}" * * * /koolshare/scripts/opsgenie_check_task.sh"
    else
        remove_cron_job
    fi
}

creat_trigger_dhcp(){
    # rm -f /jffs/configs/dnsmasq.d/dhcp_trigger.conf
    sed -i '/opsgenie_dhcp_trigger/d' /jffs/configs/dnsmasq.d/dhcp_trigger.conf
    echo "dhcp-script=/koolshare/scripts/opsgenie_dhcp_trigger.sh" >> /jffs/configs/dnsmasq.d/dhcp_trigger.conf
    [ "${opsgenie_info_logger}" == "1" ] && logger "[软件中心] - [opsgenie]: 重启DNSMASQ！"
    #service restart_dnsmasq
    killall dnsmasq
    sleep 1
    dnsmasq --log-async
}

remove_trigger_dhcp(){
    # rm -f /jffs/configs/dnsmasq.d/dhcp_trigger.conf
    sed -i '/opsgenie_dhcp_trigger/d' /jffs/configs/dnsmasq.d/dhcp_trigger.conf
    [ "${opsgenie_info_logger}" == "1" ] && logger "[软件中心] - [opsgenie]: 重启DNSMASQ！"
    service restart_dnsmasq
}

creat_trigger_ifup(){
    rm -f /koolshare/init.d/S99opsgenie.sh
    if [[ "${opsgenie_trigger_ifup}" == "1" ]]; then
        ln -sf /koolshare/scripts/opsgenie_ifup_trigger.sh /koolshare/init.d/S99opsgenie.sh
    else
        rm -f /koolshare/init.d/S99opsgenie.sh
    fi
}

remove_trigger_ifup(){
    rm -f /koolshare/init.d/S99opsgenie.sh
}

onstart(){
    creat_cron_job
    creat_trigger_ifup
    if [ "${opsgenie_trigger_dhcp}" == "1" ]; then
        creat_trigger_dhcp
    else
        remove_trigger_dhcp
    fi
}
# used by httpdb
case $1 in
start)
    if [[ "${opsgenie_enable}" == "1" ]]; then
        logger "[软件中心]: 启动opsgenie！"
        onstart
    else
        logger "[软件中心]: opsgenie未设置启动，跳过！"
    fi
    ;;
stop)
    remove_trigger_dhcp
    remove_trigger_ifup
    remove_cron_job
    logger "[软件中心]: 关闭opsgenie！"
    ;;
*)
    if [[ "${opsgenie_enable}" == "1" ]]; then
        logger "[软件中心]: 启动opsgenie！"
        onstart
    else
        logger "[软件中心]: opsgenie未设置启动，跳过！"
    fi
    ;;
esac
