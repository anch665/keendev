#!/opt/bin/sh
# Скопировать содержимое в файл 
# /opt/etc/ndm/wan.d/030-rostelecom.sh
# выполнить:
# chmod +x /opt/etc/ndm/wan.d/030-rostelecom.sh


IP_PATTERN="^(10\.|100\.6[4-9]\.|100\.[7-9][0-9]\.|100\.1[01][0-9]\.|100\.12[0-7]\.|172\.1[6-9]\.|172\.2[0-9]\.|172\.3[01]\.|46\.158\.|null)"
CONFIG_FILE="/opt/etc/restart_wan.conf"

tg_say() {
    local msg="$1"
    local proxy_port=""
    local proxy_ok=0

    local ports
    ports=$(netstat -nlpt 2>/dev/null | grep sing-box | awk '{print $4}' | sed 's/.*://' | sort -un)

    for prio in 1099 $(seq 1080 1089) $(seq 11000 11009); do
        if echo "$ports" | grep -qx "$prio"; then
            proxy_port="$prio"
            break
        fi
    done

    if [[ -z "$proxy_port" ]]; then
        echo "❌ Не найден подходящий порт SOCKS5 среди: $ports" >&2
        TG_SAY_RESUL=""
        return 1
    fi

    if curl -x "socks5h://127.0.0.1:$proxy_port" -m 5 -s -o /dev/null -w "%{http_code}" \
        "https://www.gstatic.com/generate_204" | grep -q "204"; then
        proxy_ok=1
    fi

    if [[ $proxy_ok -ne 1 ]]; then
        echo "⚠️ Прокси 127.0.0.1:$proxy_port не работает, попытка отправить без проверки..." >&2
    fi

    TG_SAY_RESUL=$(curl -x "socks5h://127.0.0.1:$proxy_port" -m 10 -k -s -X POST \
        "https://api.telegram.org/bot$API_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" -d text="$msg" 2>&1)

    if [[ -z "$TG_SAY_RESUL" ]]; then
        echo "❌ Ошибка отправки сообщения через прокси $proxy_port" >&2
        return 1
    fi
}

update_ddns() {
    DDNS_RESULT=$(curl -s -k "https://freedns.afraid.org/dynamic/update.php?${DDNS_TOKEN_NEW}")
    curl -s "https://myaddr.tools/update?key=${DDNS_TOKEN_MYADDR}&ip=$_ip"
    tg_say "DDNS обновлён: $DDNS_RESULT"
}

restart_wan() {
    curl -s -X POST -H "Content-Type: application/json" \
         -d "[{\"interface\":{\"name\":\"$_iface\",\"down\":{}}}]" \
         http://localhost:79/rci/ >/dev/null 2>&1
    sleep 3
    curl -s -X POST -H "Content-Type: application/json" \
         -d "[{\"interface\":{\"name\":\"$_iface\",\"up\":{}}}]" \
         http://localhost:79/rci/ >/dev/null 2>&1
}

check_ddns() {
set -x
    # Определяем интерфейс (из конфига или по умолчанию ppp0)
    local iface="${interface:-ppp0}"
    local domain="${DDNS_DOMAIN}"
    if [ -z "$domain" ]; then
        logger -p local0.error -t "$(readlink -f $0)" "DDNS_DOMAIN не задан в $CONFIG_FILE"
        exit 1
    fi

    # 1. Получаем текущий IP интерфейса
    local current_ip=$(ifconfig "$iface" 2>/dev/null | grep -o 'inet addr:[0-9.]*' | cut -d: -f2)
    if [ -z "$current_ip" ]; then
        current_ip=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    fi
    if [ -z "$current_ip" ]; then
        logger -p local0.error -t "$(readlink -f $0)" "Не удалось определить IP для интерфейса $iface"
        exit 1
    fi

    # 2. Убедимся, что dig установлен
    if ! command -v dig >/dev/null 2>&1; then
        logger -p local0.notice -t "$(readlink -f $0)" "dig не найден, устанавливаю bind-dig..."
        opkg update && opkg install bind-dig
        if [ $? -ne 0 ]; then
            logger -p local0.error -t "$(readlink -f $0)" "Не удалось установить bind-dig"
            exit 1
        fi
    fi

    # 3. Разрешаем домен в IP
    local domain_ip=$(dig +short "$domain" 2>/dev/null | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' | head -1)
    if [ -z "$domain_ip" ]; then
        logger -p local0.error -t "$(readlink -f $0)" "Не удалось разрешить домен $domain"
    fi

    # 4. Сравниваем
    if [ "$current_ip" != "$domain_ip" ]; then
        MSG="DDNS: текущий IP ($current_ip) не совпадает с DNS ($domain_ip). Обновляем..."
        logger -p local0.notice -t "$(readlink -f $0)" "$MSG"
        tg_say "$MSG"
        _ip="$current_ip"
        update_ddns
    else
        logger -p local0.notice -t "$(readlink -f $0)" "DDNS: IP совпадает ($current_ip). Обновление не требуется."
    fi
}

if [ -f "$CONFIG_FILE" ] ; then
    source "$CONFIG_FILE"
else
    echo "Config file not found, exit"
    exit 1
fi

# ========== ОБРАБОТКА АРГУМЕНТОВ КОМАНДНОЙ СТРОКИ ==========
if [ "$1" = "restart_wan" ]; then
    MSG="Принудительный перезапуск WAN по расписанию (cron)"
    logger -p local0.notice -t "$(readlink -f $0)" "$MSG"
    tg_say "$MSG"
    RESP=$(curl -s http://localhost:79/rci/show/interface | jq -r ".[] | select(.description==\"$ConnName\") | select(.defaultgw==true) | .id, .description, .address")
    [ -n "$RESP" ] || exit 1
    _iface=$(echo $RESP | awk '{print $1}')
    restart_wan
    exit 0
fi

if [ "$1" = "check_ddns" ]; then
    check_ddns
    exit 0
fi


if [ "$interface" != "ppp0" ]; then
    exit 0
fi

RESP=$(curl -s http://localhost:79/rci/show/interface | jq -r ".[] | select(.description==\"$ConnName\") | select(.defaultgw==true) | .id, .description, .address")
[ -n "$RESP" ] || exit 1

_ip=$(echo $RESP | awk '{print $3}')
_name=$(echo $RESP | awk '{print $2}')
_iface=$(echo $RESP | awk '{print $1}')

if echo "$_ip" | grep -qE "$IP_PATTERN"; then
    [ -f "$counter" ] || echo "0" > $counter
    try_nr=$(cat $counter)
    try_nr=$((++try_nr))
    if [ $try_nr -gt $max_tries ]; then
        echo "0" > $counter
        MSG="Соединение: $_name, интерфейс: $_iface. Слишком много попыток переподключения. Exit"
        logger -p local0.error -t "$(readlink -f $0)" "$MSG"
        tg_say "$MSG"
        exit 1
    fi
    echo "$try_nr" > $counter
    MSG="Соединение: $_name, интерфейс: $_iface. Перезапускаем WAN, Серый IP - $_ip. Попытка: ${try_nr}/${max_tries}."
    logger -p local0.error -t "$(readlink -f $0)" "$MSG"
    tg_say "$MSG"
    restart_wan
else
    echo "0" > $counter
    [ -f "$previp" ] || echo "0.0.0.0" > $previp
    _previp=$(cat $previp)
    if [ "$_previp" != "$_ip" ]; then
        MSG="Соединение: $_name, интерфейс: $_iface, Белый IP - $_ip."
        logger -p local0.notice -t "$(readlink -f $0)" "$MSG"
        tg_say "$MSG"
        update_ddns
        echo "$_ip" > $previp
    else
        MSG="Соединение: $_name, интерфейс: $_iface, Белый IP - $_ip (IP адрес не менялся)."
        logger -p local0.notice -t "$(readlink -f $0)" "$MSG"
    fi
    exit 0
fi
