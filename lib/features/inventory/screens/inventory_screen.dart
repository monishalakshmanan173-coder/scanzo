import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../data/models/product.dart';
import '../../../data/models/stock_movement.dart';
import '../../../data/repositories/inventory_repository.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  final _inventoryRepo = InventoryRepository();
  late TabController _tabController;

  List<Product> _products = [];
  List<StockMovement> _movements = [];
  double _costValuation = 0.0;
  double _retailValuation = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _products = _inventoryRepo.getAllProducts();
      _movements = _inventoryRepo.getMovements();
      _costValuation = _inventoryRepo.getTotalStockValuation();
      _retailValuation = _inventoryRepo.getTotalRetailStockValuation();
    });
  }

  Future<void> _showAdjustStockDialog(Product product) async {
    final qtyController = TextEditingController(text: product.currentStock.toStringAsFixed(0));
    final reasonController = TextEditingController();
    String movementType = AppConstants.stockMovementAdjustment;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Adjust Stock: ${product.name}', style: AppTypography.h3.copyWith(fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Stock: ${product.currentStock.toStringAsFixed(0)} ${product.unit}', style: AppTypography.caption),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: movementType,
                    decoration: const InputDecoration(labelText: 'Adjustment Reason'),
                    items: [
                      AppConstants.stockMovementAdjustment,
                      AppConstants.stockMovementPurchase,
                      AppConstants.stockMovementDamaged,
                      AppConstants.stockMovementReturn,
                    ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => movementType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'New Stock Quantity (${product.unit})',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Remarks (Optional)',
                      hintText: 'e.g. Broken packaging, supplier restock',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final newStock = double.tryParse(qtyController.text.trim());
                  if (newStock != null && newStock >= 0) {
                    await _inventoryRepo.recordAdjustment(
                      productId: product.id,
                      newStock: newStock,
                      type: movementType,
                      reason: reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null,
                    );
                    Navigator.pop(ctx, true);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPinkDark),
                child: const Text('Save Adjustment', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );

    if (updated == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lowStockCount = _products.where((p) => p.isLowStock).length;
    final outOfStockCount = _products.where((p) => p.isOutOfStock).length;

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('Inventory & Stock'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Valuation & Alert Cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.mintGreen,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Stock Value (Cost)', style: TextStyle(fontSize: 11, color: AppColors.mintGreenDark, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.format(_costValuation),
                          style: AppTypography.h3.copyWith(fontSize: 16, color: AppColors.mintGreenDark),
                        ),
                        Text('Retail: ${CurrencyFormatter.format(_retailValuation)}', style: AppTypography.caption),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: outOfStockCount > 0 ? AppColors.softRose : AppColors.softPeach,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stock Alerts', style: TextStyle(fontSize: 11, color: outOfStockCount > 0 ? AppColors.softRoseDark : AppColors.softPeachDark, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          '$outOfStockCount Out • $lowStockCount Low',
                          style: AppTypography.h3.copyWith(fontSize: 15, color: outOfStockCount > 0 ? AppColors.softRoseDark : AppColors.softPeachDark),
                        ),
                        Text('${_products.length} Total SKUs', style: AppTypography.caption),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primaryPinkDark,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textMuted,
              tabs: [
                Tab(text: 'Current Stock (${_products.length})'),
                Tab(text: 'Stock Movement Log (${_movements.length})'),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Current Stock with Adjustment Button
                _products.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.inventory_2_outlined,
                        title: 'No inventory recorded',
                        message: 'Add products to begin tracking stock valuation and reorders.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          return _buildStockItemTile(product);
                        },
                      ),

                // Tab 2: Traceable Movements Log
                _movements.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.history_rounded,
                        title: 'No Stock Movements Yet',
                        message: 'Every sale, purchase or stock adjustment will be permanently logged here.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        itemCount: _movements.length,
                        itemBuilder: (context, index) {
                          final movement = _movements[index];
                          return _buildMovementTile(movement);
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockItemTile(Product product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: product.isOutOfStock
              ? AppColors.error.withOpacity(0.4)
              : product.isLowStock
                  ? AppColors.warning.withOpacity(0.4)
                  : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  '${product.category} • Cost: ${CurrencyFormatter.format(product.purchasePrice)} • Value: ${CurrencyFormatter.format(product.stockValue)}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (product.isOutOfStock)
                const StatusBadge(text: 'Out of Stock', type: BadgeType.error)
              else if (product.isLowStock)
                StatusBadge(text: 'Low (${product.currentStock.toStringAsFixed(0)})', type: BadgeType.warning)
              else
                Text(
                  '${product.currentStock.toStringAsFixed(0)} ${product.unit}',
                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _showAdjustStockDialog(product),
                child: Text(
                  'Adjust Stock',
                  style: AppTypography.caption.copyWith(color: AppColors.primaryPinkDark, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMovementTile(StockMovement movement) {
    final isPositive = movement.quantityDelta >= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isPositive ? AppColors.successLight : AppColors.errorLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPositive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isPositive ? AppColors.success : AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(movement.productName, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                    Text(
                      '${isPositive ? '+' : ''}${movement.quantityDelta.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isPositive ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${movement.type} • Stock: ${movement.previousStock.toStringAsFixed(0)} → ${movement.newStock.toStringAsFixed(0)}',
                  style: AppTypography.caption,
                ),
                if (movement.reason != null)
                  Text(movement.reason!, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
