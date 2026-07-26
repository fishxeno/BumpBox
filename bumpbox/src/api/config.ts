function isLocalhost(): boolean {
    if (typeof window === "undefined") return false;
    const host = window.location.hostname;
    return host === "localhost" || host === "127.0.0.1" || host === "[::1]";
}

export const API_BASE_URL = isLocalhost()
    ? "http://localhost:8080"
    : "http://bumpbox-env-1.eba-43hmmxwt.ap-southeast-1.elasticbeanstalk.com";

export const API_ENDPOINTS = {
    triggerCapture: "/api/locker/trigger-capture",
    latestDetection: "/api/detections/latest",
    latestImage: "/api/detections/latest-image",
    createItem: "/api/item",
    getItem: "/api/item",
    updatePrice: "/api/item/price",
    returnItem: "/api/return",
    webhook: "/webhook",
    solenoidState: "/api/solenoid/state",
    solenoidToggle: "/api/solenoid/toggle",
} as const;

export function apiUrl(path: string): string {
    return `${API_BASE_URL}${path}`;
}
