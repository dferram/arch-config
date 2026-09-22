import QtQuick

QtObject {
    id: root

    // Apple iPhone Liquid Glass - Obsidian Frosted Glass Base
    readonly property color bg: "#08080a"
    readonly property color bgDark: "#050507"
    readonly property color bgCrust: "#020204"
    readonly property color bgGlass: "#d90d0d11"     // 85% neutral obsidian glass tint (more opaque, less see-through)
    readonly property color popupBg: "#f20f0f14"     // 95% neutral obsidian sheet glass (clean legibility)

    // Surfaces: Clean specular frosted layers
    readonly property color surface: "#15ffffff"      // Frosted semi-transparent white (~8%)
    readonly property color surfaceHover: "#24ffffff" // Hover state (~14%)
    readonly property color surfaceActive: "#33ffffff"// Active/pressed state (~20%)

    // Liquid Glass Specular Hairlines (iPhone hallmark)
    readonly property color border: "#28ffffff"       // Crisp specular hairline (16% white)
    readonly property color borderSubtle: "#14ffffff" // Subtle divider (8% white)
    readonly property color borderGlow: "#45ffffff"   // Specular sheen (27% white)
    readonly property color glassHighlight: "#33ffffff" // Top specular shine

    // Apple Clean Neutral Typography (pure neutral zinc, no blue undertones)
    readonly property color text: "#ffffff"
    readonly property color textSub: "#e2e8f0"
    readonly property color textMuted: "#a1a1aa"
    readonly property color textDim: "#71717a"
    readonly property string fontFamily: "sans-serif"

    // Refined Accent Palette (Dynamic Wallpaper Accents)
    readonly property color blue: "#42a0bf"       // Primary Dynamic Accent
    readonly property color blueLight: "#7fc4db"  // Highlights & Glow
    readonly property color blueDeep: "#205e72"   // Deep State
    readonly property color blueMuted: "#74a5b5"  // Soft Accent
    readonly property color cyan: "#7fc4db"       // Secondary Glow
    readonly property color frost: "#f1f5f9"      // Crystalline White
    readonly property color indigo: "#205e72"     // Sub-accent
    readonly property color sky: blueLight
    readonly property color mauve: blue

    // System Status Accents
    readonly property color green: "#30d158"      // Apple Emerald
    readonly property color yellow: "#ffd60a"     // Apple Amber
    readonly property color peach: "#ff9f0a"      // Apple Orange
    readonly property color red: "#ff453a"        // Apple Coral Red
    readonly property color purple: "#bf5af2"     // Apple Violet

    // Unified border radius matching Hyprland window rounding (10px)
    readonly property int windowRadius: 10
    readonly property int radiusSmall: 10         // Bar pills, workspaces, internal buttons
    readonly property int radius: 10              // Main status bar container
    readonly property int radiusLarge: 10         // Popups and cards
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
