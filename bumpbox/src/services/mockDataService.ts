import { LISTING_DURATION_MS, MOCK_ONLINE_SURGE_PROBABILITY } from "../config/pricingConfig";
import type { Item } from "../types/item";

export interface OnlineInterest {
    pageViews: number;
    clickCount: number;
    wishlistAdds: number;
    lastActivity: Date;
}

export function getMockItem(): Item {
    const now = new Date();
    const listedAt = new Date(now.getTime() - (2 * 24 + 3) * 60 * 60 * 1000);

    return {
        id: "item_001",
        name: "Bose QuietComfort 35 II",
        description:
            "Wireless noise-cancelling headphones in excellent condition. " +
            "Occasionally used, includes original case and cables. " +
            "Battery life still excellent.",
        startingPrice: 150.0,
        floorPrice: 80.0,
        listedAt,
        listingDurationMs: LISTING_DURATION_MS,
    };
}

export function getRealisticOnlineInterest(): OnlineInterest {
    const now = new Date();
    const hour = now.getHours();
    const isPeakHour = (hour >= 10 && hour <= 14) || (hour >= 18 && hour <= 21);
    const activityMultiplier = isPeakHour ? 2.0 : 1.0;

    const baseViews = (Math.floor(Math.random() * 30) + 10) * activityMultiplier;
    const baseClicks = (Math.floor(Math.random() * 10) + 2) * activityMultiplier;
    const baseWishlist = Math.floor(Math.random() * 3);
    const isSpike = Math.random() < 0.1;
    const spikeMultiplier = isSpike ? 3.0 : 1.0;

    return {
        pageViews: Math.round(baseViews * spikeMultiplier),
        clickCount: Math.round(baseClicks * spikeMultiplier),
        wishlistAdds: baseWishlist,
        lastActivity: new Date(now.getTime() - Math.floor(Math.random() * 60) * 1000),
    };
}

export function shouldTriggerOnlineSurge(): boolean {
    return Math.random() < MOCK_ONLINE_SURGE_PROBABILITY;
}
