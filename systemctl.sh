#!/bin/sh

# скопировать содержимое скрипта в:
# /opt/usr/bin/systemctl
# выполнить:
# chmod +x /opt/usr/bin/systemctl

INIT_DIR="/opt/etc/init.d"
EDITOR="${EDITOR:-vim}"

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

# Удаляет сервис (файл) с предварительной остановкой
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
            # Останавливаем сервис перед удалением
            echo "Stopping service '$service_name'..."
            run_service_command "$service_name" "stop"
            stop_exit=$?
            if [ $stop_exit -ne 0 ]; then
                echo "Warning: Service stop returned code $stop_exit, but continuing with deletion."
            fi

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

# Редактирует файл сервиса в редакторе по умолчанию
edit_service() {
    service_name="$1"
    file=$(find_service_file "$service_name")
    [ -z "$file" ] && { echo "Error: Service '$service_name' not found."; return 1; }

    if ! command -v "$EDITOR" >/dev/null 2>&1; then
        echo "Error: Editor '$EDITOR' not found. Please set EDITOR environment variable to a valid editor."
        return 1
    fi

    if [ ! -r "$file" ]; then
        echo "Error: Cannot read file '$file'."
        return 1
    fi
    if [ ! -w "$file" ]; then
        echo "Warning: File '$file' is not writable. You might not be able to save changes."
    fi

    echo "Opening '$service_name' in $EDITOR..."
    $EDITOR "$file"
    exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo "Editing finished."
    else
        echo "Editor exited with code $exit_code."
    fi
    return $exit_code
}

# Выполняет произвольную команду над сервисом (проброс в init-скрипт)
run_service_command() {
    service_name="$1"
    command="$2"
    file=$(find_service_file "$service_name")
    if [ -z "$file" ]; then
        echo "Error: Unknown service '$service_name'."
        show_service_list
        return 1
    fi
    echo "Executing: $file $command"
    $file "$command"
    return $?
}

# --- Основная логика ---
if [ $# -lt 1 ]; then
    echo "Usage: $0 {start|stop|restart|status|reload|...} [service]"
    echo "       $0 {enable|disable|delete|edit} [service]"
    echo "       $0 list"
    exit 1
fi

ACTION="$1"
SERVICE="$2"

case "$ACTION" in
    list)
        show_service_list
        exit 0
        ;;
    enable|disable|delete|edit)
        [ -z "$SERVICE" ] && { echo "Error: Missing service name for $ACTION."; exit 1; }
        case "$ACTION" in
            enable)   enable_service "$SERVICE" ;;
            disable)  disable_service "$SERVICE" ;;
            delete)   delete_service "$SERVICE" ;;
            edit)     edit_service "$SERVICE" ;;
        esac
        exit $?
        ;;
    start|stop|restart|status)
        [ -z "$SERVICE" ] && { echo "Error: Missing service name for $ACTION."; exit 1; }
        run_service_command "$SERVICE" "$ACTION"
        exit $?
        ;;
    *)
        if [ -z "$SERVICE" ]; then
            echo "Error: Missing service name for command '$ACTION'."
            exit 1
        fi
        run_service_command "$SERVICE" "$ACTION"
        exit $?
        ;;
esac
