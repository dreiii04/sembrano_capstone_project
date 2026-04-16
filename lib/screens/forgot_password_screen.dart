import 'dart:async';

import 'package:capstone_project/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../widgets/custom_textformfield.dart';
import '../constants.dart';
import '../widgets/custom_font.dart';
import 'package:flutter/gestures.dart';
import '../widgets/custom_inkwell_button.dart';
import '../services/api_service.dart';

class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key});

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  final TextEditingController _emailController = TextEditingController();

  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  bool get _canResend => !_isSendingOtp && _resendSeconds == 0;

  String get _otp => _otpControllers.map((controller) => controller.text).join();

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email);
  }

  void _showValidationError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() {
      _resendSeconds = 30;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() {
          _resendSeconds = 0;
        });
      } else {
        setState(() {
          _resendSeconds--;
        });
      }
    });
  }

  Future<void> _requestOtp({bool resend = false}) async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showValidationError('Email is required.');
      return;
    }

    if (!_isValidEmail(email)) {
      _showValidationError('Please enter a valid email address.');
      return;
    }

    setState(() {
      _isSendingOtp = true;
    });

    try {
      await ApiService.requestPasswordResetOtp(email: email);
      if (!mounted) return;
      _startResendCooldown();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resend
                ? 'OTP resent to your email.'
                : 'OTP sent to your email.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOtp = false;
        });
      }
    }
  }

  Future<void> _verifyOTPEmail() async {
    final email = _emailController.text.trim();
    final otp = _otp;

    if (email.isEmpty) {
      _showValidationError('Email is required.');
      return;
    }

    if (!_isValidEmail(email)) {
      _showValidationError('Please enter a valid email address.');
      return;
    }

    if (otp.length != 6 || !RegExp(r'^\d{6}$').hasMatch(otp)) {
      _showValidationError('Please enter a valid 6-digit OTP.');
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
    });

    try {
      await ApiService.verifyPasswordResetOtp(email: email, otp: otp);
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResetPasswordScreen(email: email, otp: otp),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(top: 40.h),
                child: Image.asset(
                  'assets/logo/logo.png',
                  height: 80.h,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.image, size: 50.h),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: FB_PRIMARY,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30.r),
                  topRight: Radius.circular(30.r),
                ),
              ),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 30.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CustomFont(
                      text: 'Forgot Password',
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      'Enter your registered email to receive One-Time Password (OTP)',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(height: 25.h),
                    CustomTextFormField(
                      height: ScreenUtil().setHeight(10),
                      width: ScreenUtil().setWidth(10),
                      controller: _emailController,
                      hintText: 'Email',
                      fontSize: 14.sp,
                      hintTextSize: 14.sp,
                      fontColor: FB_DARK_PRIMARY,
                      bgColor: Colors.white,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isSendingOtp ? null : () => _requestOtp(),
                        child: Text(
                          _isSendingOtp ? 'Sending...' : 'Verify email',
                          style: TextStyle(
                            color: FB_BACKGROUND_LIGHT,
                            fontSize: 12.sp,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: CustomFont(
                        text: 'Enter OTP',
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: FB_TEXT_COLOR_WHITE,
                      ),
                    ),
                    SizedBox(height: 15.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) => _otpBox(index)),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _canResend
                            ? () => _requestOtp(resend: true)
                            : null,
                        child: Text(
                          _isSendingOtp
                              ? 'Resending...'
                              : _resendSeconds > 0
                                  ? 'Resend in ${_resendSeconds}s'
                                  : 'Resend code',
                          style: TextStyle(
                            color: FB_BACKGROUND_LIGHT,
                            fontSize: 12.sp,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 25.h),
                    CustomInkwellButton(
                      onTap: _isVerifyingOtp ? null : _verifyOTPEmail,
                      height: 55.h,
                      width: double.infinity,
                      buttonName: _isVerifyingOtp ? 'Verifying...' : 'Verify',
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      bgColor: _isVerifyingOtp ? FB_PRIMARY : FB_DARK_PRIMARY,
                      fontColor: Colors.white,
                    ),
                    SizedBox(height: 10.h),
                    Center(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Back to ',
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _otpBox(int index) {
    return Container(
      width: 40.w,
      height: 45.h,
      decoration: BoxDecoration(
        color: FB_TEXT_COLOR_WHITE,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        style: TextStyle(
          fontSize: 20.sp,
          fontWeight: FontWeight.bold,
          color: FB_DARK_PRIMARY,
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < _otpControllers.length - 1) {
            FocusScope.of(context).nextFocus();
          }

          if (value.isEmpty && index > 0) {
            FocusScope.of(context).previousFocus();
          }
        },
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.email, required this.otp});

  final String email;
  final String otp;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _conPassController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  void _showValidationError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleResetPassword() async {
    final newPass = _newPassController.text.trim();
    final conPass = _conPassController.text.trim();

    final complexityRegex = RegExp(
      r'^(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9])(?=.*[!@#\$%^&*(),.?":{}|<>]).*$',
    );

    if (newPass.isEmpty || conPass.isEmpty) {
      _showValidationError('Please fill in both password fields.');
      return;
    }

    if (newPass.length < 8) {
      _showValidationError('Password must be at least 8 characters long.');
      return;
    }

    if (!complexityRegex.hasMatch(newPass)) {
      _showValidationError(
        'Password must include uppercase, lowercase, number, and special character.',
      );
      return;
    }

    if (newPass != conPass) {
      _showValidationError('Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.resetPasswordWithOtp(
        email: widget.email,
        otp: widget.otp,
        newPassword: newPass,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LogInScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
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
    _newPassController.dispose();
    _conPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(top: 40.h),
                child: Image.asset(
                  'assets/logo/logo.png',
                  height: 120.h,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.image, size: 50.h),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
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
                  padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 30.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomFont(
                        text: 'Reset Password',
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      SizedBox(height: 25.h),
                      CustomTextFormField(
                        height: ScreenUtil().setHeight(10),
                        width: ScreenUtil().setWidth(10),
                        controller: _newPassController,
                        isObscure: !_isPasswordVisible,
                        hintText: 'New Password',
                        fontSize: 14.sp,
                        hintTextSize: 14.sp,
                        fontColor: FB_DARK_PRIMARY,
                        bgColor: Colors.white,
                        suffixIcon: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: FB_DARK_PRIMARY,
                            size: 20.sp,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 20.h),
                      CustomTextFormField(
                        height: ScreenUtil().setHeight(10),
                        width: ScreenUtil().setWidth(10),
                        controller: _conPassController,
                        isObscure: !_isPasswordVisible,
                        hintText: 'Confirm Password',
                        fontSize: 14.sp,
                        hintTextSize: 14.sp,
                        fontColor: FB_DARK_PRIMARY,
                        bgColor: Colors.white,
                        suffixIcon: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: FB_DARK_PRIMARY,
                            size: 20.sp,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 30.h),
                      CustomInkwellButton(
                        onTap: _isLoading ? null : _handleResetPassword,
                        height: 55.h,
                        width: double.infinity,
                        buttonName: _isLoading ? 'Resetting...' : 'Reset Password',
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        bgColor: _isLoading ? FB_PRIMARY : FB_DARK_PRIMARY,
                        fontColor: Colors.white,
                      ),
                      SizedBox(height: 20.h),
                      Center(
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Back to ',
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
                                  ..onTap = () => Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const LogInScreen(),
                                        ),
                                        (route) => false,
                                      ),
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
        ],
      ),
    );
  }
}
