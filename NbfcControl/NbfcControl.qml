import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root
    property var popoutService: null

    readonly property var daemon: PluginService.pluginDaemonInstances["nbfcControl"] ?? null
    readonly property int currentSpeed: daemon?.currentSpeed ?? 50
    readonly property bool isAuto: daemon?.isAuto ?? true
    readonly property string displaySpeed: daemon?.displaySpeed ?? "Auto"

    // CC Integration
    ccWidgetIcon: "mode_fan"
    ccWidgetPrimaryText: "Fan Control"
    ccWidgetSecondaryText: displaySpeed
    ccWidgetIsActive: !isAuto

    onCcWidgetToggled: {
        if (root.daemon) root.daemon.doToggle();
    }

    popoutWidth: 320
    popoutHeight: 180

    popoutContent: Component {
        PopoutComponent {
            headerText: "Fan Control"
            detailsText: root.displaySpeed
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingL

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Mode:"
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DToggle {
                        checked: root.isAuto
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            if (root.daemon) root.daemon.doToggle();
                        }
                    }

                    StyledText {
                        text: root.isAuto ? "Auto" : "Manual"
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM
                    opacity: root.isAuto ? 0.5 : 1.0

                    DIcon {
                        name: "fan"
                        size: Theme.iconSize
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DSlider {
                        width: parent.width - Theme.iconSize - Theme.spacingM * 2 - 40
                        height: 30
                        minimum: 0
                        maximum: 100
                        value: root.currentSpeed
                        enabled: !root.isAuto
                        showValue: false
                        anchors.verticalCenter: parent.verticalCenter

                        onSliderValueChanged: (newValue) => {
                            if (!root.isAuto && root.daemon) {
                                root.daemon.setSpeedDebounced(newValue);
                            }
                        }
                    }

                    StyledText {
                        text: root.currentSpeed + "%"
                        color: Theme.surfaceText
                        width: 40
                        horizontalAlignment: Text.AlignRight
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }

    horizontalBarPill: Component {
        StyledRect {
            id: hRect
            implicitWidth: 64
            implicitHeight: parent.widgetThickness
            width: implicitWidth
            height: implicitHeight
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            Row {
                id: hRow
                anchors.centerIn: parent
                spacing: Theme.spacingS
                DIcon {
                    name: "mode_fan"
                    size: Theme.iconSizeSmall
                    color: root.isAuto ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: root.displaySpeed
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    verticalBarPill: Component {
        StyledRect {
            id: vRect
            implicitWidth: parent.widgetThickness
            implicitHeight: 64
            width: implicitWidth
            height: implicitHeight
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            Column {
                id: vCol
                anchors.centerIn: parent
                spacing: Theme.spacingS
                DIcon {
                    name: "mode_fan"
                    size: Theme.iconSizeSmall
                    color: root.isAuto ? Theme.primary : Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                StyledText {
                    text: root.displaySpeed
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
