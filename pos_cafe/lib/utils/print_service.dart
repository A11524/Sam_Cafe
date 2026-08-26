import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PrintService {
  static final NumberFormat _currency = NumberFormat('#,##0', 'en_US');

  // ==========================================
  // HÀM HỖ TRỢ IN NGẦM (DÙNG CHUNG CHO TẤT CẢ)
  // ==========================================
  static Future<void> _executeDirectPrint(pw.Document pdf, String documentName) async {
    // Tự động quét các máy in đang kết nối
    final printers = await Printing.listPrinters();
    
    if (printers.isNotEmpty) {
      // Ưu tiên chọn máy in mặc định của hệ thống
      final defaultPrinter = printers.firstWhere((p) => p.isDefault, orElse: () => printers.first);
      
      // Kích hoạt IN NGẦM (Không hiện bảng Print Preview)
      await Printing.directPrintPdf(
        printer: defaultPrinter,
        onLayout: (PdfPageFormat format) async => pdf.save(),
        format: PdfPageFormat.roll80,
        name: documentName,
      );
    } else {
      // Nếu không tìm thấy máy in nào, mở bảng Preview như cũ để làm phương án dự phòng
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(), 
        format: PdfPageFormat.roll80, 
        name: documentName
      );
    }
  }

  // ==========================================
  // 1. IN PHIẾU BẾP / PHA CHẾ
  // ==========================================
  static Future<void> printKitchenTicket(String tableName, List<Map<String, dynamic>> items) async {
    final pdf = pw.Document();
    final String time = DateFormat('HH:mm - dd/MM/yyyy').format(DateTime.now());

    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontItalic = await PdfGoogleFonts.robotoItalic();

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll80, 
      margin: const pw.EdgeInsets.all(10), 
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold, italic: fontItalic),
      build: (pw.Context context) {
        return pw.ConstrainedBox(
          constraints: const pw.BoxConstraints(minHeight: 260), 
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('PHIẾU PHA CHẾ / BẾP', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Text('Bàn: $tableName', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('Thời gian: $time', style: const pw.TextStyle(fontSize: 10)),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 5),
              
              ...items.map((item) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(child: pw.Text('${item['name']}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
                        pw.Text('x${item['quantity']}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      ]
                    ),
                    if (item['note'] != null && item['note'].toString().isNotEmpty)
                      pw.Text('  * Ghi chú: ${item['note']}', style: const pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
                  ]
                )
              )),
              
              pw.SizedBox(height: 10),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Center(child: pw.Text('--- HẾT ---', style: const pw.TextStyle(fontSize: 10))),
            ],
          ),
        );
      },
    ));

    // GỌI HÀM IN NGẦM
    await _executeDirectPrint(pdf, 'Bep_$tableName');
  }

  // ==========================================
  // 2. IN HÓA ĐƠN THANH TOÁN (BILL)
  // ==========================================
  static Future<void> printCustomerReceipt(String tableName, int totalAmount, List<Map<String, dynamic>> items) async {
    final pdf = pw.Document();
    final String time = DateFormat('HH:mm:ss - dd/MM/yyyy').format(DateTime.now());

    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontItalic = await PdfGoogleFonts.robotoItalic();

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll80,
      margin: const pw.EdgeInsets.all(10),
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold, italic: fontItalic),
      build: (pw.Context context) {
        return pw.ConstrainedBox(
          constraints: const pw.BoxConstraints(minHeight: 260),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('SAM CAFE', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text('Địa chỉ: Phan Đình Phùng, Phường Châu Phú A, Châu Đốc', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 10),
              pw.Text('HÓA ĐƠN THANH TOÁN', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              
              pw.Container(
                alignment: pw.Alignment.centerLeft,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Bàn: $tableName', style: const pw.TextStyle(fontSize: 12)),
                    pw.Text('Ngày: $time', style: const pw.TextStyle(fontSize: 12)),
                  ]
                )
              ),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              
              ...items.map((item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(child: pw.Text('${item['name']} (x${item['quantity']})', style: const pw.TextStyle(fontSize: 10))),
                    pw.Text('${_currency.format(item['price'] * item['quantity'])}đ', style: const pw.TextStyle(fontSize: 10)),
                  ]
                )
              )),
              
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TỔNG CỘNG:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${_currency.format(totalAmount)}đ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ]
              ),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 10),
              pw.Text('Cảm ơn quý khách!', style: const pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
            ],
          ),
        );
      },
    ));

    // GỌI HÀM IN NGẦM
    await _executeDirectPrint(pdf, 'Bill_$tableName');
  }

  // ==========================================
  // 3. IN PHIẾU KẾT CA
  // ==========================================
  static Future<void> printShiftReport(int invoiceCount, int totalRevenue, int startingCash, int actualCash, int difference) async {
    final pdf = pw.Document();
    final String time = DateFormat('HH:mm:ss - dd/MM/yyyy').format(DateTime.now());
    final expectedCash = startingCash + totalRevenue;

    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll80,
      margin: const pw.EdgeInsets.all(10),
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
      build: (pw.Context context) {
        return pw.ConstrainedBox(
          constraints: const pw.BoxConstraints(minHeight: 260),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('SAM CAFE', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
              pw.Center(child: pw.Text('BÁO CÁO KẾT CA', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Text('Thời gian: $time', style: const pw.TextStyle(fontSize: 10)),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Tổng hóa đơn:'), pw.Text('$invoiceCount')]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Doanh thu ca:'), pw.Text('${_currency.format(totalRevenue)}đ')]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Tiền đầu ca:'), pw.Text('${_currency.format(startingCash)}đ')]),
              pw.Divider(),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('TIỀN CẦN CÓ:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), 
                pw.Text('${_currency.format(expectedCash)}đ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
              ]),
              pw.SizedBox(height: 5),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Tiền thực tế:'), pw.Text('${_currency.format(actualCash)}đ')]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Chênh lệch:'), 
                pw.Text('${difference > 0 ? '+' : ''}${_currency.format(difference)}đ')
              ]),
              pw.SizedBox(height: 20),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(children: [pw.Text('Nhân viên'), pw.SizedBox(height: 30), pw.Text('(Ký tên)')]),
                  pw.Column(children: [pw.Text('Quản lý'), pw.SizedBox(height: 30), pw.Text('(Ký tên)')]),
                ]
              )
            ],
          ),
        );
      },
    ));

    // GỌI HÀM IN NGẦM
    await _executeDirectPrint(pdf, 'Bao_Cao_Ket_Ca');
  }
}