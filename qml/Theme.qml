pragma Singleton
import QtQuick

// Visual tokens for the two dashboard skins.
// "default" keeps the existing dark panels. "lcars" is the Star Trek LCARS skin:
// black ground, flat color blocks, elbow rail, pill controls, condensed caps.
QtObject {
    id: theme

    readonly property int revision: dashboardConfig.revision
    readonly property string name: {
        var _ = theme.revision
        var raw = String(dashboardConfig.theme || "default").toLowerCase()
        return raw === "lcars" ? "lcars" : "default"
    }
    readonly property bool lcars: name === "lcars"

    readonly property string displayTitle: {
        var _ = theme.revision
        var configured = String(dashboardConfig.title || "").trim()
        if (configured.length > 0) {
            return configured
        }
        return lcars ? "HOME OPERATIONS" : "OPENHAB"
    }

    // Antonio (OFL) is the usual open stand-in for Swiss 911 Ultra Compressed.
    // Main.qml assigns this when the bundled face finishes loading.
    property string loadedFontFamily: ""
    readonly property string fontFamily: {
        if (!lcars) {
            return ""
        }
        return loadedFontFamily.length > 0 ? loadedFontFamily : "Arial"
    }

    readonly property color ground: lcars ? "#000000" : "#070d18"
    readonly property color panel: lcars ? "#000000" : "#0f1726"
    readonly property color panelBorder: lcars ? "#000000" : "#26364d"
    readonly property int panelRadius: lcars ? 0 : 18
    readonly property int panelBorderWidth: lcars ? 0 : 1
    readonly property int tileRadius: lcars ? 20 : 12
    readonly property int tileBorderWidth: lcars ? 2 : 1

    readonly property color text: lcars ? "#FFCC66" : "#e2e8f0"
    readonly property color label: lcars ? "#FFCC99" : "#cbd5e1"
    readonly property color value: lcars ? "#FFFF99" : "#f8fafc"
    readonly property color muted: lcars ? "#CC9966" : "#94a3b8"
    readonly property color subtle: lcars ? "#FF9966" : "#8fa4bf"
    readonly property color data: lcars ? "#99CCFF" : "#f8fafc"
    readonly property color onShape: "#000000"

    // Warm structure, cool data. Adjacent rail blocks step through this list.
    readonly property var bars: [
        "#E7B08A",
        "#F0D056",
        "#FF9966",
        "#8EC8EA",
        "#F0D056",
        "#E8B84A",
        "#D7A48A",
        "#CC99CC",
        "#99CCFF",
        "#FFCC99"
    ]

    function barColor(index) {
        var list = bars
        var i = Math.abs(Number(index) || 0) % list.length
        return list[i]
    }

    function accentFor(title) {
        var s = String(title || "")
        var hash = 0
        for (var i = 0; i < s.length; ++i) {
            hash = (hash * 33 + s.charCodeAt(i)) >>> 0
        }
        return barColor(hash)
    }

    function tileFill(active) {
        if (lcars) {
            return "#000000"
        }
        return active ? "#26364d" : "#172235"
    }

    function tileStroke(active, accent) {
        if (!lcars) {
            return active ? (accent || "#f59e0b") : "#304158"
        }
        return active ? "#FFCC66" : "#FF9966"
    }
}
