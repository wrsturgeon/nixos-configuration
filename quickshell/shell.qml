import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    anchors {
        top: true
        left: true
        right: true
    }
    color: "#000000"
    implicitHeight: 32

    RowLayout {
        anchors {
            fill: parent
            margins: 8
        }

        Repeater {
            model: 9

            Text {
                property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
                property var active: Hyprland.focusedWorkspace?.id === index + 1

                color: active ? "#ffffffff" : (ws ? "#80ffffff" : "#40ffffff")
                font {
                    family: "Iosevka Custom"
                    hintingPreference: Font.PreferFullHinting
                    pixelSize: 12
                }
                renderType: Text.NativeRendering
                text: index + 1
            }
        }
    }

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
