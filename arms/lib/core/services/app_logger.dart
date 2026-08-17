import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Service to handle persistent logging of application errors to a local file
/// with timestamping and automatic file size rotation (max 2 MB per log file).
class AppLogger {
  AppLogger._();

  static const String _logFileName = 'app_errors.log';
  static const int _maxFileSizeBytes = 2 * 1024 * 1024; // 2 MB Limit

  static File? _logFile;

  static Future<File> get _file async {
    if (_logFile != null) return _logFile!;
    final directory = await getApplicationDocumentsDirectory();
    _logFile = File('${directory.path}/$_logFileName');
    return _logFile!;
  }

  /// Appends an error log entry with ISO timestamp to the app log file.
  /// Automatically rotates/truncates the file if it exceeds 2 MB.
  static Future<void> logError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
  }) async {
    try {
      final file = await _file;
      final timestamp = DateTime.now().toIso8601String();
      final buffer = StringBuffer();

      buffer.writeln('=================== ERROR LOG ===================');
      buffer.writeln('TIMESTAMP: $timestamp');
      if (context != null && context.isNotEmpty) {
        buffer.writeln('CONTEXT: $context');
      }
      buffer.writeln('ERROR DETAILS: $error');
      if (stackTrace != null) {
        buffer.writeln('STACKTRACE:\n$stackTrace');
      }
      buffer.writeln('=================================================\n');

      final logEntry = buffer.toString();
      debugPrint('[AppLogger] $logEntry');

      // Check log file size before appending
      if (await file.exists()) {
        final stat = await file.stat();
        if (stat.size >= _maxFileSizeBytes) {
          await _rotateLogFile(file);
        }
      }

      await file.writeAsString(logEntry, mode: FileMode.append, flush: true);
    } catch (e, st) {
      debugPrint('[AppLogger] Failed to write log entry: $e\n$st');
    }
  }

  /// Rotates/truncates the log file when it reaches 2 MB,
  /// preserving the most recent 1 MB of logs.
  static Future<void> _rotateLogFile(File file) async {
    try {
      final content = await file.readAsString();
      // Keep the newest half (~1 MB) of the log content
      final halfLength = content.length ~/ 2;
      final preservedContent = content.substring(halfLength);

      await file.writeAsString(
        '--- LOG ROTATED AT ${DateTime.now().toIso8601String()} (EXCEEDED 2 MB LIMIT) ---\n$preservedContent',
        flush: true,
      );
    } catch (e) {
      // Fallback: reset file if reading/parsing fails
      await file.writeAsString(
        '--- LOG RESET AT ${DateTime.now().toIso8601String()} DUE TO ROTATION FAILURE ---\n',
        flush: true,
      );
    }
  }

  /// Returns the current log file path (for settings or debug export).
  static Future<String?> getLogFilePath() async {
    try {
      final file = await _file;
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Reads and returns full log contents.
  static Future<String> readLogs() async {
    try {
      final file = await _file;
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      debugPrint('[AppLogger] Failed to read log file: $e');
    }
    return 'No error logs found.';
  }

  /// Clears log file.
  static Future<void> clearLogs() async {
    try {
      final file = await _file;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('[AppLogger] Failed to clear log file: $e');
    }
  }
}
