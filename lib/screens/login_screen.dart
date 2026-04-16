import 'package:capstone_project/screens/forgot_password_screen.dart';
import '../screens/home_screen.dart';
import '../widgets/custom_textformfield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants.dart';
import '../widgets/custom_inkwell_button.dart';
import '../widgets/custom_font.dart';
import 'package:flutter/gestures.dart';
import '../services/api_service.dart';

class LogInScreen extends StatefulWidget {
  const LogInScreen({super.key, this.role = 'alumni'});

  final String role;

  @override
  State<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen> {
  static const String _testStudentEmail = 'student.test@verifitor.test';
  static const String _testStudentPassword = 'Test@1234';

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  bool get _showSignUp => widget.role.toLowerCase() != 'student';

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email);
  }

  void _fillTestStudentCredentials() {
    setState(() {
      emailController.text = _testStudentEmail;
      passwordController.text = _testStudentPassword;
    });
  }

  @override
  void initState() {
    super.initState();
    // Initialize API service
    ApiService.init();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
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
                  height: 80.h,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.image, size: 50.h),
                ),
              ),
            ),
          ),

          // Bottom Section: Login Form
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
                  padding:
                      EdgeInsets.symmetric(horizontal: 30.w, vertical: 30.h),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        CustomFont(
                          text: 'Login to your Account',
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _fillTestStudentCredentials,
                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                            child: Text(
                              'Use Test Student Login',
                              style: TextStyle(
                                color: FB_BACKGROUND_LIGHT,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 30.h),

                        // Email
                        CustomTextFormField(
                          height: ScreenUtil().setHeight(10),
                          width: ScreenUtil().setWidth(10),
                          controller: emailController,
                          hintText: 'Email',
                          bgColor: FB_TEXT_COLOR_WHITE,
                          fontSize: 14.sp,
                          hintTextSize: 14.sp,
                          fontColor: FB_DARK_PRIMARY,
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) {
                              return 'Enter email';
                            }
                            if (!_isValidEmail(email)) {
                              return 'Enter valid email';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20.h),

                        // Password
                        CustomTextFormField(
                          height: ScreenUtil().setHeight(10),
                          width: ScreenUtil().setWidth(10),
                  
                          controller: passwordController,
                          isObscure: !_isPasswordVisible,
                          hintText: 'Password',
                          bgColor: FB_TEXT_COLOR_WHITE,
                          fontSize: 14.sp,
                          hintTextSize: 14.sp,
                          fontColor: FB_DARK_PRIMARY,
                          validator: (value) {
                            final password = value?.trim() ?? '';
                            if (password.isEmpty) {
                              return 'Enter password';
                            }
                            if (password.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            return null;
                          },
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

                        // Forgot Password
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const PasswordScreen()),
                              );
                            },
                            style:
                                TextButton.styleFrom(padding: EdgeInsets.zero),
                            child: Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: FB_BACKGROUND_LIGHT,
                                fontSize: 12.sp,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 15.h),

                        // LOGIN BUTTON
                        CustomInkwellButton(
                          onTap: () async {
                            if (!_formKey.currentState!.validate()) return;

                            final email = emailController.text.trim();
                            final password = passwordController.text.trim();

                            setState(() {
                              _isLoading = true;
                            });

                            try {
                              await ApiService.login(
                                email: email,
                                password: password,
                              );

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Login successful!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const HomeScreen(),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(e.toString().replaceAll('Exception: ', '')),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            }
                          },
                          height: 55.h,
                          width: ScreenUtil().screenWidth,
                          buttonName: _isLoading ? 'Logging in...' : 'Login',
                          fontColor: FB_TEXT_COLOR_WHITE,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          bgColor: _isLoading ? FB_PRIMARY : FB_DARK_PRIMARY,
                        ),

                        SizedBox(height: 25.h),

                        // Footer
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_showSignUp) ...[
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: "Don't have an account? ",
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Sign up',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.sp,
                                        color: FB_BACKGROUND_LIGHT,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () => Navigator.pushNamed(
                                            context, '/register'),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 15.h),
                            ],
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: "Are you an Alumni or Student? ",
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Choose Here',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.sp,
                                      color: FB_BACKGROUND_LIGHT,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => Navigator.pushNamed(
                                          context, '/choose'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
