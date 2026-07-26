import {
    DECAY_BASE,
    MAX_SURGE_COUNT,
    SURGE_MULTIPLIER,
} from "../config/pricingConfig";
import type { Item } from "../types/item";
import { getHoursElapsed, isExpired } from "../types/item";

export function calculateTimeDecayPrice(item: Item, now: Date): number {
    if (isExpired(item, now)) {
        return item.floorPrice;
    }

    const hoursElapsed = getHoursElapsed(item, now);
    const priceRange = item.startingPrice - item.floorPrice;
    const decayFactor = Math.pow(DECAY_BASE, hoursElapsed);
    const decayedPrice = item.floorPrice + priceRange * decayFactor;

    return Math.max(decayedPrice, item.floorPrice);
}

export function calculateSurgeMultiplier(surgeCount: number): number {
    if (surgeCount <= 0) return 1.0;

    const cappedCount = Math.min(surgeCount, MAX_SURGE_COUNT);
    return Math.pow(SURGE_MULTIPLIER, cappedCount);
}

export function calculateSurgePrice(decayBasePrice: number, surgeCount: number): number {
    return decayBasePrice * calculateSurgeMultiplier(surgeCount);
}

export function getFinalPrice(item: Item, surgeCount: number, now: Date): number {
    const decayPrice = calculateTimeDecayPrice(item, now);
    const surgedPrice = calculateSurgePrice(decayPrice, surgeCount);
    return Math.max(surgedPrice, item.floorPrice);
}

export function getPriceColor(item: Item, surgeCount: number, now: Date): string {
    if (surgeCount === 0) {
        const progress = (now.getTime() - item.listedAt.getTime()) / item.listingDurationMs;
        if (progress < 0.3) return "#1d4ed8";
        if (progress < 0.7) return "#15803d";
        return "#7e22ce";
    }
    if (surgeCount <= 2) return "#c2410c";
    return "#b91c1c";
}

export function getSurgeBadgeColor(physicalSurgeCount: number, onlineSurgeCount: number): string {
    if (physicalSurgeCount > 0 && onlineSurgeCount > 0) return "#9333ea";
    if (physicalSurgeCount > 0) return "#16a34a";
    return "#2563eb";
}
