import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets

Item {
    id: root

    property string pluginId: "nbfcControl"
    property var pluginService: null

    property int currentSpeed: 50
    property bool isAuto: true
    property string displaySpeed: "Auto"

    property real lastInteractionTime: 0
    property int targetSpeedCache: -1
    property var osds: []

    function runNbfcSet(args, id) {
        Proc.runCommand(id, ["nbfc", "set"].concat(args), (stdout, exitCode) => {
            if (exitCode !== 0) {
                console.warn("[NbfcControl] nbfc set failed:", args.join(" "), "exit:", exitCode, stdout);
            }
        });
    }

    Timer {
        id: debounceTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (root.targetSpeedCache >= 0) {
                root.runNbfcSet(["-s", String(root.targetSpeedCache)], "nbfc.set.speed");
            }
        }
    }

    Timer {
        id: pollTimer
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            Proc.runCommand("nbfc.status", ["nbfc", "status"], (stdout, exitCode) => {
                if (exitCode !== 0) return;
                if (Date.now() - root.lastInteractionTime < 2000) return;
                if (/Auto Control Enabled\s*:\s*true/i.test(stdout)) {
                    if (!root.isAuto) {
                        root.isAuto = true;
                        root.displaySpeed = "Auto";
                    }
                } else {
                    const match = stdout.match(/Target Fan Speed.*?:\s*([\d.]+)/)
                        || stdout.match(/Current Fan Speed.*?:\s*([\d.]+)/);
                    if (match) {
                        const newSpeed = Math.max(0, Math.min(100, Math.round(parseFloat(match[1]))));
                        if (root.isAuto || newSpeed !== root.currentSpeed) {
                            root.isAuto = false;
                            root.currentSpeed = newSpeed;
                            root.displaySpeed = newSpeed + "%";
                        }
                    }
                }
            });
        }
    }

    function setSpeedDebounced(speed) {
        if (root.isAuto) return;
        root.lastInteractionTime = Date.now();
        const safeSpeed = Math.max(0, Math.min(100, Math.round(speed)));
        root.currentSpeed = safeSpeed;
        root.displaySpeed = safeSpeed + "%";
        root.targetSpeedCache = safeSpeed;
        debounceTimer.restart();
    }

    function doUp() {
        if (root.isAuto) root.isAuto = false;
        const newSpeed = Math.min(100, root.currentSpeed + 5);
        root.setSpeedDebounced(newSpeed);
        root.showOsd();
    }

    function doDown() {
        if (root.isAuto) root.isAuto = false;
        const newSpeed = Math.max(0, root.currentSpeed - 5);
        root.setSpeedDebounced(newSpeed);
        root.showOsd();
    }

    function doToggle() {
        debounceTimer.stop();
        root.targetSpeedCache = -1;
        root.lastInteractionTime = Date.now();
        if (root.isAuto) {
            root.isAuto = false;
            root.currentSpeed = 100;
            root.displaySpeed = "100%";
            root.runNbfcSet(["-s", "100"], "nbfc.set.toggle");
        } else {
            root.isAuto = true;
            root.displaySpeed = "Auto";
            root.runNbfcSet(["-a"], "nbfc.set.toggle");
        }
        root.showOsd();
    }

    IpcHandler {
        target: "nbfcControl"

        function up(): string {
            root.doUp();
            return "Speed set to " + root.currentSpeed + "%";
        }

        function down(): string {
            root.doDown();
            return "Speed set to " + root.currentSpeed + "%";
        }

        function toggle(): string {
            root.doToggle();
            return root.isAuto ? "Auto" : (root.currentSpeed + "%");
        }

        function set(speed: string): string {
            const s = parseInt(speed);
            if (!isNaN(s)) {
                root.isAuto = false;
                root.setSpeedDebounced(s);
                root.showOsd();
                return "Speed set to " + root.currentSpeed + "%";
            }
            return "Invalid speed";
        }
    }

    function showOsd() {
        for (let i = 0; i < osds.length; i++) {
            if (!osds[i].shouldBeVisible) {
                osds[i].show();
            } else {
                osds[i].resetHideTimer();
            }
        }
    }

    Instantiator {
        model: Quickshell.screens
        delegate: DOSD {
            id: osdInst

            osdWidth: isVerticalLayout ? (40 + Theme.spacingS * 2) : 260
            osdHeight: isVerticalLayout ? 260 : (40 + Theme.spacingS * 2)
            autoHideInterval: 3000

            content: Item {
                anchors.fill: parent
                property int gap: Theme.spacingS

                MouseArea {
                    anchors.fill: parent
                    onClicked: osdInst.hide()
                }

                // Horizontal layout
                Item {
                    anchors.fill: parent
                    visible: !osdInst.isVerticalLayout

                    Rectangle {
                        width: Theme.iconSize
                        height: Theme.iconSize
                        radius: Theme.iconSize / 2
                        color: "transparent"
                        x: gap
                        anchors.verticalCenter: parent.verticalCenter
                        DIcon {
                            anchors.centerIn: parent
                            name: "mode_fan"
                            size: Theme.iconSize
                            color: root.isAuto ? Theme.primary : Theme.surfaceText
                        }
                    }

                    DSlider {
                        width: parent.width - Theme.iconSize - gap * 3
                        height: 40
                        x: gap * 2 + Theme.iconSize
                        anchors.verticalCenter: parent.verticalCenter
                        minimum: 0
                        maximum: 100
                        value: root.currentSpeed
                        enabled: !root.isAuto
                        showValue: true
                        unit: "%"
                        thumbOutlineColor: Theme.surfaceContainer

                        onSliderValueChanged: (newValue) => {
                            if (!root.isAuto) {
                                root.setSpeedDebounced(newValue);
                                osdInst.resetHideTimer();
                            }
                        }
                    }
                }

                // Vertical layout
                Item {
                    anchors.fill: parent
                    visible: osdInst.isVerticalLayout

                    Rectangle {
                        width: Theme.iconSize
                        height: Theme.iconSize
                        radius: Theme.iconSize / 2
                        color: "transparent"
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: gap
                        DIcon {
                            anchors.centerIn: parent
                            name: "mode_fan"
                            size: Theme.iconSize
                            color: root.isAuto ? Theme.primary : Theme.surfaceText
                        }
                    }

                    Item {
                        id: vertSlider
                        width: 12
                        height: parent.height - Theme.iconSize - gap * 3 - 24
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: gap * 2 + Theme.iconSize

                        property bool dragging: false

                        Rectangle {
                            id: vertTrack
                            width: parent.width
                            height: parent.height
                            anchors.centerIn: parent
                            color: Theme.outline
                            radius: Theme.cornerRadius
                        }

                        Rectangle {
                            id: vertFill
                            width: parent.width
                            height: {
                                const ratio = root.currentSpeed / 100;
                                return ratio * parent.height;
                            }
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Theme.primary
                            radius: Theme.cornerRadius
                            visible: !root.isAuto
                        }

                        Rectangle {
                            id: vertHandle
                            width: 24
                            height: 8
                            radius: Theme.cornerRadius
                            y: {
                                const ratio = root.currentSpeed / 100;
                                const travel = parent.height - height;
                                return Math.max(0, Math.min(travel, travel * (1 - ratio)));
                            }
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Theme.primary
                            border.width: 3
                            border.color: Theme.surfaceContainer
                            visible: !root.isAuto
                        }

                        MouseArea {
                            id: vertSliderArea
                            anchors.fill: parent
                            anchors.margins: -12
                            enabled: !root.isAuto
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onPressed: mouse => {
                                vertSlider.dragging = true;
                                updateValue(mouse);
                            }
                            onReleased: vertSlider.dragging = false
                            onPositionChanged: mouse => {
                                if (pressed) updateValue(mouse);
                            }
                            onClicked: mouse => updateValue(mouse)

                            function updateValue(mouse) {
                                if (root.isAuto) return;
                                const ratio = 1.0 - (mouse.y / height);
                                const newSpeed = Math.max(0, Math.min(100, Math.round(ratio * 100)));
                                if (root.currentSpeed !== newSpeed) {
                                    root.setSpeedDebounced(newSpeed);
                                    osdInst.resetHideTimer();
                                }
                            }
                        }
                    }

                    StyledText {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: gap
                        text: root.displaySpeed
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        visible: SettingsData.osdAlwaysShowValue
                    }
                }
            }
        }
        onObjectAdded: (index, object) => root.osds.push(object)
        onObjectRemoved: (index, object) => {
            const i = root.osds.indexOf(object);
            if (i > -1) root.osds.splice(i, 1);
        }
    }
}
