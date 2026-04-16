import '../constants.dart';
import '../widgets/custom_font.dart';
import '../widgets/custom_inkwell_button.dart';
import '../widgets/custom_textformfield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/gestures.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  static const String _testStudentEmail = 'student.test@verifitor.test';
  static const String _testStudentPassword = 'Test@1234';

  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController dateOfBirthController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController schoolEmailController = TextEditingController();
  TextEditingController studentIdController = TextEditingController();
  TextEditingController yearLevelController = TextEditingController();
  TextEditingController programController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();
  TextEditingController otpController = TextEditingController();

  bool _isPasswordObscure = true;
  bool _isConfirmPasswordObscure = true;
  bool _isLoading = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _hasAcceptedTerms = false;
  String _selectedRole = 'student';
  String? _verifiedEmail;

  bool get _isEmailVerified {
    final currentEmail = emailController.text.trim().toLowerCase();
    return _verifiedEmail != null && _verifiedEmail == currentEmail;
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email);
  }

  int _passwordStrengthScore(String password) {
    int score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) score++;
    return score;
  }

  String _passwordStrengthText(String password) {
    final score = _passwordStrengthScore(password);
    if (password.isEmpty) return 'Password strength: -';
    if (score <= 2) return 'Password strength: Weak';
    if (score == 3 || score == 4) return 'Password strength: Medium';
    return 'Password strength: Strong';
  }

  Color _passwordStrengthColor(String password) {
    final score = _passwordStrengthScore(password);
    if (password.isEmpty) return Colors.white70;
    if (score <= 2) return Colors.red.shade300;
    if (score == 3 || score == 4) return Colors.orange.shade300;
    return Colors.green.shade300;
  }

  void _showValidationAlert(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
          title: Text("Notice",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp)),
          content: Text(message, style: TextStyle(fontSize: 14.sp)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK",
                  style: TextStyle(
                      color: Color(0xFF233446), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendSignupOtp() async {
    final email = emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      _showValidationAlert('Email is required before OTP can be sent.');
      return;
    }

    if (!_isValidEmail(email)) {
      _showValidationAlert('Enter a valid email address.');
      return;
    }

    setState(() {
      _isSendingOtp = true;
    });

    try {
      bool isDeliverable = true;

      // Optional check; if backend validation endpoint is unavailable, continue with OTP flow.
      try {
        isDeliverable = await ApiService.validateEmailWithMailboxLayer(email: email);
      } catch (_) {
        isDeliverable = true;
      }

      if (!isDeliverable) {
        if (mounted) {
          _showValidationAlert('This email appears invalid or undeliverable.');
        }
        return;
      }

      await ApiService.requestSignupOtp(email: email);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP sent to your email.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showValidationAlert(
        'Unable to send OTP: ${e.toString().replaceAll('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOtp = false;
        });
      }
    }
  }

  Future<void> _verifySignupOtp() async {
    final email = emailController.text.trim().toLowerCase();
    final otp = otpController.text.trim();

    if (email.isEmpty || !_isValidEmail(email)) {
      _showValidationAlert('Enter a valid email first.');
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      _showValidationAlert('Enter the 6-digit OTP sent to your email.');
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
    });

    try {
      await ApiService.verifySignupOtp(email: email, otp: otp);
      if (!mounted) return;

      setState(() {
        _verifiedEmail = email;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email verified successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showValidationAlert(
        'OTP verification failed: ${e.toString().replaceAll('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
        });
      }
    }
  }

  void _fillTestStudentData() {
    firstNameController.text = 'Test';
    lastNameController.text = 'Student';
    dateOfBirthController.text = '2001-01-01';
    emailController.text = _testStudentEmail;
    schoolEmailController.text = _testStudentEmail;
    studentIdController.text = 'TEST-2026-001';
    yearLevelController.text = '4';
    programController.text = 'BS Information Technology';
    passwordController.text = _testStudentPassword;
    confirmPasswordController.text = _testStudentPassword;
    otpController.text = '123456';

    setState(() {
      _selectedRole = 'student';
      _hasAcceptedTerms = true;
      _verifiedEmail = _testStudentEmail;
    });
  }

  void _handleRegister() async {
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final email = emailController.text.trim();
    final pass = passwordController.text.trim();
    final confirm = confirmPasswordController.text.trim();

    final complexityRegex = RegExp(
        r'^(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9])(?=.*[!@#\$%^&*(),.?":{}|<>]).*$');

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || pass.isEmpty || confirm.isEmpty) {
      _showValidationAlert("All required fields must be filled.");
      return;
    }

    if (pass.length < 8) {
      _showValidationAlert("Password must be at least 8 characters long.");
      return;
    }

    if (!complexityRegex.hasMatch(pass)) {
      _showValidationAlert(
          "Password must include an uppercase, lowercase, number, and special character.");
      return;
    }

    if (pass != confirm) {
      _showValidationAlert("The passwords you entered do not match.");
      return;
    }

    if (!_isEmailVerified) {
      _showValidationAlert('Please verify your email OTP before creating an account.');
      return;
    }

    if (!_hasAcceptedTerms) {
      _showValidationAlert('You must accept the Terms and Conditions.');
      return;
    }

    // Show loading
    setState(() {
      _isLoading = true;
    });

    try {
      // Call API to register
      await ApiService.register(
        email: email,
        password: pass,
        firstName: firstName,
        lastName: lastName,
        role: _selectedRole,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account created successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showValidationAlert("Registration failed: ${e.toString().replaceAll('Exception: ', '')}");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    dateOfBirthController.dispose();
    emailController.dispose();
    schoolEmailController.dispose();
    studentIdController.dispose();
    yearLevelController.dispose();
    programController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Top Section: Logo
          Expanded(
            flex: 2,
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(top: 40.h),
                child: Image.asset(
                  'assets/logo/logo.png',
                  height: 50.h,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.image, size: 10.h),
                ),
              ),
            ),
          ),

          // Bottom Section: Registration Form
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: FB_PRIMARY,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30.r),
                  topRight: Radius.circular(30.r),
                ),
              ),
              child: SingleChildScrollView(
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 25.w, vertical: 30.h),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        CustomFont(
                          text: 'Create an Account',
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _fillTestStudentData,
                            child: Text(
                              'Use Test Student Account',
                              style: TextStyle(
                                color: FB_BACKGROUND_LIGHT,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 25.h),

                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedRole,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                            dropdownColor: Colors.white,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: FB_DARK_PRIMARY,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'student',
                                child: Text('Student'),
                              ),
                              DropdownMenuItem(
                                value: 'alumni',
                                child: Text('Alumni'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedRole = value;
                              });
                            },
                          ),
                        ),
                        SizedBox(height: 15.h),

                        // First Name
                        CustomTextFormField(
                          height: ScreenUtil().setHeight(10),
                          width: ScreenUtil().setWidth(10),
                          controller: firstNameController,
                          hintText: 'First Name',
                          fontSize: 14.sp,
                          hintTextSize: 14.sp,
                          fontColor: FB_DARK_PRIMARY,
                          bgColor: Colors.white,
                        ),
                        SizedBox(height: 15.h),

                        // Last Name
                        CustomTextFormField(
                          height: ScreenUtil().setHeight(10),
                          width: ScreenUtil().setWidth(10),
                          controller: lastNameController,
                          hintText: 'Last Name',
                          fontSize: 14.sp,
                          hintTextSize: 14.sp,
                          fontColor: FB_DARK_PRIMARY,
                          bgColor: Colors.white,
                        ),
                        SizedBox(height: 15.h),

                        // Date of Birth
                        CustomTextFormField(
                          height: ScreenUtil().setHeight(10),
                          width: ScreenUtil().setWidth(10),
                          controller: dateOfBirthController,
                          hintText: 'Date of Birth',
                          fontSize: 14.sp,
                          hintTextSize: 14.sp,
                          fontColor: FB_DARK_PRIMARY,
                          bgColor: Colors.white,
                        ),
                        SizedBox(height: 15.h),

                        // Email
                        CustomTextFormField(
                          height: ScreenUtil().setHeight(10),
                          width: ScreenUtil().setWidth(10),
                          controller: emailController,
                          hintText: 'Email',
                          fontSize: 14.sp,
                          hintTextSize: 14.sp,
                          fontColor: FB_DARK_PRIMARY,
                          bgColor: Colors.white,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter email';
                            }
                            if (!_isValidEmail(value.trim())) {
                              return 'Enter valid email';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 10.h),

                        Row(
                          children: [
                            Expanded(
                              child: CustomTextFormField(
                                height: ScreenUtil().setHeight(10),
                                width: ScreenUtil().setWidth(10),
                                controller: otpController,
                                hintText: 'Email OTP (6 digits)',
                                fontSize: 14.sp,
                                hintTextSize: 14.sp,
                                fontColor: FB_DARK_PRIMARY,
                                bgColor: Colors.white,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            TextButton(
                              onPressed: _isSendingOtp ? null : _sendSignupOtp,
                              child: Text(
                                _isSendingOtp ? 'Sending...' : 'Send OTP',
                                style: TextStyle(
                                  color: FB_BACKGROUND_LIGHT,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed:
                                _isVerifyingOtp ? null : _verifySignupOtp,
                            child: Text(
                              _isVerifyingOtp
                                  ? 'Verifying...'
                                  : _isEmailVerified
                                      ? 'Verified'
                                      : 'Verify OTP',
                              style: TextStyle(
                                color: _isEmailVerified
                                    ? Colors.green.shade200
                                    : FB_BACKGROUND_LIGHT,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 15.h),

                        // School Email
                        CustomTextFormField(
                          height: ScreenUtil().setHeight(10),
                          width: ScreenUtil().setWidth(10),
                          controller: schoolEmailController,
                          hintText: 'School Email',
                          fontSize: 14.sp,
                          hintTextSize: 14.sp,
                          fontColor: FB_DARK_PRIMARY,
                          bgColor: Colors.white,
                        ),
                        SizedBox(height: 15.h),

                        // Student ID
                        CustomTextFormField(
                          height: ScreenUtil().setHeight(10),
                          width: ScreenUtil().setWidth(10),
                          controller: studentIdController,
                          hintText: 'Student ID',
                          fontSize: 14.sp,
                          hintTextSize: 14.sp,
                          fontColor: FB_DARK_PRIMARY,
                          bgColor: Colors.white,
                        ),
                        SizedBox(height: 15.h),

                        // Year Level
                        CustomTextFormField(
                          height: ScreenUtil().setHeight(10),
                          width: ScreenUtil().setWidth(10),
                          controller: yearLevelController,
                          hintText: 'Year Level',
                          fontSize: 14.sp,
                          hintTextSize: 14.sp,
                          fontColor: FB_DARK_PRIMARY,
                          bgColor: Colors.white,
                        ),
                        SizedBox(height: 15.h),

                        // Program
                        CustomTextFormField(
                          height: ScreenUtil().setHeight(10),
                          width: ScreenUtil().setWidth(10),
                          controller: programController,
                          hintText: 'Program',
                          fontSize: 14.sp,
                          hintTextSize: 14.sp,
                          fontColor: FB_DARK_PRIMARY,
                          bgColor: Colors.white,
                        ),
                        SizedBox(height: 15.h),

                        // Confirm Password
                        CustomTextFormField(
                          height: ScreenUtil().setHeight(10),
                          width: ScreenUtil().setWidth(10),
                          controller: confirmPasswordController,
                          isObscure: _isConfirmPasswordObscure,
                          hintText: 'Confirm Password',
                          fontSize: 14.sp,
                          hintTextSize: 14.sp,
                          fontColor: FB_DARK_PRIMARY,
                          bgColor: Colors.white,
                          suffixIcon: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              _isConfirmPasswordObscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: FB_DARK_PRIMARY,
                              size: 20.sp,
                            ),
                            onPressed: () {
                              setState(() {
                                _isConfirmPasswordObscure =
                                    !_isConfirmPasswordObscure;
                              });
                            },
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Enter confirm password'
                              : null,
                        ),
                        SizedBox(height: 15.h),

                        // Password
                        CustomTextFormField(
                          height: ScreenUtil().setHeight(10),
                          width: ScreenUtil().setWidth(10),
                          controller: passwordController,
                          isObscure: _isPasswordObscure,
                          hintText: 'Password',
                          fontSize: 14.sp,
                          hintTextSize: 14.sp,
                          fontColor: FB_DARK_PRIMARY,
                          bgColor: Colors.white,
                          suffixIcon: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              _isPasswordObscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: FB_DARK_PRIMARY,
                              size: 20.sp,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordObscure = !_isPasswordObscure;
                              });
                            },
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Enter password'
                              : null,
                        ),
                        SizedBox(height: 6.h),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: passwordController,
                          builder: (context, value, _) {
                            final password = value.text;
                            return Text(
                              _passwordStrengthText(password),
                              style: TextStyle(
                                color: _passwordStrengthColor(password),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 25.h),

                        Row(
                          children: [
                            Checkbox(
                              value: _hasAcceptedTerms,
                              activeColor: FB_DARK_PRIMARY,
                              onChanged: (value) {
                                setState(() {
                                  _hasAcceptedTerms = value ?? false;
                                });
                              },
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _hasAcceptedTerms = !_hasAcceptedTerms;
                                  });
                                },
                                child: Text(
                                  'I accept the Terms and Conditions.',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),

                        // Register Button
                        CustomInkwellButton(
                          onTap: _isLoading ? null : _handleRegister,
                          height: 55.h,
                          width: double.infinity,
                          buttonName: _isLoading ? 'Registering...' : 'Register',
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          bgColor: _isLoading ? FB_PRIMARY : FB_DARK_PRIMARY,
                          fontColor: Colors.white,
                        ),
                        SizedBox(height: 20.h),

                        // Login Link
                        Center(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Already have an account? ',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: Colors.white70,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Login',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.sp,
                                    color: FB_BACKGROUND_LIGHT,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 20.h),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
