import { useCallback, useEffect, useRef, useState } from "react";
import {
    DECAY_UPDATE_INTERVAL_MS,
    ONLINE_INTEREST_POLL_INTERVAL_MS,
    STATUS_POLL_INTERVAL_SECONDS,
    formatPrice,
} from "../config/pricingConfig";
import {
    checkPaymentStatus,
    fetchLatestItem,
    // getSolenoidState,
    returnItem,
    toggleSolenoid,
    triggerBuyWebhook,
    updateItemPrice,
} from "../services/itemApiService";
import {
    getMockItem,
    getRealisticOnlineInterest,
    shouldTriggerOnlineSurge,
    type OnlineInterest,
} from "../services/mockDataService";
import {
    calculateTimeDecayPrice,
    getFinalPrice,
    getPriceColor,
    getSurgeBadgeColor,
} from "../services/pricingService";
import {
    clearCurrentItem,
    clearTestStartTime,
    loadItem,
    loadSurgeCounts,
    loadTestStartTime,
    saveItem,
    saveSurgeCounts,
    saveTestStartTime,
} from "../services/storageService";
import {
    ItemFetchStatus,
    LockerState,
    formatTimeRemaining,
    type Item,
} from "../types/item";

const TEST_DURATION_MS = 5 * 60 * 1000;

export function useKioskDashboard() {
    const [currentItem, setCurrentItem] = useState<Item | null>(null);
    const [lockerState, setLockerState] = useState<LockerState>(LockerState.Empty);
    const [isLoading, setIsLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [surgeCount, setSurgeCount] = useState(0);
    const [physicalSurgeCount, setPhysicalSurgeCount] = useState(0);
    const [onlineSurgeCount, setOnlineSurgeCount] = useState(0);
    const [currentDecayPrice, setCurrentDecayPrice] = useState(0);
    const [currentPrice, setCurrentPrice] = useState(0);
    const [lastOnlineInterest, setLastOnlineInterest] = useState<OnlineInterest | null>(null);
    const [solenoidOn, setSolenoidOn] = useState(false);
    const [debugMode, setDebugMode] = useState(false);
    const [daysFastForwarded, setDaysFastForwarded] = useState(0);
    const [testStartTime, setTestStartTime] = useState<Date | null>(null);
    const [testTimeRemaining, setTestTimeRemaining] = useState<number | null>(null);
    const [toast, setToast] = useState<{ message: string; type: "success" | "error" | "info" } | null>(null);
    const [paymentModal, setPaymentModal] = useState<{
        item: Item;
        currentPrice: number;
        isTestMode: boolean;
    } | null>(null);
    const [busyMessage, setBusyMessage] = useState<string | null>(null);

    const daysOffsetRef = useRef(0);

    const getEffectiveNow = useCallback(() => {
        return new Date(Date.now() + daysOffsetRef.current * 24 * 60 * 60 * 1000);
    }, []);

    const showToast = useCallback((message: string, type: "success" | "error" | "info" = "info") => {
        setToast({ message, type });
        setTimeout(() => setToast(null), 3000);
    }, []);


    const updatePrices = useCallback(
        (item: Item | null, surge: number) => {
            if (!item) return;
            const now = getEffectiveNow();
            setCurrentDecayPrice(calculateTimeDecayPrice(item, now));
            setCurrentPrice(getFinalPrice(item, surge, now));
        },
        [getEffectiveNow],
    );

    const saveCounts = useCallback(
        (counts: { surgeCount: number; physicalSurgeCount: number; onlineSurgeCount: number }) => {
            saveSurgeCounts(counts);
        },
        [],
    );

    const transitionToEmpty = useCallback(async () => {
        setCurrentItem(null);
        setLockerState(LockerState.Empty);
        setSurgeCount(0);
        setPhysicalSurgeCount(0);
        setOnlineSurgeCount(0);
        setCurrentDecayPrice(0);
        setCurrentPrice(0);
        clearCurrentItem();
    }, []);

    const refreshItemFromAPI = useCallback(async () => {
        const result = await fetchLatestItem();

        if (result.status === ItemFetchStatus.EmptyLocker) {
            await transitionToEmpty();
            showToast("Item sold! Locker is now empty", "success");
            return;
        }

        if (result.status === ItemFetchStatus.ItemAvailable && result.item) {
            setCurrentItem(result.item);
            setLockerState(LockerState.Available);
            setSurgeCount(0);
            setPhysicalSurgeCount(0);
            setOnlineSurgeCount(0);
            saveItem(result.item);
            saveCounts({ surgeCount: 0, physicalSurgeCount: 0, onlineSurgeCount: 0 });
            updatePrices(result.item, 0);
            showToast(`Loaded: ${result.item.name}`, "success");
            return;
        }

        showToast("Failed to load item from backend", "error");
    }, [saveCounts, showToast, transitionToEmpty, updatePrices]);

    const loadOrCreateItem = useCallback(async () => {
        const savedItem = loadItem();
        const savedCounts = loadSurgeCounts();
        const savedTestStart = loadTestStartTime();

        if (savedTestStart) {
            setTestStartTime(savedTestStart);
        }

        if (savedItem) {
            setCurrentItem(savedItem);
            setLockerState(LockerState.Available);
            setSurgeCount(savedCounts.surgeCount);
            setPhysicalSurgeCount(savedCounts.physicalSurgeCount);
            setOnlineSurgeCount(savedCounts.onlineSurgeCount);
            updatePrices(savedItem, savedCounts.surgeCount);
            setIsLoading(false);
            return;
        }

        const result = await fetchLatestItem();

        if (result.status === ItemFetchStatus.EmptyLocker) {
            await transitionToEmpty();
            setIsLoading(false);
            return;
        }

        if (result.status === ItemFetchStatus.ItemAvailable && result.item) {
            setCurrentItem(result.item);
            setLockerState(LockerState.Available);
            saveItem(result.item);
            updatePrices(result.item, 0);
            setIsLoading(false);
            return;
        }

        const mockItem = getMockItem();
        setCurrentItem(mockItem);
        setLockerState(LockerState.Available);
        saveItem(mockItem);
        updatePrices(mockItem, 0);
        setIsLoading(false);
    }, [transitionToEmpty, updatePrices]);

    const incrementPrice = useCallback((isPhysical: boolean) => {
        setSurgeCount((prev) => prev + 1);
        if (isPhysical) {
            setPhysicalSurgeCount((prev) => prev + 1);
        } else {
            setOnlineSurgeCount((prev) => prev + 1);
        }
    }, []);

    const preparePayment = useCallback(
        async (testing: boolean) => {
            if (!currentItem) return;

            setBusyMessage(testing ? "Preparing test session..." : "Preparing payment...");

            try {
                const webhookResult = await triggerBuyWebhook(testing);
                if (webhookResult !== true) {
                    throw new Error(testing ? "Failed to trigger test webhook" : "Failed to trigger buy webhook");
                }

                const updatedItem = await updateItemPrice(currentPrice);
                if (!updatedItem?.paymentLink) {
                    throw new Error("Payment link not available");
                }

                setCurrentItem(updatedItem);
                saveItem(updatedItem);
                setPaymentModal({
                    item: updatedItem,
                    currentPrice,
                    isTestMode: testing,
                });
            } catch (err) {
                showToast(err instanceof Error ? err.message : "Payment preparation failed", "error");
            } finally {
                setBusyMessage(null);
            }
        },
        [currentItem, currentPrice, showToast],
    );

    const handlePaymentComplete = useCallback(
        async (success: boolean, isTestMode: boolean) => {
            setPaymentModal(null);

            if (!success) return;

            if (isTestMode) {
                const start = new Date();
                setTestStartTime(start);
                saveTestStartTime(start);
            }

            await refreshItemFromAPI();
        },
        [refreshItemFromAPI],
    );

    const handleReturnItem = useCallback(async () => {
        setBusyMessage("Processing return...");
        try {
            const success = await returnItem();
            if (success) {
                setTestStartTime(null);
                setTestTimeRemaining(null);
                clearTestStartTime();
                showToast("Item returned successfully! Full refund processed.", "success");
                await refreshItemFromAPI();
            } else {
                showToast("Failed to return item. Please try again.", "error");
            }
        } finally {
            setBusyMessage(null);
        }
    }, [refreshItemFromAPI, showToast]);

    const handleToggleSolenoid = useCallback(async () => {
        const newState = await toggleSolenoid();
        if (newState != null) {
            setSolenoidOn(newState);
            showToast(`Solenoid turned ${newState ? "ON" : "OFF"}`, "info");
        }
    }, [showToast]);

    const fastForwardOneDay = useCallback(() => {
        daysOffsetRef.current += 1;
        setDaysFastForwarded(daysOffsetRef.current);
        if (currentItem) {
            updatePrices(currentItem, surgeCount);
        }
        showToast(`Fast forwarded to +${daysOffsetRef.current} days`, "info");
    }, [currentItem, showToast, surgeCount, updatePrices]);

    useEffect(() => {
        loadOrCreateItem().catch(() => {
            setError("Failed to initialize kiosk");
            setIsLoading(false);
        });
    }, [loadOrCreateItem]);

    useEffect(() => {
        if (!currentItem) return;
        updatePrices(currentItem, surgeCount);
        saveCounts({ surgeCount, physicalSurgeCount, onlineSurgeCount });
    }, [currentItem, surgeCount, physicalSurgeCount, onlineSurgeCount, updatePrices, saveCounts]);

    useEffect(() => {
        if (!currentItem) return;

        const interval = setInterval(() => {
            updatePrices(currentItem, surgeCount);
        }, DECAY_UPDATE_INTERVAL_MS);

        return () => clearInterval(interval);
    }, [currentItem, surgeCount, updatePrices]);

    useEffect(() => {
        const interval = setInterval(() => {
            const interest = getRealisticOnlineInterest();
            setLastOnlineInterest(interest);
            if (shouldTriggerOnlineSurge()) {
                incrementPrice(false);
            }
        }, ONLINE_INTEREST_POLL_INTERVAL_MS);

        return () => clearInterval(interval);
    }, [incrementPrice]);

    useEffect(() => {
        if (lockerState !== LockerState.Available || !currentItem) return;

        const interval = setInterval(async () => {
            const result = await fetchLatestItem();
            if (result.status === ItemFetchStatus.EmptyLocker) {
                await transitionToEmpty();
                showToast("Item sold! Locker is now empty", "success");
            }
        }, STATUS_POLL_INTERVAL_SECONDS * 1000);

        return () => clearInterval(interval);
    }, [currentItem, lockerState, showToast, transitionToEmpty]);

    useEffect(() => {
        const interval = setInterval(async () => {
            // const state = await getSolenoidState();
            const state = null
            if (state != null) setSolenoidOn(state);
        }, 5000);

        return () => clearInterval(interval);
    }, []);

    useEffect(() => {
        if (!testStartTime) {
            setTestTimeRemaining(null);
            return;
        }

        const interval = setInterval(() => {
            const elapsed = Date.now() - testStartTime.getTime();
            const remaining = TEST_DURATION_MS - elapsed;

            if (remaining <= 0) {
                setTestTimeRemaining(null);
                setTestStartTime(null);
                clearTestStartTime();
                refreshItemFromAPI();
                return;
            }

            setTestTimeRemaining(remaining);
        }, 1000);

        return () => clearInterval(interval);
    }, [refreshItemFromAPI, testStartTime]);

    const priceColor = currentItem
        ? getPriceColor(currentItem, surgeCount, getEffectiveNow())
        : "#374151";

    const surgeBadgeColor = getSurgeBadgeColor(physicalSurgeCount, onlineSurgeCount);

    return {
        currentItem,
        lockerState,
        isLoading,
        error,
        surgeCount,
        physicalSurgeCount,
        onlineSurgeCount,
        currentDecayPrice,
        currentPrice,
        lastOnlineInterest,
        solenoidOn,
        debugMode,
        setDebugMode,
        daysFastForwarded,
        testStartTime,
        testTimeRemaining,
        toast,
        paymentModal,
        busyMessage,
        priceColor,
        surgeBadgeColor,
        formatPrice,
        formatTimeRemaining: (item: Item) => formatTimeRemaining(item, getEffectiveNow()),
        refreshItemFromAPI,
        preparePayment,
        handlePaymentComplete,
        handleReturnItem,
        handleToggleSolenoid,
        fastForwardOneDay,
        checkPaymentStatus,
    };
}

export function formatDuration(ms: number): string {
    const totalSeconds = Math.floor(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
}
