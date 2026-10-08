import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/business_profile.dart';
import '../../../data/models/product.dart';
import '../../../data/models/sale.dart';
import '../../../data/models/shop_type.dart';
import '../../../data/repositories/business_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/billing_repository.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../shared/widgets/pastel_card.dart';
import '../widgets/dashboard_charts.dart';
import '../../../app/routes.dart';
import '../../../shared/widgets/scanzo_animated_background.dart';
import '../../../shared/widgets/scanzo_logo.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _businessRepo = BusinessRepository();
  final _productRepo = ProductRepository();
  final _billingRepo = BillingRepository();
  final _customerRepo = CustomerRepository();
  final _inventoryRepo = InventoryRepository();
  final _reportRepo = ReportRepository();

  BusinessProfile? _business;
  List<Product> _products = [];
  List<Sale> _sales = [];
  List<Product> _lowStockProducts = [];
  double _todaySales = 0.0;
  int _todayBills = 0;
  double _pendingCustomerBalance = 0.0;
  double _stockValue = 0.0;
  ReportSummary? _reportSummary;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  void _loadDashboardData() {
    setState(() {
      _business = _businessRepo.getBusinessProfile();
      _products = _productRepo.getAllProducts();
      _sales = _billingRepo.getAllSales();
      _lowStockProducts = _productRepo.getLowStockProducts();
      _stockValue = _inventoryRepo.getTotalStockValuation();

      // Today's metrics (Real data from stored transactions)
      final now = DateTime.now();
      final todaySalesList = _sales.where((s) =>
          s.createdAt.year == now.year &&
          s.createdAt.month == now.month &&
          s.createdAt.day == now.day).toList();

      _todaySales = todaySalesList.fold(0.0, (sum, s) => sum + s.grandTotal);
      _todayBills = todaySalesList.length;

      // Pending payments from customers
      final customers = _customerRepo.getAllCustomers();
      _pendingCustomerBalance = customers.fold(0.0, (sum, c) => sum + c.pendingBalance);

      // Report Summary for real charts
      _reportSummary = _reportRepo.generateReport();
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _showStoreSwitcher() {
    final stores = _businessRepo.getAllStores();
    final activeId = _businessRepo.activeStoreId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPink,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.swap_horiz_rounded, color: AppColors.primaryPinkDark, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Switch Store', style: AppTypography.h3.copyWith(fontSize: 18)),
                        Text('Separate inventory, billing & sales per shop', style: AppTypography.caption),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: stores.length,
                    itemBuilder: (context, index) {
                      final store = stores[index];
                      final isSelected = store.id == activeId;
                      final type = ShopType.getById(store.shopTypeId);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? type.pastelColor.withOpacity(0.5) : AppColors.backgroundCream,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? type.darkColor : AppColors.borderLight,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.surfaceWhite : type.pastelColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(type.icon, color: type.darkColor, size: 22),
                          ),
                          title: Text(
                            store.businessName,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${type.title} • Store ID: ${store.id}',
                            style: AppTypography.caption,
                          ),
                          trailing: isSelected
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: type.darkColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text('Active', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                )
                              : null,
                          onTap: () async {
                            Navigator.pop(ctx);
                            if (!isSelected) {
                              await _businessRepo.setActiveStore(store.id);
                              _loadDashboardData();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Switched to ${store.businessName} (${type.title})'),
                                    backgroundColor: AppColors.primaryPinkDark,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showCreateStoreDialog();
                  },
                  icon: const Icon(Icons.add_business_rounded),
                  label: const Text('+ Add New Shop / Business Type'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: AppColors.primaryPinkDark),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreateStoreDialog() {
    String selectedType = 'electronics';
    final nameController = TextEditingController(text: 'Electronics Store');

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final currentType = ShopType.getById(selectedType);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.add_business_rounded, color: AppColors.primaryPinkDark),
                SizedBox(width: 8),
                Text('Add New Store', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Business Category:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceWhite,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: ShopType.standardShopTypes.map((t) {
                      return DropdownMenuItem(
                        value: t.id,
                        child: Row(
                          children: [
                            Icon(t.icon, size: 18, color: t.darkColor),
                            const SizedBox(width: 8),
                            Text(t.title, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedType = val;
                          final t = ShopType.getById(val);
                          nameController.text = '${t.title} Scanzo';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('Store Name:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceWhite,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Category: ${currentType.performanceBadge} • ${currentType.benchmarkTurnover}',
                    style: TextStyle(fontSize: 12, color: currentType.darkColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(dialogCtx);
                  final newStore = await _businessRepo.createOrGetStoreForShopType(
                    selectedType,
                    storeName: name,
                  );
                  await _businessRepo.setActiveStore(newStore.id);
                  _loadDashboardData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Created & switched to $name (${ShopType.getById(selectedType).title})'),
                        backgroundColor: AppColors.primaryPinkDark,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPinkDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Create & Open', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final businessTitle = _business?.businessName ?? AppConstants.appName;
    final currentDate = DateFormatter.formatDate(DateTime.now());
    final activeShopType = ShopType.getById(_businessRepo.activeStoreType);

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      body: ScanzoAnimatedBackground(
        type: ScanzoBackgroundType.dashboard,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => _loadDashboardData(),
            color: AppColors.primaryPinkDark,
            child: CustomScrollView(
            slivers: [
              // Header Sliver
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _showStoreSwitcher,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: activeShopType.pastelColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: activeShopType.darkColor.withOpacity(0.35)),
                          ),
                          child: Icon(
                            activeShopType.icon,
                            color: activeShopType.darkColor,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    businessTitle,
                                    style: AppTypography.h2.copyWith(fontSize: 19),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: _showStoreSwitcher,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: activeShopType.pastelColor,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: activeShopType.darkColor.withOpacity(0.35)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          activeShopType.title,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: activeShopType.darkColor,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 14,
                                          color: activeShopType.darkColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_getGreeting()} • $currentDate',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                      const ScanzoLogo.icon(size: 36),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
                        tooltip: 'Settings',
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.settings).then((_) => _loadDashboardData()),
                      ),
                    ],
                  ),
                ),
              ),

              // Summary Cards (Real Stored Data: ₹0 / "No data yet" when empty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          "Today's Overview",
                          style: AppTypography.h3.copyWith(fontSize: 16),
                        ),
                      ),
                      GridView.count(
                        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.45,
                        children: [
                          _buildSummaryCard(
                            title: "Today's Sales",
                            value: CurrencyFormatter.format(_todaySales),
                            icon: Icons.currency_rupee_rounded,
                            pastelBg: AppColors.softPeach,
                            iconColor: AppColors.softPeachDark,
                          ),
                          _buildSummaryCard(
                            title: "Today's Bills",
                            value: '$_todayBills',
                            icon: Icons.receipt_long_rounded,
                            pastelBg: AppColors.pastelLavender,
                            iconColor: AppColors.pastelLavenderDark,
                          ),
                          _buildSummaryCard(
                            title: 'Total Products',
                            value: '${_products.length}',
                            icon: Icons.inventory_2_rounded,
                            pastelBg: AppColors.mintGreen,
                            iconColor: AppColors.mintGreenDark,
                          ),
                          _buildSummaryCard(
                            title: 'Low Stock Alert',
                            value: '${_lowStockProducts.length}',
                            icon: Icons.warning_amber_rounded,
                            pastelBg: AppColors.softRose,
                            iconColor: AppColors.softRoseDark,
                            isAlert: _lowStockProducts.isNotEmpty,
                          ),
                          _buildSummaryCard(
                            title: 'Pending Balances',
                            value: CurrencyFormatter.format(_pendingCustomerBalance),
                            icon: Icons.account_balance_wallet_rounded,
                            pastelBg: AppColors.lightSkyBlue,
                            iconColor: AppColors.lightSkyBlueDark,
                          ),
                          _buildSummaryCard(
                            title: 'Stock Valuation',
                            value: CurrencyFormatter.format(_stockValue),
                            icon: Icons.pie_chart_rounded,
                            pastelBg: AppColors.lightYellow,
                            iconColor: AppColors.lightYellowDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Quick Actions Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quick Actions',
                        style: AppTypography.h3.copyWith(fontSize: 16),
                      ),
                      Text(
                        'POS & Operations',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
              ),

              // Quick Action Grid
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.6,
                  ),
                  delegate: SliverChildListDelegate([
                    // New Bill -> Soft Peach
                    PastelCard(
                      title: 'New Bill',
                      subtitle: 'Fast POS Checkout',
                      icon: Icons.point_of_sale_rounded,
                      pastelColor: AppColors.softPeach,
                      darkColor: AppColors.softPeachDark,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.posBilling).then((_) => _loadDashboardData()),
                    ),
                    // Products -> Pastel Lavender
                    PastelCard(
                      title: 'Products',
                      subtitle: '${_products.length} Items Listed',
                      icon: Icons.category_rounded,
                      pastelColor: AppColors.pastelLavender,
                      darkColor: AppColors.pastelLavenderDark,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.productList).then((_) => _loadDashboardData()),
                    ),
                    // Inventory -> Mint Green
                    PastelCard(
                      title: 'Inventory',
                      subtitle: 'Stock & Movements',
                      icon: Icons.inventory_rounded,
                      pastelColor: AppColors.mintGreen,
                      darkColor: AppColors.mintGreenDark,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.inventory).then((_) => _loadDashboardData()),
                    ),
                    // Scan Barcode -> Baby Blue
                    PastelCard(
                      title: 'Scan Barcode',
                      subtitle: 'Fast Camera Lookup',
                      icon: Icons.qr_code_scanner_rounded,
                      pastelColor: AppColors.babyBlue,
                      darkColor: AppColors.babyBlueDark,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.barcodeScanner).then((_) => _loadDashboardData()),
                    ),
                    // Customers -> Soft Pink
                    PastelCard(
                      title: 'Customers',
                      subtitle: 'Accounts & Credit',
                      icon: Icons.people_alt_rounded,
                      pastelColor: AppColors.softPink,
                      darkColor: AppColors.softPinkDark,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.customerList).then((_) => _loadDashboardData()),
                    ),
                    // Suppliers -> Light Yellow
                    PastelCard(
                      title: 'Suppliers',
                      subtitle: 'Vendors & Purchases',
                      icon: Icons.local_shipping_rounded,
                      pastelColor: AppColors.lightYellow,
                      darkColor: AppColors.lightYellowDark,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.supplierList).then((_) => _loadDashboardData()),
                    ),
                    // Reports -> Pastel Purple
                    PastelCard(
                      title: 'Reports',
                      subtitle: 'Sales & Tax Insights',
                      icon: Icons.insights_rounded,
                      pastelColor: AppColors.pastelPurple,
                      darkColor: AppColors.pastelPurpleDark,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.reports).then((_) => _loadDashboardData()),
                    ),
                    // Import Excel -> Soft Aqua
                    PastelCard(
                      title: 'Import Excel',
                      subtitle: 'CSV / XLSX Bulk Sync',
                      icon: Icons.table_view_rounded,
                      pastelColor: AppColors.softAqua,
                      darkColor: AppColors.softAquaDark,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.excelImport).then((_) => _loadDashboardData()),
                    ),
                    // Sales History -> Pastel Coral
                    PastelCard(
                      title: 'Sales History',
                      subtitle: '${_sales.length} Invoices',
                      icon: Icons.history_rounded,
                      pastelColor: AppColors.pastelCoral,
                      darkColor: AppColors.pastelCoralDark,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.salesHistory).then((_) => _loadDashboardData()),
                    ),
                    // Low Stock -> Soft Rose
                    PastelCard(
                      title: 'Low Stock',
                      subtitle: '${_lowStockProducts.length} Items to Reorder',
                      icon: Icons.production_quantity_limits_rounded,
                      pastelColor: AppColors.softRose,
                      darkColor: AppColors.softRoseDark,
                      badgeText: _lowStockProducts.isNotEmpty ? '${_lowStockProducts.length}' : null,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.inventory).then((_) => _loadDashboardData()),
                    ),
                    // Settings -> Warm Cream
                    PastelCard(
                      title: 'Settings',
                      subtitle: 'Profile & Invoice Setup',
                      icon: Icons.tune_rounded,
                      pastelColor: AppColors.warmCream,
                      darkColor: AppColors.warmCreamDark,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.settings).then((_) => _loadDashboardData()),
                    ),
                  ]),
                ),
              ),

              // Real Charts Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    'Performance Analytics',
                    style: AppTypography.h3.copyWith(fontSize: 16),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: DashboardSalesBarChart(
                    dailySales: _reportSummary?.dailySales ?? [],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: DashboardCategoryDonutChart(
                    categorySales: _reportSummary?.categorySales ?? [],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.posBilling).then((_) => _loadDashboardData()),
        backgroundColor: AppColors.primaryPinkDark,
        icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
        label: const Text('New Bill', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color pastelBg,
    required Color iconColor,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAlert ? AppColors.error : AppColors.borderLight,
          width: isAlert ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: pastelBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              if (isAlert)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Alert', style: AppTypography.caption.copyWith(color: AppColors.error, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: AppTypography.h3.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: AppTypography.caption.copyWith(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
