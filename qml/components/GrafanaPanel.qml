import QtQuick
import QtQuick.Layouts
import "Format.js" as Fmt
import QtQuick.Window

Rectangle {
    id: root

    // ---- Public configuration (mirrors the panel JSON) ---------------------
    property string title: "Grafana"
    property string baseUrl: ""           // e.g. "http://192.168.0.95:3000"
    property string dashboardUid: ""      // e.g. "cdnrwiq71tc74c"
    property string slug: "dashboard"     // dashboard URL slug, anything non-empty works
    property int panelId: 0               // single panel id (>=1) for /render/d-solo
    property int orgId: 1
    property string theme: "dark"         // "dark" | "light"
    property string from: "now-2d"
    property string to: "now"
    property string timezone: ""          // "Europe/Berlin" -> Grafana ?tz= parameter; empty = server default
    property int refreshInterval: 60      // seconds between PNG refreshes
    property real renderScale: 1.0        // upscale factor for Hi-DPI panels (Grafana ?scale=)
    property var extraParams: ({})        // arbitrary additional ?key=value query parameters
    property bool active: true            // false when SwipeView page is off-screen

    // ---- Internal state ----------------------------------------------------
    property string _heldSource: ""
    property int _cacheBuster: 0
    property int _renderWidth: 0
    property int _renderHeight: 0
    property bool _missingConfig: !baseUrl || baseUrl.length === 0 || !dashboardUid || dashboardUid.length === 0 || panelId <= 0

    function _stripTrailingSlash(url) {
        var s = String(url || "")
        while (s.length > 0 && s.charAt(s.length - 1) === "/") {
            s = s.substring(0, s.length - 1)
        }
        return s
    }

    function _encodedSlug() {
        var raw = (slug && slug.length > 0) ? slug : "dashboard"
        return encodeURIComponent(raw)
    }

    function _computeUrl() {
        if (_missingConfig || _renderWidth <= 0 || _renderHeight <= 0) {
            return ""
        }
        var base = _stripTrailingSlash(baseUrl)
        var path = base + "/render/d-solo/" + encodeURIComponent(dashboardUid) + "/" + _encodedSlug()
        var params = []
        params.push("orgId=" + encodeURIComponent(orgId))
        params.push("panelId=" + encodeURIComponent(panelId))
        params.push("theme=" + encodeURIComponent(theme || "dark"))
        if (from && from.length > 0) {
            params.push("from=" + encodeURIComponent(from))
        }
        if (to && to.length > 0) {
            params.push("to=" + encodeURIComponent(to))
        }
        if (timezone && timezone.length > 0) {
            params.push("tz=" + encodeURIComponent(timezone))
        }
        if (renderScale && renderScale > 0 && renderScale !== 1) {
            params.push("scale=" + encodeURIComponent(renderScale))
        }
        // Render-time pixel dimensions. Multiply by devicePixelRatio so the
        // PNG arrives sharp on the actual screen pixel grid.
        var dpr = Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1.0
        params.push("width=" + Math.max(160, Math.round(_renderWidth * dpr)))
        params.push("height=" + Math.max(120, Math.round(_renderHeight * dpr)))

        if (extraParams && typeof extraParams === "object") {
            for (var key in extraParams) {
                if (!extraParams.hasOwnProperty(key)) continue
                var value = extraParams[key]
                if (value === undefined || value === null) continue
                if (Array.isArray(value)) {
                    for (var i = 0; i < value.length; ++i) {
                        params.push(encodeURIComponent(key) + "=" + encodeURIComponent(value[i]))
                    }
                } else {
                    params.push(encodeURIComponent(key) + "=" + encodeURIComponent(value))
                }
            }
        }

        params.push("_t=" + _cacheBuster)
        return path + "?" + params.join("&")
    }

    function refresh() {
        _cacheBuster = Date.now()
    }

    // ---- Visual styling ----------------------------------------------------
    implicitWidth: 420
    implicitHeight: 280
    radius: 18
    color: "#0f1726"
    border.color: "#26364d"
    border.width: 1
    clip: true

    onWidthChanged: if (root.active) resizeDebounce.restart()
    onHeightChanged: if (root.active) resizeDebounce.restart()
    Component.onCompleted: if (root.active) resizeDebounce.restart()

    onActiveChanged: {
        if (root.active) {
            resizeDebounce.restart()
        } else if (rendered.source.length > 0) {
            root._heldSource = rendered.source
        }
    }

    Timer {
        id: resizeDebounce
        interval: 500
        repeat: false
        onTriggered: {
            if (!root.active) {
                return
            }
            // Subtract the title bar / margins area from the available render box.
            var w = imageHost.width
            var h = imageHost.height
            if (w !== root._renderWidth || h !== root._renderHeight) {
                root._renderWidth = Math.max(0, Math.floor(w))
                root._renderHeight = Math.max(0, Math.floor(h))
                root.refresh()
            }
        }
    }

    Timer {
        id: refreshTimer
        running: root.active && !root._missingConfig && root.refreshInterval > 0
        repeat: true
        interval: Math.max(5, root.refreshInterval) * 1000
        onTriggered: root.refresh()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Fmt.panelMargin
        spacing: Fmt.panelSpacing

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.title
                color: "#e2e8f0"
                font.pixelSize: 18
                font.bold: true
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: "Panel " + root.panelId
                color: "#8fa4bf"
                font.pixelSize: 11
                visible: !root._missingConfig
            }
        }

        Rectangle {
            id: imageHost
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 14
            color: "#0b1220"
            clip: true

            onWidthChanged: if (root.active) resizeDebounce.restart()
            onHeightChanged: if (root.active) resizeDebounce.restart()

            Image {
                id: rendered
                anchors.fill: parent
                anchors.margins: 1
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                smooth: true
                source: root.active ? root._computeUrl() : root._heldSource
            }

            // Loading overlay
            Rectangle {
                anchors.fill: parent
                visible: rendered.status === Image.Loading
                color: "#990b1220"

                Text {
                    anchors.centerIn: parent
                    text: "Lade Grafana..."
                    color: "#cbd5e1"
                    font.pixelSize: 13
                }
            }

            // Error / misconfigured overlay
            Rectangle {
                anchors.fill: parent
                visible: root._missingConfig || rendered.status === Image.Error
                color: "#2a2230"
                border.color: "#f59e0b"
                border.width: 1
                radius: 14

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Fmt.panelMargin
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: root._missingConfig ? "Grafana nicht konfiguriert"
                                                  : "Grafana Bild konnte nicht geladen werden"
                        color: "#fbbf24"
                        font.pixelSize: 14
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root._missingConfig
                              ? "baseUrl, dashboardUid und panelId muessen gesetzt sein."
                              : rendered.source
                        color: "#fde68a"
                        font.pixelSize: 11
                        wrapMode: Text.WrapAnywhere
                        elide: Text.ElideRight
                    }
                }
            }

            // Status strip at the bottom
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 24
                color: "#990f1726"
                visible: !root._missingConfig

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Fmt.tileMargin
                    anchors.rightMargin: Fmt.tileMargin
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: 4
                        color: rendered.status === Image.Ready ? "#22c55e"
                            : rendered.status === Image.Error ? "#ef4444"
                            : "#fbbf24"
                    }

                    Text {
                        Layout.fillWidth: true
                        color: "#dbeafe"
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        text: {
                            switch (rendered.status) {
                            case Image.Ready:   return "Grafana live"
                            case Image.Loading: return "Lade..."
                            case Image.Error:   return "Fehler beim Laden"
                            default:            return ""
                            }
                        }
                    }

                    Text {
                        color: "#93a4ba"
                        font.pixelSize: 10
                        text: Math.max(5, root.refreshInterval) + " s"
                    }
                }
            }
        }
    }
}
