import 'package:capstone_project/screens/home_screen.dart';
import 'package:capstone_project/screens/payment_details_screen.dart';
import 'package:capstone_project/screens/pending_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants.dart';
import '../widgets/custom_font.dart';
import '../services/api_service.dart';


class RequestFormScreen extends StatefulWidget {
  const RequestFormScreen({super.key});

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  // --- State Variables ---
  String? _mainDocType;
  String? _subDocType;
  String? _selectedPurpose;
  bool _isConfirmed = false;

  final TextEditingController _otherPurposeController = TextEditingController();
  final TextEditingController _otherRequestController = TextEditingController();

  // --- Data Lists ---
  final List<String> mainCategories = [
    'Original Documents',
    'Certifications', 
    'Certified True Copy', 
    'Transcript of Records'
  ];

  final List<String> originalDocumentList = [
    'F137 / SF10',
    'Transcript of Record',
    'Diploma',
    'Others',
  ];

  final List<String> certificationList = [
    'Certificate of Enrollment',
    'Certificate of Good Moral',
    'Grade Certification',
    'Certificate of Candidacy for Graduation',
    'Certificate of Units Earned',
    'Certificate of Assessment',
    'Certificate of Registration',
    'Others',
  ];

  final List<String> trueCopyList = [
    'CTC of Certificate of Matriculation',
    'CTC of Diploma',
    'CTC of Curriculum',
    'Card',
    'CAV (Red Ribbon)',
    'Cert. of Grades / GWA / Transfer Credential',
    'Others',
  ];

  final List<String> purposes = [
    'Application to Other School',
    'Application for College',
    'Employment', 
    'Board Exam', 
    'Board Examinations',
    'Abroad',
    'Visa',
    'Correction of Name/Birthdate',
    'Personal Use', 
    'Transfer', 
    'Others'
  ];

  // --- Logic Methods ---

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
        title: Text("Notice", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp)),
        content: Text(message, style: TextStyle(fontSize: 14.sp)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(color: Color(0xFF233446), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleSubmission() async {
    // Check main requirements
    if (_mainDocType == null || _selectedPurpose == null) {
      _showErrorDialog("Please select the document type and purpose.");
      return;
    }

    // Check sub-selection if needed
    if ((_mainDocType == 'Original Documents' ||
            _mainDocType == 'Certifications' ||
            _mainDocType == 'Certified True Copy') &&
        _subDocType == null) {
      _showErrorDialog("Please specify which document you need from the list.");
      return;
    }

    if (_subDocType == 'Others' && _otherRequestController.text.trim().isEmpty) {
      _showErrorDialog("Please specify the other document you are requesting.");
      return;
    }

    if (_selectedPurpose == 'Others' && _otherPurposeController.text.trim().isEmpty) {
      _showErrorDialog("Please specify the purpose.");
      return;
    }

    // Check Checkbox
    if (!_isConfirmed) {
      _showErrorDialog("Please confirm that your details are accurate by checking the box.");
      return;
    }

    // Prepare data
    String finalDocName = (_mainDocType == 'Transcript of Records')
      ? 'Transcript of Records'
      : (_subDocType == 'Others'
        ? _otherRequestController.text.trim()
        : (_subDocType ?? _mainDocType!));

    String finalPurpose = (_selectedPurpose == 'Others')
        ? _otherPurposeController.text.trim()
        : _selectedPurpose!;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Send request to API
      final response = await ApiService.createRequest(
        documentType: _mainDocType!,
        subDocumentType: finalDocName,
        purpose: finalPurpose,
        otherPurpose: _selectedPurpose == 'Others' ? finalPurpose : '',
        quantity: 1,
      );

      if (response['_id'] != null) {
        try {
          await ApiService.updateRequestStatus(
            id: response['_id'].toString(),
            status: 'Pending Payment',
          );
          response['status'] = 'Pending Payment';
        } catch (_) {
          response['status'] = response['status'] ?? 'Pending Payment';
        }
      } else {
        response['status'] = response['status'] ?? 'Pending Payment';
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Prepare data for the Pending Screen
      final createdAt = DateTime.tryParse((response['createdAt'] ?? '').toString()) ?? DateTime.now();
      final request = PendingRequest(
        id: response['_id']?.toString(),
        status: (response['status'] ?? "Pending Payment").toString(),
        purpose: finalPurpose,
        docName: finalDocName,
        dateCreated: createdAt,
      );

      // Redirect to Pending Screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SuccessfulScreen(
            request: request,
          ),
        ),
      );
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      _showErrorDialog("Failed to submit request: ${e.toString().replaceAll('Exception: ', '')}");
    }
  }

  @override
  void dispose() {
    _otherPurposeController.dispose();
    _otherRequestController.dispose();
    super.dispose();
  }

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Light grey background
      appBar: AppBar(
        backgroundColor: const Color(0xFF5D7E97),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: Colors.white, size: 30.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Request Form", style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(25.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Document Request", style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 20.h),

            // 1. Main Category Dropdown
            _buildLabel("Type of Document:"),
            _buildDropdown(
              hint: "Type of Document",
              value: _mainDocType,
              items: mainCategories,
              onChanged: (val) {
                setState(() {
                  _mainDocType = val;
                  _subDocType = null; // Clear sub-dropdown when parent changes
                });
              },
            ),

            // 2. Nested Dropdown Logic
            if (_mainDocType == 'Original Documents') ...[
              _buildLabel("Original Documents:"),
              _buildDropdown(
                hint: "Choose Document to Request",
                value: _subDocType,
                items: originalDocumentList,
                onChanged: (val) => setState(() => _subDocType = val),
              ),
            ] else if (_mainDocType == 'Certifications') ...[
              _buildLabel("Certifications:"),
              _buildDropdown(
                hint: "Choose Document to Request",
                value: _subDocType,
                items: certificationList,
                onChanged: (val) => setState(() => _subDocType = val),
              ),
            ] else if (_mainDocType == 'Certified True Copy') ...[
              _buildLabel("Certified True Copy:"),
              _buildDropdown(
                hint: "Choose Document to Request",
                value: _subDocType,
                items: trueCopyList,
                onChanged: (val) => setState(() => _subDocType = val),
              ),
            ],

            if (_subDocType == 'Others') ...[
              SizedBox(height: 10.h),
              TextFormField(
                controller: _otherRequestController,
                decoration: _inputDecoration(hint: "Specify requested document"),
              ),
            ],

            // 3. Purpose Dropdown
            _buildLabel("Purpose of Request:"),
            _buildDropdown(
              hint: "Purpose of Request",
              value: _selectedPurpose,
              items: purposes,
              onChanged: (val) => setState(() => _selectedPurpose = val),
            ),

            // 4. Conditional Other Field
            if (_selectedPurpose == 'Others') ...[
              SizedBox(height: 10.h),
              TextFormField(
                controller: _otherPurposeController,
                decoration: _inputDecoration(hint: "Please specify purpose"),
              ),
            ],





            SizedBox(height: 120.h), // Spacing before footer

            // 5. Checkbox
            Row(
              children: [
                Checkbox(
                  value: _isConfirmed,
                  activeColor: const Color(0xFF5D7E97),
                  onChanged: (val) => setState(() => _isConfirmed = val!),
                ),
                Expanded(
                  child: Text(
                    "I confirm that the details I provided are true, accurate, and complete.",
                    style: TextStyle(fontSize: 11.sp, color: Colors.black54),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20.h),

            // 6. Submit Button
            Align(
              alignment: Alignment.bottomRight,
              child: ElevatedButton(
                onPressed: _handleSubmission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF233446), // Dark Navy
                  padding: EdgeInsets.symmetric(horizontal: 45.w, vertical: 12.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                ),
                child: Text("Submit", style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h, top: 15.h),
      child: Text(text, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.black87)),
    );
  }

  Widget _buildDropdown({
    required String hint, 
    String? value, 
    required List<String> items, 
    required Function(String?) onChanged
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        hint: Text(hint, style: TextStyle(fontSize: 13.sp, color: Colors.grey)),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 15.w),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide.none),
        ),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 13.sp)))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13.sp, color: Colors.grey),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 15.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}

// ----SUCCESS SCREEN ----

class SuccessfulScreen extends StatelessWidget {
  final PendingRequest request;

  const SuccessfulScreen({
    super.key,
    required this.request,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 120.r,
                width: 120.r,
                decoration: const BoxDecoration(
                  color: Color(0xFF9DB2BF),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 80.r,
                ),
              ),

              SizedBox(height: 30.h),

              CustomFont(
                text: "Request Submitted Successfully",
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),

              Text(
                "Your document request has been submitted and is now pending for processing. You can check the status of your request in the Pending section.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.sp, color: Colors.black54),
              ),


              SizedBox(height: 50.h),

              ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HomeScreen(
                        initialIndex: 1,
                        newRequest: request,                        
                      ),
                    ),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27374D),
                  fixedSize: Size(340.w, 50.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  elevation: 5,
                ),
                child: CustomFont(
                  text: "Proceed",
                  fontSize: 18.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}