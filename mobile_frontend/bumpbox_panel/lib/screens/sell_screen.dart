import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/api_config.dart';
import '../models/detection_result.dart';
import '../services/detection_service.dart';
import '../services/item_creation_service.dart';

/// Screen for sellers to list items using ESP32 camera detection
class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  // State management
  _ScreenState _currentState = _ScreenState.ready;
  DetectionResult? _detectionResult;
  String? _errorMessage;
  Timer? _pollingTimer;
  DateTime? _pollingStartTime;
  int _elapsedSeconds = 0;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _itemNameController;
  late TextEditingController _descriptionController;
  late TextEditingController _startingPriceController;
  late TextEditingController _floorPriceController;
  late TextEditingController _phoneController;
  int _selectedDays = 7;

  @override
  void initState() {
    super.initState();
    _itemNameController = TextEditingController();
    _descriptionController = TextEditingController();
    _startingPriceController = TextEditingController();
    _floorPriceController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _itemNameController.dispose();
    _descriptionController.dispose();
    _startingPriceController.dispose();
    _floorPriceController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _startDetection() async {
    setState(() {
      _currentState = _ScreenState.triggering;
      _errorMessage = null;
    });

    try {
      // Trigger ESP32 capture
      await DetectionService.triggerCapture();

      // Start polling for result
      setState(() {
        _currentState = _ScreenState.detecting;
        _pollingStartTime = DateTime.now();
        _elapsedSeconds = 0;
      });

      // Start timer to update elapsed seconds
      _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _elapsedSeconds = DateTime.now()
                .difference(_pollingStartTime!)
                .inSeconds;
          });
        }
      });

      // Poll for detection result
      final result = await DetectionService.pollForDetection(
        since: _pollingStartTime,
      );

      _pollingTimer?.cancel();

      if (result != null) {
        setState(() {
          _detectionResult = result;
          _currentState = _ScreenState.showingResults;
          _populateFormWithDetection(result);
        });
      } else {
        setState(() {
          _currentState = _ScreenState.ready;
          _errorMessage =
              'Detection timed out. Please try again or press the ESP32 button manually.';
        });
      }
    } catch (e) {
      _pollingTimer?.cancel();
      setState(() {
        _currentState = _ScreenState.ready;
        _errorMessage = 'Failed to trigger detection: $e';
      });
    }
  }

  void _populateFormWithDetection(DetectionResult result) {
    _itemNameController.text = result.label;
    _descriptionController.text = 'Category: ${result.category}';
    _startingPriceController.text = result.suggestedStartingPrice.toString();
    _floorPriceController.text = result.suggestedFloorPrice.toString();
  }

  Future<void> _createListing() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _currentState = _ScreenState.creating;
      _errorMessage = null;
    });

    try {
      final phone = ItemCreationService.formatPhoneNumber(
        _phoneController.text,
      );
      final result = await ItemCreationService.createItem(
        phone: phone,
        itemName: _itemNameController.text,
        description: _descriptionController.text,
        price: double.parse(_startingPriceController.text),
        days: _selectedDays,
      );

      if (!mounted) return;

      // Show success dialog with payment link
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Item Listed Successfully!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Item ID: ${result['itemId']}'),
              const SizedBox(height: 8),
              const Text('Payment Link:'),
              SelectableText(
                result['paymentLink'] ?? 'N/A',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Return to dashboard
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _currentState = _ScreenState.showingResults;
        _errorMessage = 'Failed to create listing: $e';
      });
    }
  }

  void _retryDetection() {
    setState(() {
      _currentState = _ScreenState.ready;
      _detectionResult = null;
      _errorMessage = null;
      _itemNameController.clear();
      _descriptionController.clear();
      _startingPriceController.clear();
      _floorPriceController.clear();
      _phoneController.clear();
      _selectedDays = 7;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sell Item'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_currentState) {
      case _ScreenState.ready:
        return _buildReadyState();
      case _ScreenState.triggering:
        return _buildLoadingState('Triggering camera capture...');
      case _ScreenState.detecting:
        return _buildDetectingState();
      case _ScreenState.showingResults:
        return _buildResultsForm();
      case _ScreenState.creating:
        return _buildLoadingState('Creating listing...');
    }
  }

  Widget _buildReadyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo,
              size: 120,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 32),
            const Text(
              'Place item in locker',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Place your item in the locker and close the door.\n'
              'Then press the button below to start detection.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: _startDetection,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Start Detection'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 20,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(message, style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildDetectingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 32),
            const Text(
              'Detecting item...',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Elapsed: $_elapsedSeconds seconds',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Camera is capturing and analyzing the item.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            LinearProgressIndicator(
              value: _elapsedSeconds / ApiConfig.detectionTimeout.inSeconds,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsForm() {
    final result = _detectionResult!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Detection Result Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Item Detected',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildInfoRow('Item:', result.label),
                    const SizedBox(height: 8),
                    _buildInfoRow('Category:', result.category),
                    const SizedBox(height: 8),
                    _buildInfoRow('Suggested Price:', result.priceRangeString),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Confidence: ',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(result.confidenceString),
                        const SizedBox(width: 8),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: result.confidence / 100,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              result.isHighConfidence
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Form Fields
            const Text(
              'Listing Details',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _itemNameController,
              decoration: const InputDecoration(
                labelText: 'Item Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.shopping_bag),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an item name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
                hintText: 'Describe the condition, features, etc.',
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startingPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Starting Price *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                      prefixText: '\$',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      final price = double.tryParse(value);
                      if (price == null || price <= 0) {
                        return 'Invalid price';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _floorPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Floor Price *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.price_check),
                      prefixText: '\$',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      final floorPrice = double.tryParse(value);
                      if (floorPrice == null || floorPrice <= 0) {
                        return 'Invalid price';
                      }
                      final startingPrice = double.tryParse(
                        _startingPriceController.text,
                      );
                      if (startingPrice != null && floorPrice > startingPrice) {
                        return 'Must be ≤ starting';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<int>(
              value: _selectedDays,
              decoration: const InputDecoration(
                labelText: 'Listing Duration',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 day')),
                DropdownMenuItem(value: 3, child: Text('3 days')),
                DropdownMenuItem(value: 7, child: Text('7 days')),
                DropdownMenuItem(value: 14, child: Text('14 days')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedDays = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'PayNow Phone Number *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
                hintText: '81234567 or +6581234567',
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your phone number';
                }
                if (!ItemCreationService.isValidPhoneNumber(value)) {
                  return 'Invalid phone number (8 digits or +65 format)';
                }
                return null;
              },
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _retryDetection,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Retry Detection'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _createListing,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('List Item'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
      ],
    );
  }
}

enum _ScreenState { ready, triggering, detecting, showingResults, creating }
