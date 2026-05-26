.pragma library

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
    var value = parsed.number
    var unit = parsed.unit
    if (unit.length === 0 && value >= 0 && value <= 1) {
        value *= 100
        unit = "%"
    } else if (unit.length === 0) {
        unit = "%"
    }
    return _toFixed(value, decimals) + " " + unit
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
