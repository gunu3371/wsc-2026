function normalize_http_duration(tag, timestamp, record)
  local kubernetes = record["kubernetes"]
  if type(kubernetes) ~= "table" or kubernetes["namespace_name"] ~= "wsc2026" then
    return 0, timestamp, record
  end

  local message = tostring(record["log"] or "")
  if record["status"] == nil then
    record["status"] = string.match(message, "status=([1-5][0-9][0-9])")
  end
  if record["duration"] == nil then
    local duration_value, duration_unit = string.match(message, "duration=([0-9.]+)(%S+)")
    if duration_value ~= nil then
      record["duration"] = duration_value .. duration_unit
    end
  end

  local raw = tostring(record["duration"] or "")
  local value, unit = string.match(raw, "^([0-9.]+)(%S+)$")
  if value == nil then
    return 0, timestamp, record
  end

  local factors = {
    ns = 0.000000001,
    us = 0.000001,
    ms = 0.001,
    s = 1,
    m = 60,
    h = 3600,
  }
  unit = string.lower(unit)
  if unit == "µs" or unit == "μs" then
    unit = "us"
  end
  local factor = factors[unit]
  if factor == nil then
    return 0, timestamp, record
  end

  record["duration_seconds"] = tonumber(value) * factor
  record["status"] = tostring(record["status"] or "")
  return 1, timestamp, record
end
