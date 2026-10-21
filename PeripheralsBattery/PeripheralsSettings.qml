import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "peripheralsBattery"

    // Load categories into a local ListModel for management
    property var categoriesList: SettingsData.getPluginSetting(pluginId, "categories", [
        { "name": "Mouse", "regex": "mouse|g502", "icon": "󰍽" },
        { "name": "Keyboard", "regex": "keyboard|g915", "icon": "󰌌" },
        { "name": "Headset", "regex": "headset|headphones|arctis", "icon": "󰋋" }
    ])

    function saveCategories() {
        var data = []
        for (var i = 0; i < categoriesModel.count; i++) {
            data.push(categoriesModel.get(i))
        }
        SettingsData.setPluginSetting(pluginId, "categories", data)
    }

    Component.onCompleted: {
        categoriesModel.clear()
        for (var i = 0; i < categoriesList.length; i++) {
            categoriesModel.append(categoriesList[i])
        }
    }

    StyledText {
        width: parent.width
        text: "Device Categorization"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Define patterns to group your devices and assign them icons."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
        bottomPadding: 10
    }

    // Category Creator
    StyledRect {
        width: parent.width
        height: addCategoryCol.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: addCategoryCol
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM
                Column {
                    width: (parent.width - Theme.spacingM * 2) * 0.3
                    spacing: 4
                    StyledText { text: "Name"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                    DankTextField { id: catName; width: parent.width; placeholderText: "e.g. Phone" }
                }
                Column {
                    width: (parent.width - Theme.spacingM * 2) * 0.5
                    spacing: 4
                    StyledText { text: "RegEx Matcher"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                    DankTextField { id: catRegex; width: parent.width; placeholderText: "model name pattern" }
                }
                Column {
                    width: (parent.width - Theme.spacingM * 2) * 0.2
                    spacing: 4
                    StyledText { text: "Icon"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                    DankTextField { id: catIcon; width: parent.width; placeholderText: "󰄜" }
                }
            }

            DankButton {
                text: "Add Category"
                iconName: "add"
                width: parent.width
                onClicked: {
                    if (!catName.text || !catRegex.text) return
                    categoriesModel.append({
                        "name": catName.text,
                        "regex": catRegex.text,
                        "icon": catIcon.text || "󰂄"
                    })
                    saveCategories()
                    catName.text = ""; catRegex.text = ""; catIcon.text = ""
                }
            }
        }
    }

    // Category List
    ListView {
        id: catListView
        width: parent.width
        height: contentHeight
        spacing: Theme.spacingXS
        interactive: false
        model: ListModel { id: categoriesModel }
        delegate: StyledRect {
            width: ListView.view.width
            height: 50
            radius: Theme.cornerRadius
            color: Theme.surfaceContainer
            Row {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM
                StyledText { text: model.icon; font.pixelSize: 20; width: 30; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    width: parent.width - 100
                    anchors.verticalCenter: parent.verticalCenter
                    StyledText { text: model.name; font.weight: Font.Medium }
                    StyledText { text: model.regex; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; elide: Text.ElideRight; width: parent.width }
                }
                DankIcon {
                    name: "delete"
                    size: 18
                    color: Theme.error
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            categoriesModel.remove(index)
                            saveCategories()
                        }
                    }
                }
            }
        }
    }

    StyledText {
        width: parent.width
        text: "Global Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
        topPadding: 20
    }

    SliderSetting {
        width: parent.width
        label: "Refresh Interval (seconds)"
        settingKey: "refreshInterval"
        defaultValue: 30
        minimum: 5
        maximum: 300
        unit: "s"
    }

    SliderSetting {
        width: parent.width
        label: "Default Auto Cycle Speed (seconds)"
        settingKey: "cycleSpeed"
        defaultValue: 5
        minimum: 2
        maximum: 60
        unit: "s"
    }

    Column {
        width: parent.width
        spacing: 4
        StyledText { text: "Ignore Regex Pattern (Hide Devices)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
        DankTextField {
            width: parent.width
            placeholderText: "e.g. dualshock|controller"
            text: SettingsData.getPluginSetting(pluginId, "ignoredRegex", "")
            onEditingFinished: {
                SettingsData.setPluginSetting(pluginId, "ignoredRegex", text)
            }
        }
    }

    StyledText {
        width: parent.width
        text: "Widget Variants"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
        topPadding: 20
    }

    StyledText {
        width: parent.width
        text: "Create specific widgets for your bars here. Each can have its own mode and target."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
        bottomPadding: 10
    }

    // Variant Creator
    StyledRect {
        width: parent.width
        height: addVarCol.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: addVarCol
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM
                Column {
                    width: (parent.width - Theme.spacingM) / 2
                    spacing: 4
                    StyledText { text: "Variant Name"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                    DankTextField { id: varName; width: parent.width; placeholderText: "e.g. Left Bar Auto" }
                }
                Column {
                    width: (parent.width - Theme.spacingM) / 2
                    spacing: 4
                    StyledText { text: "Display Mode"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                    DankDropdown {
                        id: varMode
                        width: parent.width
                        options: ["auto", "static", "toggle"]
                        currentValue: "auto"
                    }
                }
            }

            DankButton {
                text: "Create Widget Variant"
                iconName: "add"
                width: parent.width
                onClicked: {
                    if (!varName.text) return
                    var config = {
                        "mode": varMode.currentValue,
                        "name": varName.text
                    }
                    createVariant(varName.text, config)
                    varName.text = ""
                }
            }
        }
    }

    // Variant List
    ListView {
        width: parent.width
        height: contentHeight
        spacing: Theme.spacingXS
        interactive: false
        model: ListModel { id: variantsModel }
        onModelChanged: {
            variantsModel.clear()
            for (var i = 0; i < variants.length; i++) {
                variantsModel.append(variants[i])
            }
        }
        delegate: StyledRect {
            width: ListView.view.width
            height: 50
            radius: Theme.cornerRadius
            color: Theme.surfaceContainer
            Row {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM
                DankIcon { name: "widgets"; size: 18; anchors.verticalCenter: parent.verticalCenter }
                StyledText { text: model.name; width: parent.width - 120; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight }
                StyledText { text: model.mode; color: Theme.surfaceVariantText; anchors.verticalCenter: parent.verticalCenter }
                DankIcon {
                    name: "delete"
                    size: 18
                    color: Theme.error
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea {
                        anchors.fill: parent
                        onClicked: removeVariant(model.id)
                    }
                }
            }
        }
    }
}
