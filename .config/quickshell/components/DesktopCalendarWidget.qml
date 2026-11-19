import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

Rectangle {
    id: root
    Theme { id: theme }

    implicitWidth: 165
    implicitHeight: 165
    width: implicitWidth
    height: implicitHeight

    radius: 20
    // Apple Sonoma Translucent Obsidian Glass
    color: theme.widgetGlass
    border.color: theme.borderSubtle
    border.width: 1
    clip: true

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    property date now: sysClock.date
    readonly property int currentYear: now.getFullYear()
    readonly property int currentMonth: now.getMonth()
    readonly property int currentDay: now.getDate()

    // Days in current month
    readonly property int daysInMonth: new Date(currentYear, currentMonth + 1, 0).getDate()
    // Days in previous month
    readonly property int daysInPrevMonth: new Date(currentYear, currentMonth, 0).getDate()
    // First day of week for current month (0 = Sunday)
    readonly property int startDayOfWeek: new Date(currentYear, currentMonth, 1).getDay()
    // Number of visual rows needed (5 or 6)
    readonly property int numRows: Math.ceil((startDayOfWeek + daysInMonth) / 7)

    // Apple English Month Names
    readonly property var monthNames: [
        "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
        "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"
    ]
    readonly property var dayLabels: ["S", "M", "T", "W", "T", "F", "S"]

    Item {
        anchors.fill: parent
        anchors.topMargin: 14
        anchors.bottomMargin: 14
        anchors.leftMargin: 14
        anchors.rightMargin: 14

        // 1. Calendar Header (Dynamic Interface Accent Month Name + Year)
        Item {
            id: headerRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 22

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.monthNames[root.currentMonth]
                color: theme.blueLight != "" ? theme.blueLight : theme.blue
                font.family: theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.Bold
                font.letterSpacing: 0.8
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.currentYear.toString()
                color: theme.textDim
                font.family: theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }

        // 2. Day of Week Headers (S M T W T F S)
        Grid {
            id: dayHeadersGrid
            anchors.top: headerRow.bottom
            anchors.topMargin: 6
            anchors.left: parent.left
            anchors.right: parent.right
            columns: 7
            height: 18

            Repeater {
                model: root.dayLabels
                delegate: Item {
                    width: dayHeadersGrid.width / 7
                    height: 18

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: theme.textDim
                        font.family: theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        // 3. 7x5 or 7x6 Calendar Grid (Dynamically fills entire remaining space)
        Grid {
            id: daysGrid
            anchors.top: dayHeadersGrid.bottom
            anchors.topMargin: 4
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            columns: 7
            rowSpacing: 2
            columnSpacing: 0

            readonly property real rowHeight: Math.max(18, (height - (root.numRows - 1) * rowSpacing) / root.numRows)

            Repeater {
                model: root.numRows * 7
                delegate: Item {
                    id: cell
                    required property int index
                    width: daysGrid.width / 7
                    height: daysGrid.rowHeight

                    // Calculate day number and whether it belongs to current month
                    property int dayNumber: {
                        let d = index - root.startDayOfWeek + 1;
                        if (d <= 0) {
                            return root.daysInPrevMonth + d;
                        } else if (d > root.daysInMonth) {
                            return d - root.daysInMonth;
                        }
                        return d;
                    }
                    property bool isCurrentMonth: (index >= root.startDayOfWeek) && (index < root.startDayOfWeek + root.daysInMonth)
                    property bool isToday: isCurrentMonth && (dayNumber === root.currentDay)

                    // Dynamic Today Indicator (Monochrome Flip-Calendar Tile)
                    CalendarDayTile {
                        id: todayTile
                        anchors.centerIn: parent
                        width: Math.min(24, Math.min(parent.width, cell.height) - 2)
                        height: width
                        visible: cell.isToday
                        accentColor: theme.blue
                    }

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: cell.isToday ? 1 : 0
                        text: cell.dayNumber.toString()
                        color: cell.isToday ? todayTile.autoTextColor : (cell.isCurrentMonth ? theme.text : theme.textDim)
                        opacity: cell.isToday ? 1.0 : (cell.isCurrentMonth ? 0.95 : 0.30)
                        font.family: theme.fontFamily
                        font.pixelSize: 11
                        font.weight: cell.isToday ? Font.Bold : (cell.isCurrentMonth ? Font.Medium : Font.Normal)
                    }
                }
            }
        }
    }
}
