import { useEffect, useState, type ReactNode } from "react";
import { useNavigate } from "react-router-dom";
import { Button, Form, Spinner } from "react-bootstrap";
import {
    createItemListing,
    formatPhoneNumber,
    isValidPhoneNumber,
} from "../services/itemApiService";
import {
    getLatestImageUrl,
    pollForDetection,
    triggerCapture,
} from "../services/detectionService";
import type { DetectionResult } from "../types/detection";
import { DETECTION_TIMEOUT_MS } from "../config/pricingConfig";

type ScreenState = "ready" | "triggering" | "detecting" | "showingResults" | "creating";

export default function SellScreen() {
    const navigate = useNavigate();
    const [screenState, setScreenState] = useState<ScreenState>("ready");
    const [detectionResult, setDetectionResult] = useState<DetectionResult | null>(null);
    const [errorMessage, setErrorMessage] = useState<string | null>(null);
    const [elapsedSeconds, setElapsedSeconds] = useState(0);
    const [isEditing, setIsEditing] = useState(false);

    const [itemName, setItemName] = useState("");
    const [description, setDescription] = useState("");
    const [price, setPrice] = useState("");
    const [phone, setPhone] = useState("");
    const [selectedDays, setSelectedDays] = useState(7);
    const [imageUrl, setImageUrl] = useState(getLatestImageUrl());

    useEffect(() => {
        if (screenState !== "detecting") return;

        const interval = setInterval(() => {
            setElapsedSeconds((prev) => prev + 1);
        }, 1000);

        return () => clearInterval(interval);
    }, [screenState]);

    const startDetection = async () => {
        setScreenState("triggering");
        setErrorMessage(null);

        try {
            const startTime = new Date();
            await triggerCapture();
            setScreenState("detecting");
            setElapsedSeconds(0);

            const result = await pollForDetection({ since: startTime });

            if (result) {
                setDetectionResult(result);
                setItemName(result.label);
                setDescription(`Category: ${result.category}`);
                setPrice(String(result.maxPrice));
                setImageUrl(getLatestImageUrl());
                setScreenState("showingResults");
            } else {
                setScreenState("ready");
                setErrorMessage(
                    "Detection timed out. Please try again or press the ESP32 button manually.",
                );
            }
        } catch (err) {
            setScreenState("ready");
            setErrorMessage(
                err instanceof Error ? err.message : "Failed to trigger detection",
            );
        }
    };

    const createListing = async () => {
        if (!itemName.trim() || !description.trim() || !price.trim() || !phone.trim()) {
            setErrorMessage("Please fill in all fields");
            return;
        }

        if (!isValidPhoneNumber(phone)) {
            setErrorMessage("Invalid phone number (8 digits or +65 format)");
            return;
        }

        const parsedPrice = parseFloat(price);
        if (Number.isNaN(parsedPrice) || parsedPrice <= 0) {
            setErrorMessage("Invalid price");
            return;
        }

        setScreenState("creating");
        setErrorMessage(null);

        try {
            const result = await createItemListing({
                phone: formatPhoneNumber(phone),
                itemName: itemName.trim(),
                description: description.trim(),
                price: parsedPrice,
                days: selectedDays,
            });

            alert(
                `Item Listed Successfully!\n\nItem ID: ${result.itemId}\nPayment Link: ${result.paymentLink || "N/A"}`,
            );
            navigate("/", { replace: true });
        } catch (err) {
            setScreenState("showingResults");
            setErrorMessage(err instanceof Error ? err.message : "Failed to create listing");
        }
    };

    if (screenState === "triggering" || screenState === "creating") {
        return (
            <div className="sell-screen">
                <SellHeader onBack={() => navigate("/")} />
                <div className="sell-loading">
                    <Spinner animation="border" />
                    <p>{screenState === "triggering" ? "Triggering camera capture..." : "Creating listing..."}</p>
                </div>
            </div>
        );
    }

    if (screenState === "detecting") {
        return (
            <div className="sell-screen">
                <SellHeader onBack={() => navigate("/")} />
                <div className="sell-loading">
                    <Spinner animation="border" />
                    <h2>Detecting item...</h2>
                    <p>Elapsed: {elapsedSeconds} seconds</p>
                    <p>Camera is capturing and analyzing the item.</p>
                    <div className="progress mt-3">
                        <div
                            className="progress-bar"
                            style={{ width: `${(elapsedSeconds / (DETECTION_TIMEOUT_MS / 1000)) * 100}%` }}
                        />
                    </div>
                </div>
            </div>
        );
    }

    if (screenState === "showingResults") {
        return (
            <div className="sell-screen">
                <SellHeader onBack={() => navigate("/")} />
                <div className="sell-form-container">
                    <div className="detection-image-section">
                        <img
                            src={imageUrl}
                            alt="Detected item"
                            className="detection-image"
                            onError={(e) => {
                                (e.target as HTMLImageElement).style.display = "none";
                            }}
                        />
                    </div>

                    <div className="sell-form">
                        <div className="d-flex justify-content-between align-items-center mb-4">
                            <h2>Item Details</h2>
                            <Button
                                variant={isEditing ? "success" : "outline-primary"}
                                size="sm"
                                onClick={() => setIsEditing(!isEditing)}
                            >
                                {isEditing ? "Done" : "Edit"}
                            </Button>
                        </div>

                        <Field label="Item Name">
                            {isEditing ? (
                                <Form.Control value={itemName} onChange={(e) => setItemName(e.target.value)} />
                            ) : (
                                <div className="field-value">{itemName}</div>
                            )}
                        </Field>

                        <Field label="Description">
                            {isEditing ? (
                                <Form.Control
                                    as="textarea"
                                    rows={3}
                                    value={description}
                                    onChange={(e) => setDescription(e.target.value)}
                                />
                            ) : (
                                <div className="field-value">{description}</div>
                            )}
                        </Field>

                        <Field label="Price">
                            {isEditing ? (
                                <Form.Control
                                    type="number"
                                    step="0.01"
                                    value={price}
                                    onChange={(e) => setPrice(e.target.value)}
                                />
                            ) : (
                                <div className="field-value">${price}</div>
                            )}
                        </Field>

                        <Field label="Listing Duration">
                            {isEditing ? (
                                <Form.Select
                                    value={selectedDays}
                                    onChange={(e) => setSelectedDays(parseInt(e.target.value, 10))}
                                >
                                    <option value={1}>1 day</option>
                                    <option value={3}>3 days</option>
                                    <option value={7}>7 days</option>
                                    <option value={14}>14 days</option>
                                </Form.Select>
                            ) : (
                                <div className="field-value">
                                    {selectedDays} day{selectedDays > 1 ? "s" : ""}
                                </div>
                            )}
                        </Field>

                        <Field label="PayNow Phone Number">
                            {isEditing ? (
                                <Form.Control
                                    type="tel"
                                    placeholder="81234567 or +6581234567"
                                    value={phone}
                                    onChange={(e) => setPhone(e.target.value)}
                                />
                            ) : (
                                <div className="field-value">{phone}</div>
                            )}
                        </Field>

                        {errorMessage && <div className="alert alert-danger">{errorMessage}</div>}

                        <Button className="kiosk-primary-btn w-100 mt-4" size="lg" onClick={createListing}>
                            List My Item!
                        </Button>
                    </div>
                </div>
            </div>
        );
    }

    return (
        <div className="sell-screen">
            <SellHeader onBack={() => navigate("/")} />
            <div className="sell-ready">
                <div className="sell-icon">📷</div>
                <h2>Place item in locker</h2>
                <p>
                    Place your item in the locker and close the door.
                    <br />
                    Then press the button below to start detection.
                </p>
                <Button className="kiosk-primary-btn" size="lg" onClick={startDetection}>
                    Start Detection
                </Button>
                {errorMessage && <div className="alert alert-danger mt-4">{errorMessage}</div>}
                {detectionResult && (
                    <Button variant="link" onClick={() => setScreenState("showingResults")}>
                        View last detection results
                    </Button>
                )}
            </div>
        </div>
    );
}

function SellHeader({ onBack }: { onBack: () => void }) {
    return (
        <header className="sell-header">
            <Button variant="link" className="back-btn" onClick={onBack}>
                ← Back
            </Button>
            <h1>List Your Item</h1>
        </header>
    );
}

function Field({ label, children }: { label: string; children: ReactNode }) {
    return (
        <Form.Group className="mb-3">
            <Form.Label className="field-label">{label}</Form.Label>
            {children}
        </Form.Group>
    );
}
