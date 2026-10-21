import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services

PluginComponent {
    id: root

    property var pluginService: null
    property string pluginId: "peripheralsBattery"

    readonly property var defaultCategories: [
        { "name": "Mouse", "regex": "mouse|g502", "icon": "mouse" },
        { "name": "Keyboard", "regex": "keyboard|g915", "icon": "keyboard" },
        { "name": "Headset", "regex": "headset|headphones|arctis", "icon": "headset_mic" }
    ]

    readonly property var categories: pluginService ? pluginService.loadPluginData(pluginId, "categories", defaultCategories) : defaultCategories

    property string variantId: ""
    property var variantData: ({})
    readonly property string mode: variantData?.mode || (pluginService ? pluginService.loadPluginData(pluginId, "mode", "auto") : "auto")
    readonly property int refreshIntervalMs: (pluginService ? pluginService.loadPluginData(pluginId, "refreshInterval", 30) : 30) * 1000
    readonly property int cycleSpeedMs: (pluginService ? pluginService.loadPluginData(pluginId, "cycleSpeed", 5) : 5) * 1000
    readonly property string ignoredRegex: pluginService ? pluginService.loadPluginData(pluginId, "ignoredRegex", "") : ""

    property var allDevices: []
    property int currentIndex: 0
    property var currentDevice: null

    layerNamespacePlugin: "peripherals-battery"
    popoutWidth: 400
    popoutHeight: 450

    Timer {
        id: refreshTimer
        interval: root.refreshIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchBatteryData()
    }

    Timer {
        id: cycleTimer
        interval: root.cycleSpeedMs
        running: root.mode === "auto" && root.allDevices.length > 3
        repeat: true
        onTriggered: {
            if (root.allDevices.length > 0) {
                 root.currentIndex = (root.currentIndex + 1) % root.allDevices.length
                 updateCurrentDevice()
            }
        }
    }

    function categorize(device) {
        let model = device.model.toLowerCase()
        for (let i = 0; i < root.categories.length; i++) {
            let cat = root.categories[i]
            try {
                if (new RegExp(cat.regex, "i").test(model)) {
                    return cat
                }
            } catch (e) {}
        }
        return { "name": "Other", "icon": "devices" }
    }

    function fetchBatteryData() {
        let screenName = root.parentScreen ? root.parentScreen.name.replace(/[^a-zA-Z0-9]/g, "_") : "default"
        let procId = Math.random().toString(36).substring(2, 6)
        
        Proc.runCommand(
            "batt-fetch-" + screenName + "-" + procId,
            ["get-peripherals-batt", "--json"],
            (stdout, exitCode) => {
                if (exitCode === 0) {
                    try {
                        let data = JSON.parse(stdout)
                        let filtered = []
                        data.forEach(d => {
                            if (root.ignoredRegex && new RegExp(root.ignoredRegex, "i").test(d.model)) return;
                            
                            let cat = categorize(d)
                            d.catName = cat.name
                            d.icon = cat.icon
                            filtered.push(d)
                        })
                        filtered.sort((a, b) => {
                            if (a.percentage !== b.percentage) return a.percentage - b.percentage
                            return a.catName.localeCompare(b.catName)
                        })
                        root.allDevices = filtered
                        updateCurrentDevice()
                    } catch (e) {
                        console.error("PeripheralsBattery: JSON Error", e)
                    }
                }
            }
        )
    }

    function updateCurrentDevice() {
        if (root.allDevices.length === 0) {
            root.currentDevice = null
            return
        }
        if (root.currentIndex >= root.allDevices.length) root.currentIndex = 0
        root.currentDevice = root.allDevices[root.currentIndex]
    }

    function cycleManual() {
        if (root.allDevices.length > 0) {
            root.currentIndex = (root.currentIndex + 1) % root.allDevices.length
            updateCurrentDevice()
        }
    }

    pillClickAction: (x, y, w, section, screen) => {
        if (root.mode === "toggle") {
            cycleManual()
        } else {
            root.triggerPopout()
        }
    }

    pillRightClickAction: (x, y, w, section, screen) => {
        root.triggerPopout()
    }

    readonly property real dpr: root.parentScreen ? CompositorService.getScreenScale(root.parentScreen) : 1
    readonly property real stableWidth: Theme.snap(58 * (root.barConfig?.fontScale ?? 1.0), dpr)

    horizontalBarPill: Component {
        Item {
            property int displayedCount: root.allDevices.length === 0 ? 1 : Math.min(3, root.allDevices.length)
            implicitWidth: root.mode === "toggle" ? root.stableWidth : Theme.snap((58 * (root.barConfig?.fontScale ?? 1.0)) * displayedCount, dpr)
            implicitHeight: barThickness
            
            Row {
                anchors.centerIn: parent
                spacing: (barConfig?.noBackground ?? false) ? 2 : 6

                Repeater {
                    model: {
                        if (root.allDevices.length === 0) return [null];
                        if (root.mode === "toggle") return [root.currentDevice];
                        let items = [];
                        let count = Math.min(3, root.allDevices.length);
                        for (let i = 0; i < count; i++) {
                            items.push(root.allDevices[(root.currentIndex + i) % root.allDevices.length]);
                        }
                        return items;
                    }
                    delegate: Row {
                        spacing: (root.barConfig?.noBackground ?? false) ? 1 : 2
                        DankIcon {
                            name: modelData ? modelData.icon : "battery_unknown"
                            size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                            color: (modelData && modelData.percentage < 20) ? Theme.error : Theme.widgetIconColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            visible: modelData !== null
                            text: modelData ? modelData.percentage + "%" : ""
                            font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                            color: (modelData && modelData.percentage < 20) ? Theme.error : Theme.widgetTextColor
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: barThickness
            implicitHeight: root.stableWidth
            
            Column {
                anchors.centerIn: parent
                spacing: 1

                DankIcon {
                    name: root.currentDevice ? root.currentDevice.icon : "battery_unknown"
                    size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: (root.currentDevice && root.currentDevice.percentage < 20) ? Theme.error : Theme.widgetIconColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    visible: root.currentDevice !== null
                    text: root.currentDevice ? root.currentDevice.percentage.toString() : ""
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: (root.currentDevice && root.currentDevice.percentage < 20) ? Theme.error : Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    function isActiveProfile(profile) {
        if (typeof PowerProfiles === "undefined") return false;
        return PowerProfiles.profile === profile;
    }

    function setProfile(profile) {
        if (typeof PowerProfiles === "undefined") {
            ToastService.showError(I18n.tr("power-profiles-daemon not available"));
            return;
        }
        PowerProfiles.profile = profile;
        if (PowerProfiles.profile !== profile) {
            ToastService.showError(I18n.tr("Failed to set power profile"));
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: batteryContent
            headerText: "Peripherals Battery"
            showCloseButton: true

            Column {
                id: contentColumn
                width: parent.width
                spacing: Theme.spacingL

                Row {
                    width: parent.width
                    height: 48
                    spacing: Theme.spacingM

                    DankIcon {
                        name: BatteryService.getBatteryIcon()
                        size: Theme.iconSizeLarge
                        color: {
                            if (BatteryService.isLowBattery && !BatteryService.isCharging) return Theme.error;
                            if (BatteryService.isCharging || BatteryService.isPluggedIn) return Theme.primary;
                            return Theme.surfaceText;
                        }
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        id: headerInfoColumn
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.iconSizeLarge - Theme.spacingM

                        Row {
                            spacing: Theme.spacingS
                            StyledText {
                                text: BatteryService.batteryAvailable ? `${BatteryService.batteryLevel}%` : I18n.tr("Power")
                                font.pixelSize: Theme.fontSizeXLarge
                                color: (BatteryService.isLowBattery && !BatteryService.isCharging) ? Theme.error : (BatteryService.isCharging ? Theme.primary : Theme.surfaceText)
                                font.weight: Font.Bold
                            }
                            StyledText {
                                text: BatteryService.batteryStatus
                                font.pixelSize: Theme.fontSizeLarge
                                color: (BatteryService.isLowBattery && !BatteryService.isCharging) ? Theme.error : (BatteryService.isCharging ? Theme.primary : Theme.surfaceText)
                                font.weight: Font.Medium
                                visible: BatteryService.batteryAvailable
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS
                            
                            StyledText {
                                id: powerRateText
                                text: {
                                    let rateText = "";
                                    let isOnAC = BatteryService.batteryAvailable && (BatteryService.isCharging || BatteryService.isPluggedIn);
                                    let isDischarging = BatteryService.batteryAvailable && !BatteryService.isCharging && !BatteryService.isPluggedIn;
                                    if (BatteryService.batteryAvailable && Math.abs(BatteryService.changeRate) > 0.05) {
                                        rateText = `${isOnAC ? "+" : (isDischarging ? "-" : "")}${Math.abs(BatteryService.changeRate).toFixed(1)}W`;
                                    }
                                    if (BatteryService.isCharging && BatteryService.device && BatteryService.device.voltage) {
                                        if (rateText) rateText += " • ";
                                        rateText += `${Math.round(BatteryService.device.voltage * 1000)} mV`;
                                    }
                                    return rateText;
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: BatteryService.isCharging ? Theme.primary : Theme.surfaceTextMedium
                                font.weight: Font.Medium
                                visible: text.length > 0
                            }

                            StyledText {
                                text: {
                                    if (!BatteryService.batteryAvailable) return I18n.tr("Power profile management available");
                                    const time = BatteryService.formatTimeRemaining();
                                    if (time !== "Unknown") return BatteryService.isCharging ? I18n.tr("Time until full: %1").arg(time) : I18n.tr("Time remaining: %1").arg(time);
                                    return "";
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceTextMedium
                                elide: Text.ElideRight
                                width: parent.width - (powerRateText.visible ? (powerRateText.implicitWidth + parent.spacing) : 0)
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: profileButtonGroup.height * profileButtonGroup.scale

                    DankButtonGroup {
                        id: profileButtonGroup

                        property var profileModel: (typeof PowerProfiles !== "undefined") ? [PowerProfile.PowerSaver, PowerProfile.Balanced].concat(PowerProfiles.hasPerformanceProfile ? [PowerProfile.Performance] : []) : [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
                        property int currentProfileIndex: {
                            if (typeof PowerProfiles === "undefined") return 1;
                            return profileModel.findIndex(profile => root.isActiveProfile(profile));
                        }

                        scale: Math.min(1, parent.width / implicitWidth)
                        transformOrigin: Item.Center
                        anchors.horizontalCenter: parent.horizontalCenter
                        model: profileModel.map(profile => Theme.getPowerProfileLabel(profile))
                        currentIndex: currentProfileIndex
                        selectionMode: "single"
                        onSelectionChanged: (index, selected) => {
                            if (!selected) return;
                            root.setProfile(profileModel[index]);
                        }
                    }
                }

                StyledText {
                    text: "Peripherals"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceTextMedium
                    font.weight: Font.Medium
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Repeater {
                        model: root.allDevices
                        delegate: StyledRect {
                            width: parent.width
                            height: 48
                            radius: Theme.cornerRadius
                            color: Theme.nestedSurface
                            border.width: 0

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM

                                DankIcon {
                                    name: modelData.icon
                                    size: 22
                                    width: 30
                                    color: modelData.percentage < 20 ? Theme.error : Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    width: parent.width - 46 - 60 - Theme.spacingM * 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    StyledText {
                                        text: modelData.model
                                        font.weight: Font.Medium
                                        font.pixelSize: Theme.fontSizeSmall
                                        elide: Text.ElideRight
                                        width: parent.width
                                        color: Theme.surfaceText
                                    }
                                    StyledText {
                                        text: modelData.catName
                                        font.pixelSize: Theme.fontSizeSmall * 0.85
                                        color: Theme.surfaceTextMedium
                                    }
                                }

                                StyledText {
                                    text: modelData.percentage + "%"
                                    font.weight: Font.Bold
                                    font.pixelSize: Theme.fontSizeMedium
                                    width: 60
                                    horizontalAlignment: Text.AlignRight
                                    color: modelData.percentage < 20 ? Theme.error : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    StyledText {
                        visible: root.allDevices.length === 0
                        text: "No devices found"
                        font.italic: true
                        color: Theme.surfaceTextDim
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                    }
                }
            }
        }
    }
}