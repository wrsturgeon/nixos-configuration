import Quickshell
import Quickshell.Io
import QtQuick

PanelWindow {
    anchors {
        top: true
        left: true
        right: true
    }
    color: "#000000"
    implicitHeight: 32

    Text {
        id: clock
        anchors.centerIn: parent
        color: "#ffffff"
        font {
            family: "Iosevka Custom"
            hintingPreference: Font.PreferFullHinting
            pixelSize: 12
        }
        renderType: Text.NativeRendering

        Process {
            id: dateProc
            command: ["date", "+%Y/%m/%d %H:%M:%S.%2N"]
            running: true
            stdout: StdioCollector {
                onStreamFinished: clock.text = this.text
            }
        }

        Timer {
            interval: 19 // to avoid systematic error
            running: true // start immediately
            repeat: true
            onTriggered: dateProc.running = true
        }
    }
}
