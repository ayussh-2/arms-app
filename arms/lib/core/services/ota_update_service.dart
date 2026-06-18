import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';
import 'package:flutter/material.dart';
import '../../widgets/arms_snackbar.dart';

class OtaUpdateService {
  OtaUpdateService._();

  static const String githubUser = "ayussh-2";
  static const String githubRepo = "arms-app";

  /// Query the GitHub API to check for updates
  static Future<void> checkForUpdates(BuildContext context, {bool showFeedback = false}) async {
    if (!Platform.isAndroid) {
      if (showFeedback && context.mounted) {
        ArmsSnackbar.showInfo(context, 'OTA Updates are only available on Android devices.');
      }
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$githubUser/$githubRepo/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) {
        if (showFeedback && context.mounted) {
          ArmsSnackbar.showError(context, 'Failed to fetch release info (Status: ${response.statusCode})');
        }
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final String latestVersionTag = data['tag_name'] ?? ''; // e.g. "v1.0.1"
      final String cleanLatestVersion = latestVersionTag.replaceAll('v', '');

      // Get current app version details
      final packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version; // e.g. "1.0.0"

      if (_isVersionNewer(currentVersion, cleanLatestVersion)) {
        final List assets = data['assets'] ?? [];
        
        // Find the correct APK matching the system architecture
        // (Defaulting to arm64-v8a which fits most modern devices)
        final apkAsset = assets.firstWhere(
          (asset) => asset['name'].toString().contains('arm64-v8a'),
          orElse: () => assets.firstWhere(
            (asset) => asset['name'].toString().endsWith('.apk'),
            orElse: () => null,
          ),
        );

        if (apkAsset != null && context.mounted) {
          final downloadUrl = apkAsset['browser_download_url'] as String;
          _showUpdateDialog(context, cleanLatestVersion, downloadUrl);
        } else {
          if (showFeedback && context.mounted) {
            ArmsSnackbar.showWarning(context, 'No compatible APK found in the latest release.');
          }
        }
      } else {
        if (showFeedback && context.mounted) {
          ArmsSnackbar.showSuccess(context, 'ARMS is up to date (v$currentVersion).');
        }
      }
    } catch (e) {
      debugPrint('Error checking for OTA update: $e');
      if (showFeedback && context.mounted) {
        ArmsSnackbar.showError(context, 'Failed to check for updates: $e');
      }
    }
  }

  /// Version comparison helper (e.g. 1.0.1 > 1.0.0)
  static bool _isVersionNewer(String current, String latest) {
    List<int> currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < latestParts.length; i++) {
      int currentPart = i < currentParts.length ? currentParts[i] : 0;
      if (latestParts[i] > currentPart) return true;
      if (latestParts[i] < currentPart) return false;
    }
    return false;
  }

  /// Display a premium alert prompting the user to install the update
  static void _showUpdateDialog(BuildContext context, String version, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        double progress = 0;
        bool isDownloading = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E), // Premium dark theme matching ARMS style
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.system_update_alt_rounded, color: Colors.blueAccent),
                  SizedBox(width: 12),
                  Text('Update Available', style: TextStyle(color: Colors.white)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Version $version is ready for install.', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 20),
                  if (isDownloading) ...[
                    LinearProgressIndicator(
                      value: progress / 100,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Downloading update... ${progress.toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ] else
                    const Text('Do you want to download and install it now?', style: TextStyle(color: Colors.white60)),
                ],
              ),
              actions: [
                if (!isDownloading) ...[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Later', style: TextStyle(color: Colors.white38)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        isDownloading = true;
                      });
                      _startDownload(downloadUrl, (val) {
                        setState(() {
                          progress = val;
                        });
                      });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    child: const Text('Update Now', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  /// Start APK download and system intent installation
  static void _startDownload(String url, Function(double) onProgress) {
    try {
      OtaUpdate()
          .execute(url, destinationFilename: 'arms-update.apk')
          .listen((OtaEvent event) {
        if (event.status == OtaStatus.DOWNLOADING) {
          final double? value = double.tryParse(event.value ?? '0');
          if (value != null) onProgress(value);
        } else if (event.status == OtaStatus.INSTALLING) {
          debugPrint('Update downloaded. Prompting install...');
        }
      });
    } catch (e) {
      debugPrint('Failed to execute OTA update: $e');
    }
  }
}
