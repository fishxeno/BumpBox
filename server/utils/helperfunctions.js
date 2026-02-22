Date.prototype.addDays = function (days) {
    var date = new Date(this.valueOf());
    date.setDate(date.getDate() + days);
    return date;
};

export function addDaysAndFormat(days, baseDate = new Date()) {
    const date = new Date(baseDate);
    date.setDate(date.getDate() + days);

    const pad = (n) => String(n).padStart(2, "0");

    return (
        date.getFullYear() +
        "-" +
        pad(date.getMonth() + 1) +
        "-" +
        pad(date.getDate()) +
        " " +
        pad(date.getHours()) +
        ":" +
        pad(date.getMinutes()) +
        ":" +
        pad(date.getSeconds())
    );
}