import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/image_strings.dart';
import '../view_model/auth_viewmodel.dart';

class EmailLogin extends StatefulWidget {
  const EmailLogin({super.key});

  @override
  State<EmailLogin> createState() => _EmailLoginState();
}

class _EmailLoginState extends State<EmailLogin> {
  @override
  Widget build(BuildContext context) {

    final authVM = context.watch<AuthViewModel>();

    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 120),
                  
                  // Logo Circle
                  GestureDetector(
                    onTap: authVM.clearLocalStorage,
                    child: Center(
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[100],
                          border: Border.all(
                            color: Colors.green,
                            width: 4,
                          ),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.directions_bus,
                              size: 50,
                              color: ZColors.darkGrey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              "School Bus App",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E6BD6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Form section
                  Form(
                    key: authVM.formKey,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Input details to login",
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 20),
                  
                          // Email field
                          TextFormField(
                            controller: authVM.emailController,
                            decoration: InputDecoration(
                              hintText: "Email",
                              prefixIcon: const Icon(Icons.email_outlined),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 18, horizontal: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              // Basic email regex validation
                              final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
                              if (!emailRegex.hasMatch(value)) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                  
                          const SizedBox(height: 20),
                  
                          // Pin field
                          TextFormField(
                            controller: authVM.pinController,
                            obscureText: authVM.obscurePin,
                            decoration: InputDecoration(
                              hintText: "Pin",
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: GestureDetector(
                                onTap: authVM.togglePinVisibility,
                                child: Icon(authVM.obscurePin
                                      ? Icons.visibility
                                      : Icons.visibility_off),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 18, horizontal: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                  
                          const SizedBox(height: 30),
                  
                          // Login Button
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: authVM.isLoading
                                  ? null
                                  : () => authVM.loginWithEmail(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ZColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: authVM.isLoading
                              ? const SizedBox(
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: ZColors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text(
                                "Login",
                                style: TextStyle(
                                  color: ZColors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                  
                          const SizedBox(height: 80),
                  
                          // Footer
                          Center(
                            child: Column(
                              children: [
                                const Text(
                                  "From",
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                // Image.asset(LSTImages.limestoneLogo, height: 20)
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
