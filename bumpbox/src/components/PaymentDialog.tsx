import { useCallback, useEffect, useRef, useState } from "react";
import { Modal, Button, Spinner } from "react-bootstrap";
import { QRCodeSVG } from "qrcode.react";
import { formatPrice } from "../config/pricingConfig";
import type { Item } from "../types/item";

interface PaymentDialogProps {
    show: boolean;
    item: Item;
    currentPrice: number;
    isTestMode?: boolean;
    onClose: (success: boolean) => void;
    checkPaymentStatus: () => Promise<boolean | null>;
}

export default function PaymentDialog({
    show,
    item,
    currentPrice,
    isTestMode = false,
    onClose,
    checkPaymentStatus,
}: PaymentDialogProps) {
    const [isPaymentComplete, setIsPaymentComplete] = useState(false);
    const pollCountRef = useRef(0);
    const maxPolls = 150;
    const handleClose = useCallback((success: boolean) => {
        setIsPaymentComplete(false);
        onClose(success);
    }, [onClose]);
    useEffect(() => {
        if (!show || !item.paymentLink || isPaymentComplete) return;

        pollCountRef.current = 0;
        
        const interval = setInterval(async () => {
            pollCountRef.current++;

            if (pollCountRef.current >= maxPolls) {
                clearInterval(interval);
                return;
            }

            const isPaid = await checkPaymentStatus();

            if (isPaid) {
                clearInterval(interval);
                setIsPaymentComplete(true);
                setTimeout(() => handleClose(true), 2000);
            }
        }, 2000);

        return () => clearInterval(interval);
    }, [show, item.paymentLink, isPaymentComplete, checkPaymentStatus, onClose, handleClose]);

    const copyPaymentLink = () => {
        if (item.paymentLink) {
            navigator.clipboard.writeText(item.paymentLink);
        }
    };

    return (
        <Modal
            show={show}
            onHide={() => handleClose(false)}
            centered
            backdrop="static"
        >
            <Modal.Header closeButton={!isPaymentComplete}>
                <Modal.Title>
                    {isPaymentComplete
                        ? "Payment Successful!"
                        : isTestMode
                          ? "Test Purchase - Refundable Deposit"
                          : `Buy ${item.name}`}
                </Modal.Title>
            </Modal.Header>
            <Modal.Body>
                {isPaymentComplete ? (
                    <div className="text-center py-3">
                        <div className="payment-success-icon mb-3">✓</div>
                        <p>Thank you for your purchase!</p>
                        <p className="text-muted">
                            The locker will unlock shortly.
                        </p>
                    </div>
                ) : (
                    <>
                        {isTestMode && (
                            <div className="test-mode-banner mb-3">
                                You have 5 minutes to return this item for a
                                full refund
                            </div>
                        )}

                        <div className="price-display-box text-center mb-4">
                            <div className="price-label">Current Price</div>
                            <div className="price-value">
                                {formatPrice(currentPrice)}
                            </div>
                        </div>

                        {item.paymentLink ? (
                            <>
                                <p className="text-center fw-semibold mb-3">
                                    Scan to Pay
                                </p>
                                <div className="qr-container d-flex justify-content-center mb-3">
                                    <QRCodeSVG
                                        value={item.paymentLink}
                                        size={200}
                                    />
                                </div>
                                <button
                                    type="button"
                                    className="payment-link-copy"
                                    onClick={copyPaymentLink}
                                >
                                    {item.paymentLink}
                                </button>
                                <p className="text-center text-muted small mt-2">
                                    Tap to copy payment link
                                </p>

                                {!isPaymentComplete && (
                                    <div className="d-flex align-items-center justify-content-center gap-2 mt-4">
                                        <Spinner size="sm" />
                                        <span className="text-muted fst-italic">
                                            Waiting for payment...
                                        </span>
                                    </div>
                                )}
                            </>
                        ) : (
                            <div className="alert alert-danger mb-0">
                                Payment link not available for this item.
                            </div>
                        )}
                    </>
                )}
            </Modal.Body>
            {!isPaymentComplete && (
                <Modal.Footer>
                    <Button
                        variant="secondary"
                        onClick={() => handleClose(false)}
                    >
                        Cancel
                    </Button>
                </Modal.Footer>
            )}
        </Modal>
    );
}
