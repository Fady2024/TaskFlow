import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import '../../../main.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/services/task_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/screens/auth_screen.dart';
import 'package:flutter/services.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  _AccountSettingsScreenState createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  late TaskService _taskService;
  bool _isLoading = false;
  String? _userName;
  String? _userRole;
  String? _userEmail;
  String? _profileImageUrl;
  String? _errorMessage;
  File? _selectedImage;

  final TextEditingController _usernameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _taskService = TaskService();
    _initializeTaskService();
    _loadUserData();
  }

  Future<void> _initializeTaskService() async {
    await _taskService.initDatabase();
    print('TaskService initialized in AccountSettingsScreen');
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final isGuest = prefs.getBool('isGuest') ?? false;

      if (isGuest) {
        setState(() {
          _userName = 'Guest User';
          _userRole = 'Guest';
          _userEmail = 'guest@example.com';
          _profileImageUrl = null;
        });
      } else {
        final user = supabase.auth.currentUser;
        if (user == null) {
          throw Exception('No authenticated user found. Please log in again.');
        }

        final userDataResponse = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (userDataResponse == null) {
          throw Exception('User profile not found in database.');
        }

        setState(() {
          _userName = userDataResponse['username'] ?? 'User';
          _userRole = userDataResponse['role'] ?? 'User';
          _userEmail = user.email ?? 'No email available';
          _profileImageUrl = userDataResponse['profile_image'];
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _errorMessage = 'Failed to load user data: $e';
        _userName = 'Error';
        _userRole = 'Unknown';
        _userEmail = 'Error loading email';
        _profileImageUrl = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final isGuest = prefs.getBool('isGuest') ?? false;

    if (!isGuest) {
      await supabase.auth.signOut();
    }

    await _taskService.clearAllData();
    await prefs.setBool('isGuest', false);

    setState(() => _isLoading = false);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  Future<void> _syncData() async {
    setState(() => _isLoading = true);
    try {
      await _taskService.syncWithSupabase();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data synced successfully', style: GoogleFonts.poppins()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sync data: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editUsername() async {
    _usernameController.text = _userName ?? '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Username', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: _usernameController,
          decoration: InputDecoration(
            hintText: 'Enter new username',
            hintStyle: GoogleFonts.poppins(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final newUsername = _usernameController.text.trim();
              if (newUsername.isNotEmpty && newUsername != _userName) {
                try {
                  setState(() => _isLoading = true);
                  final user = supabase.auth.currentUser;
                  if (user == null) throw Exception('No authenticated user found.');

                  await supabase
                      .from('profiles')
                      .update({'username': newUsername})
                      .eq('id', user.id);

                  setState(() {
                    _userName = newUsername;
                    _isLoading = false;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Username updated successfully', style: GoogleFonts.poppins()),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } catch (e) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update username: $e', style: GoogleFonts.poppins()),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: Text('Save', style: GoogleFonts.poppins(color: const Color(0xFF5B4CFF))),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      setState(() {
        _isLoading = true;
        _selectedImage = File(pickedFile.path);
      });

      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user found.');

      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('profile_images').upload(fileName, _selectedImage!);

      final imageUrl = supabase.storage.from('profile_images').getPublicUrl(fileName);

      await supabase.from('profiles').update({'profile_image': imageUrl}).eq('id', user.id);

      setState(() {
        _profileImageUrl = imageUrl;
        _selectedImage = null;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile image updated successfully', style: GoogleFonts.poppins()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile image: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF5B4CFF), const Color(0xFF8A7CFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Account Settings',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(2, 2),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white, size: 24),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Help & Support coming soon!', style: GoogleFonts.poppins()),
                  backgroundColor: const Color(0xFF5B4CFF),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? [const Color(0xFF141C33), const Color(0xFF1F2A47)]
                : [const Color(0xFFF0F2FF), const Color(0xFFE6E9FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: FadeInUp(
            duration: const Duration(milliseconds: 1000),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDarkMode
                          ? [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]
                          : [Colors.white.withOpacity(0.6), Colors.white.withOpacity(0.4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF5B4CFF).withOpacity(0.5),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            width: 100,
                            height: 100,
                          ),
                          GestureDetector(
                            onTap: _pickAndUploadImage,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                backgroundImage: _getProfileImage(),
                                child: _selectedImage == null && _profileImageUrl == null
                                    ? Icon(
                                  Icons.person,
                                  size: 50,
                                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                                )
                                    : null,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickAndUploadImage,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 20,
                                  color: Color(0xFF5B4CFF),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: _editUsername,
                              child: Row(
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _userName ?? 'Loading...',
                                      style: GoogleFonts.poppins(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: isDarkMode ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.edit, size: 18, color: Color(0xFF5B4CFF)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _userRole ?? 'Loading...',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: isDarkMode ? Colors.white70 : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _userEmail ?? 'Loading...',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w300,
                                  color: isDarkMode ? Colors.white60 : Colors.grey[600],
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.poppins(
                        color: Colors.redAccent,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: 3,
                      separatorBuilder: (context, index) => Divider(
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                        height: 1,
                        thickness: 1,
                        indent: 12,
                        endIndent: 12,
                      ),
                      itemBuilder: (context, index) {
                        switch (index) {
                          case 0:
                            return FadeInLeft(
                              delay: const Duration(milliseconds: 200),
                              child: _buildMenuItem(
                                icon: Icons.brightness_6,
                                title: 'Dark Mode',
                                trailing: Switch(
                                  value: themeProvider.themeMode == ThemeMode.dark,
                                  onChanged: (value) => themeProvider.toggleTheme(value),
                                  activeColor: const Color(0xFFFF6F61),
                                  activeTrackColor: const Color(0xFFFF6F61).withOpacity(0.5),
                                  inactiveThumbColor: Colors.grey,
                                  inactiveTrackColor: Colors.grey.withOpacity(0.5),
                                ),
                                onTap: () => themeProvider.toggleTheme(
                                    themeProvider.themeMode != ThemeMode.dark),
                              ),
                            );
                          case 1:
                            return FadeInLeft(
                              delay: const Duration(milliseconds: 400),
                              child: _buildMenuItem(
                                icon: Icons.sync,
                                title: 'Sync Data',
                                trailing: _isLoading
                                    ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5B4CFF)),
                                )
                                    : const Icon(Icons.refresh, color: Color(0xFF5B4CFF)),
                                onTap: _syncData,
                              ),
                            );
                          case 2:
                            return FadeInLeft(
                              delay: const Duration(milliseconds: 600),
                              child: _buildMenuItem(
                                icon: Icons.logout,
                                title: 'Logout',
                                titleColor: const Color(0xFFFF6F61),
                                hasGlow: true,
                                onTap: _logout,
                              ),
                            );
                          default:
                            return const SizedBox.shrink();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ImageProvider<Object>? _getProfileImage() {
    if (_selectedImage != null) {
      return FileImage(_selectedImage!);
    } else if (_profileImageUrl != null) {
      return NetworkImage(_profileImageUrl!);
    }
    return null;
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    Color? titleColor,
    Widget? trailing,
    bool hasGlow = false,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Provider.of<ThemeProvider>(context).themeMode == ThemeMode.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: hasGlow
              ? LinearGradient(
            colors: [
              const Color(0xFFFF6F61).withOpacity(0.2),
              Colors.transparent,
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
              : null,
          boxShadow: hasGlow
              ? [
            BoxShadow(
              color: const Color(0xFFFF6F61).withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF5B4CFF),
                    const Color(0xFF8A7CFF).withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: title == 'Logout' ? FontWeight.w600 : FontWeight.w500,
                  color: titleColor ?? (isDarkMode ? Colors.white : Colors.black87),
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }
}