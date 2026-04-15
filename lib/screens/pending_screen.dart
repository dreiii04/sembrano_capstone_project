import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../widgets/custom_font.dart';
import '../screens/request_detail_screen.dart';
import '../services/api_service.dart';

class PendingRequest {
  final String docName;
  final String purpose;
  final DateTime dateCreated;
  final String status; // e.g., "PENDING", "APPROVED", "RELEASED"
  final String? id; // Add ID for API reference

  PendingRequest({
    required this.docName,
    required this.purpose,
    required this.dateCreated,
    required this.status,
    this.id,
  });
}

class PendingScreen extends StatefulWidget {
  final List<PendingRequest> requestList;

  const PendingScreen({super.key, required this.requestList});

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  String _selectedFilter = "All";
  List<PendingRequest> _apiRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    try {
      final requests = await ApiService.getRequests();
      setState(() {
        _apiRequests = requests.map((req) {
          return PendingRequest(
            docName: req['documentType'] ?? req['subDocumentType'] ?? 'Unknown',
            purpose: req['purpose'] ?? req['otherPurpose'] ?? 'Unknown',
            dateCreated: DateTime.tryParse(req['createdAt'] ?? '') ?? DateTime.now(),
            status: req['status'] ?? 'Pending',
            id: req['_id'],
          );
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // If API fails, use the passed requestList as fallback
      _apiRequests = widget.requestList;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Combine API requests with local requests
    List<PendingRequest> allRequests = [..._apiRequests, ...widget.requestList];

    // 1. Logic to get unique doc names from the list for the filter
    List<String> filters = ["All"];
    filters.addAll(allRequests.map((e) => e.docName).toSet().toList());

    // 2. Filter the list based on selection
    List<PendingRequest> filteredList = _selectedFilter == "All"
        ? allRequests
        : allRequests.where((r) => r.docName == _selectedFilter).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          Container(height: 70.h, width: double.infinity, color: const Color(0xFF5D7E97)),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Pending", style: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.bold)),
                      if (!_isLoading)
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _fetchRequests,
                        ),
                    ],
                  ),

                  // Filter Dropdown
                  if (!_isLoading && allRequests.isNotEmpty)
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 10.h),
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedFilter,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: filters.map((String value) {
                          return DropdownMenuItem<String>(value: value, child: Text(value));
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() => _selectedFilter = newValue!);
                        },
                      ),
                    ),

                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : filteredList.isNotEmpty
                            ? ListView.builder(
                                itemCount: filteredList.length,
                                itemBuilder: (context, index) {
                                  final item = filteredList[index];
                                  return InkWell(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => RequestDetailsScreen(request: item)),
                                    ),
                                    child: _buildCard(item),
                                  );
                                },
                              )
                            : _buildEmptyState(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }




 Widget _buildCard(PendingRequest item) {
    return Container(
      margin: EdgeInsets.only(bottom: 15.h),
      padding: EdgeInsets.all(15.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.docName, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),

              SizedBox(height: 10.h),

              Text(DateFormat('MMM d, y  h:mm a').format(item.dateCreated), 
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
            ],
          ),

          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: _getStatusColor(item.status).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(item.status, 
                style: TextStyle(color: _getStatusColor(item.status), fontSize: 10.sp, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case "RELEASED": return Colors.orange;
      case "PROCESSING": return Colors.green;
      case "APPROVED": return Colors.blue;
      default: return Colors.yellow.shade700;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_edu, size: 80.r, color: Colors.grey.shade300),
          SizedBox(height: 16.h),
          CustomFont(
            text: "No pending requests found.",
            fontSize: 16.sp,
            color: Colors.grey.shade500,
          ),
        ],
      ),
    );
  }
}
 