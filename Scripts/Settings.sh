#!/bin/bash

#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")

#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")

#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ Build by bluehj-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

#修改Argon主题footer
ARGON_HTM_FILES=$(find . -path "*/luci-theme-argon/*" -name "*.htm" -type f)
if [ -n "$ARGON_HTM_FILES" ]; then
    # 将日期格式从 yy.mm.dd-HH.MM.SS 转换为 yyyy.mm.dd
    WRT_DATE_SHORT=$(echo $WRT_DATE | sed 's/\([0-9][0-9]\)\.\([0-9][0-9]\)\.\([0-9][0-9]\)-.*/20\1.\2.\3/')
    
    # 一步完成替换：隐藏原内容，显示新内容
    sed -i 's|<a class="luci-link" href="https://github.com/openwrt/luci">Powered by <%= ver\.luciname %> (<%= ver\.luciversion %>)</a> /[[:space:]]*<%= ver\.distversion %>|Powered by ImmortalWrt SNAPSHOT Build by bluehj '"$WRT_DATE_SHORT"'|g' $ARGON_HTM_FILES
    
    echo "Argon theme footer has been modified!"
fi
CFG_FILE="./package/base-files/files/bin/config_generate"

#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE

#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#临时修复luci无法保存的问题
sed -i "s/\[sid\]\.hasOwnProperty/\[sid\]\?\.hasOwnProperty/g" $(find ./feeds/luci/modules/luci-base/ -type f -name "uci.js")

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
#echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#移除advancedplus无用功能
sed -i '/advancedplus\/advancedset/d' $(find ./**/luci-app-advancedplus/luasrc/controller/ -type f -name "advancedplus.lua")
sed -i '/advancedplus\/advancedipk/d' $(find ./**/luci-app-advancedplus/luasrc/controller/ -type f -name "advancedplus.lua")
sed -i '/^start() {/,/^}$/ { /advancedset/s/^\(.*advancedset.*\)$/#\1/ }' $(find ./**/luci-app-advancedplus/root/etc/ -type f -name "advancedplus")

#高通平台调整
DTS_PATH="./target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#取消nss相关feed
	echo "CONFIG_FEED_nss_packages=n" >> ./.config
	echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
	#设置NSS版本
	echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> ./.config
	echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
	#开启sqm-nss插件
	echo "CONFIG_PACKAGE_luci-app-sqm=y" >> ./.config
	echo "CONFIG_PACKAGE_sqm-scripts-nss=y" >> ./.config
	#无WIFI配置调整Q6大小
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi
# TTYD 免登录
sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config
