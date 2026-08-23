#!/bin/bash
set -euo pipefail

raw_fifo=/run/wsc2026-sensor-raw.fifo
rm -f "$raw_fifo"
mkfifo "$raw_fifo"

cleanup() {
  rm -f "$raw_fifo"
  for pid in "${raw_pid:-}"; do
    if [[ -n "$pid" ]]; then
      kill "$pid" 2>/dev/null || true
    fi
  done
}
trap cleanup EXIT

/opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server "$BOOTSTRAP_SERVERS" \
  --producer.config /opt/kafka/client.properties \
  --topic "$TOPIC_RAW" <"$raw_fifo" &
raw_pid=$!

exec 3>"$raw_fifo"

/opt/wsc2026-sensor-producer 2>&1 | while IFS= read -r line; do
  printf '%s\n' "$line"
  if [[ "$line" =~ (SENSOR-[0-9]+):[[:space:]]temp=([0-9.]+).*humidity=([0-9.]+)% ]]; then
    sensor="${BASH_REMATCH[1]}"
    temperature="${BASH_REMATCH[2]}"
    humidity="${BASH_REMATCH[3]}"
    case "$sensor" in
      SENSOR-001) location=factory-a ;;
      SENSOR-002) location=factory-b ;;
      *) location=factory-c ;;
    esac
    timestamp=$(TZ=Asia/Seoul date --iso-8601=seconds)
    printf '{"sensorId":"%s","timestamp":"%s","temperature":%s,"humidity":%s,"location":"%s"}\n' \
      "$sensor" "$timestamp" "$temperature" "$humidity" "$location" >&3

  fi
done
