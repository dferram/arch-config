.pragma library

function occursOnDate(r, dateObj) {
    const dStr = dateObj.getFullYear() + "-" + String(dateObj.getMonth() + 1).padStart(2, "0") + "-" + String(dateObj.getDate()).padStart(2, "0");
    const rep = (r.repeat || "none").toLowerCase();
    if (rep === "" || rep === "none") return r.date === dStr;

    const sp = (r.date || "").split("-");
    if (sp.length !== 3) return false;
    const sUtc = Date.UTC(+sp[0], +sp[1] - 1, +sp[2]);
    const tUtc = Date.UTC(dateObj.getFullYear(), dateObj.getMonth(), dateObj.getDate());
    if (tUtc < sUtc) return false;

    if (r.repeat_until) {
        const up = r.repeat_until.split("-");
        if (up.length === 3 && tUtc > Date.UTC(+up[0], +up[1] - 1, +up[2])) return false;
    }
    if (Array.isArray(r.exdates) && r.exdates.indexOf(dStr) !== -1) return false;

    const diffDays = Math.round((tUtc - sUtc) / 86400000);
    const dow = dateObj.getDay();
    const dayCodes = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];
    if (rep === "daily") return true;
    if (rep === "weekdays") return dow >= 1 && dow <= 5;
    if (rep === "weekly") {
        if (Array.isArray(r.repeat_days) && r.repeat_days.length > 0) return r.repeat_days.indexOf(dayCodes[dow]) !== -1;
        return diffDays % 7 === 0;
    }
    if (rep === "biweekly") return diffDays % 14 === 0;
    if (rep === "monthly") {
        const maxDay = new Date(dateObj.getFullYear(), dateObj.getMonth() + 1, 0).getDate();
        return dateObj.getDate() === Math.min(+sp[2], maxDay);
    }
    if (rep === "yearly") {
        if (dateObj.getMonth() + 1 !== +sp[1]) return false;
        const maxDay = new Date(dateObj.getFullYear(), dateObj.getMonth() + 1, 0).getDate();
        return dateObj.getDate() === Math.min(+sp[2], maxDay);
    }
    return false;
}

function toDate(r, dateOverride) {
    const d = (dateOverride || r.date).split("-");
    const t = (r.time || "00:00").split(":");
    return new Date(+d[0], +d[1] - 1, +d[2], +t[0] || 0, +t[1] || 0);
}

function categoryColor(cat, title) {
    const c = (cat || "").toLowerCase().trim();
    const t = (title || "").toLowerCase();
    if (c === "sara" || t.indexOf("sara") !== -1) return "#ff2d55";
    if (c === "marvel" || t.indexOf("doomsday") !== -1 || t.indexOf("marvel") !== -1) return "#10b981";
    if (c === "f1" || t.indexOf("formula 1") !== -1 || t.indexOf("grand prix") !== -1) return "#E10600";
    if (c === "colgate-palmolive" || c === "colgate") return "#0067fe";
    if (c === "projects") return "#14b8a6";
    if (c === "workshops" || c === "workshop" || t.indexOf("workshop") !== -1) return "#8b5cf6";
    if (c === "community" || t.indexOf("figma") !== -1 || t.indexOf("meetup") !== -1) return "#f59e0b";
    if (c === "free lance" || c === "free-lance" || c === "freelance") return "#06b6d4";
    if (c === "school" || c === "troyanos") return "#a855f7";
    if (c === "personal") return "#f97316";
    return "#38bdf8";
}

function contrastTextColor(col) {
    const c = (typeof col === "string") ? Qt.color(col) : col;
    const lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    return lum > 0.46 ? "#090b10" : "#ffffff";
}
