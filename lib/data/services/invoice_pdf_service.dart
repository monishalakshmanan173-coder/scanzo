import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/sale.dart';
import '../models/business_profile.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/constants/app_constants.dart';

class InvoicePdfService {
  static Future<Uint8List> generateInvoicePdf({
    required Sale sale,
    required BusinessProfile business,
    required String format, // 'Standard Invoice', '58mm Thermal Receipt', '80mm Thermal Receipt', 'A4 Full Invoice'
  }) async {
    final pdf = pw.Document();

    PdfPageFormat pageFormat;
    if (format.contains('58mm')) {
      pageFormat = const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm);
    } else if (format.contains('80mm')) {
      pageFormat = const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 3 * PdfPageFormat.mm);
    } else {
      pageFormat = PdfPageFormat.a4;
    }

    final isThermal = format.contains('58mm') || format.contains('80mm');

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          if (isThermal) {
            return _buildThermalContent(sale, business, format.contains('58mm'));
          } else {
            return _buildA4Content(sale, business);
          }
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildThermalContent(Sale sale, BusinessProfile business, bool is58mm) {
    final fontSizeTitle = is58mm ? 10.0 : 12.0;
    final fontSizeBody = is58mm ? 7.0 : 8.5;
    final fontSizeHeader = is58mm ? 7.5 : 9.0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Brand & Business Name
        pw.Text(business.businessName.toUpperCase(),
            style: pw.TextStyle(fontSize: fontSizeTitle, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 2),
        pw.Text('Powered by ${AppConstants.appName}',
            style: pw.TextStyle(fontSize: fontSizeBody - 1, fontStyle: pw.FontStyle.italic),
            textAlign: pw.TextAlign.center),
        if (business.address.isNotEmpty)
          pw.Text(business.address,
              style: pw.TextStyle(fontSize: fontSizeBody), textAlign: pw.TextAlign.center),
        if (business.city.isNotEmpty)
          pw.Text('${business.city}, ${business.state} - ${business.pincode}',
              style: pw.TextStyle(fontSize: fontSizeBody), textAlign: pw.TextAlign.center),
        pw.Text('Tel: ${business.mobile}',
            style: pw.TextStyle(fontSize: fontSizeBody), textAlign: pw.TextAlign.center),
        if (business.gstin != null && business.gstin!.isNotEmpty)
          pw.Text('GSTIN: ${business.gstin}',
              style: pw.TextStyle(fontSize: fontSizeBody, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center),
        pw.Divider(thickness: 0.8),

        // Invoice Meta
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('INV: ${sale.invoiceNumber}',
                style: pw.TextStyle(fontSize: fontSizeBody, fontWeight: pw.FontWeight.bold)),
            pw.Text(DateFormatter.formatShortDate(sale.createdAt),
                style: pw.TextStyle(fontSize: fontSizeBody)),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Time: ${DateFormatter.formatTime(sale.createdAt)}',
                style: pw.TextStyle(fontSize: fontSizeBody)),
            pw.Text('Pay: ${sale.paymentMethod}',
                style: pw.TextStyle(fontSize: fontSizeBody)),
          ],
        ),
        if (sale.customerName != null && sale.customerName!.isNotEmpty)
          pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text('Customer: ${sale.customerName}',
                style: pw.TextStyle(fontSize: fontSizeBody)),
          ),
        pw.Divider(thickness: 0.8),

        // Items Table
        pw.Row(
          children: [
            pw.Expanded(
                flex: 4,
                child: pw.Text('Item',
                    style: pw.TextStyle(
                        fontSize: fontSizeHeader, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(
                flex: 2,
                child: pw.Text('Qty',
                    style: pw.TextStyle(
                        fontSize: fontSizeHeader, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center)),
            pw.Expanded(
                flex: 2,
                child: pw.Text('Rate',
                    style: pw.TextStyle(
                        fontSize: fontSizeHeader, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right)),
            pw.Expanded(
                flex: 2,
                child: pw.Text('Total',
                    style: pw.TextStyle(
                        fontSize: fontSizeHeader, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right)),
          ],
        ),
        pw.Divider(thickness: 0.5),

        ...sale.items.map((item) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
            child: pw.Row(
              children: [
                pw.Expanded(
                    flex: 4,
                    child: pw.Text(item.productName,
                        style: pw.TextStyle(fontSize: fontSizeBody))),
                pw.Expanded(
                    flex: 2,
                    child: pw.Text('${item.quantity} ${item.unit}',
                        style: pw.TextStyle(fontSize: fontSizeBody),
                        textAlign: pw.TextAlign.center)),
                pw.Expanded(
                    flex: 2,
                    child: pw.Text(item.unitPrice.toStringAsFixed(2),
                        style: pw.TextStyle(fontSize: fontSizeBody),
                        textAlign: pw.TextAlign.right)),
                pw.Expanded(
                    flex: 2,
                    child: pw.Text(item.totalAmount.toStringAsFixed(2),
                        style: pw.TextStyle(fontSize: fontSizeBody),
                        textAlign: pw.TextAlign.right)),
              ],
            ),
          );
        }),

        pw.Divider(thickness: 0.8),

        // Calculations
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Subtotal:', style: pw.TextStyle(fontSize: fontSizeBody)),
            pw.Text(CurrencyFormatter.format(sale.subtotal),
                style: pw.TextStyle(fontSize: fontSizeBody)),
          ],
        ),
        if (sale.totalDiscount > 0)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Discount:', style: pw.TextStyle(fontSize: fontSizeBody)),
              pw.Text('- ${CurrencyFormatter.format(sale.totalDiscount)}',
                  style: pw.TextStyle(fontSize: fontSizeBody)),
            ],
          ),
        if (sale.totalGst > 0)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total Tax/GST:', style: pw.TextStyle(fontSize: fontSizeBody)),
              pw.Text(CurrencyFormatter.format(sale.totalGst),
                  style: pw.TextStyle(fontSize: fontSizeBody)),
            ],
          ),
        pw.Divider(thickness: 1),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('GRAND TOTAL:',
                style: pw.TextStyle(
                    fontSize: fontSizeTitle - 1, fontWeight: pw.FontWeight.bold)),
            pw.Text(CurrencyFormatter.format(sale.grandTotal),
                style: pw.TextStyle(
                    fontSize: fontSizeTitle - 1, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.Divider(thickness: 0.5),

        // Payment status
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Amount Received:', style: pw.TextStyle(fontSize: fontSizeBody)),
            pw.Text(CurrencyFormatter.format(sale.paidAmount),
                style: pw.TextStyle(fontSize: fontSizeBody)),
          ],
        ),
        if (sale.changeAmount > 0)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Change Returned:', style: pw.TextStyle(fontSize: fontSizeBody)),
              pw.Text(CurrencyFormatter.format(sale.changeAmount),
                  style: pw.TextStyle(fontSize: fontSizeBody)),
            ],
          ),

        pw.SizedBox(height: 8),
        pw.Text('Thank you for shopping with us!',
            style: pw.TextStyle(
                fontSize: fontSizeBody, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center),
        pw.Text('Please visit again!',
            style: pw.TextStyle(fontSize: fontSizeBody - 1),
            textAlign: pw.TextAlign.center),
      ],
    );
  }

  static pw.Widget _buildA4Content(Sale sale, BusinessProfile business) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(business.businessName,
                    style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.pink900)),
                pw.SizedBox(height: 4),
                pw.Text(business.address, style: const pw.TextStyle(fontSize: 10)),
                pw.Text('${business.city}, ${business.state} - ${business.pincode}',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Phone: ${business.mobile}',
                    style: const pw.TextStyle(fontSize: 10)),
                if (business.email != null && business.email!.isNotEmpty)
                  pw.Text('Email: ${business.email}',
                      style: const pw.TextStyle(fontSize: 10)),
                if (business.gstin != null && business.gstin!.isNotEmpty)
                  pw.Text('GSTIN: ${business.gstin}',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('TAX INVOICE',
                    style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800)),
                pw.SizedBox(height: 6),
                pw.Text('Invoice No: ${sale.invoiceNumber}',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text('Date: ${DateFormatter.formatDate(sale.createdAt)}',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Time: ${DateFormatter.formatTime(sale.createdAt)}',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Payment: ${sale.paymentMethod}',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Status: ${sale.paymentStatus}',
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800)),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 16),
        pw.Divider(thickness: 1, color: PdfColors.pink200),
        pw.SizedBox(height: 8),

        // Bill To
        if (sale.customerName != null && sale.customerName!.isNotEmpty) ...[
          pw.Text('Bill To (Customer Details):',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Text(sale.customerName!,
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)),
          if (sale.customerMobile != null && sale.customerMobile!.isNotEmpty)
            pw.Text('Mobile: ${sale.customerMobile}',
                style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 12),
        ],

        // Items Table
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(30),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FlexColumnWidth(1.5),
            5: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.pink50),
              children: [
                pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('#',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold))),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Item Description',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold))),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Quantity',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center)),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Unit Rate',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.right)),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Tax %',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center)),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Amount',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.right)),
              ],
            ),
            ...List.generate(sale.items.length, (idx) {
              final itm = sale.items[idx];
              return pw.TableRow(
                children: [
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('${idx + 1}',
                          style: const pw.TextStyle(fontSize: 9))),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(itm.productName,
                          style: const pw.TextStyle(fontSize: 9))),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('${itm.quantity} ${itm.unit}',
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center)),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(CurrencyFormatter.format(itm.unitPrice),
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.right)),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('${itm.gstRate}%',
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center)),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(CurrencyFormatter.format(itm.totalAmount),
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.right)),
                ],
              );
            }),
          ],
        ),

        pw.SizedBox(height: 16),

        // Totals summary
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(
              width: 240,
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(CurrencyFormatter.format(sale.subtotal),
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  if (sale.totalDiscount > 0) ...[
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Discount:',
                            style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('- ${CurrencyFormatter.format(sale.totalDiscount)}',
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                  if (sale.totalGst > 0) ...[
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Taxes (GST):',
                            style: const pw.TextStyle(fontSize: 10)),
                        pw.Text(CurrencyFormatter.format(sale.totalGst),
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                  pw.Divider(thickness: 1, color: PdfColors.grey400),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Grand Total:',
                          style: pw.TextStyle(
                              fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.Text(CurrencyFormatter.format(sale.grandTotal),
                          style: pw.TextStyle(
                              fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Amount Paid:',
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(CurrencyFormatter.format(sale.paidAmount),
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  if (sale.changeAmount > 0) ...[
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Change Returned:',
                            style: const pw.TextStyle(fontSize: 10)),
                        pw.Text(CurrencyFormatter.format(sale.changeAmount),
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        pw.Spacer(),

        // Footer
        pw.Divider(thickness: 1, color: PdfColors.grey300),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
                'Thank you for your business! Generated via ${AppConstants.appName}',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey600)),
            pw.Text('Authorized Signature',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey600)),
          ],
        ),
      ],
    );
  }

  static Future<void> printInvoice({
    required Sale sale,
    required BusinessProfile business,
    required String format,
  }) async {
    final pdfBytes = await generateInvoicePdf(
      sale: sale,
      business: business,
      format: format,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat f) async => pdfBytes,
      name: 'Invoice_${sale.invoiceNumber}',
    );
  }

  static Future<void> shareInvoice({
    required Sale sale,
    required BusinessProfile business,
    required String format,
  }) async {
    final pdfBytes = await generateInvoicePdf(
      sale: sale,
      business: business,
      format: format,
    );
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Invoice_${sale.invoiceNumber}.pdf',
    );
  }
}
