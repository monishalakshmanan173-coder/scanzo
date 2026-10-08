import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/business_profile.dart';
import '../../../data/models/product.dart';
import '../../../data/models/sale.dart';
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

  @override
  Widget build(BuildContext context) {
    final businessTitle = _business?.businessName ?? AppConstants.appName;
    final currentDate = DateFormatter.formatDate(DateTime.now());

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
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.primaryPink,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: AppColors.primaryPinkDark,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              businessTitle,
                              style: AppTypography.h2.copyWith(fontSize: 20),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_getGreeting()} • $currentDate',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
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
