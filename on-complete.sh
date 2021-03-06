#!/usr/bin/env bash
#============================================================
# https://github.com/P3TERX/aria2.conf
# File name：autoupload.sh
# Description: Aria2 download completes calling Rclone upload
# Lisence: MIT
# Version: 2.1
# Author: P3TERX
# Blog: https://p3terx.com
#============================================================

## 基础设置 ##

# Aria2 下载目录
# Aria2 一键安装管理脚本 增强版 请使用菜单选项统一进行修改。
# Aria2 Pro (Docker) 无需修改，通过目录映射进行设置。
DOWNLOAD_PATH='./downloads'

# Rclone 配置时填写的网盘名(name)
DRIVE_NAME='DRIVE'

## 文件过滤 ##

# 限制最低上传大小，仅 BT 多文件下载时有效，用于过滤无用文件。低于此大小的文件将被删除，不会上传。
MIN_SIZE=10m

# 保留文件类型，仅 BT 多文件下载时有效，用于过滤无用文件。其它文件将被删除，不会上传。
#INCLUDE_FILE='mp4,mkv,rmvb,mov,avi'

# 排除文件类型，仅 BT 多文件下载时有效，用于过滤无用文件。排除的文件将被删除，不会上传。
EXCLUDE_FILE='html,url,lnk,txt,jpg,png,htm,*A57X*,*uuf39*,*UUS75*,*荷官*,*UUE29*,*UU*,*在线一对一*,*YQ交友*,*房间火爆*,*妹妹直播*,*美女在线*,*N房间*,mht,*澳门*'

## 高级设置 ##

# RCLONE 配置文件路径
#export RCLONE_CONFIG=$HOME/.config/rclone/rclone.conf

# RCLONE 配置文件密码
#export RCLONE_CONFIG_PASS=password

# RCLONE 并行上传文件数，仅对单个任务有效。
#export RCLONE_TRANSFERS=4

# RCLONE 块的大小，默认5M，理论上是越大上传速度越快，同时占用内存也越多。如果设置得太大，可能会导致进程中断。
#export RCLONE_CACHE_CHUNK_SIZE=5M

# RCLONE 块可以在本地磁盘上占用的总大小，默认10G。
#export RCLONE_CACHE_CHUNK_TOTAL_SIZE=10G

# RCLONE 上传失败重试次数，默认 3
export RCLONE_RETRIES=3

# RCLONE 上传失败重试等待时间，默认禁用，单位 s, m, h
export RCLONE_RETRIES_SLEEP=10s

# RCLONE 异常退出重试次数
RETRY_NUM=3

#============================================================

FILE_PATH=$3                                   # Aria2传递给脚本的文件路径。BT下载有多个文件时该值为文件夹内第一个文件，如/root/Download/a/b/1.mp4
RELATIVE_PATH=${FILE_PATH#${DOWNLOAD_PATH}/}   # 路径转换，去掉开头的下载路径。
TOP_PATH=${DOWNLOAD_PATH}/${RELATIVE_PATH%%/*}   # 路径转换，BT下载文件夹时为顶层文件夹路径，普通单文件下载时与文件路径相同。

RED_FONT_PREFIX="\033[31m"
LIGHT_GREEN_FONT_PREFIX="\033[1;32m"
YELLOW_FONT_PREFIX="\033[1;33m"
LIGHT_PURPLE_FONT_PREFIX="\033[1;35m"
FONT_COLOR_SUFFIX="\033[0m"
INFO="[${LIGHT_GREEN_FONT_PREFIX}INFO${FONT_COLOR_SUFFIX}]"
ERROR="[${RED_FONT_PREFIX}ERROR${FONT_COLOR_SUFFIX}]"
WARRING="[${YELLOW_FONT_PREFIX}WARRING${FONT_COLOR_SUFFIX}]"

TASK_INFO() {
    echo -e "
-------------------------- [${YELLOW_FONT_PREFIX}TASK INFO${FONT_COLOR_SUFFIX}] --------------------------
${LIGHT_PURPLE_FONT_PREFIX}Download path:${FONT_COLOR_SUFFIX} ${DOWNLOAD_PATH}
${LIGHT_PURPLE_FONT_PREFIX}File path:${FONT_COLOR_SUFFIX} ${FILE_PATH}
${LIGHT_PURPLE_FONT_PREFIX}Upload path:${FONT_COLOR_SUFFIX} ${UPLOAD_PATH}
${LIGHT_PURPLE_FONT_PREFIX}Remote path:${FONT_COLOR_SUFFIX} ${REMOTE_PATH}
-------------------------- [${YELLOW_FONT_PREFIX}TASK INFO${FONT_COLOR_SUFFIX}] --------------------------
"
}

CLEAN_UP() {
    [[ -n ${MIN_SIZE} || -n ${INCLUDE_FILE} || -n ${EXCLUDE_FILE} ]] && echo -e "${INFO} Clean up excluded files ..."
    [[ -n ${MIN_SIZE} ]] && rclone delete -v --config="rclone.conf" "${UPLOAD_PATH}" --max-size ${MIN_SIZE}
    [[ -n ${INCLUDE_FILE} ]] && rclone delete -v --config="rclone.conf" "${UPLOAD_PATH}" --exclude "*.{${INCLUDE_FILE}}"
    [[ -n ${EXCLUDE_FILE} ]] && rclone delete -v --config="rclone.conf" "${UPLOAD_PATH}" --include "*.{${EXCLUDE_FILE}}"
}

UPLOAD_FILE() {
    RETRY=0
    while [ ${RETRY} -le ${RETRY_NUM} ]; do
        [ ${RETRY} != 0 ] && (
            echo
            echo -e "$(date +"%m/%d %H:%M:%S") ${ERROR} Upload failed! Retry ${RETRY}/${RETRY_NUM} ..."
            echo
        )
        rclone move -v --config="rclone.conf" "${UPLOAD_PATH}" "${REMOTE_PATH}"
        RCLONE_EXIT_CODE=$?
        if [ ${RCLONE_EXIT_CODE} -eq 0 ]; then
            [ -e "${DOT_ARIA2_FILE}" ] && rm -vf "${DOT_ARIA2_FILE}"
            rclone rmdirs -v --config="rclone.conf" "${DOWNLOAD_PATH}" --leave-root
            echo -e "$(date +"%m/%d %H:%M:%S") ${INFO} Upload done: ${UPLOAD_PATH} -> ${REMOTE_PATH}"
            [ $LOG_PATH ] && echo -e "$(date +"%m/%d %H:%M:%S") [INFO] Upload done: ${UPLOAD_PATH} -> ${REMOTE_PATH}" >>${LOG_PATH}
            break
        else
            RETRY=$((${RETRY} + 1))
            [ ${RETRY} -gt ${RETRY_NUM} ] && (
                echo
                echo -e "$(date +"%m/%d %H:%M:%S") ${ERROR} Upload failed: ${UPLOAD_PATH}"
                [ $LOG_PATH ] && echo -e "$(date +"%m/%d %H:%M:%S") [ERROR] Upload failed: ${UPLOAD_PATH}" >>${LOG_PATH}
                echo
            )
            sleep 3
        fi
    done
}

UPLOAD() {
    echo -e "$(date +"%m/%d %H:%M:%S") ${INFO} Start upload..."
    TASK_INFO
    UPLOAD_FILE
}

if [ -z $2 ]; then
    echo && echo -e "${ERROR} This script can only be used by passing parameters through Aria2."
    echo && echo -e "${WARRING} 直接运行此脚本可能导致无法开机！"
    exit 1
elif [ $2 -eq 0 ]; then
    exit 0
fi


if [ -e "${FILE_PATH}.aria2" ]; then
    DOT_ARIA2_FILE="${FILE_PATH}.aria2"
elif [ -e "${TOP_PATH}.aria2" ]; then
    DOT_ARIA2_FILE="${TOP_PATH}.aria2"
fi

if [ "${TOP_PATH}" = "${FILE_PATH}" ] && [ $2 -eq 1 ]; then # 普通单文件下载，移动文件到设定的网盘文件夹。
    UPLOAD_PATH="${FILE_PATH}"
    REMOTE_PATH="${DRIVE_NAME}:$RCLONE_DESTINATION"
    UPLOAD
    exit 0
elif [ "${TOP_PATH}" != "${FILE_PATH}" ] && [ $2 -gt 1 ]; then # BT下载（文件夹内文件数大于1），移动整个文件夹到设定的网盘文件夹。
    UPLOAD_PATH="${TOP_PATH}"
    REMOTE_PATH="${DRIVE_NAME}:$RCLONE_DESTINATION/${RELATIVE_PATH%/*}"
    CLEAN_UP
    UPLOAD
    exit 0
fi

echo -e "${ERROR} Unknown error."
TASK_INFO
exit 1
