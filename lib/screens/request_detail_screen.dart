import 'package:capstone_project/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../widgets/custom_font.dart';
import '../screens/payment_details_screen.dart';
import '../screens/pending_screen.dart';
import '../services/api_service.dart';


class RequestDetailsScreen extends StatefulWidget {
  final PendingRequest request;
  const RequestDetailsScreen({super.key, required this.request});

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  String? _receiptProof;
  bool _loadingReceipt = false;

  PendingRequest get request => widget.request;

  bool get _canPay => request.status.toLowerCase() == 'pending payment';
  bool get _isPendingApproval => request.status.toLowerCase() == 'pending approval';

  @override
  void initState() {
    super.initState();
    _loadReceiptIfAvailable();
  }

  Future<void> _loadReceiptIfAvailable() async {
    if (!_isPendingApproval || request.id == null || request.id!.isEmpty) {
      return;
    }

    setState(() {
      _loadingReceipt = true;
    });

    try {
      final txn = await ApiService.getLatestTransactionForRequest(
        requestId: request.id!,
      );
      if (!mounted) return;
      setState(() {
        _receiptProof = txn?['paymentProof']?.toString();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _receiptProof = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingReceipt = false;
        });
      }
    }
  }

  void _showReceiptDialog() {
    if (_receiptProof == null || _receiptProof!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No receipt image found for this request yet.')),
      );
      return;
    }

    final proof = _receiptProof!;
    final proofUri = Uri.tryParse(proof);
    final canPreviewNetwork = proofUri != null &&
        (proofUri.scheme == 'http' || proofUri.scheme == 'https');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uploaded Receipt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (canPreviewNetwork)
              Image.network(
                proof,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Text('Unable to preview receipt image.'),
              )
            else
              const Text('Receipt image is stored locally on device. Preview not available in this view.'),
            const SizedBox(height: 12),
            SelectableText(
              kIsWeb ? proof : 'Receipt reference: $proof',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  String get _statusMessage {
    final normalized = request.status.toLowerCase();
    if (normalized == 'pending payment') {
      return 'Payment is required to continue processing your request. Please complete your payment to proceed.';
    }
    if (normalized == 'pending approval') {
      return 'Your receipt was submitted. Please wait for registrar approval.';
    }
    return 'Your request is currently under processing. Please check back for updates.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5D7E97),
        title: const Text("Information of the Request", style: TextStyle(color: FB_TEXT_COLOR_WHITE)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          children: [
            _buildSectionCard("Student Information", [
              _buildInfoRow("Name:", "Alyssa Cruz"),
              _buildInfoRow("Student ID:", "2024-123346"),
              _buildInfoRow("Program:", "BSIT-MWA"),
              _buildInfoRow("Email:", "alyssac@school.edu.ph"),
            ]),
            SizedBox(height: 15.h),
            _buildSectionCard("Document Details", [
              _buildInfoRow("Type of Document:", request.docName),
              _buildInfoRow("Purpose of Request:", request.purpose),
              _buildInfoRow("Date Requested:", DateFormat('MMMM d, y').format(request.dateCreated)),
            ]),
            SizedBox(height: 15.h),
            _buildSectionCard("Request Status", [
              _buildInfoRow("Date:", DateFormat('MMMM d, y').format(request.dateCreated)),
              _buildInfoRow("Time:", DateFormat('h:mm a').format(request.dateCreated)),
              SizedBox(height: 10.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(color: Colors.yellow.shade100, borderRadius: BorderRadius.circular(5.r)),
                child: Text(request.status, style: TextStyle(color: Colors.yellow.shade800, fontWeight: FontWeight.bold)),
              ),
              SizedBox(height: 10.h),
              Text(_statusMessage,
                style: TextStyle(
                  color: _canPay ? Colors.red : Colors.orange.shade800,
                  fontSize: 11,
                ),
              ),
            ]),
            SizedBox(height: 15.h),
            _buildSectionCard("Payment Summary", [
              _buildInfoRow("Document Price:", "PHP 100"),
              _buildInfoRow("Processing Fee:", "PHP 10"),
              const Divider(),
              _buildInfoRow("Total Amount Due:", "PHP 110", isBold: true),
              SizedBox(height: 15.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_isPendingApproval)
                    OutlinedButton(
                      onPressed: _loadingReceipt ? null : _showReceiptDialog,
                      child: Text(_loadingReceipt ? 'Loading...' : 'View Receipt'),
                    ),
                  if (_isPendingApproval) SizedBox(width: 10.w),
                  ElevatedButton(
                    onPressed: _canPay
                        ? () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentDetailsScreen(request: request)));
                          }
                        : null,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF233446)),
                    child: CustomFont(
                      text: _canPay ? "Pay now" : "Awaiting Approval",
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(15.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
          const Divider(),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13.sp, color: Colors.black54)),
          Text(value, style: TextStyle(fontSize: 13.sp, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}