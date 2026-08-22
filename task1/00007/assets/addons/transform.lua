local function duration_seconds(value)
  if value == nil then
    return 0
  end

  local text = tostring(value)
  local milliseconds = string.match(text, "^([0-9.]+)ms$")
  if milliseconds ~= nil then
    return tonumber(milliseconds) / 1000
  end

  local seconds = string.match(text, "^([0-9.]+)s$")
  if seconds ~= nil then
    return tonumber(seconds)
  end

  return tonumber(text) or 0
end

function normalize_metrics(tag, timestamp, record)
  record["duration_seconds"] = duration_seconds(record["duration"])
  return 1, timestamp, record
end

function normalize_cloudwatch(tag, timestamp, record)
  local normalized = {
    timestamp = record["timestamp"] or os.date("!%Y-%m-%dT%H:%M:%SZ"),
    method = record["method"] or "UNKNOWN",
    path = record["path"] or "UNKNOWN",
    status_code = tonumber(record["status_code"] or record["status"]) or 0,
    client_ip = record["client_ip"] or "0.0.0.0"
  }
  return 1, timestamp, normalized
end
