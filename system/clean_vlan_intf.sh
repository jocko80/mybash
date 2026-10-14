#!/bin/bash
PHYS_IF="enp4s0"
# Удалит интерфейсы .200, .3, .1
for id in 200 3 1; do
    vlan_if="${PHYS_IF}.${id}"
    if ip link show dev "$vlan_if" > /dev/null 2>&1; then
        echo "Удаление $vlan_if..."
        sudo ip link delete "$vlan_if"
    fi
done
