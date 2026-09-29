import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:safestep/home_screen.dart';
import 'package:safestep/views/auth/user_details_form_screen.dart';
import '../../services/otp_service.dart';
import '../../services/local_session.dart';


class PhoneAuthScreen extends StatefulWidget {
  final VoidCallback? onAuthSuccess;
  const PhoneAuthScreen({super.key, this.onAuthSuccess});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _loading = false;
  bool _otpSent = false;
  String? _otpReference;
  String? _error;

  String _formatPhoneNumber(String phone) {
    // Remove all non-digit characters
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Handle Indian mobile numbers (10 digits starting with 6, 7, 8, or 9)
    if (digits.length == 10 && (digits.startsWith('6') || digits.startsWith('7') || digits.startsWith('8') || digits.startsWith('9'))) {
      return '+91$digits';
    } else if (digits.length == 12 && digits.startsWith('91')) {
      return '+$digits';
    }
    
    // Handle Sri Lankan mobile numbers
    if (digits.length == 9 && digits.startsWith('7')) {
      return '+94$digits';
    } else if (digits.length == 12 && digits.startsWith('947')) {
      return '+$digits';
    } else if (digits.length == 10 && digits.startsWith('0') && digits[1] == '7') {
      return '+94${digits.substring(1)}';
    }
    
    if (phone.startsWith('+')) return phone;
    return digits.isNotEmpty ? '+$digits' : phone;
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    
    try {
      final phoneNumber = _formatPhoneNumber(_phoneController.text.trim());
      
      // Use custom backend OTP service
      final otpResponse = await OTPService.requestOTP(
        phoneNumber: phoneNumber,
        applicationMetaData: {
          'client': 'MOBILEAPP',
          'device': 'Flutter App',
          'os': 'Android/iOS',
          'appCode': 'SafeStep'
        },
      );
      
      if (otpResponse.success) {
        setState(() {
          _otpReference = otpResponse.reference;
          _otpSent = true;
          _loading = false;
        });
      } else {
        setState(() {
          _error = otpResponse.message;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() { 
        _error = 'Failed to send OTP: ${e.toString()}';
        _loading = false;
      });
    }
  }

  // Future<void> _verifyOTP() async {
  //   if (_otpReference == null) return;
    
  //   setState(() { _loading = true; _error = null; });
    
  //   try {
  //     // Use custom backend OTP verification
  //     final verifyResponse = await OTPService.verifyOTP(
  //       reference: _otpReference!,
  //       otp: _otpController.text.trim(),
  //     );
      
  //     if (verifyResponse.success) {
  //       final phoneNumber = verifyResponse.phoneNumber!;
  //       print('✅ OTP verified successfully for: $phoneNumber');
        
  //       // Check if user exists
  //       print('🔍 Checking if user exists...');
  //       final userExistsResponse = await OTPService.checkUserExists(phoneNumber);
  //       print('📋 User exists response: ${userExistsResponse.success}, exists: ${userExistsResponse.exists}');
        
  //     //   if (userExistsResponse.success && userExistsResponse.exists == true) {
  //     //     // User exists - log them in
  //     //     print('👤 User exists, logging in with data: ${userExistsResponse.userData}');
  //     //     await _loginExistingUser(phoneNumber, userExistsResponse.userData);

  //     //     if (!mounted) return;

  //     //     // Fire the callback so AuthGate can rebuild
  //     //     print('🔄 Calling onAuthSuccess for existing user');
  //     //     widget.onAuthSuccess?.call();
  //     //     print('🔄 onAuthSuccess called for existing user');

  //     //     // Stop loading and navigate directly as a fallback
  //     //     setState(() => _loading = false);
  //     //     print('🔄 Navigating directly to home screen for existing user');
  //     //     Navigator.of(context).pushAndRemoveUntil(
  //     //       MaterialPageRoute(builder: (_) => const HomeScreen()),
  //     //       (route) => false,
  //     //     );
  //     //   } else {
  //     //     // User doesn't exist - show details form
  //     //     print('👤 User does not exist, showing registration form');
  //     //     if (mounted) {
  //     //       Navigator.pushReplacement(
  //     //         context,
  //     //         MaterialPageRoute(
  //     //           builder: (context) => UserDetailsFormScreen(
  //     //             phoneNumber: phoneNumber,
  //     //             onComplete: () {
  //     //               if (mounted) {
  //     //                 print('🔄 UserDetailsFormScreen onComplete called');
  //     //                 widget.onAuthSuccess?.call();
  //     //                 print('🔄 onAuthSuccess callback called');
  //     //               }
  //     //             },
  //     //           ),
  //     //         ),
  //     //       );
  //     //     }
  //     //   }
  //     // } 
  //     if (userExistsResponse.success) {
  //       print('👤 Showing user details screen (new or existing user)');
  //       if (mounted) {
  //         Navigator.pushReplacement(
  //           context,
  //           MaterialPageRoute(
  //             builder: (context) => UserDetailsFormScreen(
  //               phoneNumber: phoneNumber,
  //               onComplete: () {
  //                 if (mounted) {
  //                   print('🔄 UserDetailsFormScreen onComplete called');
  //                   widget.onAuthSuccess?.call();
  //                   print('🔄 onAuthSuccess callback called');
  //                 }
  //               },
  //             ),
  //           ),
  //         );
  //       }
  //     } else {
  //         // User doesn't exist - show details form
  //         print('👤 User does not exist, showing registration form');
  //         if (mounted) {
  //           Navigator.pushReplacement(
  //             context,
  //             MaterialPageRoute(
  //               builder: (context) => UserDetailsFormScreen(
  //                 phoneNumber: phoneNumber,
  //                 onComplete: () {
  //                   if (mounted) {
  //                     print('🔄 UserDetailsFormScreen onComplete called');
  //                     widget.onAuthSuccess?.call();
  //                     print('🔄 onAuthSuccess callback called');
  //                   }
  //                 },
  //               ),
  //             ),
  //           );
  //         }
  //       }
  //     } 
  //     else {
  //       if (mounted) {
  //         setState(() { 
  //           _error = verifyResponse.message;
  //           _loading = false;
  //         });
  //       }
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       setState(() { 
  //         _error = 'Failed to verify OTP: ${e.toString()}';
  //         _loading = false;
  //       });
  //     }
  //   }
  // }
  Future<void> _verifyOTP() async {
    if (_otpReference == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final verifyResponse = await OTPService.verifyOTP(
        reference: _otpReference!,
        otp: _otpController.text.trim(),
      );

      if (verifyResponse.success) {
        final phoneNumber = verifyResponse.phoneNumber!;
        print('🔍 [AUTH] OTP verified successfully for phone: $phoneNumber');

        // Sign in with Firebase Custom Token
        if (verifyResponse.customToken != null) {
          print('🔑 [AUTH] Signing in to Firebase with Custom Token...');
          await FirebaseAuth.instance.signInWithCustomToken(verifyResponse.customToken!);
        } else {
          print('⚠️ [AUTH] Warning: No custom token returned in OTP response');
        }

        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          throw Exception('Firebase authentication failed. Current user is null.');
        }

        final uid = currentUser.uid;
        print('✅ [AUTH] Firebase Auth successful! UID: $uid');
        await LocalSession.setCurrentUserId(uid);

        // Check if user profile exists and is complete in Firestore
        print('🔍 [AUTH] Checking Firestore profile for UID: $uid');
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final userData = userDoc.data();
        final profileComplete = userData?['profileComplete'] == true;

        print('✅ [AUTH] User doc exists: ${userDoc.exists}, profileComplete: $profileComplete');

        if (profileComplete) {
          print('✅ [AUTH] Profile complete, starting services and navigating to home');
          await _createCustomUserSession(phoneNumber, userData);
          if (mounted) {
            widget.onAuthSuccess?.call();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              ),
            );
          }
        } else {
          print('👤 [AUTH] Profile incomplete, navigating to UserDetailsFormScreen');
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => UserDetailsFormScreen(
                  phoneNumber: phoneNumber,
                  onComplete: () {
                    if (mounted) {
                      widget.onAuthSuccess?.call();
                    }
                  },
                ),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _error = verifyResponse.message ?? 'Invalid verification code';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Authentication failed: ${e.toString()}';
          _loading = false;
        });
      }
    }
  }

  /// Development-only bypass: Allows testing without sending or verifying SMS.
  /// Requires the backend to be running locally to issue a Firebase Custom Token.
  /// Automatically disabled and returns immediately in release mode.
  Future<void> _devBypassVerification() async {
    if (!kDebugMode) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final inputPhone = _phoneController.text.trim();
      final phoneNumber = inputPhone.isNotEmpty
          ? _formatPhoneNumber(inputPhone)
          : '+94770000000';

      print('🛠️ [DEV BYPASS] Continuing without SMS verification for: $phoneNumber');

      // Request development custom token from backend (must be running)
      final devResponse = await OTPService.requestDevCustomToken(phoneNumber);

      if (!devResponse.success || devResponse.customToken == null) {
        final msg = devResponse.message ?? 'Failed to retrieve development token';
        throw Exception(msg);
      }

      // Sign in to Firebase with the real custom token from the backend
      print('🔑 [DEV BYPASS] Signing in to Firebase with dev Custom Token...');
      await FirebaseAuth.instance.signInWithCustomToken(devResponse.customToken!);

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Firebase signInWithCustomToken succeeded but currentUser is null');
      }

      final uid = currentUser.uid;
      print('✅ [DEV BYPASS] Firebase Auth successful! UID: $uid');
      await LocalSession.setCurrentUserId(uid);

      // Check Firestore profile status
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data();
      final profileComplete = userData?['profileComplete'] == true;

      if (profileComplete) {
        print('✅ [DEV BYPASS] Existing user profile complete. Navigating to Home.');
        await _createCustomUserSession(phoneNumber, userData);
        if (mounted) {
          widget.onAuthSuccess?.call();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            ),
          );
        }
      } else {
        print('👤 [DEV BYPASS] Navigating to UserDetailsFormScreen for: $phoneNumber');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => UserDetailsFormScreen(
                phoneNumber: phoneNumber,
                onComplete: () {
                  if (mounted) {
                    widget.onAuthSuccess?.call();
                  }
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ [DEV BYPASS] Error: $e');
      if (mounted) {
        setState(() {
          _error = 'Development authentication server is unavailable.\n\n'
              'Make sure the backend is running locally:\n'
              '  cd backend && npm start\n\n'
              'And set BACKEND_URL in .env:\n'
              '  BACKEND_URL=http://<YOUR-PC-IP>:3000\n\n'
              'Error: ${e.toString()}';
          _loading = false;
        });
      }
    }
  }

  /*Future<void> _verifyOTP() async {
  if (_otpReference == null) return;

  setState(() {
    _loading = true;
    _error = null;
  });

  try {
    final verifyResponse = await OTPService.verifyOTP(
      reference: _otpReference!,
      otp: _otpController.text.trim(),
    );

    if (verifyResponse.success) {
      final phoneNumber = verifyResponse.phoneNumber!;
      print('✅ OTP verified successfully for: $phoneNumber');

      // ✅ Navigate to Onboarding screen after OTP
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OnboardingScreen(
              phoneNumber: phoneNumber,
              onAuthSuccess: widget.onAuthSuccess,
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() {
          _error = verifyResponse.message;
          _loading = false;
        });
      }
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _error = 'Failed to verify OTP: ${e.toString()}';
        _loading = false;
      });
    }
  }
}*/



  Future<void> _createCustomUserSession(String phoneNumber, Map<String, dynamic>? userData) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? await LocalSession.getCurrentUserId() ?? 'phone_${phoneNumber.replaceAll(RegExp(r'[^\d]'), '')}';
      print('💾 [AUTH] Creating/updating user session for UID: $uid (phone: $phoneNumber)');
      
      final sessionData = {
        'uid': uid,
        'phoneNumber': phoneNumber,
        'name': userData?['name'] ?? 'User',
        'email': userData?['email'],
        'dateOfBirth': userData?['dateOfBirth'],
        'createdAt': userData?['createdAt'] ?? FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isVerified': true,
        'isAuthenticated': true,
        'profileComplete': userData?['profileComplete'] ?? false,
      };
      
      sessionData.removeWhere((key, value) => value == null);
      
      final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
      await userDoc.set(sessionData, SetOptions(merge: true));
      
      await LocalSession.setCurrentUserId(uid);
      print('✅ [AUTH] User session updated in Firestore with UID: $uid');
      
      // Start shake detection service for existing users (after calibration)
      if (userData?['profileComplete'] == true) {
        print('🔄 [AUTH] Starting shake detection service for existing user');
        try {
          const platform = MethodChannel('com.example.safestep/shake_gesture');
          final result = await platform.invokeMethod('startShakeDetection');
          print('✅ [AUTH] Shake detection service started: $result');
        } catch (e) {
          print('⚠️ [AUTH] Failed to start shake detection service: $e');
        }
      }
      
    } catch (e) {
      print('❌ [AUTH] Error creating user session: $e');
      rethrow;
    }
  }

  void _resendOTP() {
    setState(() {
      _otpSent = false;
      _otpController.clear();
      _otpReference = null;
    });
    _sendOTP();
  }

  void _goBack() {
    setState(() {
      _otpSent = false;
      _otpController.clear();
      _otpReference = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 
                         MediaQuery.of(context).padding.top - 
                         MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  // Illustration
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: Image.asset(
                        'assets/login.png',
                        height: 250,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const Spacer(),
                  
                  // Main content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Text(
                            _otpSent ? 'Enter Verification Code' : 'Welcome to SafeStep',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7B3FA0),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _otpSent 
                              ? 'We sent a verification code to ${_phoneController.text}'
                              : 'Enter your phone number to get started',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          
                          if (!_otpSent) ...[
                            // Phone field only
                            TextFormField(
                              controller: _phoneController,
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                hintText: '+91 73586 38986',
                                prefixIcon: const Icon(Icons.phone),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Phone number is required';
                                }
                                final digits = value.replaceAll(RegExp(r'[^\d]'), '');
                                if (digits.length < 9) {
                                  return 'Please enter a valid phone number';
                                }
                                return null;
                              },
                            ),
                          ] else ...[
                            // OTP field
                            TextFormField(
                              controller: _otpController,
                              decoration: InputDecoration(
                                labelText: 'Verification Code',
                                hintText: 'XXXXXX',
                                hintStyle: TextStyle(
                                  color: Colors.grey.withOpacity(0.35),
                                  fontSize: 18,
                                ),
                                prefixIcon: const Icon(Icons.security),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 8,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Verification code is required';
                                }
                                if (value.length < 6) {
                                  return 'Please enter the complete verification code';
                                }
                                return null;
                              },
                            ),
                          ],
                          
                          const SizedBox(height: 24),
                          
                          // Error message
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: TextStyle(color: Colors.red.shade700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          
                          // Main action button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _loading ? null : (_otpSent ? _verifyOTP : _sendOTP),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7B3FA0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: _loading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : Text(
                                      _otpSent ? 'Verify & Continue' : 'Send Verification Code',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          
                          // Resend/Back button
                          if (_otpSent) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: _loading ? null : _goBack,
                                  child: const Text(
                                    '← Change Number',
                                    style: TextStyle(color: Color(0xFF7B3FA0)),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _loading ? null : _resendOTP,
                                  child: const Text(
                                    'Resend Code',
                                    style: TextStyle(color: Color(0xFF7B3FA0)),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Skip Verification button (debug builds only)
                          if (kDebugMode) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _loading ? null : () {
                                  final input = _phoneController.text.trim();
                                  if (input.isEmpty) {
                                    setState(() {
                                      _error = 'Please enter your phone number.';
                                    });
                                    return;
                                  }

                                  final digits = input.replaceAll(RegExp(r'[^\d]'), '');
                                  String? validDigits;
                                  if (digits.length == 10 &&
                                      (digits.startsWith('6') ||
                                          digits.startsWith('7') ||
                                          digits.startsWith('8') ||
                                          digits.startsWith('9'))) {
                                    validDigits = digits;
                                  } else if (digits.length == 12 && digits.startsWith('91')) {
                                    final sub = digits.substring(2);
                                    if (sub.startsWith('6') ||
                                        sub.startsWith('7') ||
                                        sub.startsWith('8') ||
                                        sub.startsWith('9')) {
                                      validDigits = sub;
                                    }
                                  }

                                  if (validDigits == null) {
                                    setState(() {
                                      _error = 'Please enter a valid 10-digit Indian mobile number.';
                                    });
                                    return;
                                  }

                                  final formattedPhoneNumber =
                                      '+91 ${validDigits.substring(0, 5)} ${validDigits.substring(5)}';

                                  setState(() {
                                    _error = null;
                                  });

                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => UserDetailsFormScreen(
                                        phoneNumber: formattedPhoneNumber,
                                        isVerified: false,
                                        onComplete: () {
                                          if (mounted) {
                                            widget.onAuthSuccess?.call();
                                          }
                                        },
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.skip_next, color: Color(0xFF7B3FA0), size: 20),
                                label: const Text(
                                  'Skip Verification',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7B3FA0),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF7B3FA0)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Footer
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Text(
                      'By continuing, you agree to our Terms of Service and Privacy Policy',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
