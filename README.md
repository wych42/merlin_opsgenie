# Merlin Opsgenie通知

基于 [serverchan](https://github.com/koolshare/armsoft/tree/master/serverchan/serverchan) 修改。

与 serverchan,pushplus 冲突。

因为都要修改文件 `/jffs/configs/dnsmasq.d/dhcp_trigger.conf` 添加 dhcp-script 参数，而 dnsmasq 只允许添加一个。
