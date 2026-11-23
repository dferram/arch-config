import QtQuick
import Quickshell
import "../theme"
import "ReminderUtils.js" as ReminderUtils

// Renders the canonical reminder category icon + exposes its category color.
Item {
    id: root
    Theme { id: theme }

    property string category: ""
    property string title: ""
    property string notes: ""
    property string logo: ""
    property int boxSize: 16

    readonly property color categoryColor: ReminderUtils.categoryColor(category, title)
    readonly property string catLow: (category || "").toLowerCase().trim()
    readonly property string titleLow: (title || "").toLowerCase()
    readonly property string notesLow: (notes || "").toLowerCase()
    readonly property string logoLow: (logo || "").toLowerCase().trim()

    readonly property bool isSara: catLow === "sara" || titleLow.indexOf("sara") !== -1
    readonly property bool isMarvel: catLow === "marvel" || titleLow.indexOf("doomsday") !== -1 || titleLow.indexOf("marvel") !== -1
    readonly property bool isF1: catLow === "f1" || titleLow.indexOf("formula 1") !== -1 || titleLow.indexOf("grand prix") !== -1
    readonly property bool isCP: catLow === "colgate-palmolive" || catLow === "colgate"
    readonly property bool isSchool: catLow === "school" || catLow === "troyanos"
    readonly property bool isProjects: catLow === "projects"
    readonly property bool isFreelance: catLow === "free lance" || catLow === "free-lance" || catLow === "freelance"
    readonly property bool isPersonal: catLow === "personal"
    readonly property bool isWorkshops: catLow === "workshops" || catLow === "workshop" || titleLow.indexOf("workshop") !== -1
    readonly property bool isCommunity: catLow === "community" || titleLow.indexOf("figma") !== -1 || titleLow.indexOf("meetup") !== -1

    readonly property string iconSource: {
        if (isSara) return "file:///home/ferram/Personal/dotfiles/.config/quickshell/icons/holiday-heart.svg";
        if (isMarvel) return "file:///home/ferram/Personal/dotfiles/.config/quickshell/icons/marvel.svg";
        if (isF1) return "file:///home/ferram/.local/share/icons/f1.svg";
        if (isCP) return "file:///home/ferram/.local/share/icons/cp.svg";
        if (isSchool) return "file:///home/ferram/.local/share/icons/troyanos.svg";
        if (isPersonal) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='%23f97316' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'><path d='M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2'/><circle cx='12' cy='7' r='4'/></svg>";
        }
        if (isWorkshops) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='%238b5cf6' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'><path d='M2 3h20'/><path d='M21 3v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V3'/><path d='m7 21 5-5 5 5'/></svg>";
        }
        if (isProjects || isFreelance) {
            const hex = isProjects ? "%2314b8a6" : "%2306b6d4";
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + hex + "' stroke-width='2.4' stroke-linecap='round' stroke-linejoin='round'><path d='m18 16 4-4-4-4'/><path d='m6 8-4 4 4 4'/><path d='m14.5 4-5 16'/></svg>";
        }
        if (isCommunity) {
            if (logoLow === "fof-qro") return "file://" + Quickshell.shellPath("icons/community-fof-qro.svg");
            if (logoLow === "claude") return "file://" + Quickshell.shellPath("icons/claude.svg");
            if (logoLow === "devin") return "file:///usr/share/pixmaps/devin-desktop.png";
            if (logoLow === "gdg") return "file://" + Quickshell.shellPath("icons/community-gdg.svg");
            if (logoLow === "default") return "file://" + Quickshell.shellPath("icons/community-default.svg");
            const full = titleLow + " " + notesLow;
            if (full.indexOf("figma") !== -1 || full.indexOf("fof") !== -1) return "file://" + Quickshell.shellPath("icons/community-fof-qro.svg");
            if (full.indexOf("claude") !== -1 || full.indexOf("anthropic") !== -1) return "file://" + Quickshell.shellPath("icons/claude.svg");
            if (full.indexOf("devin") !== -1 || full.indexOf("cognition") !== -1) return "file:///usr/share/pixmaps/devin-desktop.png";
            if (full.indexOf("gdg") !== -1 || full.indexOf("google developer") !== -1 || full.indexOf("devfest") !== -1 || full.indexOf("google") !== -1) return "file://" + Quickshell.shellPath("icons/community-gdg.svg");
            return "file://" + Quickshell.shellPath("icons/community-default.svg");
        }
        return "";
    }

    implicitWidth: boxSize
    implicitHeight: boxSize
    width: boxSize
    height: boxSize

    Rectangle {
        visible: root.iconSource === ""
        anchors.centerIn: parent
        width: Math.max(7, Math.round(root.boxSize * 0.55))
        height: width
        radius: width / 2
        color: root.categoryColor
    }

    Image {
        visible: root.iconSource !== ""
        anchors.centerIn: parent
        width: root.isMarvel ? Math.round(root.boxSize * 1.15) : root.boxSize
        height: (root.isMarvel || root.isF1 || root.isCP) ? Math.round(root.boxSize * 0.72) : root.boxSize
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
