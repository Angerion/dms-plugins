import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.OSD

Item {
    id: root

    property string pluginId: "nbfcControl"
    property var pluginService: null

    Component.onCompleted: {
        IslandActivityService.registerRenderer("nbfcControl", islandSliderFace, null);
    }

    Component {
        id: islandSliderFace

        OsdLevelRow {
            implicitWidth: SettingsData.osdAlwaysShowValue ? 330 : 282
            implicitHeight: 36
            iconName: "mode_fan"
            tonalIcon: false
            iconInteractive: true
            iconLabel: root.isAuto ? "Manual (100%)" : "Auto"
            value: root.requestedSpeed
            minimum: 0
            maximum: 100
            unit: "%"
            displayText: root.displaySpeed
            sliderEnabled: !root.isAuto
            onIconClicked: root.doToggle()
            onSliderValueChanged: newValue => {
                if (!root.isAuto && newValue !== root.requestedSpeed) {
                    root.setSpeedDebounced(newValue);
                    root.showOsd();
                }
            }
        }
    }

    // Reactive fan state model
    property int requestedSpeed: 50
    property int actualSpeed: 0
    property bool isAuto: true
    readonly property string displaySpeed: isAuto ? "Auto" : (requestedSpeed + "%")

    property bool _initialized: false
    property real lastInteractionTime: 0
    property int targetSpeedCache: -1
    property var osds: []

    readonly property var fallbackOsdScreens: {
        const screens = SettingsData.getFilteredScreens("osd");
        if (!SettingsData.dankIslandEnabled)
            return screens;
        return screens.filter(screen => !SettingsData.dankIslandHandlesSystemOsd(screen));
    }

    function clampSpeed(speed) {
        return Math.max(0, Math.min(100, Math.round(speed)));
    }

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

                const curMatch = stdout.match(/Current Fan Speed.*?:\s*([\d.]+)/);
                if (curMatch) {
                    root.actualSpeed = root.clampSpeed(parseFloat(curMatch[1]));
                }

                if (Date.now() - root.lastInteractionTime < 2000) return;

                const autoEnabled = /Auto Control Enabled\s*:\s*true/i.test(stdout);
                const targetMatch = stdout.match(/Target Fan Speed.*?:\s*([\d.]+)/) || curMatch;

                if (autoEnabled) {
                    root.isAuto = true;
                    if (!root._initialized && targetMatch) {
                        root.requestedSpeed = root.clampSpeed(parseFloat(targetMatch[1]));
                    }
                } else {
                    root.isAuto = false;
                    if (targetMatch) {
                        root.requestedSpeed = root.clampSpeed(parseFloat(targetMatch[1]));
                    }
                }
                root._initialized = true;
            });
        }
    }

    function setSpeedDebounced(speed) {
        if (root.isAuto) return;
        root.lastInteractionTime = Date.now();
        const safeSpeed = root.clampSpeed(speed);
        root.requestedSpeed = safeSpeed;
        root.targetSpeedCache = safeSpeed;
        debounceTimer.restart();
    }

    function doUp() {
        if (root.isAuto) root.isAuto = false;
        const newSpeed = Math.min(100, root.requestedSpeed + 5);
        root.setSpeedDebounced(newSpeed);
        root.showOsd();
    }

    function doDown() {
        if (root.isAuto) root.isAuto = false;
        const newSpeed = Math.max(0, root.requestedSpeed - 5);
        root.setSpeedDebounced(newSpeed);
        root.showOsd();
    }

    function doToggle() {
        debounceTimer.stop();
        root.targetSpeedCache = -1;
        root.lastInteractionTime = Date.now();
        if (root.isAuto) {
            root.isAuto = false;
            root.requestedSpeed = 100;
            root.runNbfcSet(["-s", "100"], "nbfc.set.toggle");
        } else {
            root.isAuto = true;
            root.runNbfcSet(["-a"], "nbfc.set.toggle");
        }
        root.showOsd();
    }

    Connections {
        target: IslandActivityService
        function onActionInvoked(source, id, action) {
            if (source === "nbfcControl" && id === "osd" && action === "toggle") {
                root.doToggle();
            }
        }
    }

    IpcHandler {
        target: "nbfcControl"

        function up(): string {
            root.doUp();
            return "Speed set to " + root.requestedSpeed + "%";
        }

        function down(): string {
            root.doDown();
            return "Speed set to " + root.requestedSpeed + "%";
        }

        function toggle(): string {
            root.doToggle();
            return root.isAuto ? "Auto" : (root.requestedSpeed + "%");
        }

        function set(speed: string): string {
            const s = parseInt(speed);
            if (!isNaN(s)) {
                root.isAuto = false;
                root.setSpeedDebounced(s);
                root.showOsd();
                return "Speed set to " + root.requestedSpeed + "%";
            }
            return "Invalid speed";
        }
    }

    function showOsd() {
        if (SettingsData.dankIslandEnabled && IslandActivityService.activitiesAvailable) {
            IslandActivityService.publish("nbfcControl", "osd", {
                title: root.isAuto ? "Fan: Auto" : ("Fan: " + root.requestedSpeed + "%"),
                subtitle: root.isAuto ? ("Current " + root.actualSpeed + "%") : "Manual",
                value: root.isAuto ? "Auto" : (root.requestedSpeed + "%"),
                icon: "mode_fan",
                iconAnimation: root.isAuto ? "" : "spin",
                progress: root.isAuto ? -1 : (root.requestedSpeed / 100),
                duration: 2500,
                announce: true,
                priorityClass: "high",
                preemption: "higher",
                compact: "label",
                actions: [
                    {
                        id: "toggle",
                        label: root.isAuto ? "100%" : "Auto",
                        role: "secondary"
                    }
                ]
            });
        }

        for (let i = 0; i < osds.length; i++) {
            if (!osds[i].shouldBeVisible) {
                osds[i].show();
            } else {
                osds[i].resetHideTimer();
            }
        }
    }

    Instantiator {
        model: root.fallbackOsdScreens
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
                        value: root.requestedSpeed
                        enabled: !root.isAuto
                        showValue: true
                        unit: "%"
                        thumbOutlineColor: Theme.surfaceContainer

                        onSliderValueChanged: (newValue) => {
                            if (!root.isAuto && newValue !== root.requestedSpeed) {
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
                                const ratio = root.requestedSpeed / 100;
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
                                const ratio = root.requestedSpeed / 100;
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
                                if (root.requestedSpeed !== newSpeed) {
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
