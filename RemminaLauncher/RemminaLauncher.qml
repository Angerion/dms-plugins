import QtQuick
import Quickshell
import qs.Common
import qs.Services

Item {
    id: root

    property var pluginService: null
    property string trigger: "r:"
    property string remminaPath: "~/.local/share/remmina"

    property var cachedProfiles: []
    property bool isLoaded: false

    signal itemsChanged()

    Component.onCompleted: {
        if (pluginService) {
            let noTrigger = pluginService.loadPluginData("remminaLauncher", "noTrigger", false)
            trigger = noTrigger ? "" : pluginService.loadPluginData("remminaLauncher", "trigger", "r:")
            remminaPath = pluginService.loadPluginData("remminaLauncher", "remminaPath", "~/.local/share/remmina")
        }
        loadProfiles()
    }

    Connections {
        target: pluginService
        function onGlobalVarChanged(pid, varName) {
            if (pid === "remminaLauncher" && varName === "forceRefresh") {
                if (pluginService) {
                    let noTrigger = pluginService.loadPluginData("remminaLauncher", "noTrigger", false)
                    trigger = noTrigger ? "" : pluginService.loadPluginData("remminaLauncher", "trigger", "r:")
                    remminaPath = pluginService.loadPluginData("remminaLauncher", "remminaPath", "~/.local/share/remmina")
                }
                loadProfiles()
            }
        }
    }

    function loadProfiles() {
        const path = remminaPath.replace("~", Quickshell.env("HOME"))

        Proc.runCommand(
            "remminaLauncher.load",
            ["sh", "-c", "grep -H -E '^(name|server|protocol|group)=' " + path + "/*.remmina || true"],
            (stdout, exitCode) => {
                if (exitCode === 0 && stdout) {
                    parseProfiles(stdout)
                } else {
                    cachedProfiles = []
                    isLoaded = true
                    itemsChanged()
                }
            }
        )
    }

    function parseProfiles(output) {
        const lines = output.trim().split("\n")
        const profilesMap = {}

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i]
            const firstColon = line.indexOf(':')
            if (firstColon === -1) continue

            const filePath = line.substring(0, firstColon)
            const content = line.substring(firstColon + 1)
            const firstEq = content.indexOf('=')
            if (firstEq === -1) continue

            const key = content.substring(0, firstEq).trim()
            const value = content.substring(firstEq + 1).trim()

            if (!profilesMap[filePath]) {
                profilesMap[filePath] = {
                    file: filePath,
                    name: "",
                    server: "",
                    protocol: "",
                    group: ""
                }
            }
            profilesMap[filePath][key] = value
        }

        const profilesList = []
        for (const file in profilesMap) {
            const p = profilesMap[file]
            let iconName = "monitor"

            const proto = (p.protocol || "").toUpperCase()
            if (proto === "RDP") iconName = "desktop_windows"
            else if (proto === "VNC") iconName = "cast"
            else if (proto === "SSH") iconName = "terminal"
            else if (proto === "SFTP") iconName = "folder_shared"

            let comment = p.server || "No server specified"
            if (p.group) comment = p.group + " • " + comment

            const filename = file.substring(file.lastIndexOf('/') + 1)

            profilesList.push({
                name: p.name || filename.replace(".remmina", ""),
                icon: "material:" + iconName,
                comment: comment,
                action: "launch:" + file,
                categories: ["Remmina"],
                _searchString: (p.name + " " + p.server + " " + p.group + " " + filename).toLowerCase()
            })
        }

        cachedProfiles = profilesList
        isLoaded = true
        itemsChanged()
    }

    function getItems(query) {
        if (!isLoaded) return []
        if (!query || query.trim() === "") return cachedProfiles

        const lowerQuery = query.toLowerCase().trim()
        const terms = lowerQuery.split(/\s+/)

        return cachedProfiles.filter(item => {
            for (let i = 0; i < terms.length; i++) {
                if (!item._searchString.includes(terms[i])) {
                    return false
                }
            }
            return true
        })
    }

    function executeItem(item) {
        if (!item || !item.action) return
        const parts = item.action.split(":")
        if (parts[0] === "launch") {
            const filePath = parts.slice(1).join(":")
            Quickshell.execDetached(["remmina", "-c", filePath])
        }
    }
}