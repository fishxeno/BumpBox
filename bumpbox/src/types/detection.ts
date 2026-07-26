export interface DetectionResult {
    label: string;
    category: string;
    minPrice: number;
    maxPrice: number;
    confidence: number;
    timestamp: Date;
    lockerId?: string;
}

export function parseDetectionResult(json: Record<string, unknown>): DetectionResult | null {
    const detection = json.detection as Record<string, unknown> | null | undefined;
    if (!detection) return null;

    return {
        label: (detection.label as string) ?? "Unknown",
        category: (detection.category as string) ?? "Uncategorized",
        minPrice: (detection.minPrice as number) ?? 0,
        maxPrice: (detection.maxPrice as number) ?? 0,
        confidence: (detection.confidence as number) ?? 0,
        timestamp: json.timestamp
            ? new Date(json.timestamp as string)
            : new Date(),
        lockerId: json.lockerId as string | undefined,
    };
}

export function getSuggestedStartingPrice(result: DetectionResult): number {
    return result.maxPrice;
}
