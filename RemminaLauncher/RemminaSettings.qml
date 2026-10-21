import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "remminaLauncher"

    StyledText {
        width: parent.width
        text: "General Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    ToggleSetting {
        settingKey: "noTrigger"
        label: "No trigger (always show)"
        description: "Show Remmina profiles alongside regular applications without needing a trigger prefix."
        defaultValue: false
    }

    StringSetting {
        settingKey: "trigger"
        label: "Launcher Trigger"
        description: "Prefix string used to activate the Remmina launcher (e.g., 'r:')."
        placeholder: "r:"
        defaultValue: "r:"
        visible: !loadPluginData("noTrigger", false)
    }

    StringSetting {
        settingKey: "remminaPath"
        label: "Profiles Path"
        description: "Directory where your Remmina connection profiles are stored."
        placeholder: "~/.local/share/remmina"
        defaultValue: "~/.local/share/remmina"
    }

    Item {
        width: parent.width
        height: 60

        Rectangle {
            width: 140
            height: 36
            radius: Theme.cornerRadius
            color: refreshArea.containsMouse ? Theme.primaryHover : Theme.primary
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: "refresh"
                    size: 16
                    color: Theme.primaryText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Refresh Profiles"
                    color: Theme.primaryText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: refreshArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (pluginService) {
                        pluginService.setGlobalVar("remminaLauncher", "forceRefresh", Date.now())
                        ToastService.showInfo("Remmina Launcher", "Profiles refreshed")
                    }
                }
            }
        }
    }
}
