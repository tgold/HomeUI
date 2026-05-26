import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string title: "Kamera"
    property string location: ""
    property string streamUrl: ""
    property string snapshotUrl: ""
    property int refreshInterval: 1000
    property string streamFormat: ""
    property bool ignoreSslErrors: false

    readonly property string effectiveFormat: {
        if (streamFormat && streamFormat.length > 0) {
            return streamFormat.toLowerCase()
        }
        if (streamUrl && streamUrl.length > 0) {
            return "mjpeg"
        }
        if (snapshotUrl && snapshotUrl.length > 0) {
            return "snapshot"
        }
        return "placeholder"
    }

    implicitWidth: 420
    implicitHeight: 260
    radius: 18
    color: "#0f1726"
    border.color: "#26364d"
    border.width: 1
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

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
                text: root.location
                color: "#8fa4bf"
                font.pixelSize: 12
                visible: root.location.length > 0
                elide: Text.ElideRight
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 14
            clip: true
            color: "#1e293b"

            // ---- Live MJPEG stream ------------------------------------
            MjpegView {
                id: mjpeg
                anchors.fill: parent
                visible: root.effectiveFormat === "mjpeg"
                                && root.streamUrl.length > 0
                url: visible ? root.streamUrl : ""
                ignoreSslErrors: root.ignoreSslErrors
            }

            // ---- Snapshot polling fallback ----------------------------
            Image {
                id: snapshot
                anchors.fill: parent
                visible: root.effectiveFormat === "snapshot"
                                && root.snapshotUrl.length > 0
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                smooth: true
                property int tick: 0
                source: visible && root.snapshotUrl.length > 0
                    ? root.snapshotUrl + (root.snapshotUrl.indexOf("?") >= 0 ? "&" : "?") + "_=" + tick
                    : ""
            }

            Timer {
                running: snapshot.visible
                repeat: true
                interval: Math.max(250, root.refreshInterval)
                onTriggered: snapshot.tick += 1
            }

            // ---- Static placeholder -----------------------------------
            Item {
                anchors.fill: parent
                visible: root.effectiveFormat === "placeholder"

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: parent.height * 0.45
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#7dd3fc" }
                        GradientStop { position: 1.0; color: "#bae6fd" }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.height * 0.55
                    color: "#64748b"
                }

                Rectangle {
                    x: parent.width * 0.06
                    y: parent.height * 0.22
                    width: parent.width * 0.24
                    height: parent.height * 0.22
                    color: "#e2e8f0"
                    border.color: "#94a3b8"
                }

                Rectangle {
                    x: parent.width * 0.62
                    y: parent.height * 0.18
                    width: parent.width * 0.28
                    height: parent.height * 0.26
                    color: "#f8fafc"
                    border.color: "#94a3b8"
                }

                Rectangle {
                    x: parent.width * 0.20
                    y: parent.height * 0.56
                    width: parent.width * 0.62
                    height: parent.height * 0.26
                    radius: 10
                    color: "#334155"
                    rotation: -3
                }
            }

            // ---- Status overlay ---------------------------------------
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 30
                color: "#990f1726"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: 4
                        color: {
                            if (root.effectiveFormat === "mjpeg") {
                                return mjpeg.active && mjpeg.frameCount > 0 ? "#22c55e" : "#fbbf24"
                            }
                            if (root.effectiveFormat === "snapshot") {
                                return snapshot.status === Image.Ready ? "#22c55e" : "#fbbf24"
                            }
                            return "#94a3b8"
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        color: "#dbeafe"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        text: {
                            switch (root.effectiveFormat) {
                            case "mjpeg":
                                if (mjpeg.lastError && mjpeg.lastError.length > 0) {
                                    return "MJPEG error: " + mjpeg.lastError
                                }
                                if (mjpeg.frameCount === 0) {
                                    return "MJPEG verbinden..."
                                }
                                return "MJPEG live"
                            case "snapshot":
                                if (snapshot.status === Image.Error) {
                                    return "Snapshot Fehler"
                                }
                                if (snapshot.status === Image.Loading) {
                                    return "Snapshot lade..."
                                }
                                return "Snapshot poll"
                            default:
                                return "Kein Stream konfiguriert"
                            }
                        }
                    }

                    Text {
                        color: "#93a4ba"
                        font.pixelSize: 11
                        text: {
                            if (root.effectiveFormat === "mjpeg") {
                                return mjpeg.frameRate > 0
                                    ? mjpeg.frameRate.toFixed(1) + " fps"
                                    : "--"
                            }
                            if (root.effectiveFormat === "snapshot") {
                                return Math.max(250, root.refreshInterval) + " ms"
                            }
                            return "16:9"
                        }
                    }
                }
            }
        }
    }
}
