import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/debug/debug_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_spacing.dart';
import '../widgets/arms_top_app_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DebugService _debugService = DebugService();
  late TextEditingController _urlController;
  bool _isPinging = false;
  String? _pingMessage;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: _debugService.apiBaseUrl.value,
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pingApi() async {
    setState(() {
      _isPinging = true;
      _pingMessage = null;
    });

    try {
      final url = _debugService.apiBaseUrl.value;
      final pingUri = _buildPingUri(url);
      final response = await http
          .get(pingUri)
          .timeout(const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          if (response.statusCode == 200) {
            _pingMessage = '✓ API is responding (${response.statusCode})';
          } else {
            _pingMessage = '✗ API responded with ${response.statusCode}';
          }
          _isPinging = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pingMessage =
              '✗ Connection failed: ${e.toString().split(':').last.trim()}';
          _isPinging = false;
        });
      }
    }
  }

  Uri _buildPingUri(String apiUrl) {
    final uri = Uri.parse(apiUrl);
    final segments = List<String>.from(uri.pathSegments);

    if (segments.isNotEmpty && segments.last == 'graphql') {
      segments.removeLast();
    }

    return uri.replace(pathSegments: [...segments, 'ping']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ArmsTopAppBar(title: 'Settings'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.marginPage,
          vertical: AppSpacing.stackLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preferences',
              style: AppTextStyles.labelXsUppercase.copyWith(
                fontSize: 11,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.stackSm),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.roundSixteen),
                border: Border.all(color: AppColors.outlineLight),
              ),
              child: ValueListenableBuilder<bool>(
                valueListenable: _debugService.isDebugMode,
                builder: (context, isDebug, _) {
                  return Column(
                    children: [
                      SwitchListTile.adaptive(
                        value: isDebug,
                        onChanged: (val) {
                          setState(() {
                            _debugService.isDebugMode.value = val;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                val
                                    ? 'Developer options enabled'
                                    : 'Developer options disabled',
                              ),
                              backgroundColor: AppColors.primary,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(
                          alpha: 0.2,
                        ),
                        title: Text(
                          'Developer Options',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMain,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Enable to view backend configurations and test connectivity.',
                            style: AppTextStyles.labelXs.copyWith(
                              color: AppColors.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isDebug) ...[
                        const Divider(height: 1, color: AppColors.outlineLight),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.gutterCard),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GraphQL Server Endpoint',
                                style: AppTextStyles.labelXsUppercase.copyWith(
                                  fontSize: 10,
                                  color: AppColors.onSurfaceVariant.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _urlController,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.textMain,
                                      ),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: AppColors.cardSurface,
                                        hintText: 'http://...',
                                        hintStyle: AppTextStyles.bodyMedium
                                            .copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.roundEight,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.outlineLight,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.roundEight,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      _debugService.updateApiBaseUrl(
                                        _urlController.text,
                                      );
                                      setState(() {
                                        _pingMessage = null;
                                      });
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Endpoint updated successfully',
                                          ),
                                          backgroundColor: AppColors.primary,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.save_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Update'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: AppColors.onPrimary,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.roundEight,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: _isPinging ? null : _pingApi,
                                    icon:
                                        _isPinging
                                            ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(AppColors.primary),
                                              ),
                                            )
                                            : const Icon(
                                              Icons.network_check_outlined,
                                              size: 16,
                                            ),
                                    label: const Text('Ping'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: const BorderSide(
                                        color: AppColors.primary,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.roundEight,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_pingMessage != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        _pingMessage!.startsWith('✓')
                                            ? AppColors.successBg
                                            : AppColors.errorBg,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.roundEight,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _pingMessage!.startsWith('✓')
                                            ? Icons.check_circle_outline
                                            : Icons.error_outline,
                                        size: 16,
                                        color:
                                            _pingMessage!.startsWith('✓')
                                                ? AppColors.successText
                                                : AppColors.errorText,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _pingMessage!,
                                          style: AppTextStyles.labelXs.copyWith(
                                            color:
                                                _pingMessage!.startsWith('✓')
                                                    ? AppColors.successText
                                                    : AppColors.errorText,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.stackLg),
            Text(
              'Application Info',
              style: AppTextStyles.labelXsUppercase.copyWith(
                fontSize: 11,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.stackSm),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.roundSixteen),
                border: Border.all(color: AppColors.outlineLight),
              ),
              child: Column(
                children: [
                  _infoTile(
                    icon: Icons.info_outline,
                    title: 'Version',
                    value: '1.2.0-beta',
                  ),
                  const Divider(height: 1, color: AppColors.outlineLight),
                  _infoTile(
                    icon: Icons.domain_verification,
                    title: 'Environment',
                    value: 'Development',
                  ),
                  const Divider(height: 1, color: AppColors.outlineLight),
                  _infoTile(
                    icon: Icons.code,
                    title: 'Engine',
                    value: 'Flutter 3.x / GraphQL',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
            size: 20,
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textMain,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
