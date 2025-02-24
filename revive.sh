#!/bin/bash

AUTOUPDATE=${AUTOUPDATE:-Y}
SENDTYPE=${SENDTYPE:-null}
TELEGRAM_TOKEN=${TELEGRAM_TOKEN:-null}
TELEGRAM_USERID=${TELEGRAM_USERID:-null}
WXSENDKEY=${WXSENDKEY:-null}
BUTTON_URL=${BUTTON_URL:-null}
LOGININFO=${LOGININFO:-N}
export TELEGRAM_TOKEN TELEGRAM_USERID BUTTON_URL

# 使用 jq 提取 JSON 数组，并将其加载为 Bash 数组
AUTOUPDATE=${AUTOUPDATE:-Y}
SENDTYPE=${SENDTYPE:-null}
TELEGRAM_TOKEN=${TELEGRAM_TOKEN:-null}
TELEGRAM_USERID=${TELEGRAM_USERID:-null}
WXSENDKEY=${WXSENDKEY:-null}
BUTTON_URL=${BUTTON_URL:-null}

hosts_info=($(echo "${HOSTS_JSON}" | jq -c ".info[]"))
summary=""
for info in "${hosts_info[@]}"; do
  user=$(echo $info | jq -r ".username")
  host=$(echo $info | jq -r ".host")
  port=$(echo $info | jq -r ".port")
  pass=$(echo $info | jq -r ".password")

  if [[ "$AUTOUPDATE" == "Y" ]]; then
    script="/home/$user/serv00-play/keepalive.sh autoupdate ${SENDTYPE} \"${TELEGRAM_TOKEN}\" \"${TELEGRAM_USERID}\" \"${WXSENDKEY}\" \"${BUTTON_URL}\" \"${pass}\""
  else
    script="/home/$user/serv00-play/keepalive.sh noupdate ${SENDTYPE} \"${TELEGRAM_TOKEN}\" \"${TELEGRAM_USERID}\" \"${WXSENDKEY}\" \"${BUTTON_URL}\" \"${pass}\""
  fi
  output=$(sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -p "$port" "$user@$host" "bash -s" <<<"$script")

  echo "output:$output"

  if echo "$output" | grep -q "keepalive.sh"; then
    echo "登录成功"
    msg="🟢主机 ${host}, 用户 ${user}， 登录成功!\n"
    
    # 检查newapi进程是否运行
    process_check=$(sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -p "$port" "$user@$host" "ps aux | grep newapi | grep -v grep")
    
    if [ -z "$process_check" ]; then
      echo "newapi进程未运行，创建定时任务"
      # 检查是否已存在相同的定时任务
      cron_check=$(sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -p "$port" "$user@$host" "crontab -l | grep newapi.xcllampon")
      
      if [ -z "$cron_check" ]; then
        # 创建新的定时任务
        sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -p "$port" "$user@$host" '(crontab -l 2>/dev/null; echo "*/5 * * * * cd /usr/home/xcllampon/domains/newapi.xcllampon.serv00.net/public_html && ./start.sh") | crontab -'
        msg="${msg}已添加newapi进程监控定时任务\n"
      fi
    else
      echo "newapi进程正在运行"
    fi
  else
    echo "登录失败"
    msg="🔴主机 ${host}, 用户 ${user}， 登录失败!\n"
    chmod +x ./tgsend.sh
    export PASS=$pass
    ./tgsend.sh "Host:$host, user:$user, 登录失败，请检查!"
  fi
  summary=$summary$(echo -n $msg)
done

if [[ "$LOGININFO" == "Y" ]]; then
  chmod +x ./tgsend.sh
  ./tgsend.sh "$summary"
fi
