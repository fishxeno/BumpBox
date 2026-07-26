export const LISTING_DURATION_MS = 7 * 24 * 60 * 60 * 1000;
export const DECAY_HALF_LIFE_HOURS = 84.0;
export const DECAY_BASE = Math.pow(0.2, 1.0 / DECAY_HALF_LIFE_HOURS);
export const DECAY_UPDATE_INTERVAL_MS = 10_000;
export const SURGE_MULTIPLIER = 1.01;
export const MAX_SURGE_MULTIPLIER = 1.5;
export const MAX_SURGE_COUNT = Math.floor(
    Math.log(MAX_SURGE_MULTIPLIER) / Math.log(SURGE_MULTIPLIER),
);
export const ONLINE_INTEREST_POLL_INTERVAL_MS = 5_000;
export const MOCK_ONLINE_SURGE_PROBABILITY = 0.01;
export const STATUS_POLL_INTERVAL_SECONDS = 15;
export const DETECTION_TIMEOUT_MS = 30_000;
export const DETECTION_POLL_INTERVAL_MS = 2_000;
export const DEFAULT_LOCKER_ID = "locker1";

export function formatPrice(price: number): string {
    return `$${price.toFixed(2)}`;
}
