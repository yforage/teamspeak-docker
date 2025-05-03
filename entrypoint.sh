#!/bin/sh
set -ex

echo ">>> Скрипт работает — пауза 300 сек." >&2
sleep 300

echo "PWD: $(pwd)" >&2
ls -la /opt/ts3server >&2

touch /opt/ts3server/entrypoint_marker
touch /opt/ts3server/.ts3server_license_accepted

echo ">>> Запуск entrypoint.sh" >&2
echo ">>> Аргументы: $@" >&2
env >&2

if [ -z "$1" ]; then
    echo ">>> Ошибка: не передан первый аргумент. Прерывание." >&2
    exit 1
fi

if [ "$1" = 'ts3server' ] && [ "$(id -u)" = '0' ]; then
    echo ">>> Запуск от root, смена владельца и пользователя..." >&2
    chown -R ts3server /var/ts3server
    exec su-exec ts3server "$0" "$@"
fi

if [ "$1" = 'ts3server' ]; then
    echo ">>> Аргумент ts3server, добавление ini-файла..." >&2
    set -- "$@" inifile=/var/run/ts3server/ts3server.ini
fi

file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    eval local varValue="\$${var}"
    eval local fileVarValue="\$${var}_FILE"
    local def="${2:-}"

    if [ "${varValue:-}" ] && [ "${fileVarValue:-}" ]; then
        echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
        exit 1
    fi

    local val="$def"
    if [ "${varValue:-}" ]; then
        val="${varValue}"
    elif [ "${fileVarValue:-}" ]; then
        val="$(cat "${fileVarValue}")"
    fi
    export "$var"="$val"
    unset "$fileVar"
    unset "fileVarValue"
}

if [ "$1" = 'ts3server' ]; then
    echo ">>> Подготовка переменных окружения..." >&2
    file_env 'TS3SERVER_DB_HOST'
    file_env 'TS3SERVER_DB_USER'
    file_env 'TS3SERVER_DB_PASSWORD'
    file_env 'TS3SERVER_DB_NAME'

    echo ">>> Создание ts3server.ini..." >&2
    mkdir -p /var/run/ts3server
    cat << EOF | sed 's/^[ \t]*//;s/[ \t]*$//;/^$/d' > /var/run/ts3server/ts3server.ini
        licensepath=${TS3SERVER_LICENSEPATH}
        ...
EOF

    echo ">>> Создание ts3db.ini..." >&2
    cat << EOF | sed 's/^[ \t]*//;s/[ \t]*$//;/^$/d' > /var/run/ts3server/ts3db.ini
        [config]
        host='${TS3SERVER_DB_HOST}'
        ...
EOF
fi

echo ">>> Выполнение exec: $@" >&2
exec "$@"
