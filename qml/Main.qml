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

    function currentPageTitle() {
        if (!dashboardConfig.valid || dashboardConfig.pages.length === 0) {
            return "CONFIG"
        }

        return dashboardConfig.pages[Math.min(swipeView.currentIndex, dashboardConfig.pages.length - 1)].title
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
    }

    SwipeView {
        id: swipeView
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: statusBar.bottom
        anchors.bottom: footer.top
        clip: true
        interactive: dashboardConfig.valid && dashboardConfig.pages.length > 1
        visible: dashboardConfig.valid

        Repeater {
            model: dashboardConfig.pages

            ConfiguredPage {
                page: modelData
                openhab: openhabClient
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: statusBar.bottom
        anchors.bottom: footer.top
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
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 56
        color: "#0b1220"
        border.color: "#1f2b3d"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24

            Text {
                text: "Config: " + dashboardConfig.sourcePath + " · OpenHAB " + openhabClient.baseUrl
                color: dashboardConfig.valid ? "#64748b" : "#fbbf24"
                font.pixelSize: 12
                elide: Text.ElideMiddle
                Layout.fillWidth: true
            }

            PageDots {
                visible: dashboardConfig.valid
                count: swipeView.count
                currentIndex: swipeView.currentIndex
            }

            Text {
                text: dashboardConfig.valid ? (swipeView.currentIndex + 1) + " / " + swipeView.count : "invalid config"
                color: dashboardConfig.valid ? "#93a4ba" : "#fbbf24"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignRight
                Layout.fillWidth: true
            }
        }
    }
}
