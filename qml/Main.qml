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
                        openhab: openhabClient
                        title: "Wohnzimmer"
                        subtitle: "Licht, Hue, Rollo"
                        temperature: "24.9 C"
                        humidity: "45 %"
                        lightOn: true
                        shutterClosed: false
                        shutterPosition: "Terrasse 30 %"
                        temperatureItem: "Wohnzimmer_Temperatur"
                        humidityItem: "Wohnzimmer_Luftfeuchtigkeit"
                        lightItem: "Wohnzimmer_Licht"
                        hueItem: "Wohnzimmer_Hue"
                        shutterItem: "Wohnzimmer_Rollo"
                        Layout.fillWidth: true
                    }

                    RoomPanel {
                        openhab: openhabClient
                        title: "Terrasse"
                        subtitle: "Aussenbereich"
                        temperature: "30.0 C"
                        humidity: "38 %"
                        lightOn: false
                        shutterClosed: true
                        shutterPosition: "Sonne 20 %"
                        temperatureItem: "Terrasse_Temperatur"
                        humidityItem: "Terrasse_Luftfeuchtigkeit"
                        lightItem: "Terrasse_Licht"
                        shutterItem: "Terrasse_Rollo"
                        Layout.fillWidth: true
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 292
                    Layout.fillHeight: true
                    spacing: 16

                    RoomPanel {
                        openhab: openhabClient
                        title: "Esszimmer"
                        subtitle: "Esstisch und Szene"
                        temperature: "24.8 C"
                        humidity: "43 %"
                        lightOn: true
                        shutterClosed: true
                        shutterPosition: "100 %"
                        temperatureItem: "Esszimmer_Temperatur"
                        humidityItem: "Esszimmer_Luftfeuchtigkeit"
                        lightItem: "Esszimmer_Licht"
                        hueItem: "Esszimmer_Hue"
                        shutterItem: "Esszimmer_Rollo"
                        Layout.fillWidth: true
                    }

                    RoomPanel {
                        openhab: openhabClient
                        title: "Kueche"
                        subtitle: "Arbeitslicht"
                        temperature: "24.6 C"
                        humidity: "46 %"
                        lightOn: false
                        shutterClosed: false
                        shutterPosition: "0 %"
                        temperatureItem: "Kueche_Temperatur"
                        humidityItem: "Kueche_Luftfeuchtigkeit"
                        lightItem: "Kueche_Licht"
                        shutterItem: "Kueche_Rollo"
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
                        openhab: openhabClient
                        title: "Flur"
                        subtitle: "Praesenz und Szene"
                        temperature: "23.5 C"
                        humidity: "41 %"
                        lightOn: true
                        shutterClosed: false
                        shutterPosition: "offen"
                        temperatureItem: "Flur_Temperatur"
                        humidityItem: "Flur_Luftfeuchtigkeit"
                        lightItem: "Flur_Licht"
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
                        openhab: openhabClient
                        pvItem: "PV_Power"
                        gridItem: "Grid_Power"
                        consumptionItem: "House_Power"
                        batteryItem: "Battery_Level"
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
                    openhab: openhabClient
                    title: "Wohnzimmer Klima"
                    subtitle: "Soll 22.0 C"
                    temperature: "24.9 C"
                    humidity: "45 %"
                    lightOn: false
                    shutterClosed: false
                    shutterPosition: "offen"
                    temperatureItem: "Wohnzimmer_Temperatur"
                    humidityItem: "Wohnzimmer_Luftfeuchtigkeit"
                    shutterItem: "Wohnzimmer_Rollo"
                    Layout.fillWidth: true
                }

                RoomPanel {
                    openhab: openhabClient
                    title: "Esszimmer Klima"
                    subtitle: "Soll 22.0 C"
                    temperature: "24.8 C"
                    humidity: "43 %"
                    lightOn: false
                    shutterClosed: true
                    shutterPosition: "100 %"
                    temperatureItem: "Esszimmer_Temperatur"
                    humidityItem: "Esszimmer_Luftfeuchtigkeit"
                    shutterItem: "Esszimmer_Rollo"
                    Layout.fillWidth: true
                }

                RoomPanel {
                    openhab: openhabClient
                    title: "Schlafzimmer"
                    subtitle: "Nachtprofil"
                    temperature: "21.2 C"
                    humidity: "50 %"
                    lightOn: false
                    shutterClosed: true
                    shutterPosition: "90 %"
                    temperatureItem: "Schlafzimmer_Temperatur"
                    humidityItem: "Schlafzimmer_Luftfeuchtigkeit"
                    lightItem: "Schlafzimmer_Licht"
                    shutterItem: "Schlafzimmer_Rollo"
                    Layout.fillWidth: true
                }

                RoomPanel {
                    openhab: openhabClient
                    title: "Bad"
                    subtitle: "Lueftung"
                    temperature: "23.1 C"
                    humidity: "58 %"
                    lightOn: true
                    shutterClosed: false
                    shutterPosition: "offen"
                    temperatureItem: "Bad_Temperatur"
                    humidityItem: "Bad_Luftfeuchtigkeit"
                    lightItem: "Bad_Licht"
                    Layout.fillWidth: true
                }

                RoomPanel {
                    openhab: openhabClient
                    title: "Buero"
                    subtitle: "Arbeitsmodus"
                    temperature: "22.7 C"
                    humidity: "42 %"
                    lightOn: true
                    shutterClosed: false
                    shutterPosition: "30 %"
                    temperatureItem: "Buero_Temperatur"
                    humidityItem: "Buero_Luftfeuchtigkeit"
                    lightItem: "Buero_Licht"
                    shutterItem: "Buero_Rollo"
                    Layout.fillWidth: true
                }

                RoomPanel {
                    openhab: openhabClient
                    title: "Keller"
                    subtitle: "Technikraum"
                    temperature: "19.4 C"
                    humidity: "54 %"
                    lightOn: false
                    shutterClosed: false
                    shutterPosition: "n/a"
                    temperatureItem: "Keller_Temperatur"
                    humidityItem: "Keller_Luftfeuchtigkeit"
                    lightItem: "Keller_Licht"
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
                        openhab: openhabClient
                        title: "Energie"
                        pvItem: "PV_Power"
                        gridItem: "Grid_Power"
                        consumptionItem: "House_Power"
                        batteryItem: "Battery_Level"
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
                        openhab: openhabClient
                        title: "Aussenlicht"
                        subtitle: "Dusk scene"
                        temperature: "18.0 C"
                        humidity: "62 %"
                        lightOn: true
                        shutterClosed: false
                        shutterPosition: "n/a"
                        temperatureItem: "Aussen_Temperatur"
                        humidityItem: "Aussen_Luftfeuchtigkeit"
                        lightItem: "Aussen_Licht"
                        Layout.fillWidth: true
                    }

                    EnergyPanel {
                        openhab: openhabClient
                        title: "Verbrauch"
                        consumptionItem: "House_Power"
                        batteryItem: "Battery_Level"
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
                text: "Swipe to change page · OpenHAB " + openhabClient.baseUrl
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
