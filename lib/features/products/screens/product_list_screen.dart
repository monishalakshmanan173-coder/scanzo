import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product.dart';
import '../../../data/models/category.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../app/routes.dart';
import '../../../shared/widgets/scanzo_animated_background.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _productRepo = ProductRepository();
  final _searchController = TextEditingController();

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  List<ProductCategory> _categories = [];
  String _selectedCategory = 'All';
  String _sortBy = 'Name';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadProducts() {
    setState(() {
      _allProducts = _productRepo.getAllProducts();
      _categories = _productRepo.getAllCategories();
      _applyFilters();
    });
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    var list = _allProducts.where((p) {
      final matchesQuery = query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          p.barcode.toLowerCase().contains(query) ||
          p.sku.toLowerCase().contains(query) ||
          (p.brand != null && p.brand!.toLowerCase().contains(query));

      final matchesCat = _selectedCategory == 'All' || p.category == _selectedCategory;
      return matchesQuery && matchesCat;
    }).toList();

    // Sort
    switch (_sortBy) {
      case 'Price: Low to High':
        list.sort((a, b) => a.sellingPrice.compareTo(b.sellingPrice));
        break;
      case 'Price: High to Low':
        list.sort((a, b) => b.sellingPrice.compareTo(a.sellingPrice));
        break;
      case 'Stock: Low to High':
        list.sort((a, b) => a.currentStock.compareTo(b.currentStock));
        break;
      case 'Recent':
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'Name':
      default:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }

    _filteredProducts = list;
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to remove "${product.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _productRepo.deleteProduct(product.id);
      _loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('Product Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_view_rounded),
            tooltip: 'Import Excel / CSV',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.excelImport).then((_) => _loadProducts()),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan Barcode',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.barcodeScanner).then((_) => _loadProducts()),
          ),
        ],
      ),
      body: ScanzoAnimatedBackground(
        type: ScanzoBackgroundType.products,
        child: Column(
          children: [
            // Search & Filter Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              color: Colors.transparent,
            child: Column(
              children: [
                // Search Field
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(_applyFilters),
                  decoration: InputDecoration(
                    hintText: 'Search products by name, barcode, SKU...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(_applyFilters);
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceWhite,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),

                // Category & Sort row
                Row(
                  children: [
                    // Category Chips
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildCatChip('All'),
                            ..._categories.map((c) => _buildCatChip(c.name)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Sort dropdown
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.sort_rounded, color: AppColors.textPrimary),
                      tooltip: 'Sort By',
                      onSelected: (val) {
                        setState(() {
                          _sortBy = val;
                          _applyFilters();
                        });
                      },
                      itemBuilder: (ctx) => [
                        'Name',
                        'Price: Low to High',
                        'Price: High to Low',
                        'Stock: Low to High',
                        'Recent',
                      ].map((s) => PopupMenuItem(value: s, child: Text(s))).toList(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Product List or Empty State
          Expanded(
            child: _filteredProducts.isEmpty
                ? EmptyStateView(
                    icon: Icons.inventory_2_outlined,
                    title: _allProducts.isEmpty ? 'No Products Added Yet' : 'No Matching Products',
                    message: _allProducts.isEmpty
                        ? 'Add items manually or import an Excel/CSV spreadsheet to start billing.'
                        : 'Try searching with a different term or clear the active category filter.',
                    buttonText: _allProducts.isEmpty ? 'Add Your First Product' : null,
                    onButtonPressed: () => Navigator.pushNamed(context, AppRoutes.addEditProduct).then((_) => _loadProducts()),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return _buildProductCard(product);
                    },
                  ),
          ),
        ],
      ),
    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.addEditProduct).then((_) => _loadProducts()),
        backgroundColor: AppColors.primaryPinkDark,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCatChip(String name) {
    final isSelected = _selectedCategory == name;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(name),
        selected: isSelected,
        selectedColor: AppColors.primaryPink,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedCategory = name;
              _applyFilters();
            });
          }
        },
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: product.isOutOfStock
              ? AppColors.error.withOpacity(0.5)
              : product.isLowStock
                  ? AppColors.warning.withOpacity(0.5)
                  : AppColors.borderLight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category / Icon Box
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.pastelLavender,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shopping_bag_outlined, color: AppColors.pastelLavenderDark, size: 24),
          ),
          const SizedBox(width: 14),

          // Main Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: AppTypography.h3.copyWith(fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (product.isOutOfStock)
                      const StatusBadge(text: 'Out of Stock', type: BadgeType.error)
                    else if (product.isLowStock)
                      const StatusBadge(text: 'Low Stock', type: BadgeType.warning)
                    else
                      StatusBadge(text: '${product.currentStock.toStringAsFixed(0)} ${product.unit}', type: BadgeType.success),
                  ],
                ),
                const SizedBox(height: 4),

                // Barcode / SKU / Category
                Text(
                  '${product.category}${product.barcode.isNotEmpty ? ' • ${product.barcode}' : ''}',
                  style: AppTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Pricing Row
                Row(
                  children: [
                    Text(
                      CurrencyFormatter.format(product.sellingPrice),
                      style: AppTypography.h3.copyWith(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (product.mrp > product.sellingPrice) ...[
                      const SizedBox(width: 8),
                      Text(
                        CurrencyFormatter.format(product.mrp),
                        style: AppTypography.caption.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (product.profitMargin > 0)
                      Text(
                        'Profit: +${CurrencyFormatter.format(product.profitMargin)}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // More Options Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textSecondary),
            onSelected: (val) {
              if (val == 'edit') {
                Navigator.pushNamed(
                  context,
                  AppRoutes.addEditProduct,
                  arguments: {'product': product},
                ).then((_) => _loadProducts());
              } else if (val == 'delete') {
                _deleteProduct(product);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: AppColors.error), SizedBox(width: 8), Text('Delete', style: TextStyle(color: AppColors.error))])),
            ],
          ),
        ],
      ),
    );
  }
}
