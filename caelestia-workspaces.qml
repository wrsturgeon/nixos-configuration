pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

// Replacement for Caelestia's fixed workspace pager.
// Shows only occupied normal workspaces, plus the current normal workspace.
StyledClippingRect {
    id: root

    required property ShellScreen screen
    required property bool fullscreen

    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property bool onSpecial: (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? monitor : Hypr.focusedMonitor)?.lastIpcObject.specialWorkspace?.name !== ""
    readonly property int activeWsId: GlobalConfig.bar.workspaces.perMonitorWorkspaces ? (monitor?.activeWorkspace?.id ?? 1) : Hypr.activeWsId

    readonly property var occupied: {
        const occ = {};
        for (const ws of Hypr.workspaces.values) {
            if (showsWorkspace(ws))
                occ[ws.id] = ws.lastIpcObject.windows > 0;
        }
        return occ;
    }

    readonly property var visibleWorkspaceIds: {
        const ids = [];
        const seen = {};

        for (const ws of Hypr.workspaces.values) {
            if (showsWorkspace(ws) && ws.lastIpcObject.windows > 0)
                addWorkspaceId(ids, seen, ws.id);
        }

        addWorkspaceId(ids, seen, activeWsId);
        return ids.sort((a, b) => a - b);
    }

    function addWorkspaceId(ids, seen, id) {
        if (id <= 0 || seen[id])
            return;

        seen[id] = true;
        ids.push(id);
    }

    function showsWorkspace(ws) {
        return ws.id > 0 && (!GlobalConfig.bar.workspaces.perMonitorWorkspaces || ws.monitor === root.monitor);
    }

    property real blur: onSpecial ? 1 : 0

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: layout.implicitHeight + Tokens.padding.small * 2

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    Item {
        anchors.fill: parent
        scale: root.onSpecial ? 0.8 : 1
        opacity: root.onSpecial ? 0.5 : 1
        visible: !root.fullscreen

        layer.enabled: root.blur > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.blur
            blurMax: 32
        }

        ColumnLayout {
            id: layout

            anchors.centerIn: parent
            spacing: Math.floor(Tokens.spacing.small / 2)

            Repeater {
                id: workspaces

                model: ScriptModel {
                    values: root.visibleWorkspaceIds
                }

                Workspace {
                    required property int modelData

                    activeWsId: root.activeWsId
                    occupied: root.occupied
                    ws: modelData
                }
            }
        }

        Loader {
            asynchronous: true
            anchors.horizontalCenter: parent.horizontalCenter
            active: Config.bar.workspaces.activeIndicator

            sourceComponent: ActiveIndicator {
                activeWsId: root.activeWsId
                workspaces: workspaces
                mask: layout
                fullscreen: root.fullscreen
            }
        }

        MouseArea {
            anchors.fill: layout
            onClicked: event => {
                const ws = (layout.childAt(event.x, event.y) as Workspace)?.ws;
                if (!ws)
                    return;

                if (Hypr.activeWsId !== ws)
                    Hypr.dispatch(`workspace ${ws}`);
                else
                    Hypr.dispatch("togglespecialworkspace special");
            }
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {}
        }
    }

    Loader {
        id: specialWs

        asynchronous: true

        anchors.fill: parent
        anchors.margins: Tokens.padding.small

        active: opacity > 0

        scale: root.onSpecial ? 1 : 0.5
        opacity: root.onSpecial ? 1 : 0

        sourceComponent: SpecialWorkspaces {
            screen: root.screen
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {}
        }
    }

    Behavior on blur {
        Anim {
            type: Anim.StandardSmall
        }
    }
}
