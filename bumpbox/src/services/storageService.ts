import type { Item } from "../types/item";

const KEYS = {
    itemId: "current_item_id",
    itemName: "current_item_name",
    itemDescription: "current_item_description",
    itemStartingPrice: "current_item_starting_price",
    itemFloorPrice: "current_item_floor_price",
    itemListedAt: "current_item_listed_at",
    itemListingDurationMs: "current_item_listing_duration_ms",
    itemPaymentLink: "current_item_payment_link",
    itemIsSold: "current_item_is_sold",
    surgeCount: "surge_count",
    physicalSurgeCount: "physical_surge_count",
    onlineSurgeCount: "online_surge_count",
    testStartTime: "test_start_time",
} as const;

export function saveItem(item: Item): void {
    localStorage.setItem(KEYS.itemId, item.id);
    localStorage.setItem(KEYS.itemName, item.name);
    localStorage.setItem(KEYS.itemDescription, item.description);
    localStorage.setItem(KEYS.itemStartingPrice, String(item.startingPrice));
    localStorage.setItem(KEYS.itemFloorPrice, String(item.floorPrice));
    localStorage.setItem(KEYS.itemListedAt, item.listedAt.toISOString());
    localStorage.setItem(KEYS.itemListingDurationMs, String(item.listingDurationMs));

    if (item.paymentLink) {
        localStorage.setItem(KEYS.itemPaymentLink, item.paymentLink);
    } else {
        localStorage.removeItem(KEYS.itemPaymentLink);
    }

    if (item.isSold != null) {
        localStorage.setItem(KEYS.itemIsSold, String(item.isSold));
    } else {
        localStorage.removeItem(KEYS.itemIsSold);
    }
}

export function loadItem(): Item | null {
    const id = localStorage.getItem(KEYS.itemId);
    if (!id) return null;

    const name = localStorage.getItem(KEYS.itemName);
    const description = localStorage.getItem(KEYS.itemDescription);
    const startingPrice = localStorage.getItem(KEYS.itemStartingPrice);
    const floorPrice = localStorage.getItem(KEYS.itemFloorPrice);
    const listedAtStr = localStorage.getItem(KEYS.itemListedAt);
    const listingDurationMs = localStorage.getItem(KEYS.itemListingDurationMs);
    const paymentLink = localStorage.getItem(KEYS.itemPaymentLink);
    const isSoldStr = localStorage.getItem(KEYS.itemIsSold);

    if (!name || !description || !startingPrice || !floorPrice || !listedAtStr || !listingDurationMs) {
        return null;
    }

    try {
        return {
            id,
            name,
            description,
            startingPrice: parseFloat(startingPrice),
            floorPrice: parseFloat(floorPrice),
            listedAt: new Date(listedAtStr),
            listingDurationMs: parseInt(listingDurationMs, 10),
            paymentLink,
            isSold: isSoldStr != null ? isSoldStr === "true" : null,
        };
    } catch {
        return null;
    }
}

export function saveSurgeCounts(counts: {
    surgeCount: number;
    physicalSurgeCount: number;
    onlineSurgeCount: number;
}): void {
    localStorage.setItem(KEYS.surgeCount, String(counts.surgeCount));
    localStorage.setItem(KEYS.physicalSurgeCount, String(counts.physicalSurgeCount));
    localStorage.setItem(KEYS.onlineSurgeCount, String(counts.onlineSurgeCount));
}

export function loadSurgeCounts(): {
    surgeCount: number;
    physicalSurgeCount: number;
    onlineSurgeCount: number;
} {
    return {
        surgeCount: parseInt(localStorage.getItem(KEYS.surgeCount) ?? "0", 10),
        physicalSurgeCount: parseInt(localStorage.getItem(KEYS.physicalSurgeCount) ?? "0", 10),
        onlineSurgeCount: parseInt(localStorage.getItem(KEYS.onlineSurgeCount) ?? "0", 10),
    };
}

export function clearCurrentItem(): void {
    localStorage.removeItem(KEYS.itemId);
    localStorage.removeItem(KEYS.itemName);
    localStorage.removeItem(KEYS.itemDescription);
    localStorage.removeItem(KEYS.itemStartingPrice);
    localStorage.removeItem(KEYS.itemFloorPrice);
    localStorage.removeItem(KEYS.itemListedAt);
    localStorage.removeItem(KEYS.itemListingDurationMs);
    localStorage.removeItem(KEYS.itemPaymentLink);
    localStorage.removeItem(KEYS.itemIsSold);
    localStorage.removeItem(KEYS.testStartTime);
}

export function saveTestStartTime(startTime: Date): void {
    localStorage.setItem(KEYS.testStartTime, startTime.toISOString());
}

export function loadTestStartTime(): Date | null {
    const timeStr = localStorage.getItem(KEYS.testStartTime);
    if (!timeStr) return null;

    try {
        const startTime = new Date(timeStr);
        const elapsed = Date.now() - startTime.getTime();
        if (elapsed > 5 * 60 * 1000) {
            clearTestStartTime();
            return null;
        }
        return startTime;
    } catch {
        return null;
    }
}

export function clearTestStartTime(): void {
    localStorage.removeItem(KEYS.testStartTime);
}
