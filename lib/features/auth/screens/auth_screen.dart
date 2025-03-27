import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../main.dart';
import '../../../screens/main_screen.dart';
import '../../../core/services/task_service.dart';
import '../../task/bloc/task_bloc.dart';
import '../../task/bloc/task_event.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../../core/theme/theme_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(String userId) async {
    if (_profileImage == null) return null;

    try {
      final fileName = '$userId/profile.jpg';
      final response = await supabase.storage
          .from('profile-images')
          .upload(fileName, _profileImage!, fileOptions: const FileOptions(upsert: true));

      if (response.isEmpty) {
        throw Exception('Failed to upload image: Empty response from server');
      }

      final imageUrl = supabase.storage.from('profile-images').getPublicUrl(fileName);
      print('Image uploaded successfully. Public URL: $imageUrl');
      return imageUrl;
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }

  Future<bool> _isOnline() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print('Error checking connectivity: $e');
      return false;
    }
  }

  Future<void> _authenticate() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        throw Exception('Email and password cannot be empty');
      }

      if (!_isLogin && _usernameController.text.isEmpty) {
        throw Exception('Username cannot be empty');
      }

      if (!await _isOnline()) {
        throw Exception('No internet connection');
      }

      print('Attempting to authenticate with email: ${_emailController.text}');

      if (_isLogin) {
        print('Signing in with Supabase...');
        final response = await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        print('Sign-in response: $response');
      } else {
        print('Signing up with Supabase...');
        final response = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        print('Sign-up response: $response');

        final userId = response.user!.id;
        String? imageUrl;
        try {
          imageUrl = await _uploadImage(userId);
        } catch (e) {
          print('Failed to upload profile image: $e');
          setState(() => _error = 'Failed to upload profile image: $e');
          return;
        }

        try {
          await supabase.from('profiles').insert({
            'id': userId,
            'username': _usernameController.text.trim(),
            'role': 'User',
            'profile_image': imageUrl,
          });
        } catch (e) {
          print('Error inserting user profile: $e');
          setState(() => _error = 'Failed to create user profile: $e');
          return;
        }
      }

      print('Setting guest user to false');
      await setGuestUser(false);

      print('Initializing TaskService...');
      final taskService = TaskService();
      await taskService.initDatabase();
      print('TaskService database initialized');

      print('Importing data from Supabase...');
      await taskService.importFromSupabase();
      print('Data imported from Supabase');

      if (mounted) {
        print('Loading tasks into TaskBloc...');
        context.read<TaskBloc>().add(LoadTasks());
        print('Navigating to MainScreen...');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } on AuthException catch (e) {
      print('AuthException: ${e.message}');
      setState(() => _error = e.message);
    } on PostgrestException catch (e) {
      print('PostgrestException: ${e.message}, details: ${e.details}');
      setState(() => _error = 'Database error: ${e.message}');
    } catch (e, stackTrace) {
      print('Unexpected error: $e');
      print('Stack trace: $stackTrace');
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    await setGuestUser(true);
    final taskService = TaskService();
    await taskService.initDatabase();
    await taskService.clearAllData();
    if (mounted) {
      context.read<TaskBloc>().add(LoadTasks());
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailController.text.isEmpty) {
      setState(() => _error = 'Please enter your email first');
      return;
    }

    try {
      setState(() => _isLoading = true);
      await supabase.auth.resetPasswordForEmail(_emailController.text.trim());
      setState(() {
        _error = 'Password reset email sent. Check your inbox.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error sending reset email: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isLogin ? 'Login' : 'Sign Up',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [const Color(0xFF1F2A44), const Color(0xFF2A3756)]
                : [const Color(0xFFF5F6F5), const Color(0xFFE8ECEF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin ? 'Welcome Back' : 'Create Account',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : const Color(0xFF1F2A44),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin ? 'Sign in to continue' : 'Join us today',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: isDarkMode ? Colors.grey[400] : const Color(0xFF7A869A),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (!_isLogin) ...[
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDarkMode ? Colors.white24 : Colors.grey[300]!,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          image: _profileImage != null
                              ? DecorationImage(
                            image: FileImage(_profileImage!),
                            fit: BoxFit.cover,
                          )
                              : null,
                        ),
                        child: _profileImage == null
                            ? Icon(
                          Icons.add_a_photo_rounded,
                          size: 40,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          if (!_isLogin) ...[
                            TextField(
                              controller: _usernameController,
                              decoration: const InputDecoration(
                                labelText: 'Username',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            obscureText: _obscurePassword,
                          ),
                          if (_isLogin) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _forgotPassword,
                                child: Text(
                                  'Forgot Password?',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: isDarkMode ? Colors.grey[400] : const Color(0xFF5D737E),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Colors.red[400],
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _authenticate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6F61),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : Text(
                        _isLogin ? 'Login' : 'Sign Up',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin ? 'Need an account? Sign Up' : 'Have an account? Login',
                      style: GoogleFonts.poppins(
                        color: isDarkMode ? Colors.grey[400] : const Color(0xFF5D737E),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _continueAsGuest,
                    child: Text(
                      'Continue as Guest',
                      style: GoogleFonts.poppins(
                        color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                      ),
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