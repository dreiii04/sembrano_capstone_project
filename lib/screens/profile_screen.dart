import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic> _profile = {
    'firstName': 'Alyssa',
    'lastName': 'Cruz',
    'studentId': '2024-123346',
    'yearLevel': '2nd Year',
    'program': 'BSIT-MWA',
    'schoolEmail': 'alyssac@school.edu.ph',
    'personalEmail': 'alyssacruz1@email.com',
    'imagePath': '',
  };

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      await ApiService.init();
      final data = await ApiService.getCurrentUserProfile();
      if (!mounted) return;
      setState(() {
        _profile = {
          ..._profile,
          ...data,
        };
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickProfileImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    final updated = {
      ..._profile,
      'imagePath': picked.path,
    };

    await ApiService.updateCurrentUserProfile(profile: updated);
    if (!mounted) return;
    setState(() {
      _profile = updated;
    });
  }

  Future<void> _showEditProfileDialog() async {
    final firstNameController = TextEditingController(text: (_profile['firstName'] ?? '').toString());
    final lastNameController = TextEditingController(text: (_profile['lastName'] ?? '').toString());
    final studentIdController = TextEditingController(text: (_profile['studentId'] ?? '').toString());
    final yearLevelController = TextEditingController(text: (_profile['yearLevel'] ?? '').toString());
    final programController = TextEditingController(text: (_profile['program'] ?? '').toString());
    final schoolEmailController = TextEditingController(text: (_profile['schoolEmail'] ?? '').toString());
    final personalEmailController = TextEditingController(text: (_profile['personalEmail'] ?? '').toString());

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Profile Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField('First Name', firstNameController),
                _buildDialogField('Last Name', lastNameController),
                _buildDialogField('Student ID', studentIdController),
                _buildDialogField('Year Level', yearLevelController),
                _buildDialogField('Program', programController),
                _buildDialogField('School Email', schoolEmailController),
                _buildDialogField('Personal Email', personalEmailController),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updated = {
                  ..._profile,
                  'firstName': firstNameController.text.trim(),
                  'lastName': lastNameController.text.trim(),
                  'studentId': studentIdController.text.trim(),
                  'yearLevel': yearLevelController.text.trim(),
                  'program': programController.text.trim(),
                  'schoolEmail': schoolEmailController.text.trim(),
                  'personalEmail': personalEmailController.text.trim(),
                };

                await ApiService.updateCurrentUserProfile(profile: updated);
                if (!mounted) return;
                setState(() {
                  _profile = updated;
                });
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated.')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField('Current Password', currentController, obscure: true),
                _buildDialogField('New Password', newController, obscure: true),
                _buildDialogField('Confirm New Password', confirmController, obscure: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final current = currentController.text.trim();
                final next = newController.text.trim();
                final confirm = confirmController.text.trim();

                if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fill in all password fields.')),
                  );
                  return;
                }

                if (next.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New password must be at least 8 characters.')),
                  );
                  return;
                }

                if (next != confirm) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New passwords do not match.')),
                  );
                  return;
                }

                try {
                  await ApiService.changePassword(
                    currentPassword: current,
                    newPassword: next,
                  );
                  if (!mounted) return;
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password changed successfully.')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final deleteTextController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This action is permanent. Type DELETE to continue.'),
              SizedBox(height: 12.h),
              _buildDialogField('Type DELETE', deleteTextController),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () async {
                if (deleteTextController.text.trim().toUpperCase() != 'DELETE') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Type DELETE to confirm account deletion.')),
                  );
                  return;
                }

                await ApiService.deleteCurrentAccount();
                HomeScreen.globalRequests.clear();
                HomeScreen.globalHistory.clear();
                if (!mounted) return;
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                Navigator.pushNamedAndRemoveUntil(context, '/choose', (route) => false);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color headerBlue = Color(0xFF5D7E97);
    const Color darkNavy = Color(0xFF233446);

    final imagePath = (_profile['imagePath'] ?? '').toString();
    final hasImage = imagePath.isNotEmpty && File(imagePath).existsSync();
    final fullName = '${(_profile['firstName'] ?? '').toString()} ${(_profile['lastName'] ?? '').toString()}'.trim();

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            // Top Section: Header and Avatar
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 160.h,
                  width: double.infinity,
                  color: headerBlue,
                  padding: EdgeInsets.only(left: 20.w, top: 50.h),
                  child: Text(
                    "Profile",
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: 32.sp, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
                Positioned(
                  bottom: -50.h,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white, 
                      shape: BoxShape.circle
                    ),
                    padding: EdgeInsets.all(5.r),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 55.r,
                          backgroundColor: headerBlue,
                          backgroundImage: hasImage ? FileImage(File(imagePath)) : null,
                          child: !hasImage
                              ? Icon(Icons.person, size: 80.r, color: Colors.black)
                              : null,
                        ),
                        Positioned(
                          right: -4.w,
                          bottom: -2.h,
                          child: GestureDetector(
                            onTap: _pickProfileImage,
                            child: Container(
                              padding: EdgeInsets.all(8.r),
                              decoration: BoxDecoration(
                                color: darkNavy,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Icon(Icons.camera_alt, color: Colors.white, size: 16.sp),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 70.h),

            // Basic Information Card (View Only)
            Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: 20.w),
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15.r),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Basic Information",
                    style: TextStyle(
                      fontSize: 18.sp, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  SizedBox(height: 20.h),
                  _buildInfoRow("Name:", fullName.isEmpty ? 'N/A' : fullName),
                  _buildInfoRow("Student ID:", (_profile['studentId'] ?? 'N/A').toString()),
                  _buildInfoRow("Year level:", (_profile['yearLevel'] ?? 'N/A').toString()),
                  _buildInfoRow("Program:", (_profile['program'] ?? 'N/A').toString()),
                  _buildInfoRow("School Email:", (_profile['schoolEmail'] ?? 'N/A').toString()),
                  _buildInfoRow("Personal Email:", (_profile['personalEmail'] ?? 'N/A').toString()),
                ],
              ),
            ),

            SizedBox(height: 30.h),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                children: [
                  _buildActionButton(
                    title: 'Edit Profile Details',
                    color: darkNavy,
                    onTap: _showEditProfileDialog,
                  ),
                  SizedBox(height: 12.h),
                  _buildActionButton(
                    title: 'Change Password',
                    color: darkNavy,
                    onTap: _showChangePasswordDialog,
                  ),
                  SizedBox(height: 12.h),
                  _buildActionButton(
                    title: 'Delete Account',
                    color: Colors.red.shade700,
                    onTap: _confirmDeleteAccount,
                  ),
                ],
              ),
            ),

            SizedBox(height: 26.h),

            // Log out Button
            ElevatedButton(
              onPressed: () async {
                await ApiService.clearToken();
                HomeScreen.globalRequests.clear();
                HomeScreen.globalHistory.clear();
                if (!context.mounted) return;

                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/choose',
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: darkNavy,
                fixedSize: Size(180.w, 45.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.r)
                ),
              ),
              child: Text(
                "Log out",
                style: TextStyle(color: Colors.white, fontSize: 20.sp),
              ),
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.symmetric(vertical: 12.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        ),
        child: Text(
          title,
          style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildDialogField(String label, TextEditingController controller, {bool obscure = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  // Helper to build the row labels and values
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100.w,
            child: Text(
              label,
              style: TextStyle(fontSize: 13.sp, color: Colors.black87),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.sp, 
                color: Colors.black, 
                fontWeight: FontWeight.w500
              ),
            ),
          ),
        ],
      ),
    );
  }
}