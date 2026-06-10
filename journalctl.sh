#!/bin/sh


# скопировать содержимое скрипта в:
# /opt/usr/bin/journalctl
# выполнить:
# chmod +x /opt/usr/bin/journalctl

LOG_FILE="/opt/var/log/telemt.log"

# Игнорируем все аргументы, просто выводим содержимое файла или tail -f
follow=0
lines=10

# Примитивный разбор
while [ $# -gt 0 ]; do
    case "$1" in
        -f) follow=1 ;;
        -n) lines="$2"; shift ;;
        *) ;;
    esac
    shift
done

if [ ! -f "$LOG_FILE" ]; then
    echo "Error: log file not found" >&2
    exit 1
fi

if [ "$follow" -eq 1 ]; then
    # Если указан -f, выводим последние $lines строк и затем следим
    if [ "$lines" -gt 0 ]; then
        tail -n "$lines" "$LOG_FILE"
    fi
    exec tail -f "$LOG_FILE"
else
    tail -n "$lines" "$LOG_FILE"
fi
