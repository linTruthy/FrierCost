import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rive/rive.dart';
import 'dart:io';

import 'app.dart';

// Auth state provider
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Auth notifier
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier() : super(const AsyncValue.data(null));

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> signUp(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> signInWithApple() async {
    state = const AsyncValue.loading();
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oAuthProvider = OAuthProvider('apple.com');
      final credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncValue.loading();
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>(
  (ref) => AuthNotifier(),
);

// Theme provider
final themeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// Custom colors and themes

// Login Page
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _errorMessage;
  late final SMITrigger? _successTrigger;
  late final SMITrigger? _failTrigger;
  late final RiveAnimationController _riveController;
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  bool _isAnimatingCard = false;
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // _riveController = OneShotAnimation('idle');
    _riveController = OneShotAnimation('mobile artboard');
    _checkDeviceInfo();

    // Listen for keyboard visibility changes
    KeyboardVisibilityController().onChange.listen((bool visible) {
      setState(() {
        _isKeyboardVisible = visible;
      });
    });

    _emailFocusNode.addListener(_handleFocusChange);
    _passwordFocusNode.addListener(_handleFocusChange);
    _confirmPasswordFocusNode.addListener(_handleFocusChange);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _isAnimatingCard = true;
          _errorMessage = null;
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _isAnimatingCard = false;
            });
          }
        });
      }
    });
  }

  Future<void> _checkDeviceInfo() async {
    if (Platform.isAndroid) {
      // Use MediaQuery to get screen width in logical pixels
      setState(() {
        // Adjust threshold as needed
      });
    } else if (Platform.isIOS) {
      setState(() {
        // Check if it's a smaller iPhone
      });
    }
  }

  void _handleFocusChange() {
    setState(() {});
  }

  void _onRiveInit(Artboard artboard) {
    final controller = StateMachineController.fromArtboard(
      artboard,
      'State Machine 1',
    );
    artboard.addController(controller!);
    _successTrigger = controller.findSMI('success') as SMITrigger;
    _failTrigger = controller.findSMI('fail') as SMITrigger;
  }

  void _showSuccessAnimation() {
    _successTrigger?.fire();
  }

  void _showFailAnimation() {
    _failTrigger?.fire();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) {
    showGeneralDialog(
      context: context,
      pageBuilder:
          (_, __, ___) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.error),
                const SizedBox(width: 10),
                Text('Error'),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
      transitionBuilder: (_, anim, __, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  void _showResetPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Reset Password Dialog',
      pageBuilder:
          (_, __, ___) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: Row(
                      children: [
                        Icon(
                          Icons.lock_reset,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Text('Reset Password'),
                      ],
                    ),
                    content: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Enter your email address and we\'ll send you a link to reset your password.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: resetEmailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator:
                                (value) =>
                                    value!.isEmpty || !value.contains('@')
                                        ? 'Please enter a valid email'
                                        : null,
                            autofocus: true,
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed:
                            isLoading
                                ? null
                                : () async {
                                  if (formKey.currentState!.validate()) {
                                    setState(() => isLoading = true);
                                    try {
                                      await ref
                                          .read(authProvider.notifier)
                                          .resetPassword(
                                            resetEmailController.text.trim(),
                                          );
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Password reset email sent!',
                                          ),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    } catch (e) {
                                      Navigator.of(context).pop();
                                      _showErrorDialog(
                                        'Failed to send reset email: ${e.toString().split(']').last}',
                                      );
                                    }
                                  }
                                },
                        child:
                            isLoading
                                ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : Text('Send Reset Link'),
                      ),
                    ],
                  )
                  .animate()
                  .scale(duration: 300.ms, curve: Curves.easeOutBack)
                  .fadeIn(duration: 200.ms);
            },
          ),
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  void _toggleTheme() {
    final currentTheme = ref.read(themeProvider);
    ref.read(themeProvider.notifier).state =
        currentTheme == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final isLoading = authState is AsyncLoading;

    return Scaffold(
      body: Stack(
        children: [
          // Background design
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                image: DecorationImage(
                  image: AssetImage(
                    isDarkMode
                        ? 'assets/images/bg_pattern_dark.jpg'
                        : 'assets/images/bg_pattern_light.jpg',
                  ),
                  fit: BoxFit.cover,
                  opacity: 0.05,
                ),
              ),
            ),
          ),

          // Theme toggle
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
                  icon: Icon(
                    isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: _toggleTheme,
                )
                .animate()
                .scale(duration: 300.ms, curve: Curves.easeOutBack)
                .fadeIn(duration: 500.ms),
          ),

          // Main content
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: _isKeyboardVisible ? 20 : 40,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 450),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo and welcome animation
                    if (!_isKeyboardVisible || size.height > 700)
                      Column(
                        children: [
                          SizedBox(
                            height: 160,
                            width: 160,
                            child: RiveAnimation.asset(
                              'assets/animations/login_character.riv',
                              fit: BoxFit.contain,
                              onInit: _onRiveInit,
                              controllers: [_riveController],
                            ),
                          ).animate().scale(
                            duration: 800.ms,
                            curve: Curves.easeOutBack,
                          ),
                          const SizedBox(height: 20),
                          Text(
                                'Welcome Back',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              )
                              .animate()
                              .fadeIn(duration: 500.ms)
                              .slideY(begin: 0.3, end: 0),
                          const SizedBox(height: 10),
                          Text(
                            _tabController.index == 0
                                ? 'Sign in to continue'
                                : 'Create your account',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                          const SizedBox(height: 30),
                        ],
                      ),

                    // Auth card
                    AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          transform:
                              _isAnimatingCard
                                  ? (Matrix4.identity()..rotateY(0.1))
                                  : Matrix4.identity(),
                          transformAlignment: Alignment.center,
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Tab bar
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: TabBar(
                                      controller: _tabController,
                                      tabs: const [
                                        Tab(text: 'Login'),
                                        Tab(text: 'Sign Up'),
                                      ],
                                      labelColor:
                                          Theme.of(context).colorScheme.primary,
                                      unselectedLabelColor: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.6),
                                      indicator: BoxDecoration(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.1),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      labelStyle: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      dividerHeight: 0,
                                      splashBorderRadius: BorderRadius.circular(
                                        12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 30),

                                  // Tab content
                                  SizedBox(
                                    height:
                                        _tabController.index == 0 ? 340 : 390,
                                    child: TabBarView(
                                      controller: _tabController,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      children: [
                                        LoginForm(
                                          emailFocusNode: _emailFocusNode,
                                          passwordFocusNode: _passwordFocusNode,
                                          onForgotPassword:
                                              _showResetPasswordDialog,
                                          onError: (error) {
                                            setState(
                                              () => _errorMessage = error,
                                            );
                                            _showFailAnimation();
                                          },
                                          onSuccess: _showSuccessAnimation,
                                        ),
                                        SignUpForm(
                                          emailFocusNode: _emailFocusNode,
                                          passwordFocusNode: _passwordFocusNode,
                                          confirmPasswordFocusNode:
                                              _confirmPasswordFocusNode,
                                          onError: (error) {
                                            setState(
                                              () => _errorMessage = error,
                                            );
                                            _showFailAnimation();
                                          },
                                          onSuccess: () {
                                            _showSuccessAnimation();
                                            Future.delayed(
                                              const Duration(
                                                milliseconds: 1000,
                                              ),
                                              () {
                                                if (mounted) {
                                                  _tabController.animateTo(0);
                                                }
                                              },
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Error message
                                  if (_errorMessage != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child:
                                          Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.error
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.error_outline,
                                                      color: AppColors.error,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        _errorMessage!
                                                            .split(']')
                                                            .last,
                                                        style: TextStyle(
                                                          color:
                                                              AppColors.error,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                              .animate()
                                              .fadeIn(duration: 300.ms)
                                              .shake(),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 500.ms)
                        .slideY(begin: 0.1, end: 0),

                    // Footer
                    if (!_isKeyboardVisible || size.height > 700)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '© ${DateTime.now().year} Truthy Systems',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '•',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(width: 10),
                            TextButton(
                              onPressed: () {
                                // Show privacy policy
                              },
                              child: Text(
                                'Privacy Policy',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 500.ms, delay: 500.ms),
                  ],
                ),
              ),
            ),
          ),

          // Loading overlay
          if (isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 50,
                          height: 50,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Processing...',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
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

class LoginForm extends ConsumerStatefulWidget {
  final Function(String) onError;
  final VoidCallback onSuccess;
  final VoidCallback onForgotPassword;
  final FocusNode emailFocusNode;
  final FocusNode passwordFocusNode;

  const LoginForm({
    super.key,
    required this.onError,
    required this.onSuccess,
    required this.onForgotPassword,
    required this.emailFocusNode,
    required this.passwordFocusNode,
  });

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _isHovering = false;
  bool _rememberMe = false;
  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();
    _buttonAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _buttonAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _buttonAnimationController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      try {
        await ref
            .read(authProvider.notifier)
            .login(_emailController.text.trim(), _passwordController.text);
        widget.onSuccess();
      } catch (e) {
        widget.onError(e.toString());
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
      widget.onSuccess();
    } catch (e) {
      widget.onError(e.toString());
    }
  }

  Future<void> _signInWithApple() async {
    try {
      await ref.read(authProvider.notifier).signInWithApple();
      widget.onSuccess();
    } catch (e) {
      widget.onError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email field
          TextFormField(
            controller: _emailController,
            focusNode: widget.emailFocusNode,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              focusedBorder:
                  widget.emailFocusNode.hasFocus
                      ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      )
                      : null,
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
          const SizedBox(height: 20),

          // Password field
          TextFormField(
            controller: _passwordController,
            focusNode: widget.passwordFocusNode,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _passwordVisible = !_passwordVisible;
                  });
                },
              ),
              focusedBorder:
                  widget.passwordFocusNode.hasFocus
                      ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      )
                      : null,
            ),
            obscureText: !_passwordVisible,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
            onFieldSubmitted: (_) => _login(),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
          const SizedBox(height: 5),

          // Remember me and forgot password
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (value) {
                        setState(() {
                          _rememberMe = value ?? false;
                        });
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Remember me', style: TextStyle(fontSize: 14)),
                ],
              ),
              TextButton(
                onPressed: widget.onForgotPassword,
                child: Text(
                  'Forgot password?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
          const SizedBox(height: 25),

          // Login button
          MouseRegion(
            onEnter:
                (_) => setState(() {
                  _isHovering = true;
                  _buttonAnimationController.forward();
                }),
            onExit:
                (_) => setState(() {
                  _isHovering = false;
                  _buttonAnimationController.reverse();
                }),
            child: AnimatedBuilder(
              animation: _buttonAnimationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _buttonScaleAnimation.value,
                  child: child,
                );
              },
              child: ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  elevation: _isHovering ? 4 : 0,
                  animationDuration: const Duration(milliseconds: 200),
                ),
                child: Text('Login'),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
          const SizedBox(height: 30),

          // Or sign in with
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Or sign in with',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.2),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
          const SizedBox(height: 20),

          // Social sign in buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Google button
              InkWell(
                onTap: _signInWithGoogle,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            isDarkMode
                                ? Colors.black.withOpacity(0.2)
                                : Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/google.svg',
                    height: 24,
                    width: 24,
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Apple button (show only on iOS or macOS)
              if (Platform.isIOS || Platform.isMacOS)
                InkWell(
                  onTap: _signInWithApple,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode ? AppColors.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              isDarkMode
                                  ? Colors.black.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SvgPicture.asset(
                      'assets/icons/apple.svg',
                      height: 24,
                      width: 24,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
        ],
      ),
    );
  }
}

class SignUpForm extends ConsumerStatefulWidget {
  final Function(String) onError;
  final VoidCallback onSuccess;
  final FocusNode emailFocusNode;
  final FocusNode passwordFocusNode;
  final FocusNode confirmPasswordFocusNode;

  const SignUpForm({
    super.key,
    required this.onError,
    required this.onSuccess,
    required this.emailFocusNode,
    required this.passwordFocusNode,
    required this.confirmPasswordFocusNode,
  });

  @override
  ConsumerState<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends ConsumerState<SignUpForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameFocusNode = FocusNode();
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _acceptTerms = false;
  bool _isHovering = false;
  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();
    _buttonAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _buttonAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _nameFocusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocusNode.dispose();
    _buttonAnimationController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_acceptTerms) {
      widget.onError('Please accept the Terms and Privacy Policy');
      return;
    }

    if (_formKey.currentState!.validate()) {
      try {
        await ref
            .read(authProvider.notifier)
            .signUp(_emailController.text.trim(), _passwordController.text);
        // Add user's name to profile if needed
        await FirebaseAuth.instance.currentUser?.updateDisplayName(
          _nameController.text.trim(),
        );
        widget.onSuccess();
      } catch (e) {
        widget.onError(e.toString());
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (!_acceptTerms) {
      widget.onError('Please accept the Terms and Privacy Policy');
      return;
    }

    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
      widget.onSuccess();
    } catch (e) {
      widget.onError(e.toString());
    }
  }

  Future<void> _signInWithApple() async {
    if (!_acceptTerms) {
      widget.onError('Please accept the Terms and Privacy Policy');
      return;
    }

    try {
      await ref.read(authProvider.notifier).signInWithApple();
      widget.onSuccess();
    } catch (e) {
      widget.onError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Name field
          TextFormField(
            controller: _nameController,
            focusNode: _nameFocusNode,
            decoration: InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person_outline),
              focusedBorder:
                  _nameFocusNode.hasFocus
                      ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      )
                      : null,
            ),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your name';
              }
              return null;
            },
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
          const SizedBox(height: 20),

          // Email field
          TextFormField(
            controller: _emailController,
            focusNode: widget.emailFocusNode,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              focusedBorder:
                  widget.emailFocusNode.hasFocus
                      ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      )
                      : null,
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
          const SizedBox(height: 20),

          // Password field
          TextFormField(
            controller: _passwordController,
            focusNode: widget.passwordFocusNode,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _passwordVisible = !_passwordVisible;
                  });
                },
              ),
              focusedBorder:
                  widget.passwordFocusNode.hasFocus
                      ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      )
                      : null,
            ),
            obscureText: !_passwordVisible,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
          const SizedBox(height: 20),

          // Confirm Password field
          TextFormField(
            controller: _confirmPasswordController,
            focusNode: widget.confirmPasswordFocusNode,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _confirmPasswordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _confirmPasswordVisible = !_confirmPasswordVisible;
                  });
                },
              ),
              focusedBorder:
                  widget.confirmPasswordFocusNode.hasFocus
                      ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      )
                      : null,
            ),
            obscureText: !_confirmPasswordVisible,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
            onFieldSubmitted: (_) => _signUp(),
          ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
          const SizedBox(height: 20),

          // Terms checkbox
          Row(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _acceptTerms,
                  onChanged: (value) {
                    setState(() {
                      _acceptTerms = value ?? false;
                    });
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    children: [
                      TextSpan(text: 'I agree to the '),
                      TextSpan(
                        text: 'Terms',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        recognizer:
                            TapGestureRecognizer()
                              ..onTap = () {
                                // Show terms
                              },
                      ),
                      TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        recognizer:
                            TapGestureRecognizer()
                              ..onTap = () {
                                // Show privacy policy
                              },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
          const SizedBox(height: 25),

          // Sign up button
          MouseRegion(
            onEnter:
                (_) => setState(() {
                  _isHovering = true;
                  _buttonAnimationController.forward();
                }),
            onExit:
                (_) => setState(() {
                  _isHovering = false;
                  _buttonAnimationController.reverse();
                }),
            child: AnimatedBuilder(
              animation: _buttonAnimationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _buttonScaleAnimation.value,
                  child: child,
                );
              },
              child: ElevatedButton(
                onPressed: _signUp,
                style: ElevatedButton.styleFrom(
                  elevation: _isHovering ? 4 : 0,
                  animationDuration: const Duration(milliseconds: 200),
                ),
                child: Text('Create Account'),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
          const SizedBox(height: 30),

          // Or sign up with
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Or sign up with',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.2),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 700.ms),
          const SizedBox(height: 20),

          // Social sign up buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Google button
              InkWell(
                onTap: _signInWithGoogle,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            isDarkMode
                                ? Colors.black.withOpacity(0.2)
                                : Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/google.svg',
                    height: 24,
                    width: 24,
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Apple button (show only on iOS or macOS)
              if (Platform.isIOS || Platform.isMacOS)
                InkWell(
                  onTap: _signInWithApple,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode ? AppColors.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              isDarkMode
                                  ? Colors.black.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SvgPicture.asset(
                      'assets/icons/apple.svg',
                      height: 24,
                      width: 24,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 800.ms),
        ],
      ),
    );
  }
}
