#!/usr/bin/env bash
ram_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
ram_MB=$(echo "scale=0; ${ram_KB} / 1000" | bc)
  ten_percent_ram_MB=$(echo "scale=0; ${ram_KB} / 10000" | bc)
  twenty_percent_ram_MB=$(echo "scale=0; ${ram_KB} / 5000" | bc)
  thirty_percent_ram_MB=$(echo "scale=0; ${ram_KB} / 3000" | bc)
  fourty_percent_ram_MB=$(echo "scale=0; ${ram_KB} / 2500" | bc)
  fifty_percent_ram_MB=$(echo "scale=0; ${ram_KB} / 2000" | bc)
  sixty_percent_ram_MB=$((thirty_percent_ram_MB + thirty_percent_ram_MB))
  seventy_percent_ram_MB=$((fifty_percent_ram_MB + twenty_percent_ram_MB))
  eighty_percent_ram_MB=$((fifty_percent_ram_MB + thirty_percent_ram_MB))
  ninety_percent_ram_MB=$((fifty_percent_ram_MB + fourty_percent_ram_MB))
  if [[ ${ram_MB} -lt 1500 ]]; then
    mysqlRAM="500"
  fi
  if [[ ${ram_MB} -ge 1500 ]]; then
    mysqlRAM="$(echo "scale=0; ${seventy_percent_ram_MB} / 2" | bc)"
  fi
  if [[ ${ram_MB} -ge 8000 ]]; then
    mysqlRAM="$(echo "scale=0; ${ninety_percent_ram_MB} / 2" | bc)"
  fi
  if [[ ${ram_MB} -ge 16000 ]]; then
    mysqlRAM="${fifty_percent_ram_MB}"
  fi

echo $mysqlRAM