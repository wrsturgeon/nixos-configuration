pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.misc
import qs.services

// Replacement for Caelestia's active-window slot that displays resource metrics.
StyledRect {
    id: root

    required property var bar
    required property var monitor

    readonly property var rootDisk: SystemUsage.disks.length > 0 ? SystemUsage.disks[0] : null
    readonly property var networkRateUnits: ["B", "K", "M", "G", "T"]
    readonly property int networkRateUnitIndex: rateUnitIndex(Math.max(NetworkUsage.downloadSpeed, NetworkUsage.uploadSpeed))

    function boundedPercent(value: real): string {
        const bounded = Math.max(0, Math.min(1, value || 0));
        return Math.round(bounded * 100) + "%";
    }

    function compactValue(value: real, unit: string): string {
        if (!isFinite(value) || isNaN(value))
            return "0" + unit;

        if (value >= 100)
            return Math.round(value) + unit;

        if (value >= 10)
            return Math.round(value) + unit;

        return value.toFixed(1) + unit;
    }

    function leftPad(text: string, width: int): string {
        let padded = text;
        while (padded.length < width)
            padded = " " + padded;
        return padded;
    }

    function rateUnitIndex(bytes: real): int {
        let value = Math.max(0, bytes || 0);
        let unitIndex = 0;

        while (value >= 999.5 && unitIndex < networkRateUnits.length - 1) {
            value /= 1024;
            unitIndex++;
        }

        return unitIndex;
    }

    function compactRate(bytes: real): string {
        const divisor = Math.pow(1024, networkRateUnitIndex);
        const value = Math.max(0, bytes || 0) / divisor;
        const unit = networkRateUnits[networkRateUnitIndex];
        const text = value > 0 && value < 0.5 ? "<1" + unit : Math.round(value) + unit;

        return leftPad(text, 4);
    }

    function compactKib(kib: real): string {
        const formatted = SystemUsage.formatKib(kib || 0);
        return compactValue(formatted.value, formatted.unit.charAt(0));
    }

    color: "transparent"
    radius: Tokens.rounding.full
    clip: true
    implicitWidth: Math.max(Tokens.sizes.bar.innerWidth, metrics.implicitWidth + Tokens.padding.normal * 2)
    implicitHeight: metrics.implicitHeight + Tokens.padding.normal * 2

    Ref {
        service: SystemUsage
    }

    Ref {
        service: NetworkUsage
    }

    ColumnLayout {
        id: metrics

        anchors.centerIn: parent
        spacing: Tokens.spacing.smaller

        Metric {
            icon: "memory"
            value: root.boundedPercent(SystemUsage.cpuPerc)
            accent: Colours.palette.m3primary
        }

        Metric {
            icon: "memory_alt"
            value: root.boundedPercent(SystemUsage.memPerc)
            accent: Colours.palette.m3tertiary
        }

        Metric {
            icon: "desktop_windows"
            value: SystemUsage.gpuType === "NONE" ? "—" : root.boundedPercent(SystemUsage.gpuPerc)
            accent: Colours.palette.m3secondary
        }

        Metric {
            icon: "swap_vert"
            value: "↓" + root.compactRate(NetworkUsage.downloadSpeed) + "\n↑" + root.compactRate(NetworkUsage.uploadSpeed)
            accent: Colours.palette.m3primary
        }

        Metric {
            icon: "hard_disk"
            value: root.rootDisk ? root.compactKib(root.rootDisk.free) : "—"
            accent: root.rootDisk && root.rootDisk.perc >= 0.9 ? Colours.palette.m3error : Colours.palette.m3secondary
        }
    }

    component Metric: ColumnLayout {
        id: metric

        required property string icon
        required property string value
        property color accent: Colours.palette.m3primary

        spacing: 0
        Layout.alignment: Qt.AlignHCenter

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            animate: true
            text: metric.icon
            color: metric.accent
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 0.85
            text: metric.value
            color: Colours.palette.m3onSurface
            font.family: Tokens.font.family.mono
            font.pointSize: Tokens.font.size.small
            font.weight: Font.Medium
        }
    }
}
