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

    readonly property string layoutKind: layoutValue(page, "layout", "columns")

    Loader {
        anchors.fill: parent
        sourceComponent: {
            switch (root.layoutKind) {
            case "grid":
                return gridPageComponent
            case "masonry":
                return masonryPageComponent
            default:
                return columnsPageComponent
            }
        }
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

    // Masonry layout: packs panels top-to-bottom into the column with the
    // smallest current height. Panels keep their natural height so short
    // tiles do not get stretched to match tall neighbours.
    Component {
        id: masonryPageComponent

        Item {
            id: masonryRoot
            anchors.fill: parent

            readonly property int margins: 20
            readonly property int hspacing: 16
            readonly property int vspacing: 16
            readonly property int minColumnWidth: root.layoutValue(root.page, "columnWidth", 320)

            readonly property int columnsCount: {
                var explicit = Number(root.layoutValue(root.page, "columns", 0))
                if (explicit > 0) {
                    return explicit
                }
                var available = width - 2 * margins
                if (available <= 0) {
                    return 3
                }
                var fit = Math.floor((available + hspacing) / (minColumnWidth + hspacing))
                return Math.max(1, fit)
            }

            readonly property real columnWidth: {
                var available = width - 2 * margins - (columnsCount - 1) * hspacing
                return Math.max(120, Math.floor(available / Math.max(1, columnsCount)))
            }

            function relayout() {
                if (panelRepeater.count === 0 || width <= 0) {
                    return
                }
                var cols = columnsCount
                var heights = new Array(cols)
                for (var c = 0; c < cols; ++c) {
                    heights[c] = margins
                }
                var fullWidth = width - 2 * margins

                for (var i = 0; i < panelRepeater.count; ++i) {
                    var p = panelRepeater.itemAt(i)
                    if (!p) {
                        continue
                    }
                    var span = Number(root.layoutValue(p.panel, "columnSpan", 1))
                    if (!isFinite(span) || span < 1) {
                        span = 1
                    }
                    var effSpan = Math.min(Math.floor(span), cols)

                    var startCol = 0
                    var placeY = 0
                    if (effSpan >= cols) {
                        for (var c2 = 0; c2 < cols; ++c2) {
                            if (heights[c2] > placeY) {
                                placeY = heights[c2]
                            }
                        }
                        startCol = 0
                    } else if (effSpan > 1) {
                        var bestY = Number.POSITIVE_INFINITY
                        for (var s = 0; s <= cols - effSpan; ++s) {
                            var topY = 0
                            for (var k = s; k < s + effSpan; ++k) {
                                if (heights[k] > topY) {
                                    topY = heights[k]
                                }
                            }
                            if (topY < bestY) {
                                bestY = topY
                                startCol = s
                            }
                        }
                        placeY = bestY
                    } else {
                        var shortest = 0
                        for (var k2 = 1; k2 < cols; ++k2) {
                            if (heights[k2] < heights[shortest]) {
                                shortest = k2
                            }
                        }
                        startCol = shortest
                        placeY = heights[shortest]
                    }

                    var panelWidth = effSpan >= cols
                            ? fullWidth
                            : effSpan * columnWidth + (effSpan - 1) * hspacing
                    var explicitHeight = root.panelHeight(p.panel)
                    var panelHeight = explicitHeight > 0 ? explicitHeight : p.implicitHeight

                    p.x = margins + startCol * (columnWidth + hspacing)
                    p.y = placeY
                    p.width = panelWidth
                    p.height = panelHeight

                    var consumedBottom = placeY + panelHeight + vspacing
                    if (effSpan >= cols) {
                        for (var c3 = 0; c3 < cols; ++c3) {
                            heights[c3] = consumedBottom
                        }
                    } else {
                        for (var c4 = startCol; c4 < startCol + effSpan; ++c4) {
                            heights[c4] = consumedBottom
                        }
                    }
                }
            }

            Connections {
                target: masonryRoot
                function onWidthChanged()        { Qt.callLater(masonryRoot.relayout) }
                function onColumnsCountChanged() { Qt.callLater(masonryRoot.relayout) }
                function onColumnWidthChanged()  { Qt.callLater(masonryRoot.relayout) }
            }

            Repeater {
                id: panelRepeater
                model: root.layoutValue(root.page, "panels", [])

                ConfiguredPanel {
                    panel: modelData
                    openhab: root.openhab
                    mqtt: root.mqtt
                    onImplicitHeightChanged: Qt.callLater(masonryRoot.relayout)
                    Component.onCompleted: Qt.callLater(masonryRoot.relayout)
                }
            }
        }
    }
}
