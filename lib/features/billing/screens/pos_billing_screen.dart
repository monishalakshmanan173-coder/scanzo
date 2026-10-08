import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/id_generator.dart';
import '../../../shared/widgets/scanzo_button.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../data/models/product.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/sale_item.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/billing_repository.dart';
import '../../../data/repositories/customer_repository.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../data/repositories/business_repository.dart';
import '../../../shared/widgets/scanzo_logo.dart';
import '../../../app/routes.dart';

class PosBillingScreen extends StatefulWidget {
  const PosBillingScreen({super.key});

  @override
  State<PosBillingScreen> createState() => _PosBillingScreenState();
}

class _PosBillingScreenState extends State<PosBillingScreen> {
  final _productRepo = ProductRepository();
  final _billingRepo = BillingRepository();
  final _customerRepo = CustomerRepository();
  final _businessRepo = BusinessRepository();

  final _searchController = TextEditingController();
  final _paidAmountController = TextEditingController();
  final _discountController = TextEditingController(text: '0');

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  List<Customer> _allCustomers = [];

  String _selectedCategory = 'All';
  Customer? _selectedCustomer;
  String _selectedPaymentMethod = 'Cash';

  // Cart
  final Map<String, SaleItem> _cartItems = {};
  double _customDiscount = 0.0;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _paidAmountController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _allProducts = _productRepo.getAllProducts();
      _allCustomers = _customerRepo.getAllCustomers();
      _applySearch();
    });
  }

  void _applySearch() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredProducts = _allProducts.where((p) {
        final matchesQuery = query.isEmpty ||
            p.name.toLowerCase().contains(query) ||
            p.barcode.toLowerCase().contains(query) ||
            p.sku.toLowerCase().contains(query);
        final matchesCat = _selectedCategory == 'All' || p.category == _selectedCategory;
        return matchesQuery && matchesCat;
      }).toList();
    });
  }

  void _addToCart(Product product) {
    if (product.currentStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} is out of stock!')),
      );
      return;
    }

    if (_cartItems.containsKey(product.id)) {
      _increaseItemQty(product.id);
    } else {
      setState(() {
        final price = product.sellingPrice;
        final gstAmt = (price * product.gstRate) / 100.0;
        final total = price + gstAmt;

        _cartItems[product.id] = SaleItem(
          id: IdGenerator.generateId('si'),
          saleId: '',
          productId: product.id,
          productName: product.name,
          barcode: product.barcode,
          quantity: 1,
          unit: product.unit,
          unitPrice: product.sellingPrice,
          purchasePrice: product.purchasePrice,
          discountAmount: product.discount,
          gstRate: product.gstRate,
          gstAmount: gstAmt,
          totalAmount: total,
        );
        _updatePaidAmountToTotal();
      });
    }
  }

  void _increaseItemQty(String productId) {
    final item = _cartItems[productId];
    if (item == null) return;

    final prod = _productRepo.getProductById(productId) ??
        _allProducts.where((p) => p.id == productId).firstOrNull;

    if (prod != null && item.quantity + 1 > prod.currentStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot add more than available stock (${prod.currentStock.toStringAsFixed(0)})'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    _updateItemQty(productId, item.quantity + 1);
  }

  void _decreaseItemQty(String productId) {
    final item = _cartItems[productId];
    if (item == null) return;

    if (item.quantity <= 1) {
      // Quantity cannot reduce below 1 via minus button
      return;
    }

    _updateItemQty(productId, item.quantity - 1);
  }

  void _removeFromCart(String productId) {
    setState(() {
      _cartItems.remove(productId);
      _updatePaidAmountToTotal();
    });
  }

  void _updateItemQty(String productId, double newQty) {
    if (newQty <= 0) {
      _removeFromCart(productId);
      return;
    }

    setState(() {
      final item = _cartItems[productId];
      if (item == null) return;

      final gstAmt = (item.unitPrice * newQty * item.gstRate) / 100.0;
      final total = (item.unitPrice * newQty) + gstAmt - (item.discountAmount * newQty);

      _cartItems[productId] = SaleItem(
        id: item.id,
        saleId: item.saleId,
        productId: item.productId,
        productName: item.productName,
        barcode: item.barcode,
        quantity: newQty,
        unit: item.unit,
        unitPrice: item.unitPrice,
        purchasePrice: item.purchasePrice,
        discountAmount: item.discountAmount,
        gstRate: item.gstRate,
        gstAmount: gstAmt,
        totalAmount: total > 0 ? total : 0,
      );
      _updatePaidAmountToTotal();
    });
  }

  double get _subtotal => _cartItems.values.fold(0.0, (sum, i) => sum + (i.unitPrice * i.quantity));
  double get _itemDiscounts => _cartItems.values.fold(0.0, (sum, i) => sum + (i.discountAmount * i.quantity));
  double get _totalDiscount => _itemDiscounts + _customDiscount;
  double get _totalGst => _cartItems.values.fold(0.0, (sum, i) => sum + i.gstAmount);
  double get _grandTotal {
    final t = _subtotal - _totalDiscount + _totalGst;
    return t > 0 ? t : 0.0;
  }

  void _updatePaidAmountToTotal() {
    _paidAmountController.text = _grandTotal.toStringAsFixed(2);
  }

  void _showPaymentModal() {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty. Please add items to checkout.')),
      );
      return;
    }

    String activeTab = (_selectedPaymentMethod == 'UPI' || _selectedPaymentMethod == 'GPay') ? 'UPI' : 'Cash';
    final cashController = TextEditingController(text: _grandTotal.toStringAsFixed(0));
    final upiInputController = TextEditingController(text: _businessRepo.activeStoreUpiId);
    double cashReceived = double.tryParse(cashController.text) ?? _grandTotal;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isCash = activeTab == 'Cash';
          final changeToReturn = cashReceived >= _grandTotal ? (cashReceived - _grandTotal) : 0.0;
          final isInsufficient = isCash && (cashReceived < _grandTotal);
          final upiId = _businessRepo.activeStoreUpiId;
          final storeName = _businessRepo.activeStoreName.isNotEmpty
              ? _businessRepo.activeStoreName
              : AppConstants.appName;
          final upiUri = 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(storeName)}&am=${_grandTotal.toStringAsFixed(2)}&cu=INR&tn=${Uri.encodeComponent("Scanzo Bill")}';

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.90,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 20,
              right: 20,
              top: 14,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header with Grand Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Checkout & Payment', style: AppTypography.h3.copyWith(fontSize: 18)),
                          Text('${_cartItems.length} items in cart', style: AppTypography.caption),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPinkLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primaryPinkDark.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Grand Total', style: AppTypography.caption.copyWith(fontSize: 10)),
                            Text(
                              CurrencyFormatter.format(_grandTotal),
                              style: AppTypography.h3.copyWith(
                                color: AppColors.primaryPinkDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Payment Tabs: Cash vs GPay / UPI
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundCream,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() {
                              activeTab = 'Cash';
                              setState(() => _selectedPaymentMethod = 'Cash');
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isCash ? AppColors.surfaceWhite : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: isCash
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.payments_rounded,
                                    size: 18,
                                    color: isCash ? AppColors.primaryPinkDark : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Cash Payment',
                                    style: TextStyle(
                                      fontWeight: isCash ? FontWeight.bold : FontWeight.w500,
                                      color: isCash ? AppColors.primaryPinkDark : AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() {
                              activeTab = 'UPI';
                              setState(() => _selectedPaymentMethod = 'GPay / UPI');
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isCash ? AppColors.surfaceWhite : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: !isCash
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.qr_code_scanner_rounded,
                                    size: 18,
                                    color: !isCash ? AppColors.mintGreenDark : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'GPay / UPI QR',
                                    style: TextStyle(
                                      fontWeight: !isCash ? FontWeight.bold : FontWeight.w500,
                                      color: !isCash ? AppColors.mintGreenDark : AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (isCash) ...[
                    // CASH PAYMENT SECTION
                    const Text('Cash Received from Customer:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: cashController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixIcon: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Text('₹', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ),
                        filled: true,
                        fillColor: AppColors.backgroundCream,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 20),
                          onPressed: () {
                            cashController.clear();
                            setModalState(() => cashReceived = 0.0);
                          },
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          cashReceived = double.tryParse(val.trim()) ?? 0.0;
                        });
                      },
                    ),
                    const SizedBox(height: 10),

                    // Quick Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          label: Text('Exact: ${CurrencyFormatter.format(_grandTotal)}', style: const TextStyle(fontSize: 11)),
                          backgroundColor: AppColors.surfaceWhite,
                          side: const BorderSide(color: AppColors.primaryPinkDark),
                          onPressed: () {
                            cashController.text = _grandTotal.toStringAsFixed(0);
                            setModalState(() => cashReceived = _grandTotal);
                          },
                        ),
                        if (_grandTotal < 500)
                          ActionChip(
                            label: const Text('₹500', style: TextStyle(fontSize: 11)),
                            backgroundColor: AppColors.surfaceWhite,
                            onPressed: () {
                              cashController.text = '500';
                              setModalState(() => cashReceived = 500);
                            },
                          ),
                        if (_grandTotal < 1000)
                          ActionChip(
                            label: const Text('₹1000', style: TextStyle(fontSize: 11)),
                            backgroundColor: AppColors.surfaceWhite,
                            onPressed: () {
                              cashController.text = '1000';
                              setModalState(() => cashReceived = 1000);
                            },
                          ),
                        if (_grandTotal < 2000)
                          ActionChip(
                            label: const Text('₹2000', style: TextStyle(fontSize: 11)),
                            backgroundColor: AppColors.surfaceWhite,
                            onPressed: () {
                              cashController.text = '2000';
                              setModalState(() => cashReceived = 2000);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Real-time Change / Insufficient validation card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isInsufficient ? AppColors.errorLight : AppColors.mintGreen.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isInsufficient ? AppColors.error : AppColors.mintGreenDark.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isInsufficient ? Icons.warning_amber_rounded : Icons.change_circle_rounded,
                            color: isInsufficient ? AppColors.error : AppColors.mintGreenDark,
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isInsufficient
                                      ? 'Insufficient Cash Received'
                                      : (changeToReturn > 0 ? 'Change to Return' : 'Exact Amount Paid'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isInsufficient ? AppColors.error : AppColors.mintGreenDark,
                                  ),
                                ),
                                Text(
                                  isInsufficient
                                      ? 'Short by ${CurrencyFormatter.format(_grandTotal - cashReceived)}'
                                      : CurrencyFormatter.format(changeToReturn),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isInsufficient ? AppColors.error : AppColors.mintGreenDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    ScanzoButton(
                      text: isInsufficient
                          ? 'Enter Adequate Cash to Confirm'
                          : 'Confirm Cash Sale (${CurrencyFormatter.format(_grandTotal)})',
                      onPressed: isInsufficient || _isProcessing
                          ? null
                          : () async {
                              Navigator.pop(modalCtx);
                              _paidAmountController.text = cashReceived.toStringAsFixed(2);
                              await _handleCompleteCheckout(
                                method: 'Cash',
                                paidAmount: cashReceived,
                                changeAmount: changeToReturn,
                              );
                            },
                      isLoading: _isProcessing,
                      icon: Icons.check_circle_rounded,
                      backgroundColor: AppColors.primaryPinkDark,
                      textColor: Colors.white,
                    ),
                  ] else ...[
                    // GPAY / UPI QR PAYMENT SECTION
                    if (upiId.isEmpty) ...[
                      // UPI ID Not Configured: Prompt to add
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.lightYellow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.lightYellowDark.withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info_outline_rounded, color: AppColors.lightYellowDark, size: 20),
                                SizedBox(width: 8),
                                Text('Store UPI ID Required', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Enter your UPI ID (Google Pay / PhonePe / BHIM) to generate real QR codes for billing:',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: upiInputController,
                              decoration: InputDecoration(
                                hintText: 'e.g. store@okaxis or 9876543210@upi',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: () async {
                                final text = upiInputController.text.trim();
                                if (text.isNotEmpty) {
                                  await _businessRepo.updateStoreUpiId(text);
                                  setModalState(() {});
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryPinkDark,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Save & Show QR', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Display dynamic QR Code
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.mintGreenDark.withOpacity(0.3)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: QrImageView(
                                data: upiUri,
                                version: QrVersions.auto,
                                size: 175,
                                backgroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.mintGreen.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'UPI ID: $upiId',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.mintGreenDark,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Customer scans with Google Pay, PhonePe, Paytm or BHIM',
                              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundCream,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active_outlined, size: 20, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Check your UPI app notification or soundbox, then click confirm below:',
                                style: AppTypography.caption,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      ScanzoButton(
                        text: 'Confirm Payment Received (${CurrencyFormatter.format(_grandTotal)})',
                        onPressed: _isProcessing
                            ? null
                            : () async {
                                Navigator.pop(modalCtx);
                                _paidAmountController.text = _grandTotal.toStringAsFixed(2);
                                await _handleCompleteCheckout(
                                  method: 'GPay / UPI',
                                  paidAmount: _grandTotal,
                                  changeAmount: 0.0,
                                );
                              },
                        isLoading: _isProcessing,
                        icon: Icons.check_circle_rounded,
                        backgroundColor: AppColors.mintGreenDark,
                        textColor: Colors.white,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleCompleteCheckout({
    required String method,
    required double paidAmount,
    required double changeAmount,
  }) async {
    setState(() => _errorMessage = null);
    if (_cartItems.isEmpty) return;

    if (_isProcessing) return; // Prevent duplicate checkout
    setState(() => _isProcessing = true);

    try {
      final sale = await _billingRepo.processCheckout(
        customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.name,
        customerMobile: _selectedCustomer?.mobile,
        items: _cartItems.values.toList(),
        subtotal: _subtotal,
        totalDiscount: _totalDiscount,
        totalGst: _totalGst,
        grandTotal: _grandTotal,
        paymentMethod: method,
        paidAmount: paidAmount,
        changeAmount: changeAmount,
      );

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.billSuccess,
        arguments: {'sale': sale},
      );
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ..._productRepo.getAllCategories().map((c) => c.name)];
    final cartCount = _cartItems.values.fold<int>(0, (sum, i) => sum + i.quantity.toInt());

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ScanzoLogo.icon(size: 26),
            const SizedBox(width: 8),
            const Text('New POS Bill'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan Barcode',
            onPressed: () async {
              final scanned = await Navigator.pushNamed(context, AppRoutes.barcodeScanner) as String?;
              if (scanned != null && scanned.isNotEmpty) {
                final prod = _productRepo.getProductByBarcode(scanned);
                if (prod != null) {
                  _addToCart(prod);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No product found for barcode: $scanned')),
                  );
                }
              }
            },
          ),
          if (_cartItems.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _cartItems.clear()),
              child: const Text('Clear Cart', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Row(
        children: [
          // Left: Product Catalog & Search
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _applySearch(),
                    decoration: InputDecoration(
                      hintText: 'Search product name, barcode...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: AppColors.surfaceWhite,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),

                // Category Chips
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: categories.length,
                    itemBuilder: (context, idx) {
                      final cat = categories[idx];
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          selectedColor: AppColors.primaryPink,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedCategory = cat;
                                _applySearch();
                              });
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // Product Grid / List
                Expanded(
                  child: _filteredProducts.isEmpty
                      ? const EmptyStateView(
                          icon: Icons.search_off_rounded,
                          title: 'No products available',
                          message: 'Add products or adjust filters to add to bill.',
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.35,
                          ),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            final inCartQty = _cartItems[product.id]?.quantity.toInt() ?? 0;
                            return _buildCatalogCard(product, inCartQty);
                          },
                        ),
                ),
              ],
            ),
          ),

          // Right: Real-time Cart & Checkout Panel
          Container(
            width: MediaQuery.of(context).size.width > 800 ? 360 : 320,
            decoration: const BoxDecoration(
              color: AppColors.surfaceWhite,
              border: Border(left: BorderSide(color: AppColors.borderLight)),
            ),
            child: Column(
              children: [
                // Customer Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: const BoxDecoration(
                    color: AppColors.warmCream,
                    border: Border(bottom: BorderSide(color: AppColors.borderLight)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 20, color: AppColors.warmCreamDark),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Customer?>(
                            isExpanded: true,
                            value: _selectedCustomer,
                            hint: const Text('Walk-in Customer (Select)'),
                            items: [
                              const DropdownMenuItem<Customer?>(
                                value: null,
                                child: Text('Walk-in Customer', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              ..._allCustomers.map((c) {
                                return DropdownMenuItem<Customer?>(
                                  value: c,
                                  child: Text('${c.name} (${c.mobile})'),
                                );
                              }),
                            ],
                            onChanged: (c) => setState(() => _selectedCustomer = c),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Cart Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Current Bill ($cartCount items)', style: AppTypography.h3.copyWith(fontSize: 15)),
                      Text(CurrencyFormatter.format(_grandTotal), style: AppTypography.h3.copyWith(fontSize: 16, color: AppColors.primaryPinkDark)),
                    ],
                  ),
                ),
                const Divider(),

                // Cart Items List
                Expanded(
                  child: _cartItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shopping_cart_outlined, size: 40, color: AppColors.textMuted),
                              const SizedBox(height: 8),
                              Text('Cart is empty', style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
                              const SizedBox(height: 4),
                              Text('Tap items to add to bill', style: AppTypography.caption),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          itemCount: _cartItems.length,
                          separatorBuilder: (_, __) => const Divider(height: 10),
                          itemBuilder: (context, index) {
                            final item = _cartItems.values.elementAt(index);
                            return _buildCartItemTile(item);
                          },
                        ),
                ),

                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(_errorMessage!, style: AppTypography.caption.copyWith(color: AppColors.error)),
                  ),

                // Financial Calculation Summary Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundCream,
                    border: Border(top: BorderSide(color: AppColors.borderLight)),
                  ),
                  child: Column(
                    children: [
                      _buildCalcRow('Subtotal', CurrencyFormatter.format(_subtotal)),
                      if (_totalGst > 0)
                        _buildCalcRow('GST / Taxes', '+ ${CurrencyFormatter.format(_totalGst)}'),
                      if (_totalDiscount > 0)
                        _buildCalcRow('Discount', '- ${CurrencyFormatter.format(_totalDiscount)}', color: AppColors.success),
                      const Divider(height: 14),
                      _buildCalcRow('GRAND TOTAL', CurrencyFormatter.format(_grandTotal), color: AppColors.textPrimary, isBold: true),
                      const SizedBox(height: 10),

                      // Payment Method Chips
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: AppConstants.paymentMethods.map((m) {
                          final isSelected = _selectedPaymentMethod == m;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: ChoiceChip(
                                label: Text(m, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                selected: isSelected,
                                selectedColor: AppColors.primaryPink,
                                onSelected: (sel) {
                                  if (sel) setState(() => _selectedPaymentMethod = m);
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),

                      // Checkout Button
                      ScanzoButton(
                        text: 'Proceed to Pay (${CurrencyFormatter.format(_grandTotal)})',
                        onPressed: _cartItems.isNotEmpty && !_isProcessing ? _showPaymentModal : null,
                        isLoading: _isProcessing,
                        icon: Icons.check_circle_rounded,
                        backgroundColor: AppColors.primaryPinkDark,
                        textColor: Colors.white,
                        height: 48,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogCard(Product product, int inCartQty) {
    return GestureDetector(
      onTap: () => _addToCart(product),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: inCartQty > 0 ? AppColors.primaryPinkLight : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: inCartQty > 0 ? AppColors.primaryPinkDark : AppColors.borderLight,
            width: inCartQty > 0 ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundCream,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${product.currentStock.toStringAsFixed(0)} ${product.unit}', style: AppTypography.caption),
                ),
                if (inCartQty > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPinkDark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$inCartQty in cart', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            Text(
              product.name,
              style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  CurrencyFormatter.format(product.sellingPrice),
                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const Icon(Icons.add_circle_outline_rounded, size: 20, color: AppColors.primaryPinkDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItemTile(SaleItem item) {
    final prod = _productRepo.getProductById(item.productId) ??
        _allProducts.where((p) => p.id == item.productId).firstOrNull;
    final isAtMaxStock = prod != null && item.quantity >= prod.currentStock;
    final isAtMinQty = item.quantity <= 1;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.productName, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600), maxLines: 1),
              Text(
                '${CurrencyFormatter.format(item.unitPrice)} / ${item.unit}',
                style: AppTypography.caption,
              ),
            ],
          ),
        ),
        // Qty Controls
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.remove_circle_outline_rounded,
                size: 20,
                color: isAtMinQty ? AppColors.textMuted.withOpacity(0.4) : AppColors.textSecondary,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: isAtMinQty ? null : () => _decreaseItemQty(item.productId),
              tooltip: isAtMinQty ? 'Minimum quantity is 1' : 'Decrease quantity',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                item.quantity.toStringAsFixed(0),
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.add_circle_outline_rounded,
                size: 20,
                color: isAtMaxStock ? AppColors.textMuted.withOpacity(0.4) : AppColors.primaryPinkDark,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: () => _increaseItemQty(item.productId),
              tooltip: isAtMaxStock ? 'Maximum stock reached' : 'Increase quantity',
            ),
          ],
        ),
        const SizedBox(width: 8),
        Text(
          CurrencyFormatter.format(item.totalAmount),
          style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          tooltip: 'Remove from cart',
          onPressed: () => _removeFromCart(item.productId),
        ),
      ],
    );
  }

  Widget _buildCalcRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.caption.copyWith(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: AppTypography.bodySmall.copyWith(fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
