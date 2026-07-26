import { LISTING_DURATION_MS } from "../config/pricingConfig";

export enum LockerState {
    Empty = "empty",
    Available = "available",
    Sold = "sold",
}

export interface Item {
    id: string;
    name: string;
    description: string;
    startingPrice: number;
    floorPrice: number;
    listedAt: Date;
    listingDurationMs: number;
    paymentLink?: string | null;
    isSold?: boolean | null;
}

export enum ItemFetchStatus {
    ItemAvailable = "itemAvailable",
    EmptyLocker = "emptyLocker",
    Error = "error",
}

export interface ItemFetchResult {
    status: ItemFetchStatus;
    item?: Item;
    message?: string;
}

export function getAge(item: Item, now: Date): number {
    return now.getTime() - item.listedAt.getTime();
}

export function getHoursElapsed(item: Item, now: Date): number {
    return getAge(item, now) / (1000 * 60 * 60);
}

export function isExpired(item: Item, now: Date): boolean {
    return getAge(item, now) >= item.listingDurationMs;
}

export function getTimeRemaining(item: Item, now: Date): number {
    const remaining = item.listingDurationMs - getAge(item, now);
    return Math.max(0, remaining);
}

export function formatTimeRemaining(item: Item, now: Date): string {
    const remainingMs = getTimeRemaining(item, now);
    if (remainingMs <= 0) return "Expired";

    const totalMinutes = Math.floor(remainingMs / (1000 * 60));
    const days = Math.floor(totalMinutes / (60 * 24));
    const hours = Math.floor((totalMinutes % (60 * 24)) / 60);
    const minutes = totalMinutes % 60;

    if (days > 0) {
        return `${days} day${days === 1 ? "" : "s"} ${hours}h remaining`;
    }
    if (hours > 0) {
        return `${hours}h ${minutes}m remaining`;
    }
    return `${minutes}m remaining`;
}

export function getListingProgress(item: Item, now: Date): number {
    const totalHours = item.listingDurationMs / (1000 * 60 * 60);
    const progress = getHoursElapsed(item, now) / totalHours;
    return Math.min(1, Math.max(0, progress));
}

export function isItemAvailable(item: Item): boolean {
    return !(item.isSold ?? false);
}

export const DEFAULT_LISTING_DURATION_MS = LISTING_DURATION_MS;
