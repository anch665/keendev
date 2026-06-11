#!/bin/sh

# скопировать содержимое скрипта в:
# /opt/usr/bin/journalctl
# выполнить:
# chmod +x /opt/usr/bin/journalctl

INIT_DIR="/opt/etc/init.d"

# --- Функции, аналогичные systemctl ---
get_service_name_from_file() {
    echo "$1" | sed 's/^[SK][0-9][0-9]//'
}

find_service_file() {
    service_name="$1"
    for file in "$INIT_DIR"/*; do
        [ -f "$file" ] || continue
        basename_file=$(basename "$file")
        case "$basename_file" in
            [SK][0-9][0-9]*)
                name=$(get_service_name_from_file "$basename_file")
                if [ "$name" = "$service_name" ]; then
                    echo "$file"
                    return 0
                fi
                ;;
        esac
    done
    return 1
}

# Извлекает путь к лог-файлу из init-скрипта (первая найденная переменная LOG_FILE или LOGFILE)
get_logfile_from_service() {
    service_file="$1"
    # ищем LOG_FILE=... (с возможными кавычками)
    logfile=$(grep -E '^LOG_FILE=' "$service_file" | head -n1 | cut -d= -f2- | tr -d '"' | tr -d "'")
    if [ -z "$logfile" ]; then
        logfile=$(grep -E '^LOGFILE=' "$service_file" | head -n1 | cut -d= -f2- | tr -d '"' | tr -d "'")
    fi
    # удаляем пробелы по краям
    echo "$logfile" | xargs
}

# --- Команда list: показывает сервисы, у которых задан лог-файл ---
show_logfile_services() {
    echo "Services with LOG_FILE/LOGFILE defined:"
    found=0
    for file in "$INIT_DIR"/*; do
        [ -f "$file" ] || continue
        basename_file=$(basename "$file")
        case "$basename_file" in
            [SK][0-9][0-9]*)
                name=$(get_service_name_from_file "$basename_file")
                logfile=$(get_logfile_from_service "$file")
                if [ -n "$logfile" ]; then
                    echo "  $name -> $logfile"
                    found=1
                fi
                ;;
        esac
    done
    if [ $found -eq 0 ]; then
        echo "  (none)"
    fi
}

# --- Основная логика (эмуляция journalctl) ---
usage() {
    echo "Usage: $0 list"
    echo "       $0 -u SERVICE [-n LINES] [-f] [--since DATE] [--no-pager] [-o short-iso]"
    exit 1
}

# Если первый аргумент "list" — выводим список и выходим
if [ "$1" = "list" ]; then
    show_logfile_services
    exit 0
fi

# Парсим остальные аргументы (должен быть -u и т.д.)
SERVICE=""
LINES=10
FOLLOW=0

while [ $# -gt 0 ]; do
    case "$1" in
        -u)
            SERVICE="$2"
            shift 2
            ;;
        -n)
            LINES="$2"
            shift 2
            ;;
        -f)
            FOLLOW=1
            shift
            ;;
        --since)
            # игнорируем --since и следующее значение
            shift 2
            ;;
        --no-pager|-o)
            # игнорируем
            shift
            ;;
        *)
            # неизвестный аргумент — пропускаем
            shift
            ;;
    esac
done

if [ -z "$SERVICE" ]; then
    echo "Error: missing required -u SERVICE" >&2
    usage
fi

# Находим init-скрипт сервиса
service_file=$(find_service_file "$SERVICE")
if [ -z "$service_file" ]; then
    echo "Error: service '$SERVICE' not found in $INIT_DIR" >&2
    exit 1
fi

# Извлекаем путь к лог-файлу
log_file=$(get_logfile_from_service "$service_file")
if [ -z "$log_file" ]; then
    echo "Error: no LOG_FILE or LOGFILE variable found in $service_file" >&2
    exit 1
fi

if [ ! -f "$log_file" ]; then
    echo "Error: log file '$log_file' does not exist or is not readable" >&2
    exit 1
fi

# Функция вывода последних N строк (без фильтрации по --since, т.к. игнорируем)
print_lines() {
    tail -n "$LINES" "$log_file"
}

# Режим слежения
if [ "$FOLLOW" -eq 1 ]; then
    # сначала показать последние строки
    print_lines
    # затем следить за новыми (не выводить существующие)
    exec tail -n 0 -f "$log_file"
else
    print_lines
fi

