import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_spacing.dart';
import '../core/graphql/queries.dart';
import '../core/auth/auth_service.dart';
import '../widgets/arms_input_field.dart';

/// Queries the admins list from the backend for authentication.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    final userId = _userIdController.text.trim();
    final password = _passwordController.text.trim();

    if (userId.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter User ID and Password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = GraphQLProvider.of(context).value;
      final result = await client.query(
        QueryOptions(
          document: gql(GqlQueries.login),
          variables: {
            'adminId': userId,
            'password': password,
          },
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (result.hasException) {
        setState(() {
          _errorMessage = 'Connection error. Is the backend running?';
          _isLoading = false;
        });
        return;
      }

      final loginResponse = result.data?['login'];
      final error = loginResponse?['error'];
      final adminData = loginResponse?['data'];

      if (error != null) {
        setState(() {
          _errorMessage = error.toString();
          _isLoading = false;
        });
        return;
      }

      if (adminData != null && mounted) {
        await AuthService.saveSession(Map<String, dynamic>.from(adminData));
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/shell');
        }
      } else {
        setState(() {
          _errorMessage = 'Invalid User ID or Password';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error. Please check your network.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.marginPage),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Text(
                    'ARMS',
                    style: AppTextStyles.displayLarge.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.stackSm),
                  Text(
                    'Sign In',
                    style: AppTextStyles.headerSmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.stackLg),

                  // User ID field
                  _buildLabel('User ID'),
                  const SizedBox(height: AppSpacing.stackSm),
                  ArmsInputField(
                    controller: _userIdController,
                    hintText: 'Enter your User ID',
                    prefixIcon: Icons.person_outline,
                  ),
                  const SizedBox(height: AppSpacing.stackMd),

                  // Password field
                  _buildLabel('Password'),
                  const SizedBox(height: AppSpacing.stackSm),
                  ArmsInputField(
                    controller: _passwordController,
                    hintText: '••••••••',
                    prefixIcon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.outlineMedium,
                        size: 22,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),

                  // Error message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.stackMd),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.errorBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: AppTextStyles.labelXs.copyWith(
                          color: AppColors.errorText,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.stackLg),

                  // Sign In button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.6,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9999),
                        ),
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.onPrimary,
                                  ),
                                ),
                              )
                              : Text(
                                'Sign In',
                                style: AppTextStyles.headerSmall.copyWith(
                                  color: AppColors.onPrimary,
                                ),
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

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text,
          style: AppTextStyles.labelXs.copyWith(color: AppColors.textMain),
        ),
      ),
    );
  }
}
