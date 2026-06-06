import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "components"

ApplicationWindow {
    id: root

    width: 1280
    height: 800
    visible: true
    visibility: Window.FullScreen
    title: "HomeUI"
    color: "#070d18"
    property int maxDebugEvents: 300
    property string doorbellItemName: "Doorbell_Pressed"
    property bool lastDoorbellPressed: false
    readonly property bool blackoutActive: (typeof screenIdle !== "undefined")
            && (screenIdle.nightModeActive
                || (screenIdle.idle && screenIdle.idleBrightness <= 0))
    readonly property string doorbellStreamUrl: {
        var _ = dashboardConfig.revision
        return resolveDoorbellStreamUrl()
    }

    function resolveDoorbellStreamUrl() {
        if (!dashboardConfig.valid || !dashboardConfig.pages) {
            return ""
        }

        function firstDoorbellCamera(panels) {
            if (!panels) {
                return ""
            }
            for (var i = 0; i < panels.length; ++i) {
                var panel = panels[i]
                if (!panel || panel.type !== "camera") {
                    continue
                }
                var title = String(panel.title || "").toLowerCase()
                var stream = String(panel.streamUrl || "")
                if (stream.length === 0) {
                    continue
                }
                if (title.indexOf("tuerklingel") !== -1 || title.indexOf("doorbell") !== -1) {
                    return stream
                }
            }
            return ""
        }

        for (var p = 0; p < dashboardConfig.pages.length; ++p) {
            var page = dashboardConfig.pages[p]
            if (!page) {
                continue
            }

            var direct = firstDoorbellCamera(page.panels)
            if (direct.length > 0) {
                return direct
            }

            if (page.columns) {
                for (var c = 0; c < page.columns.length; ++c) {
                    var column = page.columns[c]
                    var nested = firstDoorbellCamera(column ? column.panels : null)
                    if (nested.length > 0) {
                        return nested
                    }
                }
            }
        }

        return ""
    }

    function appendRawEvent(rawEvent) {
        if (!rawEvent || rawEvent.length === 0) {
            return
        }

        debugEventModel.insert(0, {
            "timestamp": new Date().toLocaleTimeString(Qt.locale(), "HH:mm:ss"),
            "payload": rawEvent
        })

        while (debugEventModel.count > maxDebugEvents) {
            debugEventModel.remove(debugEventModel.count - 1)
        }
    }

    function currentPageTitle() {
        if (!dashboardConfig.valid || dashboardConfig.pages.length === 0) {
            return "CONFIG"
        }

        return dashboardConfig.pages[Math.min(swipeView.currentIndex, dashboardConfig.pages.length - 1)].title
    }

    function currentPageId() {
        if (!dashboardConfig.valid || dashboardConfig.pages.length === 0) {
            return ""
        }
        var page = dashboardConfig.pages[Math.min(swipeView.currentIndex, dashboardConfig.pages.length - 1)]
        return page.id || page.title || String(swipeView.currentIndex)
    }

    function setPageById(identifier) {
        if (!identifier || !dashboardConfig.valid) {
            return
        }
        var idx = parseInt(identifier)
        if (!isNaN(idx) && idx >= 0 && idx < dashboardConfig.pages.length) {
            swipeView.currentIndex = idx
            return
        }
        for (var i = 0; i < dashboardConfig.pages.length; ++i) {
            var page = dashboardConfig.pages[i]
            if (page.id === identifier || page.title === identifier) {
                swipeView.currentIndex = i
                return
            }
        }
    }

    function publishCurrentPageStatus() {
        if (mqttClient && mqttClient.setStatusField) {
            mqttClient.setStatusField("page", currentPageId())
        }
    }

    // Helpers for status bar activity indicators. They read openhabClient and
    // depend on stateRevision so QML re-evaluates them on every state change.
    function _evccCharging() {
        var _ = openhabClient.stateRevision
        return openhabClient.itemIsOn("evcc_loadpoint0_charging", false)
    }

    function _robotRunning() {
        var _ = openhabClient.stateRevision
        var state = (openhabClient.itemState("GF_robi_command", "") || "").toLowerCase().trim()
        // EG Robi Ecovacs command/status values: "charge"/"pause" = idle,
        // "clean"/"cleaning"/area modes = running.
        return state === "vacuum" || state === "clean" || state === "cleaning"
                || state === "spot" || state === "spotarea"
                || state === "customarea" || state === "sceneclean"
    }

    function _irrigationRunning() {
        var _ = openhabClient.stateRevision
        var valves = ["gardena_ventil1_activity", "gardena_ventil2_activity", "gardena_ventil3_activity"]
        for (var i = 0; i < valves.length; ++i) {
            var v = (openhabClient.itemState(valves[i], "") || "").toUpperCase().trim()
            // Gardena valve activities: "CLOSED" = idle, "MANUAL_WATERING"/"SCHEDULED_WATERING" = running
            if (v && v !== "CLOSED" && v !== "NULL" && v !== "UNDEF") {
                return true
            }
        }
        var pump = (openhabClient.itemState("gardena_pumpe_activity", "") || "").toUpperCase().trim()
        if (pump && pump !== "OFF" && pump !== "NULL" && pump !== "UNDEF") {
            return true
        }
        if (openhabClient.itemIsOn("gardena_start_irrigation_switch", false)) {
            return true
        }
        return false
    }

    function _thzHeating() {
        var _ = openhabClient.stateRevision
        return openhabClient.itemIsOn("thz_heizen", false)
    }

    function _thzHotWater() {
        var _ = openhabClient.stateRevision
        return openhabClient.itemIsOn("thz_warmwasserbereitung", false)
    }

    Shortcut {
        sequences: ["Ctrl+Q", "Esc"]
        context: Qt.ApplicationShortcut
        onActivated: Qt.quit()
    }

    Connections {
        target: mqttClient
        ignoreUnknownSignals: true
        function onPageSetRequested(page) { root.setPageById(page) }
        function onConnectedChanged() {
            if (mqttClient.connected) {
                root.publishCurrentPageStatus()
            }
        }
    }

    Connections {
        target: openhabClient
        ignoreUnknownSignals: true
        function onRawEventReceived(rawEvent) {
            root.appendRawEvent(rawEvent)
        }
        function onItemStateChanged(itemName, state) {
            if (itemName !== root.doorbellItemName) {
                return
            }
            var pressed = String(state || "").toUpperCase() === "ON"
            if (pressed && !root.lastDoorbellPressed) {
                doorbellPopup.open()
                doorbellAutoClose.restart()
            } else if (!pressed && root.lastDoorbellPressed) {
                doorbellAutoClose.restart()
            }
            root.lastDoorbellPressed = pressed
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#070d18"
    }

    StatusBar {
        id: statusBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        title: "OPENHAB"
        section: root.currentPageTitle()
        openhabConnected: openhabClient.connected
        eventStreamConnected: openhabClient.eventStreamConnected
        itemCount: openhabClient.itemCount
        statusText: openhabClient.statusText
        indicators: [
            { "label": "OH",   "state": openhabClient.connected ? "ok" : "warn" },
            { "label": "LIVE", "state": openhabClient.eventStreamConnected ? "ok" : "warn" },
            { "label": "CAR",  "state": root._evccCharging() ? "active" : "idle" },
            { "label": "ROBI", "state": root._robotRunning() ? "active" : "idle" },
            { "label": "BEW",  "state": root._irrigationRunning() ? "active" : "idle" },
            { "label": "HEIZ", "state": root._thzHeating() ? "active" : "idle" },
            { "label": "WW",   "state": root._thzHotWater() ? "active" : "idle" }
        ]
        showDebugButton: true
        debugActive: debugModal.visible
        showPageNav: dashboardConfig.valid && dashboardConfig.pages.length > 1
        pageCount: dashboardConfig.valid ? dashboardConfig.pages.length : 0
        pageIndex: swipeView.currentIndex
        onDebugClicked: debugModal.open()
    }

    ListModel {
        id: debugEventModel
    }

    Popup {
        id: debugModal
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(root.width - 40, 1040)
        height: Math.min(root.height - 70, 640)
        anchors.centerIn: Overlay.overlay
        padding: 0

        background: Rectangle {
            radius: 12
            color: "#0f172a"
            border.color: "#334155"
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "OpenHAB raw events (" + debugEventModel.count + ")"
                    color: "#f8fafc"
                    font.pixelSize: 16
                    font.bold: true
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 88
                    height: 30
                    radius: 8
                    color: "#334155"

                    Text {
                        anchors.centerIn: parent
                        text: "Clear"
                        color: "#e2e8f0"
                        font.pixelSize: 12
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: debugEventModel.clear()
                    }
                }

                Rectangle {
                    width: 92
                    height: 30
                    radius: 8
                    color: "#7f1d1d"

                    Text {
                        anchors.centerIn: parent
                        text: "Quit app"
                        color: "#fee2e2"
                        font.pixelSize: 12
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Qt.quit()
                    }
                }

                Rectangle {
                    width: 88
                    height: 30
                    radius: 8
                    color: "#475569"

                    Text {
                        anchors.centerIn: parent
                        text: "Close"
                        color: "#f8fafc"
                        font.pixelSize: 12
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: debugModal.close()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: "#020617"
                border.color: "#1e293b"

                ListView {
                    id: debugEventList
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true
                    spacing: 6
                    model: debugEventModel

                    delegate: Rectangle {
                        required property string timestamp
                        required property string payload
                        width: debugEventList.width
                        color: "#0b1220"
                        radius: 6
                        border.color: "#1f2b3d"
                        border.width: 1
                        implicitHeight: eventText.implicitHeight + 12

                        Text {
                            id: eventText
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 6
                            text: "[" + timestamp + "] " + payload
                            color: "#cbd5e1"
                            font.pixelSize: 12
                            font.family: "monospace"
                            wrapMode: Text.WrapAnywhere
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: doorbellAutoClose
        interval: 20000
        repeat: false
        onTriggered: doorbellPopup.close()
    }

    Popup {
        id: doorbellPopup
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(root.width - 60, 920)
        height: Math.min(root.height - 80, 560)
        anchors.centerIn: Overlay.overlay
        padding: 0
        z: 40

        background: Rectangle {
            radius: 14
            color: "#020617"
            border.color: "#38bdf8"
            border.width: 2
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Doorbell"
                    color: "#e2e8f0"
                    font.pixelSize: 18
                    font.bold: true
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 94
                    height: 32
                    radius: 8
                    color: "#1e293b"
                    border.color: "#475569"

                    Text {
                        anchors.centerIn: parent
                        text: "Close"
                        color: "#f8fafc"
                        font.pixelSize: 12
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: doorbellPopup.close()
                    }
                }
            }

            CameraTile {
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: (typeof screenIdle !== "undefined") ? !screenIdle.nightModeActive : true
                title: "Tuerklingel"
                location: "Einfahrt"
                streamUrl: root.doorbellStreamUrl
                streamFormat: "mjpeg"
                refreshInterval: 1000
            }
        }
    }

    SwipeView {
        id: swipeView
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: statusBar.bottom
        anchors.bottom: parent.bottom
        clip: true
        interactive: dashboardConfig.valid && dashboardConfig.pages.length > 1
        visible: dashboardConfig.valid

        Repeater {
            model: dashboardConfig.pages

            ConfiguredPage {
                page: modelData
                openhab: openhabClient
                sonos: sonosClient
                mqtt: mqttClient
                pageCurrent: swipeView.currentIndex === index
                pageNear: Math.abs(swipeView.currentIndex - index) <= 1
            }
        }

        onCurrentIndexChanged: root.publishCurrentPageStatus()
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: statusBar.bottom
        anchors.bottom: parent.bottom
        visible: !dashboardConfig.valid
        color: "#070d18"

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 820)
            height: Math.min(parent.height - 80, 260)
            radius: 18
            color: "#2a2230"
            border.color: "#f59e0b"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 14

                Text {
                    text: "Dashboard config error"
                    color: "#fbbf24"
                    font.pixelSize: 24
                    font.bold: true
                    Layout.fillWidth: true
                }

                Text {
                    text: dashboardConfig.errorText
                    color: "#f8fafc"
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                Rectangle {
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 42
                    radius: 10
                    color: "#f59e0b"

                    Text {
                        anchors.centerIn: parent
                        text: "Reload config"
                        color: "#111827"
                        font.pixelSize: 13
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: dashboardConfig.reload()
                    }
                }
            }
        }
    }

    Rectangle {
        id: sleepBlackout
        anchors.fill: parent
        visible: root.blackoutActive
        z: 9999
        color: "black"

        // First touch/key should wake the panel without activating underlying UI.
        MouseArea {
            anchors.fill: parent
            onPressed: {
                if (typeof screenIdle !== "undefined") {
                    screenIdle.wake()
                }
                mouse.accepted = true
            }
        }

        Keys.onPressed: {
            if (typeof screenIdle !== "undefined") {
                screenIdle.wake()
            }
            event.accepted = true
        }
        focus: visible
    }

}
