import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/api_config.dart';
import '../models/detection_result.dart';
import '../services/detection_service.dart';
import '../services/item_creation_service.dart';

enum _ScreenState { ready, triggering, detecting, showingResults, creating }

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
  bool _isEditing = false;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _itemNameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _phoneController;
  int _selectedDays = 7;

  @override
  void initState() {
    super.initState();
    _itemNameController = TextEditingController();
    _descriptionController = TextEditingController();
    _priceController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _itemNameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
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
    _priceController.text = result.suggestedStartingPrice.toString();
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
        price: double.parse(_priceController.text),
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
      _isEditing = false;
      _itemNameController.clear();
      _descriptionController.clear();
      _priceController.clear();
      _phoneController.clear();
      _selectedDays = 7;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'List Your Item',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF4169E1), // Royal blue
        foregroundColor: Colors.white,
        elevation: 0,
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
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section
            Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Image.network(
                    'https://m.media-amazon.com/images/I/612u463P8LL.jpg',
                    height: 250,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            // Form Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Item Details Header with Edit/Done button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Item Details',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _isEditing = !_isEditing;
                            });
                          },
                          icon: Icon(_isEditing ? Icons.check : Icons.edit),
                          label: Text(_isEditing ? 'Done' : 'Edit'),
                          style: TextButton.styleFrom(
                            backgroundColor: _isEditing
                                ? Colors.green
                                : Colors.transparent,
                            foregroundColor: _isEditing
                                ? Colors.white
                                : Theme.of(context).colorScheme.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Item Name
                    _buildFieldLabel('Item Name'),
                    const SizedBox(height: 8),
                    _isEditing
                        ? TextFormField(
                            controller: _itemNameController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter an item name';
                              }
                              return null;
                            },
                          )
                        : _buildFieldValue(_itemNameController.text),

                    const SizedBox(height: 20),

                    // Description
                    _buildFieldLabel('Description:'),
                    const SizedBox(height: 8),
                    _isEditing
                        ? TextFormField(
                            controller: _descriptionController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                              hintText:
                                  'Describe the condition, features, etc.',
                            ),
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a description';
                              }
                              return null;
                            },
                          )
                        : _buildFieldValue(_descriptionController.text),

                    const SizedBox(height: 20),

                    // Price
                    _buildFieldLabel('Price:'),
                    const SizedBox(height: 8),
                    _isEditing
                        ? TextFormField(
                            controller: _priceController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.all(16),
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
                                return 'Please enter a price';
                              }
                              final price = double.tryParse(value);
                              if (price == null || price <= 0) {
                                return 'Invalid price';
                              }
                              return null;
                            },
                          )
                        : _buildFieldValue('\$${_priceController.text}'),

                    const SizedBox(height: 20),

                    // Listing Duration
                    _buildFieldLabel('Listing Duration:'),
                    const SizedBox(height: 8),
                    _isEditing
                        ? DropdownButtonFormField<int>(
                            value: _selectedDays,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('1 day')),
                              DropdownMenuItem(value: 3, child: Text('3 days')),
                              DropdownMenuItem(value: 7, child: Text('7 days')),
                              DropdownMenuItem(
                                value: 14,
                                child: Text('14 days'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedDays = value!;
                              });
                            },
                          )
                        : _buildFieldValue(
                            '$_selectedDays day${_selectedDays > 1 ? 's' : ''}',
                          ),

                    const SizedBox(height: 20),

                    // PayNow Phone Number
                    _buildFieldLabel('PayNow Phone Number:'),
                    const SizedBox(height: 8),
                    _isEditing
                        ? TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                              hintText: '81234567 or +6581234567',
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your phone number';
                              }
                              if (!ItemCreationService.isValidPhoneNumber(
                                value,
                              )) {
                                return 'Invalid phone number (8 digits or +65 format)';
                              }
                              return null;
                            },
                          )
                        : _buildFieldValue(_phoneController.text),

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

                    const SizedBox(height: 32),

                    // List My Item Button
                    ElevatedButton(
                      onPressed: _createListing,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4169E1), // Royal blue
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'List My Item!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldValue(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
      ),
    );
  }
}
