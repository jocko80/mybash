#!/bin/bash
# ============================================================
# Мониторинг RAID и SMART через Adaptec arcconf
#
# Использование:
#   ./check_raid_adaptec.sh              # Показать всё (RAID + PD + SMART)
#   ./check_raid_adaptec.sh -raid        # Только RAID статус
#   ./check_raid_adaptec.sh -pd          # Только физические диски
#   ./check_raid_adaptec.sh -smart       # Только SMART статус
#   ./check_raid_adaptec.sh -full        # Показать всё (полный вывод)
#   ./check_raid_adaptec.sh -h --help    # Показать помощь
# ============================================================

ARCCONF="/usr/StorMan/arcconf"

# Цвета
RED='\033[91m'
GREEN='\033[92m'
YELLOW='\033[93m'
BLUE='\033[94m'
RESET='\033[0m'

# ===================== ФУНКЦИИ ==============================

show_help() {
    echo -e "${BLUE}Использование:${RESET} $0 [ОПЦИИ]

${BLUE}Опции:${RESET}
  -raid, --raid      Показать статус RAID массивов (LD)
  -pd, --pd          Показать статус физических дисков (PD)
  -smart, --smart    Показать SMART статус дисков
  -full, --full      Показать всё (по умолчанию)
  -h, --help         Показать эту справку

${BLUE}Примеры:${RESET}
  $0                 # Показать всё
  $0 -smart          # Только SMART
  $0 -raid -pd       # RAID + физические диски
  $0 -full           # Полный вывод

${BLUE}Цвета вывода:${RESET}
  ${GREEN}Зелёный${RESET}  — OK / Online / Optimal
  ${YELLOW}Жёлтый${RESET}   — Rebuilding / Предупреждение
  ${RED}Красный${RESET}    — Degraded / Failed / Ошибка"
    exit 0
}

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${BLUE}  $1${RESET}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${RESET}"
}

show_raid() {
    echo -e "\n${BLUE}=== СТАТУС RAID МАССИВОВ (LD) ===${RESET}"

    "$ARCCONF" GETCONFIG 1 LD 2>/dev/null | while IFS= read -r line; do
        if echo "$line" | grep -q "Logical device number"; then
            echo -e "\n${BLUE}$line${RESET}"
        elif echo "$line" | grep -q "Status of logical device"; then
            if echo "$line" | grep -qi "Optimal"; then
                echo -e "${GREEN}$line${RESET}"
            elif echo "$line" | grep -qi "Degraded"; then
                echo -e "${RED}$line${RESET}"
            else
                echo -e "${YELLOW}$line${RESET}"
            fi
        elif echo "$line" | grep -q "Segment"; then
            if echo "$line" | grep -q "Inconsistent\|Missing"; then
                echo -e "${RED}$line${RESET}"
            elif echo "$line" | grep -q "Rebuilding"; then
                echo -e "${YELLOW}$line${RESET}"
            else
                echo -e "${GREEN}$line${RESET}"
            fi
        else
            echo "$line"
        fi
    done
}

show_pd() {
    echo -e "\n${BLUE}=== ФИЗИЧЕСКИЕ ДИСКИ (PD) ===${RESET}"

    "$ARCCONF" GETCONFIG 1 PD 2>/dev/null | while IFS= read -r line; do
        if echo "$line" | grep -q "Device #"; then
            echo -e "\n${BLUE}$line${RESET}"
        elif echo "$line" | grep -q "State"; then
            if echo "$line" | grep -qi "Online"; then
                echo -e "${GREEN}$line${RESET}"
            elif echo "$line" | grep -qi "Failed\|Missing"; then
                echo -e "${RED}$line${RESET}"
            else
                echo -e "${YELLOW}$line${RESET}"
            fi
        else
            echo "$line"
        fi
    done
}

show_smart() {
    echo -e "\n${BLUE}=== SMART-СТАТУС ДИСКОВ ===${RESET}"

    "$ARCCONF" GETSMARTSTATS 1 2>/dev/null | while IFS= read -r line; do
        echo "$line"
    done
}


show_default() {
    print_header "СТАТУС КОНТРОЛЛЕРА ADAPTEC (RAID + PD)"
    echo "Время: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Хост: $(hostname)"

    show_raid
    show_pd

    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${GREEN}✅ Проверка завершена${RESET}"
    echo -e "${YELLOW}💡 Для просмотра SMART используйте: $0 -smart${RESET}"
    echo -e "${YELLOW}💡 Для полного вывода используйте: $0 -full${RESET}"
}


show_full() {
    print_header "РАЗВЁРНУТЫЙ СТАТУС КОНТРОЛЛЕРА ADAPTEC"
    echo "Контроллер: Adaptec 5805Z"
    echo "Время: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Хост: $(hostname)"

    show_raid
    show_pd
    show_smart

    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${GREEN}✅ Проверка завершена${RESET}"
}

# ===================== ОСНОВНАЯ ЛОГИКА =========================

# Проверки
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Ошибка: Запустите от root${RESET}" >&2
    exit 3
fi

if [ ! -x "$ARCCONF" ]; then
    echo -e "${RED}Ошибка: arcconf не найден: $ARCCONF${RESET}" >&2
    exit 4
fi

# Нет аргументов — показываем всё
if [ $# -eq 0 ]; then
    show_default
    exit 0
fi

# Обработка аргументов
show_raid=false
show_pd=false
show_smart=false
show_full=false

while [ $# -gt 0 ]; do
    case "$1" in
        -raid|--raid)
            show_raid=true
            shift
            ;;
        -pd|--pd)
            show_pd=true
            shift
            ;;
        -smart|--smart)
            show_smart=true
            shift
            ;;
        -full|--full)
            show_full=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo -e "${RED}Неизвестная опция: $1${RESET}" >&2
            echo "Используйте $0 --help для справки"
            exit 1
            ;;
    esac
done

# Если выбран -full, показываем всё
if [ "$show_full" = true ]; then
    show_full
    exit 0
fi

# Показываем выбранные разделы
print_header "СТАТУС КОНТРОЛЛЕРА ADAPTEC"

[ "$show_raid" = true ] && show_raid
[ "$show_pd" = true ] && show_pd
[ "$show_smart" = true ] && show_smart

echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}✅ Проверка завершена${RESET}"
