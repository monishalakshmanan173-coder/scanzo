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

    setState(() {
      if (_cartItems.containsKey(product.id)) {
        final existing = _cartItems[product.id]!;
        final newQty = existing.quantity + 1;
        if (newQty > product.currentStock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot add more than available stock (${product.currentStock.toStringAsFixed(0)})')),
          );
          return;
        }
        _updateItemQty(product.id, newQty);
      } else {
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
      }
      _updatePaidAmountToTotal();
    });
  }

  void _updateItemQty(String productId, double newQty) {
    if (newQty <= 0) {
      _cartItems.remove(productId);
    } else {
      final item = _cartItems[productId]!;
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
    }
    _updatePaidAmountToTotal();
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

  Future<void> _handleCheckout() async {
    setState(() => _errorMessage = null);
    if (_cartItems.isEmpty) {
      setState(() => _errorMessage = 'Cart is empty. Please add items to checkout.');
      return;
    }

    final paidAmount = double.tryParse(_paidAmountController.text.trim()) ?? _grandTotal;
    if (paidAmount < 0) {
      setState(() => _errorMessage = 'Paid amount cannot be negative');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final changeAmount = paidAmount > _grandTotal ? (paidAmount - _grandTotal) : 0.0;

      final sale = await _billingRepo.processCheckout(
        customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.name,
        customerMobile: _selectedCustomer?.mobile,
        items: _cartItems.values.toList(),
        subtotal: _subtotal,
        totalDiscount: _totalDiscount,
        totalGst: _totalGst,
        grandTotal: _grandTotal,
        paymentMethod: _selectedPaymentMethod,
        paidAmount: paidAmount,
        changeAmount: changeAmount,
      );

      if (!mounted) return;

      // Navigate to Success screen
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.billSuccess,
        arguments: {'sale': sale},
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString());
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
        title: const Text('New POS Bill'),
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
                        text: 'Complete Bill (${CurrencyFormatter.format(_grandTotal)})',
                        onPressed: _cartItems.isNotEmpty && !_isProcessing ? _handleCheckout : null,
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
              icon: const Icon(Icons.remove_circle_outline_rounded, size: 20, color: AppColors.textSecondary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: () => _updateItemQty(item.productId, item.quantity - 1),
            ),
            Text(
              item.quantity.toStringAsFixed(0),
              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: AppColors.primaryPinkDark),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: () => _updateItemQty(item.productId, item.quantity + 1),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Text(
          CurrencyFormatter.format(item.totalAmount),
          style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold),
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
