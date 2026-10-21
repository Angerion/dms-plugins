import QtQuick
import Quickshell.Io
import qs.Services

Item {
    id: root

    function getWeatherStyle(code, isDay) {
        const c = String(code);
        // RGB Colors
        const colYellow = "\x1b[38;2;253;216;53m";
        const colNight = "\x1b[38;2;159;168;218m"; // Indigo 200
        const colBlue = "\x1b[38;2;66;165;245m";
        const colWhite = "\x1b[38;2;224;224;224m";
        const colCyan = "\x1b[38;2;38;198;218m";
        const colMagenta = "\x1b[38;2;171;71;188m";
        
        if (c === "0" || c === "1") return [isDay ? "󰖙" : "󰖔", isDay ? colYellow : colNight];
        if (c === "2") return [isDay ? "󰖕" : "󰼱", isDay ? colYellow : colNight];
        if (c === "3") return ["󰖐", colWhite];
        if (c === "45" || c === "48") return ["󰖑", colWhite];
        if (["51", "53", "55", "56", "57", "61", "63", "65", "66", "67", "80", "81", "82"].includes(c)) return ["󰖖", colBlue];
        if (["71", "73", "75", "77", "85", "86"].includes(c)) return ["󰖘", colCyan];
        if (["95", "96", "99"].includes(c)) return ["󰖓", colMagenta];
        
        return [isDay ? "󰖙" : "󰖔", isDay ? colYellow : colNight];
    }

    IpcHandler {
        target: "weather"

        function get(): string {
            if (!WeatherService.weather.available) {
                return "--";
            }
            const style = getWeatherStyle(WeatherService.weather.wCode, WeatherService.weather.isDay);
            const icon = style[0];
            const color = style[1];
            const reset = "\x1b[0m";
            
            return color + icon + " " + WeatherService.currentTempText() + reset;
        }
    }
}
