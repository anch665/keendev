#!/bin/sh

# скопировать содержимое скрипта в:
# /opt/usr/bin/systemctl
# выполнить:
# chomd +x /opt/usr/bin/systemctl

INIT_DIR="/opt/etc/init.d"

if [ ! -d "$INIT_DIR" ]; then
    echo "Error: Directory $INIT_DIR does not exist."
    exit 1
fi

# Извлекает имя сервиса из имени файла (удаляет префикс [SK] + две цифры)
get_service_name_from_file() {
    echo "$1" | sed 's/^[SK][0-9][0-9]//'
}

# Возвращает префикс файла (S или K)
get_prefix() {
    echo "$1" | cut -c1
}

# Ищет файл сервиса по имени, возвращает полный путь или пустую строку
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

# Показывает список всех сервисов с их состоянием (enabled/disabled)
show_service_list() {
    echo "Available services:"
    for file in "$INIT_DIR"/*; do
        [ -f "$file" ] || continue
        basename_file=$(basename "$file")
        case "$basename_file" in
            [SK][0-9][0-9]*)
                name=$(get_service_name_from_file "$basename_file")
                prefix=$(get_prefix "$basename_file")
                [ "$prefix" = "S" ] && status="enabled" || status="disabled"
                echo "  $name ($status)"
                ;;
        esac
    done | sort
}

# Включает сервис (переименовывает K??* -> S??*)
enable_service() {
    service_name="$1"
    file=$(find_service_file "$service_name")
    [ -z "$file" ] && { echo "Error: Service '$service_name' not found."; return 1; }

    basename_file=$(basename "$file")
    prefix=$(get_prefix "$basename_file")
    if [ "$prefix" = "S" ]; then
        echo "Service '$service_name' is already enabled."
        return 0
    fi

    new_basename=$(echo "$basename_file" | sed 's/^K/S/')
    new_file="$INIT_DIR/$new_basename"
    if [ -e "$new_file" ]; then
        echo "Error: Target file '$new_file' already exists. Cannot enable."
        return 1
    fi

    mv "$file" "$new_file" && echo "Service '$service_name' enabled (renamed to $new_basename)." \
        || { echo "Error: Failed to enable service '$service_name'."; return 1; }
}

# Отключает сервис (переименовывает S??* -> K??*)
disable_service() {
    service_name="$1"
    file=$(find_service_file "$service_name")
    [ -z "$file" ] && { echo "Error: Service '$service_name' not found."; return 1; }

    basename_file=$(basename "$file")
    prefix=$(get_prefix "$basename_file")
    if [ "$prefix" = "K" ]; then
        echo "Service '$service_name' is already disabled."
        return 0
    fi

    new_basename=$(echo "$basename_file" | sed 's/^S/K/')
    new_file="$INIT_DIR/$new_basename"
    if [ -e "$new_file" ]; then
        echo "Error: Target file '$new_file' already exists. Cannot disable."
        return 1
    fi

    mv "$file" "$new_file" && echo "Service '$service_name' disabled (renamed to $new_basename)." \
        || { echo "Error: Failed to disable service '$service_name'."; return 1; }
}

# Удаляет сервис (файл)
delete_service() {
    service_name="$1"
    file=$(find_service_file "$service_name")
    [ -z "$file" ] && { echo "Error: Service '$service_name' not found."; return 1; }

    basename_file=$(basename "$file")
    echo "Warning: You are about to delete service '$service_name' (file: $basename_file)."
    printf "Are you sure? (y/N): "
    read -r answer
    case "$answer" in
        y|Y)
            rm -f "$file"
            if [ $? -eq 0 ]; then
                echo "Service '$service_name' deleted successfully."
                return 0
            else
                echo "Error: Failed to delete service '$service_name'."
                return 1
            fi
            ;;
        *)
            echo "Deletion cancelled."
            return 0
            ;;
    esac
}

# --- Основная логика ---
if [ $# -lt 1 ]; then
    echo "Usage: $0 {start|stop|restart|status|enable|disable|delete|list} [service]"
    exit 1
fi

ACTION="$1"
SERVICE="$2"

case "$ACTION" in
    list)
        show_service_list
        exit 0
        ;;
    enable|disable|delete)
        [ -z "$SERVICE" ] && { echo "Error: Missing service name for $ACTION."; exit 1; }
        case "$ACTION" in
            enable)   enable_service "$SERVICE" ;;
            disable)  disable_service "$SERVICE" ;;
            delete)   delete_service "$SERVICE" ;;
        esac
        exit $?
        ;;
    start|stop|restart|status)
        [ -z "$SERVICE" ] && { echo "Error: Missing service name for $ACTION."; exit 1; }
        INIT_SCRIPT=$(find_service_file "$SERVICE")
        if [ -z "$INIT_SCRIPT" ]; then
            echo "Error: Unknown service '$SERVICE'."
            show_service_list
            exit 1
        fi
        echo "Executing: $INIT_SCRIPT $ACTION"
        $INIT_SCRIPT "$ACTION"
        exit $?
        ;;
    *)
        echo "Error: Action '$ACTION' not supported. Use start, stop, restart, status, enable, disable, delete, or list."
        exit 1
        ;;
esac
