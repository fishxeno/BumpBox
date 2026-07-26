import axios from "axios";
import { API_ENDPOINTS, apiUrl } from "../api/config";
import { LISTING_DURATION_MS } from "../config/pricingConfig";
import type { Item } from "../types/item";
import {
    ItemFetchStatus,
    type ItemFetchResult,
} from "../types/item";

function parsePrice(priceData: unknown): number {
    if (priceData == null) return 100.0;
    if (typeof priceData === "number") return priceData;
    if (typeof priceData === "string") {
        const parsed = parseFloat(priceData);
        return Number.isNaN(parsed) ? 100.0 : parsed;
    }
    return 100.0;
}

function parseDateTime(dateData: unknown): Date {
    if (dateData == null) {
        return new Date(Date.now() + LISTING_DURATION_MS);
    }

    if (typeof dateData === "string") {
        const isoParsed = new Date(dateData);
        if (!Number.isNaN(isoParsed.getTime())) return isoParsed;

        const parts = dateData.split(" ");
        if (parts.length === 2) {
            const dateParts = parts[0].split("-");
            const timeParts = parts[1].split(":");
            if (dateParts.length === 3 && timeParts.length === 3) {
                return new Date(
                    parseInt(dateParts[0], 10),
                    parseInt(dateParts[1], 10) - 1,
                    parseInt(dateParts[2], 10),
                    parseInt(timeParts[0], 10),
                    parseInt(timeParts[1], 10),
                    parseInt(timeParts[2], 10),
                );
            }
        }
    }

    return new Date(Date.now() + LISTING_DURATION_MS);
}

function parseItemFromBackend(data: Record<string, unknown>, isSold = false): Item {
    const itemId = data.itemid?.toString() ?? "unknown";
    const itemName = (data.item_name as string) ?? "Unknown Item";
    const price = parsePrice(data.price);
    const description =
        (data.description as string) ??
        "High-quality item available for purchase";
    const paymentLink = (data.paymentLink as string) ?? null;
    const expirationDate = parseDateTime(data.datetime_expire);
    const listedAt = new Date(expirationDate.getTime() - LISTING_DURATION_MS);

    return {
        id: itemId,
        name: itemName,
        description,
        startingPrice: price * 1.15,
        floorPrice: price,
        listedAt,
        listingDurationMs: LISTING_DURATION_MS,
        paymentLink,
        isSold,
    };
}

export async function fetchLatestItem(): Promise<ItemFetchResult> {
    try {
        const response = await axios.get(apiUrl(API_ENDPOINTS.getItem), {
            headers: { "Content-Type": "application/json" },
            validateStatus: (status) => status === 200 || status === 404,
        });

        if (response.status === 404) {
            return { status: ItemFetchStatus.Error, message: "No item found" };
        }

        const jsonData = response.data as Record<string, unknown>;
        const status = jsonData.status;
        const message = jsonData.message?.toString() ?? "";

        if (status === true && message === "Item is sold with status sold") {
            return { status: ItemFetchStatus.EmptyLocker, message };
        }

        if (jsonData.data == null) {
            return { status: ItemFetchStatus.Error, message: "No item data" };
        }

        const isSold = status === true && message === "Item is sold with status sold";
        const item = parseItemFromBackend(
            jsonData.data as Record<string, unknown>,
            isSold,
        );

        return { status: ItemFetchStatus.ItemAvailable, item };
    } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        return { status: ItemFetchStatus.Error, message };
    }
}

export async function checkPaymentStatus(): Promise<boolean | null> {
    try {
        const response = await axios.get(apiUrl(API_ENDPOINTS.getItem), {
            headers: { "Content-Type": "application/json" },
        });
        const jsonData = response.data as Record<string, unknown>;
        return jsonData.status === true;
    } catch {
        return null;
    }
}

export async function updateItemPrice(newPrice: number): Promise<Item | null> {
    try {
        const response = await axios.put(
            apiUrl(API_ENDPOINTS.updatePrice),
            { price: newPrice },
            { headers: { "Content-Type": "application/json" } },
        );

        const jsonData = response.data as Record<string, unknown>;
        const items = jsonData.items as Record<string, unknown>[] | undefined;

        if (!items?.length) return null;

        return parseItemFromBackend(items[0], false);
    } catch {
        return null;
    }
}

export async function returnItem(): Promise<boolean> {
    try {
        const response = await axios.get(apiUrl(API_ENDPOINTS.returnItem), {
            headers: { "Content-Type": "application/json" },
        });
        return response.status === 200;
    } catch {
        return false;
    }
}

export async function triggerBuyWebhook(testing: boolean): Promise<boolean | null> {
    try {
        const response = await axios.post(
            apiUrl(API_ENDPOINTS.webhook),
            { testing_intent: testing },
            { headers: { "Content-Type": "application/json" } },
        );
        return response.status === 200 ? true : null;
    } catch {
        return null;
    }
}

export async function getSolenoidState(): Promise<boolean | null> {
    try {
        const response = await axios.get(apiUrl(API_ENDPOINTS.solenoidState), {
            headers: { "Content-Type": "application/json" },
        });
        const data = response.data as Record<string, unknown>;
        return data.solenoidOn === true;
    } catch {
        return null;
    }
}

export async function toggleSolenoid(): Promise<boolean | null> {
    try {
        const response = await axios.post(
            apiUrl(API_ENDPOINTS.solenoidToggle),
            {},
            { headers: { "Content-Type": "application/json" } },
        );
        const data = response.data as Record<string, unknown>;
        return data.solenoidOn === true;
    } catch {
        return null;
    }
}

export function isValidPhoneNumber(phone: string): boolean {
    const cleaned = phone.replace(/[\s-]/g, "");

    if (cleaned.startsWith("+65")) {
        return cleaned.length === 11 && /^\+65[0-9]{8}$/.test(cleaned);
    }
    if (cleaned.startsWith("65")) {
        return cleaned.length === 10 && /^65[0-9]{8}$/.test(cleaned);
    }
    return cleaned.length === 8 && /^[0-9]{8}$/.test(cleaned);
}

export function formatPhoneNumber(phone: string): string {
    const cleaned = phone.replace(/[\s-]/g, "");

    if (cleaned.startsWith("+65")) return cleaned;
    if (cleaned.startsWith("65")) return `+${cleaned}`;
    return `+65${cleaned}`;
}

export async function createItemListing(params: {
    phone: string;
    itemName: string;
    description: string;
    price: number;
    days: number;
}): Promise<{ itemId: string; paymentLink: string }> {
    const response = await axios.post(
        apiUrl(API_ENDPOINTS.createItem),
        {
            phone: params.phone,
            item_name: params.itemName,
            description: params.description,
            price: params.price,
            days: params.days,
        },
        { headers: { "Content-Type": "application/json" } },
    );

    if (response.status !== 201) {
        throw new Error(`Failed to create item: ${response.status}`);
    }

    const data = response.data as Record<string, unknown>;
    if (data.message !== "Item created successfully") {
        throw new Error(`Unexpected response: ${data.message}`);
    }

    const itemData = data.data as Record<string, unknown> | undefined;

    return {
        itemId: String(data.itemId ?? ""),
        paymentLink: (itemData?.paymentLink as string) ?? "",
    };
}
