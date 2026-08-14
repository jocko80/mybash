#!/bin/bash
# ============================================================
# check_raid_status.sh - RAID status monitoring with email alerts
# ============================================================
# Строгий режим Bash для отлова скрытых ошибок
set -euo pipefail

# Константы (ВСЕГДА ВЕРХНИЙ РЕГИСТР)
ARCCONF="/usr/StorMan/arcconf"
EMAIL_TO="mail-rack@sunlink.ru"
LOG_FILE="/var/log/raid_status.log"
STATE_FILE="/var/tmp/raid_status"

# Коды с которым завершился скрипт, можно проверить после выполнения скрипта
# вывести код завершиния через 'echo $?'. Можно применять для других скриптов или мониторинга.
OK=0
WARN=1
CRIT=2
UNKNOWN=3

log() {
    local log_msg="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $log_msg" | tee -a "$LOG_FILE"
    logger -t "raid_monitor" "$log_msg"
}

send_email() {
    # Локальные переменные функций (всегда local и нижний регистр)
    local subject="$1"
    local body="$2"
    # echo -e "$body" | mail -s "$subject" "$EMAIL_TO"
    # Безопасная отправка многострочного текста без echo -e
    mail -s "$subject" "$EMAIL_TO" <<< "$body"
    log "Email sent: $subject"
}

# ===================== MAIN ==============================

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Must run as root"
    exit $UNKNOWN
fi

if [ ! -x "$ARCCONF" ]; then
    log "ERROR: arcconf not found"
    exit $UNKNOWN
fi

# Выключаем 'set -e' временно, так как arcconf или grep могут вернуть не-ноль
set +e
# Динамические переменные (в нижнем регистре)
output=$("$ARCCONF" GETCONFIG 1 LD 2>/dev/null)
set -e

if [ -z "$output" ]; then
    log "ERROR: Cannot get RAID status"
    exit $UNKNOWN
fi

# === ОПРЕДЕЛЯЕМ СТАТУС ===

if echo "$output" | grep -q "Status of logical device.*Failed"; then
    status="CRITICAL"
    status_code=$CRIT
    details="RAID array FAILED"

elif echo "$output" | grep -q "Status of logical device.*Degraded"; then
    status="WARNING"
    status_code=$WARN
    details="RAID array DEGRADED"

elif echo "$output" | grep -q "Segment.*Missing"; then
    status="WARNING"
    status_code=$WARN
    details="Disk MISSING in array"

elif echo "$output" | grep -q "Segment.*Rebuilding"; then
    status="REBUILDING"
    status_code=$WARN
    details="RAID rebuilding in progress"

else
    status="OK"
    status_code=$OK
    details="All arrays optimal"
fi

# Читаем предыдущий статус
# [ -f "$STATE_FILE" ] && prev_status=$(cat "$STATE_FILE") || prev_status="OK"
# Безопасное чтение предыдущего статуса
#prev_status=$(cat "$STATE_FILE" 2>/dev/null || echo "OK")

# Безопасное чтение предыдущего статуса (берем только 1-ю строку)
prev_status=$(head -1 "$STATE_FILE" 2>/dev/null)
# Если файл отсутствовал или оказался пустым — задаем статус "OK"
prev_status="${prev_status:-OK}"


# === ОТПРАВЛЯЕМ ТОЛЬКО ПРИ ИЗМЕНЕНИИ СТАТУСА ===
# ВСЕГДА используем кавычки вокруг переменных в условиях [ ]
if [ "$status" != "$prev_status" ]; then
    if [ "$status" != "OK" ]; then
        log "ALERT: RAID $status (was $prev_status)"
    else
        log "RECOVERED: RAID OK (was $prev_status)"
    fi

    hostname_short=$(hostname -s)
    raid_info=$(echo "$output" | grep -E "Logical device|Status|Segment")
    # body="Status: ${status}\n\n${details}\n\n${raid_info}"

    if [ "$status" != "OK" ]; then
        subject="[${status}] RAID on ${hostname_short}"
        # Формируем тело письма с явными переносами строк внутри кавычек
        body="Status: ${status}

Details: ${details}

${raid_info}"
        send_email "$subject" "$body"
    else
        subject="[RECOVERED] RAID OK on $(hostname)"
        #body="RAID has recovered.\n\nPrevious status: ${prev_status}"
        body="RAID has recovered.

Previous status: ${prev_status}"
        send_email "$subject" "$body"
    fi

    echo "$status" > "$STATE_FILE"
fi

exit $status_code
