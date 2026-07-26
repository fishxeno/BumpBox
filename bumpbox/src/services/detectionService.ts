import axios from "axios";
import { API_ENDPOINTS, apiUrl } from "../api/config";
import {
    DETECTION_POLL_INTERVAL_MS,
    DETECTION_TIMEOUT_MS,
    DEFAULT_LOCKER_ID,
} from "../config/pricingConfig";
import { parseDetectionResult, type DetectionResult } from "../types/detection";

export async function triggerCapture(lockerId = DEFAULT_LOCKER_ID): Promise<void> {
    const response = await axios.post(
        apiUrl(API_ENDPOINTS.triggerCapture),
        { lockerId },
        { headers: { "Content-Type": "application/json" } },
    );

    const data = response.data as Record<string, unknown>;
    if (data.success !== true) {
        throw new Error(`Backend returned failure: ${data.message}`);
    }
}

export async function fetchLatestDetection(since?: Date): Promise<DetectionResult | null> {
    try {
        const params = since ? { since: since.toISOString() } : undefined;
        const response = await axios.get(apiUrl(API_ENDPOINTS.latestDetection), { params });
        const data = response.data as Record<string, unknown>;

        if (data.detection == null) return null;

        return parseDetectionResult(data);
    } catch {
        return null;
    }
}

export async function pollForDetection(options?: {
    timeoutMs?: number;
    pollIntervalMs?: number;
    since?: Date;
}): Promise<DetectionResult | null> {
    const timeoutMs = options?.timeoutMs ?? DETECTION_TIMEOUT_MS;
    const pollIntervalMs = options?.pollIntervalMs ?? DETECTION_POLL_INTERVAL_MS;
    const since = options?.since ?? new Date();
    const startTime = Date.now();

    while (Date.now() - startTime < timeoutMs) {
        const result = await fetchLatestDetection(since);
        if (result) return result;
        await new Promise((resolve) => setTimeout(resolve, pollIntervalMs));
    }

    return null;
}

export function getLatestImageUrl(): string {
    return `${apiUrl(API_ENDPOINTS.latestImage)}?t=${Date.now()}`;
}
