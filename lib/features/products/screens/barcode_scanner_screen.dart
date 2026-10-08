import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/scanzo_button.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../app/routes.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final _productRepo = ProductRepository();
  final _manualInputController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController();

  Product? _foundProduct;
  String? _scannedBarcode;
  bool _isTorchOn = false;
  bool _hasCameraError = false;

  @override
  void dispose() {
    _manualInputController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final code = barcodes.first.rawValue;
      if (code != null && code.isNotEmpty && code != _scannedBarcode) {
        _lookupBarcode(code);
      }
    }
  }

  void _lookupBarcode(String barcode) {
    setState(() {
      _scannedBarcode = barcode;
      _foundProduct = _productRepo.getProductByBarcode(barcode);
    });
  }

  void _toggleTorch() {
    _scannerController.toggleTorch();
    setState(() => _isTorchOn = !_isTorchOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Scan Barcode', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: Colors.white,
            ),
            tooltip: 'Flashlight',
            onPressed: _toggleTorch,
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
            tooltip: 'Flip Camera',
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview or Fallback
          _hasCameraError
              ? Container(
                  color: const Color(0xFF1A1A1A),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.videocam_off_rounded, size: 54, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'Camera Not Available or Permission Denied',
                          style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'You can use manual barcode entry below for testing.',
                          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                )
              : MobileScanner(
                  controller: _scannerController,
                  onDetect: _onBarcodeDetected,
                  errorBuilder: (context, error, child) {
                    return Container(
                      color: const Color(0xFF1E1E1E),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.camera_alt_outlined, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text('Camera preview mode', style: AppTypography.bodyMedium.copyWith(color: Colors.white)),
                            const SizedBox(height: 6),
                            Text('Enter barcode manually below', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    );
                  },
                ),

          // Reticle Overlay (Target Frame)
          Center(
            child: Container(
              width: 260,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primaryPinkDark, width: 2.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Container(
                      height: 2,
                      color: AppColors.primaryPink.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Sheet / Manual Entry & Product Card
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Found Product Card
                    if (_scannedBarcode != null) ...[
                      if (_foundProduct != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.mintGreen,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppColors.mintGreenDark),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_foundProduct!.name, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                                    Text(
                                      'Price: ${CurrencyFormatter.format(_foundProduct!.sellingPrice)} • Stock: ${_foundProduct!.currentStock.toStringAsFixed(0)}',
                                      style: AppTypography.caption,
                                    ),
                                  ],
                                ),
                              ),
                              ScanzoButton(
                                text: 'Select',
                                height: 36,
                                onPressed: () {
                                  Navigator.pop(context, _foundProduct!.barcode);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.softPeach,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.help_outline_rounded, color: AppColors.softPeachDark),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Barcode: $_scannedBarcode', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                                    const Text('Product not found in database', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              ScanzoButton(
                                text: 'Add Item',
                                height: 36,
                                onPressed: () {
                                  Navigator.pushReplacementNamed(
                                    context,
                                    AppRoutes.addEditProduct,
                                    arguments: {'initialBarcode': _scannedBarcode},
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],

                    // Manual Barcode Input Fallback
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _manualInputController,
                            keyboardType: TextInputType.text,
                            decoration: InputDecoration(
                              hintText: 'Enter barcode or SKU manually',
                              prefixIcon: const Icon(Icons.keyboard_alt_outlined, color: AppColors.textMuted),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onSubmitted: (val) {
                              if (val.trim().isNotEmpty) _lookupBarcode(val.trim());
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        ScanzoButton(
                          text: 'Lookup',
                          height: 48,
                          onPressed: () {
                            final code = _manualInputController.text.trim();
                            if (code.isNotEmpty) _lookupBarcode(code);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
