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

    property var pageTitles: ["RAUME EG", "KLIMA", "ENERGIE & SECURITY"]

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
        section: root.pageTitles[swipeView.currentIndex]
    }

    SwipeView {
        id: swipeView
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: statusBar.bottom
        anchors.bottom: footer.top
        clip: true
        interactive: true

        Item {
            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16

                ColumnLayout {
                    Layout.preferredWidth: 292
                    Layout.fillHeight: true
                    spacing: 16

                    RoomPanel {
                        title: "Wohnzimmer"
                        subtitle: "Licht, Hue, Rollo"
                        temperature: "24.9 C"
                        humidity: "45 %"
                        lightOn: true
                        shutterClosed: false
                        shutterPosition: "Terrasse 30 %"
                        Layout.fillWidth: true
                    }

                    RoomPanel {
                        title: "Terrasse"
                        subtitle: "Aussenbereich"
                        temperature: "30.0 C"
                        humidity: "38 %"
                        lightOn: false
                        shutterClosed: true
                        shutterPosition: "Sonne 20 %"
                        Layout.fillWidth: true
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 292
                    Layout.fillHeight: true
                    spacing: 16

                    RoomPanel {
                        title: "Esszimmer"
                        subtitle: "Esstisch und Szene"
                        temperature: "24.8 C"
                        humidity: "43 %"
                        lightOn: true
                        shutterClosed: true
                        shutterPosition: "100 %"
                        Layout.fillWidth: true
                    }

                    RoomPanel {
                        title: "Kueche"
                        subtitle: "Arbeitslicht"
                        temperature: "24.6 C"
                        humidity: "46 %"
                        lightOn: false
                        shutterClosed: false
                        shutterPosition: "0 %"
                        Layout.fillWidth: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 16

                    CameraTile {
                        title: "Live Kamera"
                        location: "Einfahrt"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 292
                    }

                    RoomPanel {
                        title: "Flur"
                        subtitle: "Praesenz und Szene"
                        temperature: "23.5 C"
                        humidity: "41 %"
                        lightOn: true
                        shutterClosed: false
                        shutterPosition: "offen"
                        Layout.fillWidth: true
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 292
                    Layout.fillHeight: true
                    spacing: 16

                    ModePanel {
                        Layout.fillWidth: true
                    }

                    EnergyPanel {
                        Layout.fillWidth: true
                    }
                }
            }
        }

        Item {
            GridLayout {
                anchors.fill: parent
                anchors.margins: 20
                columns: 3
                columnSpacing: 16
                rowSpacing: 16

                RoomPanel {
                    title: "Wohnzimmer Klima"
                    subtitle: "Soll 22.0 C"
                    temperature: "24.9 C"
                    humidity: "45 %"
                    lightOn: false
                    shutterClosed: false
                    shutterPosition: "offen"
                    Layout.fillWidth: true
                }

                RoomPanel {
                    title: "Esszimmer Klima"
                    subtitle: "Soll 22.0 C"
                    temperature: "24.8 C"
                    humidity: "43 %"
                    lightOn: false
                    shutterClosed: true
                    shutterPosition: "100 %"
                    Layout.fillWidth: true
                }

                RoomPanel {
                    title: "Schlafzimmer"
                    subtitle: "Nachtprofil"
                    temperature: "21.2 C"
                    humidity: "50 %"
                    lightOn: false
                    shutterClosed: true
                    shutterPosition: "90 %"
                    Layout.fillWidth: true
                }

                RoomPanel {
                    title: "Bad"
                    subtitle: "Lueftung"
                    temperature: "23.1 C"
                    humidity: "58 %"
                    lightOn: true
                    shutterClosed: false
                    shutterPosition: "offen"
                    Layout.fillWidth: true
                }

                RoomPanel {
                    title: "Buero"
                    subtitle: "Arbeitsmodus"
                    temperature: "22.7 C"
                    humidity: "42 %"
                    lightOn: true
                    shutterClosed: false
                    shutterPosition: "30 %"
                    Layout.fillWidth: true
                }

                RoomPanel {
                    title: "Keller"
                    subtitle: "Technikraum"
                    temperature: "19.4 C"
                    humidity: "54 %"
                    lightOn: false
                    shutterClosed: false
                    shutterPosition: "n/a"
                    Layout.fillWidth: true
                }
            }
        }

        Item {
            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16

                ColumnLayout {
                    Layout.preferredWidth: 292
                    Layout.fillHeight: true
                    spacing: 16

                    EnergyPanel {
                        title: "Energie"
                        Layout.fillWidth: true
                    }

                    ModePanel {
                        Layout.fillWidth: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 16

                    CameraTile {
                        title: "Security Kamera"
                        location: "Carport"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        ControlTile {
                            label: "Alarm"
                            value: "HOME"
                            secondary: "armed night"
                            iconText: "S"
                            active: true
                            accentColor: "#ef4444"
                            Layout.fillWidth: true
                        }

                        ControlTile {
                            label: "Tuer"
                            value: "LOCKED"
                            secondary: "front"
                            iconText: "D"
                            active: true
                            accentColor: "#22c55e"
                            Layout.fillWidth: true
                        }

                        ControlTile {
                            label: "Fenster"
                            value: "CLOSED"
                            secondary: "all zones"
                            iconText: "W"
                            active: false
                            accentColor: "#38bdf8"
                            Layout.fillWidth: true
                        }
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 292
                    Layout.fillHeight: true
                    spacing: 16

                    RoomPanel {
                        title: "Aussenlicht"
                        subtitle: "Dusk scene"
                        temperature: "18.0 C"
                        humidity: "62 %"
                        lightOn: true
                        shutterClosed: false
                        shutterPosition: "n/a"
                        Layout.fillWidth: true
                    }

                    EnergyPanel {
                        title: "Verbrauch"
                        Layout.fillWidth: true
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
                text: "Swipe to change page"
                color: "#64748b"
                font.pixelSize: 12
                Layout.fillWidth: true
            }

            PageDots {
                count: swipeView.count
                currentIndex: swipeView.currentIndex
            }

            Text {
                text: (swipeView.currentIndex + 1) + " / " + swipeView.count
                color: "#93a4ba"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignRight
                Layout.fillWidth: true
            }
        }
    }
}
