#!/bin/sh
source /koolshare/scripts/base.sh
eval $(dbus export opsgenie_)
if [ "${opsgenie_config_ntp}" == "" ]; then
    ntp_server="ntp1.aliyun.com"
else
    ntp_server=${opsgenie_config_ntp}
fi
ntpclient -h ${ntp_server} -i3 -l -s >/dev/null 2>&1
[ "${opsgenie_info_logger}" == "1" ] && logger "[opsgenie]: 网络重启触发消息推送！"

if [[ "${opsgenie_enable}" != "1" ]]; then
    [ "${opsgenie_info_logger}" == "1" ] && logger "[opsgenie]: 程序未开启，自动退出！"
    exit
fi
if [[ ${opsgenie_trigger_ifup} != "1" ]]; then
    exit
fi
opsgenie_ifup_text="/tmp/.opsgenie_ifup.md"
send_title=$(dbus get opsgenie_config_name | base64_decode) || "本次未获取到！"
router_uptime=$(cat /proc/uptime | awk '{print $1}' | awk '{print int($1/86400)"天 "int($1%86400/3600)"小时 "int(($1%3600)/60)"分钟 "int($1%60)"秒"}')
router_reboot_time=$(echo $(TZ=UTC-8 date "+%Y年%m月%d日 %H点%M分%S秒"))

echo "** 你的网络刚刚发生了重启，重启后WAN信息如下： **" >${opsgenie_ifup_text}
echo "---" >>${opsgenie_ifup_text}
echo "系统开机时间: ${router_uptime}" >>${opsgenie_ifup_text}
echo "网络重启时间: ${router_reboot_time}" >>${opsgenie_ifup_text}
echo "---" >>${opsgenie_ifup_text}
router_wan0_proto=$(nvram get wan0_proto)
router_wan0_ifname=$(nvram get wan0_ifname)
router_wan0_gw=$(nvram get wan0_gw_ifname)
router_wan0_ip4=$(curl -4 --interface ${router_wan0_gw} -s https://api.ip.sb/ip 2>&1)
router_wan0_ip6=$(curl -6 --interface ${router_wan0_gw} -s https://api.ip.sb/ip 2>&1)
router_wan0_dns1=$(nvram get wan0_dns | awk '{print $1}')
router_wan0_dns2=$(nvram get wan0_dns | awk '{print $2}')
router_wan0_ip=$(nvram get wan0_ipaddr)
router_wan0_rx=$(ifconfig ${router_wan0_ifname} | grep 'RX bytes' | cut -d\( -f2 | cut -d\) -f1)
router_wan0_tx=$(ifconfig ${router_wan0_ifname} | grep 'TX bytes' | cut -d\( -f3 | cut -d\) -f1)

echo "**网络状态信息:**" >>${opsgenie_ifup_text}
echo "**WAN0状态信息:**" >>${opsgenie_ifup_text}
echo "联机类型: ${router_wan0_proto}" >>${opsgenie_ifup_text}
echo "公网IPv4地址: ${router_wan0_ip4}" >>${opsgenie_ifup_text}
echo "公网IPv6地址: ${router_wan0_ip6}" >>${opsgenie_ifup_text}
echo "WAN口IPv4地址: ${router_wan0_ip}" >>${opsgenie_ifup_text}
echo "WAN口DNS地址: ${router_wan0_dns1} ${router_wan0_dns2}" >>${opsgenie_ifup_text}
echo "WAN口接收流量: ${router_wan0_rx}" >>${opsgenie_ifup_text}
echo "WAN口发送流量: ${router_wan0_tx}" >>${opsgenie_ifup_text}
echo "---" >>${opsgenie_ifup_text}
router_wan1_ifname=$(nvram get wan1_ifname)
router_wan1_gw=$(nvram get wan1_gw_ifname)
if [ -n "${router_wan1_ifname}" ] && [ -n "${router_wan1_gw}" ]; then
    router_wan1_proto=$(nvram get wan1_proto)
    router_wan1_ip4=$(curl -4 --interface ${router_wan1_gw} -s https://api.ip.sb/ip 2>&1)
    router_wan1_ip6=$(curl -6 --interface ${router_wan1_gw} -s https://api.ip.sb/ip 2>&1)
    router_wan1_dns1=$(nvram get wan1_dns | awk '{print $1}')
    router_wan1_dns2=$(nvram get wan1_dns | awk '{print $2}')
    router_wan1_ip=$(nvram get wan1_ipaddr)
    router_wan1_rx=$(ifconfig ${router_wan1_ifname} | grep 'RX bytes' | cut -d\( -f2 | cut -d\) -f1)
    router_wan1_tx=$(ifconfig ${router_wan1_ifname} | grep 'TX bytes' | cut -d\( -f3 | cut -d\) -f1)
    echo "**WAN1状态信息:**" >>${opsgenie_ifup_text}
    echo "联机类型: ${router_wan1_proto}" >>${opsgenie_ifup_text}
    echo "公网IPv4地址: ${router_wan1_ip4}" >>${opsgenie_ifup_text}
    echo "公网IPv6地址: ${router_wan1_ip6}" >>${opsgenie_ifup_text}
    echo "WAN口IPv4地址: ${router_wan1_ip}" >>${opsgenie_ifup_text}
    echo "WAN口DNS地址: ${router_wan1_dns1} ${router_wan1_dns2}" >>${opsgenie_ifup_text}
    echo "WAN口接收流量: ${router_wan1_rx}" >>${opsgenie_ifup_text}
    echo "WAN口发送流量: ${router_wan1_tx}" >>${opsgenie_ifup_text}
    echo "---" >>${opsgenie_ifup_text}
fi
opsgenie_send_title="${send_title} 路由器网络重启通知："
opsgenie_send_content=$(cat ${opsgenie_ifup_text} | sed 's/$/\\n/' | tr -d '\n')
sckey_nu=$(dbus list opsgenie_config_sckey | sort -n -t "_" -k 4 | cut -d "=" -f 1 | cut -d "_" -f 4)
for nu in ${sckey_nu}; do
    opsgenie_config_sckey=$(dbus get opsgenie_config_sckey_${nu})
    result=$(curl -X POST https://api.opsgenie.com/v2/alerts \
        -H "Content-Type: application/json" \
        -H "Authorization: GenieKey ${opsgenie_config_sckey}" \
        -d "{\"message\": \"${opsgenie_send_title}\", \"note\": \"${opsgenie_send_content}\", \"tags\": [\"设备重启\", \"${opsgenie_config_name}\"], \"priority\":\"P3\"}")
    if [[ -n "$(echo $result | grep 'Request will be processed')" ]]; then
        [ "${opsgenie_info_logger}" == "1" ] && logger "[opsgenie]: 网络重启信息推送到 SCKEY No.${nu} 成功！！"
    else
        [ "${opsgenie_info_logger}" == "1" ] && logger "[opsgenie]: 网络重启信息推送到 SCKEY No.${nu} 失败，请检查网络及配置！"
    fi
done
sleep 2
rm -rf ${opsgenie_ifup_text}
if [[ "${opsgenie_trigger_ifup_sendinfo}" == "1" ]]; then
    sh /koolshare/scripts/opsgenie_check_task.sh
fi
