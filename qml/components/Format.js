.pragma library

// Touchscreen layout density (1280x800). Import as `Fmt` in QML.
var pageMargin = 12
var pageSpacing = 10
var panelMargin = 10
var panelSpacing = 8
var gridSpacing = 8
var tileMargin = 8
var actionButtonHeight = 40
var selectorButtonHeight = 44

// Internal: split a raw OpenHAB state into { number, unit } when possible.
// Returns null when the state cannot be parsed as a leading number.
function _split(state) {
    if (state === null || state === undefined) {
        return null
    }
    var raw = String(state).trim()
    if (raw.length === 0) {
        return null
    }
    var m = raw.match(/^(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)\s*(.*)$/)
    if (!m) {
        return null
    }
    var n = Number(m[1])
    if (isNaN(n)) {
        return null
    }
    return { number: n, unit: (m[2] || "").trim() }
}

function _toFixed(value, decimals) {
    if (decimals === undefined || decimals === null || decimals < 0) {
        decimals = 0
    }
    return value.toFixed(decimals)
}

function _passThrough(state) {
    return (state === null || state === undefined) ? "" : String(state)
}

function _twoDigits(value) {
    var n = Math.floor(Math.abs(value))
    return n < 10 ? ("0" + n) : String(n)
}

function _hoursMinutes(totalMinutes) {
    if (!isFinite(totalMinutes)) {
        return ""
    }
    var minutes = Math.max(0, Math.floor(totalMinutes))
    var daysPart = Math.floor(minutes / (24 * 60))
    minutes = minutes % (24 * 60)
    var hoursPart = Math.floor(minutes / 60)
    var minsPart = minutes % 60
    var hhmm = _twoDigits(hoursPart) + ":" + _twoDigits(minsPart)
    if (daysPart > 0) {
        return daysPart + "d " + hhmm
    }
    return hhmm
}

function _parseDurationMinutes(raw) {
    var text = String(raw).trim().toLowerCase()
    if (text.length === 0) {
        return NaN
    }

    var colon = text.match(/^(\d{1,3}):(\d{1,2})(?::\d{1,2})?$/)
    if (colon) {
        return Number(colon[1]) * 60 + Number(colon[2])
    }

    var compact = text.match(/^(\d+(?:\.\d+)?)\s*(s|sec|secs|second|seconds|min|mins|minute|minutes|h|hr|hrs|hour|hours)$/)
    if (compact) {
        var amount = Number(compact[1])
        var unit = compact[2]
        if (unit.indexOf("h") === 0) {
            return amount * 60
        }
        if (unit.indexOf("s") === 0) {
            return amount / 60
        }
        return amount
    }

    var spaced = text.match(/(\d+(?:\.\d+)?)\s*(h|hr|hrs|hour|hours|min|mins|minute|minutes|s|sec|secs|second|seconds)/g)
    if (spaced && spaced.length > 0) {
        var minutes = 0
        for (var i = 0; i < spaced.length; ++i) {
            var chunk = spaced[i].match(/(\d+(?:\.\d+)?)\s*(h|hr|hrs|hour|hours|min|mins|minute|minutes|s|sec|secs|second|seconds)/)
            if (!chunk) {
                continue
            }
            var value = Number(chunk[1])
            var chunkUnit = chunk[2]
            if (chunkUnit.indexOf("h") === 0) {
                minutes += value * 60
            } else if (chunkUnit.indexOf("s") === 0) {
                minutes += value / 60
            } else {
                minutes += value
            }
        }
        return minutes
    }

    var parsed = _split(text)
    if (!parsed) {
        return NaN
    }
    if (parsed.unit === "s") {
        return parsed.number / 60
    }
    if (parsed.unit === "h") {
        return parsed.number * 60
    }
    if (parsed.unit === "min" || parsed.unit === "m") {
        return parsed.number
    }
    if (parsed.unit.length === 0) {
        // For plain numeric duration items (like Fritzbox uptime counters),
        // treat the value as seconds.
        return parsed.number / 60
    }
    return NaN
}

function hhmm(state) {
    if (state === null || state === undefined) {
        return ""
    }
    var raw = String(state).trim()
    if (raw.length === 0) {
        return ""
    }

    var date = new Date(raw)
    if (!isNaN(date.getTime()) && (raw.indexOf("T") >= 0 || raw.indexOf("-") >= 0 || raw.indexOf("/") >= 0)) {
        return _twoDigits(date.getHours()) + ":" + _twoDigits(date.getMinutes())
    }

    var hm = raw.match(/^(\d{1,3}):(\d{1,2})(?::\d{1,2})?$/)
    if (hm) {
        return _twoDigits(Number(hm[1])) + ":" + _twoDigits(Number(hm[2]))
    }

    var durationMinutes = _parseDurationMinutes(raw)
    if (isFinite(durationMinutes)) {
        return _hoursMinutes(durationMinutes)
    }

    return _passThrough(state)
}

function mapValue(state, mapping) {
    var text = _passThrough(state)
    if (!mapping || typeof mapping !== "object") {
        return text
    }
    if (mapping[text] !== undefined) {
        return String(mapping[text])
    }
    var lowered = text.toLowerCase()
    for (var key in mapping) {
        if (!mapping.hasOwnProperty(key)) {
            continue
        }
        if (String(key).toLowerCase() === lowered) {
            return String(mapping[key])
        }
    }
    return text
}

// Generic numeric formatter. Preserves any unit found in the state, otherwise
// falls back to opts.unit. Supports an optional `scale` multiplier.
//
// opts = { decimals: 1, unit: "", scale: 1 }
function format(state, opts) {
    opts = opts || {}
    var parsed = _split(state)
    if (!parsed) {
        return _passThrough(state)
    }

    var decimals = opts.decimals !== undefined ? opts.decimals : 1
    var fallbackUnit = opts.unit !== undefined ? opts.unit : ""
    var scale = opts.scale !== undefined ? opts.scale : 1

    var value = parsed.number * scale
    var unit = parsed.unit.length > 0 ? parsed.unit : fallbackUnit
    return unit.length > 0 ? _toFixed(value, decimals) + " " + unit : _toFixed(value, decimals)
}

function temperature(state, decimals) {
    return format(state, { decimals: decimals !== undefined ? decimals : 1, unit: "\u00B0C" })
}

function humidity(state, decimals) {
    return format(state, { decimals: decimals !== undefined ? decimals : 0, unit: "%" })
}

function power(state, decimals) {
    return format(state, { decimals: decimals !== undefined ? decimals : 0, unit: "W" })
}

function energy(state, decimals) {
    return format(state, { decimals: decimals !== undefined ? decimals : 2, unit: "kWh" })
}

// Treats unitless 0..1 values as fractions, scaling them to a percentage.
// Values that already look like percentages (anything > 1, or anything with a
// unit) are formatted untouched.
function fraction(state, decimals) {
    var parsed = _split(state)
    if (!parsed) {
        return _passThrough(state)
    }
    if (decimals === undefined) {
        decimals = 1
    }
    var value = asPercentValue(parsed.number, state, false)
    var unit = parsed.unit
    if (unit.length === 0) {
        unit = "%"
    }
    return _toFixed(value, decimals) + " " + unit
}

// Normalise OpenHAB/evcc style 0..1 fractions to 0..100 percent display.
// "1" / "1.0" -> 100, "0.85" -> 85, "100" / "100 %" stay unchanged.
function asPercentValue(number, raw, forceFraction) {
    if (number === null || number === undefined || isNaN(number)) {
        return number
    }
    var parsed = _split(raw)
    var unit = parsed ? parsed.unit : ""
    if (forceFraction) {
        return number * 100
    }
    if (unit === "%") {
        return number
    }
    if (unit.length === 0 && number >= 0 && number <= 1) {
        return number * 100
    }
    return number
}

// Applies a named formatter ("temperature", "humidity", "power", "energy",
// "fraction") or a manual { unit, decimals } pair. Falls back to `smart`
// when no hint is given. Used by control tiles that accept a `format`,
// `unit`, or `decimals` option.
function apply(state, opts) {
    opts = opts || {}
    var named = opts.format
    var mapped = opts.valueMap !== undefined ? mapValue(state, opts.valueMap) : state
    if (named) {
        switch (String(named).toLowerCase()) {
        case "temperature": return temperature(mapped, opts.decimals)
        case "humidity":    return humidity(mapped, opts.decimals)
        case "power":       return power(mapped, opts.decimals)
        case "energy":      return energy(mapped, opts.decimals)
        case "fraction":    return fraction(mapped, opts.decimals)
        case "hhmm":        return hhmm(mapped)
        }
    }
    if (opts.unit !== undefined && opts.unit !== null) {
        return format(mapped, {
            unit: String(opts.unit),
            decimals: opts.decimals !== undefined ? Number(opts.decimals) : 1,
            scale: opts.scale
        })
    }
    if (opts.decimals !== undefined && opts.decimals !== null) {
        return format(mapped, { decimals: Number(opts.decimals), scale: opts.scale })
    }
    if (opts.valueMap !== undefined) {
        return _passThrough(mapped)
    }
    return smart(mapped)
}

// Best-effort formatter for the generic ControlsPanel. Leaves strings like
// "ON" / "OFF" / "UP" untouched, and rounds numeric states sensibly.
function smart(state) {
    if (state === null || state === undefined) {
        return ""
    }
    var raw = String(state).trim()
    if (raw.length === 0) {
        return ""
    }

    // Recognise non-numeric tokens (ON, OFF, UP, OPEN, HOME, ...) and pass
    // them through verbatim so toggles render their original label.
    if (!/^-?\d/.test(raw)) {
        return raw
    }

    var parsed = _split(raw)
    if (!parsed) {
        return raw
    }

    var value = parsed.number
    var unit = parsed.unit

    if (unit.length === 0) {
        if (value >= 0 && value <= 1 && value !== Math.floor(value)) {
            return _toFixed(value * 100, 1) + " %"
        }
        if (value === Math.floor(value)) {
            return String(value)
        }
        return _toFixed(value, 1)
    }

    var decimals = 1
    if (unit === "W" || unit === "VA" || unit === "A" || unit === "V") {
        decimals = 0
    } else if (unit === "kWh" || unit === "Wh") {
        decimals = 2
    } else if (unit === "%") {
        decimals = 1
    } else if (unit === "s" || unit === "min" || unit === "h") {
        decimals = 0
    }
    return _toFixed(value, decimals) + " " + unit
}

// Dashboard JSON arrays arrive from C++ as QVariantList: array-like in QML but
// Array.isArray() is false, so always normalize before using as a Repeater model.
function asArray(value) {
    if (value === undefined || value === null) {
        return []
    }
    if (Array.isArray(value)) {
        return value
    }
    if (typeof value === "object" && typeof value.length === "number") {
        var out = []
        for (var i = 0; i < value.length; ++i) {
            out.push(value[i])
        }
        return out
    }
    return []
}
