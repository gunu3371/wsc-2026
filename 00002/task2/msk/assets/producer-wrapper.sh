#!/bin/bash
set -euo pipefail

raw_fifo=/run/wsc2026-sensor-raw.fifo
alert_fifo=/run/wsc2026-sensor-alert.fifo
rm -f "$raw_fifo" "$alert_fifo"
mkfifo "$raw_fifo" "$alert_fifo"

cleanup() {
  rm -f "$raw_fifo" "$alert_fifo"
  for pid in "${raw_pid:-}" "${alert_pid:-}"; do
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

/opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server "$BOOTSTRAP_SERVERS" \
  --producer.config /opt/kafka/client.properties \
  --topic "$TOPIC_ALERT" <"$alert_fifo" &
alert_pid=$!

exec 3>"$raw_fifo"
exec 4>"$alert_fifo"

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

    reason=""
    awk "BEGIN { exit !($temperature > 80) }" && reason="Temperature exceeded threshold: ${temperature}C"
    awk "BEGIN { exit !($temperature < 10) }" && reason="Temperature below threshold: ${temperature}C"
    awk "BEGIN { exit !($humidity > 90) }" && reason="Humidity exceeded threshold: ${humidity}%"
    awk "BEGIN { exit !($humidity < 20) }" && reason="Humidity below threshold: ${humidity}%"
    if [[ -n "$reason" ]]; then
      printf '{"sensorId":"%s","timestamp":"%s","temperature":%s,"humidity":%s,"location":"%s","status":"ALERT","alert_reason":"%s"}\n' \
        "$sensor" "$timestamp" "$temperature" "$humidity" "$location" "$reason" >&4
    fi
  fi
done
