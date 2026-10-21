import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root
    property var popoutService: null
    
    property int currentSpeed: 50
    property bool isAuto: true
    property string displaySpeed: "Auto"
    
    property real lastInteractionTime: 0
    property int targetSpeedCache: -1
    property var osds: []

    Timer {
        id: debounceTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (root.targetSpeedCache >= 0) {
                Quickshell.execDetached(["nbfc", "set", "-s", String(root.targetSpeedCache)]);
            }
        }
    }

    function setSpeedDebounced(speed) {
        if (root.isAuto) return;
        root.lastInteractionTime = Date.now();
        let safeSpeed = Math.max(0, Math.min(100, speed));
        root.currentSpeed = safeSpeed;
        root.displaySpeed = safeSpeed + "%";
        root.targetSpeedCache = safeSpeed;
        debounceTimer.restart();
    }

    // CC Integration
    ccWidgetIcon: "mode_fan"
    ccWidgetPrimaryText: "Fan Control"
    ccWidgetSecondaryText: displaySpeed
    ccWidgetIsActive: !isAuto

    onCcWidgetToggled: {
        root.doToggle();
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
                    
                    DankToggle {
                        checked: root.isAuto
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            root.doToggle();
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

                    DankIcon {
                        name: "fan"
                        size: Theme.iconSize
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DankSlider {
                        width: parent.width - Theme.iconSize - Theme.spacingM * 2 - 40
                        height: 30
                        minimum: 0
                        maximum: 100
                        value: root.currentSpeed
                        enabled: !root.isAuto
                        showValue: false
                        anchors.verticalCenter: parent.verticalCenter
                        
                        onSliderValueChanged: (newValue) => {
                            if (!root.isAuto) {
                                root.setSpeedDebounced(newValue);
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
                DankIcon {
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
                DankIcon {
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

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            Proc.runCommand("nbfc.status.poll", ["nbfc", "status"], (stdout, exitCode) => {
                if (exitCode === 0) {
                    if (Date.now() - root.lastInteractionTime < 2000) return;
                    if (stdout.includes("Auto Control Enabled     : true")) {
                        if (!root.isAuto) {
                            root.isAuto = true;
                            root.displaySpeed = "Auto";
                        }
                    } else {
                        const match = stdout.match(/Current Fan Speed.*?:\s*([\d.]+)/);
                        if (match) {
                            const newSpeed = parseInt(match[1]);
                            if (newSpeed !== root.currentSpeed) {
                                root.isAuto = false;
                                root.currentSpeed = newSpeed;
                                root.displaySpeed = newSpeed + "%";
                            }
                        }
                    }
                }
            });
        }
    }

    function doUp() {
        if (root.isAuto) root.isAuto = false;
        let newSpeed = Math.min(100, root.currentSpeed + 5);
        root.setSpeedDebounced(newSpeed);
        root.showOsd();
    }

    function doDown() {
        if (root.isAuto) root.isAuto = false;
        let newSpeed = Math.max(0, root.currentSpeed - 5);
        root.setSpeedDebounced(newSpeed);
        root.showOsd();
    }

    function doToggle() {
        if (root.isAuto) {
            root.isAuto = false;
            root.currentSpeed = 100;
            root.displaySpeed = "100%";
            Quickshell.execDetached(["nbfc", "set", "-s", "100"]);
        } else {
            root.isAuto = true;
            root.displaySpeed = "Auto";
            Quickshell.execDetached(["nbfc", "set", "-a"]);
        }
        root.showOsd();
    }

    IpcHandler {
        target: "nbfcControl"
        
        function up() {
            root.doUp();
            return "Speed increased";
        }
        
        function down() {
            root.doDown();
            return "Speed decreased";
        }
        
        function toggle() {
            root.doToggle();
            return "Mode toggled";
        }
        
        function set(speed: string) {
            let s = parseInt(speed);
            if (!isNaN(s)) {
                root.isAuto = false;
                root.setSpeedDebounced(s);
                root.showOsd();
                return "Speed set to " + root.currentSpeed + "%";
            }
            return "Invalid speed";
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            Proc.runCommand("nbfc.status", ["nbfc", "status"], (stdout, exitCode) => {
                if (exitCode === 0) {
                    if (Date.now() - root.lastInteractionTime < 2000) return;
                    if (stdout.includes("Auto Control Enabled     : true")) {
                        root.isAuto = true;
                        root.displaySpeed = "Auto";
                    } else {
                        root.isAuto = false;
                        const match = stdout.match(/Target Fan Speed.*?:\s*([\d.]+)/);
                        if (match) {
                            root.currentSpeed = parseInt(match[1]);
                            root.displaySpeed = root.currentSpeed + "%";
                        } else {
                            // Fallback just in case
                            const curMatch = stdout.match(/Current Fan Speed.*?:\s*([\d.]+)/);
                            if (curMatch) {
                                root.currentSpeed = parseInt(curMatch[1]);
                                root.displaySpeed = root.currentSpeed + "%";
                            }
                        }
                    }
                }
            });
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
        delegate: DankOSD {
            id: osdInst
            screen: modelData
            
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
                        DankIcon {
                            anchors.centerIn: parent
                            name: "mode_fan"
                            size: Theme.iconSize
                            color: root.isAuto ? Theme.primary : Theme.surfaceText
                        }
                    }

                    DankSlider {
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
                        DankIcon {
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
