import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Button, Modal, Spinner } from "react-bootstrap";
import PaymentDialog from "../components/PaymentDialog";
import { formatDuration, useKioskDashboard } from "../hooks/useKioskDashboard";
import { LockerState } from "../types/item";

export default function KioskDashboard() {
    const navigate = useNavigate();
    const kiosk = useKioskDashboard();
    const [showReturnConfirm, setShowReturnConfirm] = useState(false);

    if (kiosk.isLoading) {
        return (
            <div className="kiosk-loading">
                <Spinner animation="border" variant="primary" />
                <p>Initializing...</p>
            </div>
        );
    }

    if (kiosk.error) {
        return (
            <div className="kiosk-error">
                <h2>Service Temporarily Unavailable</h2>
                <p>{kiosk.error}</p>
                <Button onClick={() => window.location.reload()}>Retry</Button>
            </div>
        );
    }

    if (kiosk.lockerState === LockerState.Empty || !kiosk.currentItem) {
        return (
            <div className="kiosk-empty">
                <div className="empty-icon">📦</div>
                <h1>Locker is Empty</h1>
                <p>No items currently listed for sale</p>
                <p className="empty-subtitle">Want to sell something? List your item now!</p>
                <Button
                    className="kiosk-primary-btn"
                    size="lg"
                    onClick={() => navigate("/sell")}
                >
                    List an Item for Sale
                </Button>
                <Button variant="link" className="refresh-link" onClick={() => kiosk.refreshItemFromAPI()}>
                    Refresh
                </Button>

                {kiosk.toast && <Toast message={kiosk.toast.message} type={kiosk.toast.type} />}
            </div>
        );
    }

    const item = kiosk.currentItem;

    return (
        <div className="kiosk-dashboard">
            <div className="availability-bar available">Available Now</div>

            <h1
                className="item-title"
                onContextMenu={(e) => {
                    e.preventDefault();
                    kiosk.setDebugMode((prev) => !prev);
                }}
                onTouchStart={(e) => {
                    const timer = window.setTimeout(() => {
                        kiosk.setDebugMode((prev) => !prev);
                    }, 800);
                    (e.target as HTMLElement).dataset.longPressTimer = String(timer);
                }}
                onTouchEnd={(e) => {
                    const timer = (e.target as HTMLElement).dataset.longPressTimer;
                    if (timer) window.clearTimeout(Number(timer));
                }}
            >
                {item.name}
            </h1>

            <p className="item-description">{item.description}</p>

            <div className="time-remaining">
                <span>⏱</span>
                {kiosk.formatTimeRemaining(item)}
            </div>

            <div className="price-card">
                <div className="price-label">Current Price</div>
                <div className="price-value" style={{ color: kiosk.priceColor }}>
                    {kiosk.formatPrice(kiosk.currentPrice)}
                </div>
                {kiosk.debugMode && (
                    <div className="price-debug">
                        <div>Decay: {kiosk.formatPrice(kiosk.currentDecayPrice)}</div>
                        {kiosk.surgeCount > 0 && (
                            <div style={{ color: kiosk.surgeBadgeColor }}>
                                Surge: +{kiosk.formatPrice(kiosk.currentPrice - kiosk.currentDecayPrice)}
                            </div>
                        )}
                        <div>Floor: {kiosk.formatPrice(item.floorPrice)}</div>
                    </div>
                )}
            </div>

            {kiosk.surgeCount > 0 && (
                <div className="surge-banner">
                    <span>📈</span>
                    High demand pricing
                    {kiosk.lastOnlineInterest && (
                        <span className="surge-detail">
                            Online: {kiosk.lastOnlineInterest.pageViews} views,{" "}
                            {kiosk.lastOnlineInterest.clickCount} clicks
                        </span>
                    )}
                </div>
            )}

            {kiosk.testTimeRemaining != null && kiosk.testStartTime && (
                <div className="test-period-banner">
                    <div>
                        ⏱ Test Period: {formatDuration(kiosk.testTimeRemaining)} remaining
                    </div>
                    <Button
                        variant="warning"
                        className="w-100 mt-2"
                        onClick={() => setShowReturnConfirm(true)}
                    >
                        Return Item for Full Refund
                    </Button>
                </div>
            )}

            <div className="action-buttons">
                <Button className="kiosk-primary-btn flex-fill" onClick={() => kiosk.preparePayment(false)}>
                    🛒 Buy
                </Button>
                <Button variant="outline-secondary" className="flex-fill" onClick={() => kiosk.preparePayment(true)}>
                    ⏱ Test 5 min
                </Button>
                {kiosk.debugMode && (
                    <Button variant="success" className="flex-fill" onClick={() => navigate("/sell")}>
                        Sell
                    </Button>
                )}
            </div>

            {kiosk.debugMode && (
                <div className="debug-actions">
                    <Button size="sm" variant="warning" onClick={kiosk.fastForwardOneDay}>
                        FF +{kiosk.daysFastForwarded || 1}d
                    </Button>
                    <Button size="sm" variant="info" onClick={() => kiosk.refreshItemFromAPI()}>
                        Refresh
                    </Button>
                    <Button
                        size="sm"
                        variant={kiosk.solenoidOn ? "danger" : "secondary"}
                        onClick={kiosk.handleToggleSolenoid}
                    >
                        Solenoid: {kiosk.solenoidOn ? "ON" : "OFF"}
                    </Button>
                </div>
            )}

            {kiosk.busyMessage && (
                <div className="kiosk-overlay">
                    <Spinner animation="border" />
                    <p>{kiosk.busyMessage}</p>
                </div>
            )}

            {kiosk.paymentModal && (
                <PaymentDialog
                    show
                    item={kiosk.paymentModal.item}
                    currentPrice={kiosk.paymentModal.currentPrice}
                    isTestMode={kiosk.paymentModal.isTestMode}
                    checkPaymentStatus={kiosk.checkPaymentStatus}
                    onClose={(success) =>
                        kiosk.handlePaymentComplete(success, kiosk.paymentModal!.isTestMode)
                    }
                />
            )}

            <Modal show={showReturnConfirm} onHide={() => setShowReturnConfirm(false)} centered>
                <Modal.Header closeButton>
                    <Modal.Title>Return Item?</Modal.Title>
                </Modal.Header>
                <Modal.Body>
                    Are you sure you want to return this item? You will receive a full refund.
                </Modal.Body>
                <Modal.Footer>
                    <Button variant="secondary" onClick={() => setShowReturnConfirm(false)}>
                        Cancel
                    </Button>
                    <Button
                        variant="warning"
                        onClick={() => {
                            setShowReturnConfirm(false);
                            kiosk.handleReturnItem();
                        }}
                    >
                        Return Item
                    </Button>
                </Modal.Footer>
            </Modal>

            {kiosk.toast && <Toast message={kiosk.toast.message} type={kiosk.toast.type} />}
        </div>
    );
}

function Toast({ message, type }: { message: string; type: "success" | "error" | "info" }) {
    return <div className={`kiosk-toast kiosk-toast-${type}`}>{message}</div>;
}
