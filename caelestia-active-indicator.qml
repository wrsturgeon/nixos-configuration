pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services

// Active-workspace highlight for the dynamic workspace list.
StyledRect {
    id: root

    required property int activeWsId
    required property Repeater workspaces
    required property Item mask
    required property bool fullscreen

    readonly property int currentWsIdx: {
        for (let i = 0; i < workspaces.count; i++) {
            const ws = (workspaces.itemAt(i) as Workspace)?.ws ?? -1;
            if (ws === activeWsId)
                return i;
        }
        return -1;
    }

    property real leading: currentWsIdx >= 0 && workspaces.count > 0 ? workspaces.itemAt(currentWsIdx)?.y ?? 0 : 0
    property real trailing: currentWsIdx >= 0 && workspaces.count > 0 ? workspaces.itemAt(currentWsIdx)?.y ?? 0 : 0
    property real currentSize: currentWsIdx >= 0 && workspaces.count > 0 ? (workspaces.itemAt(currentWsIdx) as Workspace)?.size ?? 0 : 0
    property real offset: Math.min(leading, trailing)
    property real size: {
        if (currentWsIdx < 0)
            return 0;

        const s = Math.abs(leading - trailing) + currentSize;
        if (Config.bar.workspaces.activeTrail && lastWs > currentWsIdx && lastWs < workspaces.count) {
            const ws = workspaces.itemAt(lastWs) as Workspace;
            return ws ? Math.min(ws.y + ws.size - offset, s) : 0;
        }
        return s;
    }

    property int cWs
    property int lastWs

    onCurrentWsIdxChanged: {
        lastWs = cWs;
        cWs = currentWsIdx;
    }

    clip: true
    y: offset + mask.y
    implicitWidth: Tokens.sizes.bar.innerWidth - Tokens.padding.small * 2
    implicitHeight: size
    radius: Tokens.rounding.full
    color: Colours.palette.m3primary

    Colouriser {
        source: root.mask
        sourceColor: Colours.palette.m3onSurface
        colorizationColor: Colours.palette.m3onPrimary

        x: 0
        y: -parent.offset
        implicitWidth: root.mask.implicitWidth
        implicitHeight: root.mask.implicitHeight

        anchors.horizontalCenter: parent.horizontalCenter
    }

    Behavior on leading {
        enabled: root.Config.bar.workspaces.activeTrail

        EAnim {}
    }

    Behavior on trailing {
        enabled: root.Config.bar.workspaces.activeTrail

        EAnim {
            duration: Tokens.anim.durations.normal * 2
        }
    }

    Behavior on currentSize {
        enabled: root.Config.bar.workspaces.activeTrail

        EAnim {}
    }

    Behavior on offset {
        enabled: !root.Config.bar.workspaces.activeTrail

        EAnim {}
    }

    Behavior on size {
        enabled: !root.Config.bar.workspaces.activeTrail

        EAnim {}
    }

    component EAnim: Anim {
        type: Anim.Emphasized
    }
}
