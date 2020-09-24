#!/bin/sh

set -x
source /koolshare/scripts/base.sh
eval $(dbus export opsgenie_)
if [ "${opsgenie_config_ntp}" == "" ]; then
    ntp_server="ntp1.aliyun.com"
else
    ntp_server=${opsgenie_config_ntp}
fi
ntpclient -h ${ntp_server} -i3 -l -s >/dev/null 2>&1
dnsmasq_leases_file="/var/lib/misc/dnsmasq.leases"
opsgenie_lease_text="/tmp/.opsgenie_dhcp.md"
dhcp_lease_time=$(nvram get dhcp_lease)
client_join_time=$(TZ=UTC-8 date "+%Y-%m-%d %H:%M:%S")
client_lease_info=$(cat ${dnsmasq_leases_file} | sort -rn | head -n1)
client_lease_time=$(echo ${client_lease_info} | awk '{print $1}')
time_diff=$(expr ${dhcp_lease_time} - ${client_lease_time})

if [ "${time_diff}" -gt "30" ]; then
    #logger "[opsgenie]: 未发现新上线设备，推送任务通道静默！"
    exit
fi
[ "${opsgenie_info_logger}" == "1" ] && logger "[opsgenie]: 启动设备上线通知任务！"
dnsmasq_pid=$(ps | grep "dnsmasq" | grep "nobody" | grep -v grep | awk '{print $1}')
kill -12 ${dnsmasq_pid}
sleep 1
if [[ "${opsgenie_enable}" != "1" ]]; then
    [ "${opsgenie_info_logger}" == "1" ] && logger "[opsgenie]: 程序未开启，自动退出！"
    exit
fi
if [[ "${opsgenie_trigger_dhcp}" != "1" ]]; then
    exit
fi
if [[ "${opsgenie_silent_time}" == "1" ]]; then
    router_now_hour=$(TZ=UTC-8 date "+%H")
    if [[ "${router_now_hour}" -ge "${opsgenie_silent_time_start_hour}" ]] || [[ "${router_now_hour}" -lt "${opsgenie_silent_time_end_hour}" ]]; then
        [ "${opsgenie_info_logger}" == "1" ] && logger "[opsgenie]: 推送时间在消息免打扰时间内，推送任务通道静默！"
        exit
    fi
fi
send_title=$(dbus get opsgenie_config_name | base64_decode) || "本次未获取到！"
client_join_time_format=$(TZ=UTC-8 date -d "${client_join_time}" "+%Y年%m月%d日 %H点%M分%S秒")
client_lease_epired_time=$(TZ=UTC-8 date -d @$(expr $(TZ=UTC-8 date -d "${client_join_time}" +%s) + ${dhcp_lease_time}) "+%Y-%m-%d %H:%M:%S")
client_lease_epired_time_format=$(TZ=UTC-8 date -d "${client_lease_epired_time}" "+%Y年%m月%d日 %H点%M分%S秒")
total_lease_client=$(cat ${dnsmasq_leases_file} | wc -l)
client_lease_mac=$(echo ${client_lease_info} | awk '{print $2}' | tr '[A-Z]' '[a-z]')
client_lease_ip=$(echo ${client_lease_info} | awk '{print $3}')
client_dhcp_white_name=$(echo $(dbus get opsgenie_trigger_dhcp_white | base64_decode | grep -i "${client_lease_mac}") | cut -d# -f2)
if [[ "${client_dhcp_white_name}" == "" ]]; then
    client_custom_clientlist=$(echo $(nvram get custom_clientlist | sed 's/</\n/g' | awk -F ">" '{print $1""$2}' | sed '/^*$/d' | grep -i "${client_lease_mac}"))
    if [[ "${client_custom_clientlist}" == "" ]]; then
        client_lease_name=$(echo ${client_lease_info} | awk '{print $4}')
    else
        client_lease_name=$(echo ${client_custom_clientlist} | awk -F "" '{print $1}')
    fi
else
    client_lease_name=$(echo ${client_dhcp_white_name})
fi
if [[ "${opsgenie_dhcp_bwlist_en}" == "1" ]]; then
    if [[ "${opsgenie_dhcp_white_en}" == "1" ]]; then
        trigger_dhcp_white_diff=$(echo $(dbus get opsgenie_trigger_dhcp_white | base64_decode | grep -i "${client_lease_mac}"))
        if [[ "${trigger_dhcp_white_diff}" != "" ]]; then
            [ "${opsgenie_info_logger}" == "1" ] && logger "[opsgenie]: 新登录设备在设备上线提醒白名单列表内，推送任务通道静默！"
            exit
        fi
    fi
    if [[ "${opsgenie_dhcp_black_en}" == "1" ]]; then
        trigger_dhcp_black_diff=$(echo $(dbus get opsgenie_trigger_dhcp_white | base64_decode | grep -i "${client_lease_mac}"))
        if [[ "${trigger_dhcp_black_diff}" == "" ]]; then
            [ "${opsgenie_info_logger}" == "1" ] && logger "[opsgenie]: 新登录设备不在设备上线提醒黑名单列表内，推送任务通道静默！"
            exit
        fi
    fi
fi
get_lease_send_mac=$(echo $(dbus get opsgenie_lease_send_mac) | tr '[A-Z]' '[a-z]')
get_lease_send_time=$(dbus get opsgenie_lease_send_time)
if [[ "${get_lease_send_mac}" == "${client_lease_mac}" ]]; then
    join_time_format=$(TZ=UTC-8 date -d "${client_join_time}" +%s)
    join_time_diff=$(expr ${join_time_format} - ${get_lease_send_time})
    if [ "${join_time_diff}" -lt "600" ]; then
        [ "${opsgenie_info_logger}" == "1" ] && logger "[opsgenie]: 重复上线，推送任务通道静默！"
        exit
    fi
fi

dbus set opsgenie_lease_send_mac="${client_lease_mac}"
dbus set opsgenie_lease_send_time="$(TZ=UTC-8 date -d "${client_join_time}" +%s)"
echo "** 刚刚有新的客户端加入了你的网络，信息如下： **" >${opsgenie_lease_text}
echo "---" >>${opsgenie_lease_text}
echo "客户端名: ${client_lease_name}" >>${opsgenie_lease_text}
echo "客户端IP: ${client_lease_ip}" >>${opsgenie_lease_text}
echo "客户端MAC: ${client_lease_mac}" >>${opsgenie_lease_text}
echo "客户端上线时间: ${client_join_time_format}" >>${opsgenie_lease_text}
echo "租约过期的时间: ${client_lease_epired_time_format}" >>${opsgenie_lease_text}
echo "---" >>${opsgenie_lease_text}
if [[ ${opsgenie_trigger_dhcp_leases} == "1" ]]; then
    echo "现在租约期内的客户端共有 ${total_lease_client} 个,情况如下：" >>${opsgenie_lease_text}
    if [ "$opsgenie_trigger_dhcp_macoff" == "1" ]; then
        total_lease_info_title="|IP|客户端名称|"
        total_lease_info_tab="|:-|:-|"
    else
        total_lease_info_title="|IP|MAC|客户端名称|"
        total_lease_info_tab="|:-|:-|:-|"
    fi
    echo "${total_lease_info_title}" >>${opsgenie_lease_text}
    echo "${total_lease_info_tab}" >>${opsgenie_lease_text}
    dnsmasq_leases_list=$(cat ${dnsmasq_leases_file} | sort -t "." -k3n,3 -k4n,4)
    num=0
    echo "${dnsmasq_leases_list}" | while read line; do
        dhcp_client_mac=$(echo ${line} | awk '{print $2}')
        trigger_dhcp_white_name=$(echo $(dbus get opsgenie_trigger_dhcp_white | base64_decode | grep -i "${dhcp_client_mac}") | cut -d# -f2)
        if [[ "${trigger_dhcp_white_name}" == "" ]]; then
            dhcp_custom_clientlist=$(echo $(nvram get custom_clientlist | sed 's/</\n/g' | awk -F ">" '{print $1""$2}' | sed '/^*$/d' | grep -i "${dhcp_client_mac}"))
            if [[ "${dhcp_custom_clientlist}" == "" ]]; then
                if [ "$opsgenie_trigger_dhcp_macoff" == "1" ]; then
                    echo ${line} | awk '{print "|"$3"%26nbsp;%26nbsp;|"$4"|"}' >>${opsgenie_lease_text}
                else
                    echo ${line} | awk '{print "|"$3"%26nbsp;%26nbsp;|"$2"%26nbsp;%26nbsp;|"$4"|"}' >>${opsgenie_lease_text}
                fi
            else
                dhcp_lease_name=$(echo ${dhcp_custom_clientlist} | awk -F "" '{print $1}')
                if [ "$opsgenie_trigger_dhcp_macoff" == "1" ]; then
                    echo $(echo "${line}" | awk '{print "|"$3"%26nbsp;%26nbsp;|"}')"${dhcp_lease_name}|" >>${opsgenie_lease_text}
                else
                    echo $(echo "${line}" | awk '{print "|"$3"%26nbsp;%26nbsp;|"$2"%26nbsp;%26nbsp;|"}')"${dhcp_lease_name}|" >>${opsgenie_lease_text}
                fi
            fi
        else
            if [ "$opsgenie_trigger_dhcp_macoff" == "1" ]; then
                echo $(echo "${line}" | awk '{print "|"$3"%26nbsp;%26nbsp;|"}')"${trigger_dhcp_white_name}|" >>${opsgenie_lease_text}
            else
                echo $(echo "${line}" | awk '{print "|"$3"%26nbsp;%26nbsp;|"$2"%26nbsp;%26nbsp;|"}')"${trigger_dhcp_white_name}|" >>${opsgenie_lease_text}
            fi
        fi
        let num=num+1
    done
    echo "---" >>${opsgenie_lease_text}
fi
opsgenie_send_title="${send_title} 路由器客户端上线通知"
opsgenie_send_content=$(cat ${opsgenie_lease_text} | sed 's/$/\\n/' | tr -d '\n')
sckey_nu=$(dbus list opsgenie_config_sckey | sort -n -t "_" -k 4 | cut -d "=" -f 1 | cut -d "_" -f 4)
for nu in ${sckey_nu}; do
    opsgenie_config_sckey=$(dbus get opsgenie_config_sckey_${nu})
    result=$(curl -X POST https://api.opsgenie.com/v2/alerts \
        -H "Content-Type: application/json" \
        -H "Authorization: GenieKey ${opsgenie_config_sckey}" \
        -d "{\"message\": \"${opsgenie_send_title}\", \"note\": \"${opsgenie_send_content}\", \"tags\": [\"设备上线\", \"${send_title}\"], \"priority\":\"P3\"}")
    if [[ -n "$(echo $result | grep 'Request will be processed')" ]]; then
        [ "${opsgenie_info_logger}" == "1" ] && logger "[opsgenie]: 设备上线信息推送到 SCKEY No.${nu} 成功！！"
    else
        [ "${opsgenie_info_logger}" == "1" ] && logger "[opsgenie]: 设备上线信息推送到 SCKEY No.${nu} 失败，请检查网络及配置！"
    fi
done
sleep 2
rm -rf ${opsgenie_lease_text}
