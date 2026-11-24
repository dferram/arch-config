import QtQuick

QtObject {
    id: root

    // Apple Liquid Glass - Cohesive Smoked Obsidian Glass (Slightly Lighter & Airier Across All Surfaces)
    readonly property color bg: "#0c0f17"
    readonly property color bgDark: "#9e0c0f17"
    readonly property color bgCrust: "#b8090b12"
    readonly property color bgGlass: "#7d10131d"     // 49% smoked obsidian glass
    readonly property color popupBg: "#c8121520"     // 78% smoked obsidian sheet glass
    readonly property color widgetGlass: "#7810131d" // 47% desktop widget smoked glass

    // Surfaces: Clean specular frosted layers
    readonly property color surface: "#19ffffff"      // Frosted semi-transparent white (~10%)
    readonly property color surfaceHover: "#28ffffff" // Hover state (~16%)
    readonly property color surfaceActive: "#38ffffff"// Active/pressed state (~22%)

    // Liquid Glass Specular Hairlines
    readonly property color border: "#40ffffff"       // Crisp specular hairline (25% white)
    readonly property color borderSubtle: "#1cffffff" // Subtle divider (11% white)
    readonly property color borderGlow: "#5cffffff"   // Specular sheen (36% white)
    readonly property color glassHighlight: "#3cffffff"

    // Apple Clean Neutral Typography (High legibility)
    readonly property color text: "#ffffff"
    readonly property color textSub: "#e2e8f0"
    readonly property color textMuted: "#b8c2d0"
    readonly property color textDim: "#8b95a5"
    readonly property string fontFamily: "sans-serif"

    // Luminous Accent Palette (Dynamic Wallpaper Accents)
    readonly property color blue: "#9bbf42"       // Primary Dynamic Accent
    readonly property color blueLight: "#c1db7f"  // Highlights & Glow
    readonly property color blueDeep: "#5b7220"   // Deep State
    readonly property color blueMuted: "#a2b574"  // Soft Accent
    readonly property color cyan: "#c1db7f"       // Secondary Glow
    readonly property color frost: "#f1f5f9"      // Crystalline White
    readonly property color indigo: "#5b7220"     // Sub-accent
    readonly property color sky: blueLight
    readonly property color mauve: blue

    // System Status Accents
    readonly property color green: "#30d158"      // Apple Emerald
    readonly property color yellow: "#ffd60a"     // Apple Amber
    readonly property color peach: "#ff9f0a"      // Apple Orange
    readonly property color red: "#ff453a"        // Apple Coral Red
    readonly property color purple: "#bf5af2"     // Apple Violet

    // Unified border radius matching Hyprland window rounding (4px)
    readonly property int windowRadius: 4
    readonly property real radiusSmall: 9.5         // Bar pills, workspaces, internal buttons
    readonly property int radius: 12              // Main status bar container
    readonly property int radiusLarge: 12         // Popups and cards
    readonly property int barHeight: 38

    // Helper to safely URL-encode colors for SVG data URIs
    function urlColor(col) {
        let str = col.toString();
        if (str.startsWith("#")) {
            return "%23" + str.substring(1);
        }
        return str;
    }
}
