import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var page: ({})
    property var openhab: null
    property var mqtt: null

    function layoutValue(object, key, fallback) {
        if (!object || object[key] === undefined || object[key] === null) {
            return fallback
        }
        return object[key]
    }

    function panelHeight(panel) {
        if (panel && panel.fillHeight === true) {
            return -1
        }
        return layoutValue(panel, "height", -1)
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.layoutValue(root.page, "layout", "columns") === "grid" ? gridPageComponent : columnsPageComponent
    }

    Component {
        id: columnsPageComponent

        RowLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            Repeater {
                model: root.layoutValue(root.page, "columns", [])

                ColumnLayout {
                    Layout.preferredWidth: root.layoutValue(modelData, "width", 292)
                    Layout.fillWidth: root.layoutValue(modelData, "fillWidth", false)
                    Layout.fillHeight: true
                    spacing: 16

                    Repeater {
                        model: root.layoutValue(modelData, "panels", [])

                        ConfiguredPanel {
                            panel: modelData
                            openhab: root.openhab
                            mqtt: root.mqtt
                            Layout.fillWidth: true
                            Layout.fillHeight: root.layoutValue(modelData, "fillHeight", false)
                            Layout.preferredHeight: root.panelHeight(modelData)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: gridPageComponent

        GridLayout {
            anchors.fill: parent
            anchors.margins: 20
            columns: root.layoutValue(root.page, "columns", 3)
            columnSpacing: 16
            rowSpacing: 16

            Repeater {
                model: root.layoutValue(root.page, "panels", [])

                ConfiguredPanel {
                    panel: modelData
                    openhab: root.openhab
                    mqtt: root.mqtt
                    Layout.fillWidth: true
                    Layout.fillHeight: root.layoutValue(modelData, "fillHeight", false)
                    Layout.preferredHeight: root.panelHeight(modelData)
                    Layout.columnSpan: root.layoutValue(modelData, "columnSpan", 1)
                    Layout.rowSpan: root.layoutValue(modelData, "rowSpan", 1)
                }
            }
        }
    }
}
