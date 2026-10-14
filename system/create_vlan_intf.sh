#!/bin/bash
# Скрипт для создания интерфейсов на компе
#
# Массив с настройками VLAN в формате: "ID:IP_АДРЕС:ИМЯ_ДЛЯ_КОММЕНТАРИЯ"
VLANS=(
  "200:172.27.65.212/16:vlan200_lan"
  "3:172.23.192.212/16:vlan3_mgmt"
  "1:172.30.192.212/16:vlan_old_lan"
  )

PHYS_IF="enp4s0"
GATEWAY="172.27.0.1"

echo "=== Запуск настройки VLAN на интерфейсе $PHYS_IF ==="

for vlan in "${VLANS[@]}"; do 
  IFS=":" read -r vlan_id ip_addr comment <<< "$vlan"

  vlan_if="${PHYS_IF}.${vlan_id}"
  echo "Создание VLAN $vlan_id ($comment) -> $vlan_if c IP $ip_addr"

  sudo ip link add link "$PHYS_IF" name "$vlan_if" type vlan id "$vlan_id"
  sudo ip link set dev "$vlan_if" up
  sudo ip addr add "$ip_addr" dev "$vlan_if"

done

# Добавление шлюза по умолчанию (только после того, как поднялся enp4s0.200)
echo "=== Настройка маршрутизации ==="
if ip link show dev "${PHYS_IF}.200" > /dev/null 2>&1; then
    echo "Добавление шлюза по умолчанию через ${PHYS_IF}.200..."
    sudo ip route add default via "$GATEWAY" dev "${PHYS_IF}.200"
else
    echo "Ошибка: Интерфейс ${PHYS_IF}.200 не найден, шлюз не установлен!"
fi

echo "=== Настройка завершена ==="
