import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../widgets/custom_font.dart';
import '../screens/history_detail_screen.dart';
import '../services/api_service.dart';

class HistoryItem {
  final String title;
  final DateTime date;
  final String purpose; // New
  final String status;  // e.g., "Released", "Rejected"
  final bool isApproved;
  final String? id; // Add ID for API reference

  HistoryItem({
    required this.title,
    required this.date,
    required this.purpose,
    required this.status,
    required this.isApproved,
    this.id,
  });
}

class HistoryScreen extends StatefulWidget {
  final List<HistoryItem> historyList;
  const HistoryScreen({super.key, required this.historyList});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedFilter = "All";
  List<HistoryItem> _apiHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  List<HistoryItem> _dedupeHistory(List<HistoryItem> items) {
    final unique = <String, HistoryItem>{};
    for (final item in items) {
      final key = (item.id != null && item.id!.isNotEmpty)
          ? 'id:${item.id}'
          : 'fallback:${item.title}|${item.purpose}|${item.status}|${item.date.toIso8601String()}';
      unique[key] = item;
    }
    return unique.values.toList();
  }

  Future<void> _fetchHistory() async {
    try {
      final requests = await ApiService.getRequests();
      setState(() {
        _apiHistory = requests
            .where((req) {
              final status = (req['status'] ?? '').toString().toLowerCase();
              const nonHistoryStatuses = {
                'pending',
                'pending payment',
                'pending approval',
                'processing',
              };
              return !nonHistoryStatuses.contains(status);
            })
            .map((req) {
          return HistoryItem(
            title: req['documentType'] ?? req['subDocumentType'] ?? 'Unknown',
            date: DateTime.tryParse(req['createdAt'] ?? '') ?? DateTime.now(),
            purpose: req['purpose'] ?? req['otherPurpose'] ?? 'Unknown',
            status: req['status'] ?? 'Unknown',
            isApproved: req['status'] == 'Completed' || req['status'] == 'Released',
            id: req['_id'],
          );
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // If API fails, use the passed historyList as fallback
      _apiHistory = widget.historyList;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Combine API history with local history
    final localNonPending = widget.historyList
        .where((item) => item.status.toLowerCase() != 'pending')
        .toList();
    List<HistoryItem> allHistory = _dedupeHistory([..._apiHistory, ...localNonPending]);

    // Filter Logic
    List<String> filters = ["All"];
    filters.addAll(allHistory.map((e) => e.title).toSet().toList());

    List<HistoryItem> filteredList = _selectedFilter == "All"
        ? allHistory
        : allHistory.where((h) => h.title == _selectedFilter).toList();

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
                      CustomFont(text: "History", fontSize: 40.sp, fontWeight: FontWeight.bold, color: Colors.black),
                      if (!_isLoading)
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _fetchHistory,
                        ),
                    ],
                  ),

                  // Filter Dropdown
                  if (!_isLoading && allHistory.isNotEmpty)
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
                        items: filters.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                        onChanged: (val) => setState(() => _selectedFilter = val!),
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
                                      MaterialPageRoute(builder: (context) => HistoryDetailScreen(item: item)),
                                    ),
                                    child: _buildHistoryCard(item),
                                  );
                                },
                              )
                            : const Center(child: Text("No history found")),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(HistoryItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: 15.h),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomFont(text: item.title, fontSize: 18.sp, fontWeight: FontWeight.bold, color: const Color(0xFF233446)),
          CustomFont(text: DateFormat('MMMM d, y').format(item.date), fontSize: 13.sp, color: Colors.black54),
          SizedBox(height: 15.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F5),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.isApproved ? Icons.check_circle : Icons.cancel, 
                     size: 14.sp, color: item.isApproved ? Colors.green : Colors.red),
                SizedBox(width: 8.w),
                CustomFont(text: item.status, fontSize: 12.sp, fontWeight: FontWeight.w600, color: item.isApproved ? Colors.green : Colors.red),
              ],
            ),
          )
        ],
      ),
    );
  }
}