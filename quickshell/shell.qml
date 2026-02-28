import Quickshell
import QtQuick

PanelWindow {
    anchors.top: true
    anchors.left: true
    anchors.right: true

    implicitHeight: 32
    color: "#000000"

    Text {
        anchors.centerIn: parent
        text: "Hello, world!"
        color: "#ffffff"
        font.family: "Inter"
        font.pixelSize: 18
    }
}
