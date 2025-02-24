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

  else
    echo "登录失败"
    msg="🔴主机 ${host}, 用户 ${user}， 登录失败!\n"
    chmod +x ./tgsend.sh
    export PASS=$pass
    ./tgsend.sh "Host:$host, user:$user, 登录失败，请检查!"
  fi

  # 启动 newapi 服务的函数
  start_newapi() {
    local host="$1"
    local user="$2"
    local port="$3"
    local pass="$4"

    echo "🔄 正在启动 newapi 服务..."
    
    sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -p "$port" "$user@$host" "
        # 加载环境变量
        source ~/.bashrc
        source ~/.profile
        export PATH=/usr/local/bin:$PATH
        export NVM_DIR=\"\$HOME/.nvm\"
        [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"
        
        cd /usr/home/xcllampon/domains/newapi.xcllampon.serv00.net/public_html
        pm2 start ./start.sh --name new-api
    "
    
    # 验证服务是否成功启动
    sleep 2
    check_newapi=$(sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -p "$port" "$user@$host" "
        source ~/.bashrc
        source ~/.profile
        export PATH=/usr/local/bin:$PATH
        export NVM_DIR=\"\$HOME/.nvm\"
        [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"
        
        pm2 list | grep 'new-api' || echo 'not found'
    ")
    if echo "$check_newapi" | grep -q "online"; then
        echo "✅ newapi 服务启动成功"
        return 0
    else
        echo "❌ newapi 服务启动失败"
        return 1
    fi
  }

  # 在原有代码中添加检查和启动逻辑
  check_newapi=$(sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -p "$port" "$user@$host" "
    source ~/.bashrc
    source ~/.profile
    export PATH=/usr/local/bin:$PATH
    export NVM_DIR=\"\$HOME/.nvm\"
    [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"
    
    pm2 list | grep 'new-api' || echo 'not found'
  ")

  if ! echo "$check_newapi" | grep -q "online"; then
    echo "⚠️ 主机 ${host} 上的 newapi 服务未运行，准备启动..."
    if start_newapi "$host" "$user" "$port" "$pass"; then
      msg="${msg}✅ newapi 服务启动成功\n"
    else
      msg="${msg}❌ newapi 服务启动失败\n"
    fi
  else
    echo "✓ 主机 ${host} 上的 newapi 服务正常运行中"
  fi

  summary=$summary$(echo -n $msg)
done

if [[ "$LOGININFO" == "Y" ]]; then
  chmod +x ./tgsend.sh
  ./tgsend.sh "$summary"
fi
