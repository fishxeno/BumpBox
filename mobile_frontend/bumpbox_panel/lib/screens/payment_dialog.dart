import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/item.dart';
import '../services/item_api_service.dart';

/// Show a payment dialog with QR code and payment polling
///
/// Returns true if payment was successful, false if cancelled
Future<bool> showPaymentDialog(
  BuildContext context, {
  required Item item,
  required double currentPrice,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // Prevent accidental dismissal
    builder: (context) =>
        _PaymentDialog(item: item, currentPrice: currentPrice),
  );

  return result ?? false;
}

class _PaymentDialog extends StatefulWidget {
  final Item item;
  final double currentPrice;

  const _PaymentDialog({required this.item, required this.currentPrice});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  Timer? _pollingTimer;
  bool _isPaymentComplete = false;
  bool _isPolling = true;
  int _pollCount = 0;
  static const int _maxPolls = 150; // 5 minutes at 2 second intervals
  static const Duration _pollInterval = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(_pollInterval, (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _pollCount++;

      // Check for timeout
      if (_pollCount >= _maxPolls) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isPolling = false;
          });
          _showTimeoutMessage();
        }
        return;
      }

      // Poll backend for payment status
      final isPaid = await ItemApiService.checkPaymentStatus();

      if (isPaid == true) {
        // Payment successful!
        timer.cancel();
        if (mounted) {
          setState(() {
            _isPaymentComplete = true;
            _isPolling = false;
          });

          // Auto-close after 2 seconds
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.of(context).pop(true);
            }
          });
        }
      }
    });
  }

  void _showTimeoutMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment timeout. Please check your payment status.'),
        duration: Duration(seconds: 5),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _copyPaymentLink() {
    if (widget.item.paymentLink != null) {
      Clipboard.setData(ClipboardData(text: widget.item.paymentLink!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment link copied to clipboard!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      title: _isPaymentComplete
          ? Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(child: const Text('Payment Successful!')),
              ],
            )
          : Text('Buy ${widget.item.name}'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isPaymentComplete) ...[
                // Success message
                const SizedBox(height: 16),
                Text(
                  'Thank you for your purchase!',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'The locker will unlock shortly.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                // Price display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Current Price',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${widget.currentPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4169E1),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // QR Code
                if (widget.item.paymentLink != null) ...[
                  Text(
                    'Scan to Pay',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                    ),
                    child: QrImageView(
                      data: widget.item.paymentLink!,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Clickable payment link
                  InkWell(
                    onTap: _copyPaymentLink,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy,
                            size: 16,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              widget.item.paymentLink!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                decoration: TextDecoration.underline,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to copy payment link',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ] else ...[
                  // No payment link available
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Payment link not available for this item.',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Polling status
                if (_isPolling && widget.item.paymentLink != null) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Waiting for payment...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (!_isPaymentComplete)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: const Text('Cancel'),
          ),
      ],
    );
  }
}
