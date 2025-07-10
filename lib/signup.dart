import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:to_do_app/view_tasks.dart'; // Ensure this path is correct

class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnackBar(
    String message, {
    Color backgroundColor = Colors.redAccent,
  }) {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating, // Makes it float above content
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _navigateToTaskScreen() {
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/tasks');
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please enter your email and password.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      if (_isLogin) {
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      _navigateToTaskScreen();
      _showSnackBar(
        'Successfully ${_isLogin ? 'signed in' : 'signed up'}!',
        backgroundColor: Colors.green,
      );
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided for that user.';
      } else if (e.code == 'email-already-in-use') {
        message = 'The account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      } else if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else {
        message = e.message ?? 'Authentication error occurred.';
      }
      _showSnackBar(message);
    } catch (e) {
      _showSnackBar('An unexpected error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Future<void> _signInWithGoogle() async {
  //   FocusScope.of(context).unfocus();
  //   setState(() {
  //     _isLoading = true;
  //   });

  //   try {
  //     final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

  //     if (googleUser == null) {
  //       setState(() {
  //         _isLoading = false;
  //       });
  //       return; // User cancelled the sign-in
  //     }

  //     final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

  //     final AuthCredential credential = GoogleAuthProvider.credential(
  //       accessToken: googleAuth.accessToken,
  //       idToken: googleAuth.idToken,
  //     );

  //     await _auth.signInWithCredential(credential);
  //     _navigateToTaskScreen();
  //     _showSnackBar('Signed in with Google successfully!', backgroundColor: Colors.green);
  //   } on FirebaseAuthException catch (e) {
  //     String message;
  //     if (e.code == 'account-exists-with-different-credential') {
  //       message = 'An account already exists with the same email but different sign-in method.';
  //     } else if (e.code == 'invalid-credential') {
  //       message = 'The Google credential provided is invalid or expired.';
  //     } else {
  //       message = e.message ?? 'Google Sign-In failed.';
  //     }
  //     _showSnackBar(message);
  //   } catch (e) {
  //     _showSnackBar('Google Sign-In failed: $e');
  //   } finally {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.lightBlue.shade50, Colors.lightGreen.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon / Logo
                  Icon(
                    Icons.check_circle_outline, // Changed icon
                    size: 80,
                    color: Colors.blueAccent, // Icon color
                  ),
                  const SizedBox(height: 24),
                  // Welcome / Create Account Text
                  Text(
                    _isLogin ? 'Welcome Back!' : 'Join ToDoNow!',
                    style: TextStyle(
                      color: Colors.blueGrey.shade800,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isLogin
                        ? 'Sign in to manage your tasks.'
                        : 'Create an account to start organizing!',
                    style: TextStyle(
                      color: Colors.blueGrey.shade600,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  // Auth Card Container
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTextField(
                          controller: _emailController,
                          labelText: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _passwordController,
                          labelText: 'Password',
                          icon: Icons.lock_outline,
                          obscureText: true,
                        ),
                        const SizedBox(height: 30),
                        _isLoading
                            ? const CircularProgressIndicator(
                              color: Colors.teal,
                            )
                            : SizedBox(
                              width: double.infinity, // Make button fill width
                              child: ElevatedButton(
                                onPressed: _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.teal, // Primary button color
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 8,
                                  shadowColor: Colors.teal.withOpacity(0.5),
                                ),
                                child: Text(
                                  _isLogin ? 'Sign In' : 'Sign Up',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () {
                            setState(() => _isLogin = !_isLogin);
                          },
                          child: Text(
                            _isLogin
                                ? 'Don’t have an account? Sign Up'
                                : 'Already have an account? Sign In',
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Divider(color: Colors.grey.shade300),
                        const SizedBox(height: 20),
                        // SizedBox(
                        //   width: double.infinity, // Make button fill width
                        //   child: ElevatedButton.icon(
                        //     onPressed: (){},
                        //    // _signInWithGoogle,
                        //     // icon: Image.asset(
                        //     //   'assets/google_logo.png', // Ensure this path is correct
                        //     //   height: 24,
                        //     //   width: 24,
                        //     // ),
                        //     // label: const Text(
                        //     //   'Continue with Google',
                        //     //   style: TextStyle(fontSize: 16, color: Colors.blueGrey),
                        //     // ),
                        //     style: ElevatedButton.styleFrom(
                        //       backgroundColor: Colors.white,
                        //       foregroundColor: Colors.blueGrey,
                        //       padding: const EdgeInsets.symmetric(vertical: 14),
                        //       shape: RoundedRectangleBorder(
                        //         borderRadius: BorderRadius.circular(12),
                        //         side: BorderSide(color: Colors.grey.shade300),
                        //       ),
                        //       elevation: 3,
                        //       shadowColor: Colors.grey.withOpacity(0.3),
                        //     ),
                        //   ),
                        // ),
                      ],
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

  // Helper method to build TextFields consistently
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(color: Colors.blueGrey.shade800),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: Colors.blueGrey.shade500),
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        filled: true,
        fillColor: Colors.grey.shade100,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 12,
        ),
      ),
    );
  }
}
