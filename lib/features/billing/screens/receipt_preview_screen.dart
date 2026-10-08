import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/sale.dart';
import '../../../data/models/business_profile.dart';
import '../../../data/repositories/business_repository.dart';
import '../../../data/services/invoice_pdf_service.dart';
import '../../../shared/widgets/scanzo_logo.dart';

class ReceiptPreviewScreen extends StatefulWidget {
  final Map<String, dynamic> arguments;

  const ReceiptPreviewScreen({super.key, required this.arguments});

  @override
  State<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends State<ReceiptPreviewScreen> {
  final _businessRepo = BusinessRepository();
  late Sale _sale;
  late BusinessProfile _business;

  String _selectedFormat = 'Standard Invoice';

  @override
  void initState() {
    super.initState();
    _sale = widget.arguments['sale'] as Sale;
    _business = _businessRepo.getBusinessProfile() ??
        BusinessProfile(
          id: 'temp',
          businessName: 'SCANZO Store',
          ownerName: 'Store Owner',
          mobile: '9876543210',
          address: 'Main Market Road',
          city: 'Bengaluru',
          state: 'Karnataka',
          pincode: '560001',
          shopTypeId: 'retail',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ScanzoLogo.icon(size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Receipt #${_sale.invoiceNumber}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Print Receipt',
            onPressed: () => InvoicePdfService.printInvoice(
              sale: _sale,
              business: _business,
              format: _selectedFormat,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share Receipt PDF',
            onPressed: () => InvoicePdfService.shareInvoice(
              sale: _sale,
              business: _business,
              format: _selectedFormat,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Format Selector Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.surfaceWhite,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: AppConstants.receiptFormats.map((format) {
                  final isSelected = _selectedFormat == format;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(format),
                      selected: isSelected,
                      selectedColor: AppColors.primaryPink,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedFormat = format);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Interactive PDF Viewer & Print Preview
          Expanded(
            child: PdfPreview(
              build: (pageFormat) => InvoicePdfService.generateInvoicePdf(
                sale: _sale,
                business: _business,
                format: _selectedFormat,
              ),
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              allowPrinting: true,
              allowSharing: true,
              actions: const [],
              pdfFileName: 'Scanzo_Invoice_${_sale.invoiceNumber}.pdf',
            ),
          ),
        ],
      ),
    );
  }
}
