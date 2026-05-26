import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Service to manage debug logs and network monitoring
class DebugService {
  static final DebugService _instance = DebugService._internal();

  factory DebugService() {
    return _instance;
  }

  DebugService._internal();

  final List<DebugLog> _logs = [];
  final ValueNotifier<List<DebugLog>> logs = ValueNotifier([]);
  final ValueNotifier<String> apiBaseUrl = ValueNotifier('http://192.168.29.188:4000/graphql');

  static const int maxLogs = 100;

  /// Add a network log entry
  void logNetworkRequest({
    required String method,
    required String url,
    required DateTime timestamp,
    Map<String, dynamic>? variables,
  }) {
    final log = DebugLog(
      type: LogType.request,
      method: method,
      url: url,
      timestamp: timestamp,
      variables: variables,
      message: 'Request: $method to $url',
    );
    _addLog(log);
    developer.log('🔵 GraphQL Request: $method\nURL: $url\nVariables: $variables');
  }

  /// Add a network response log entry
  void logNetworkResponse({
    required String method,
    required String url,
    required DateTime timestamp,
    required Duration duration,
    required int statusCode,
    dynamic responseData,
  }) {
    final log = DebugLog(
      type: LogType.response,
      method: method,
      url: url,
      timestamp: timestamp,
      statusCode: statusCode,
      duration: duration,
      responseData: responseData,
      message: 'Response: $method - $statusCode (${duration.inMilliseconds}ms)',
    );
    _addLog(log);
    developer.log('🟢 GraphQL Response: $statusCode\nDuration: ${duration.inMilliseconds}ms\nData: $responseData');
  }

  /// Add an error log entry
  void logError({
    required String error,
    required DateTime timestamp,
    String? url,
    StackTrace? stackTrace,
  }) {
    final log = DebugLog(
      type: LogType.error,
      timestamp: timestamp,
      url: url,
      message: error,
      stackTrace: stackTrace,
    );
    _addLog(log);
    developer.log('🔴 Error: $error\nURL: $url\nStackTrace: $stackTrace', error: error, stackTrace: stackTrace);
  }

  /// Add a general log entry
  void log({
    required String message,
    required DateTime timestamp,
    LogType type = LogType.info,
  }) {
    final log = DebugLog(
      type: type,
      timestamp: timestamp,
      message: message,
    );
    _addLog(log);
    developer.log('ℹ️ $message');
  }

  /// Internal method to add log and manage list size
  void _addLog(DebugLog log) {
    _logs.add(log);

    // Keep only the most recent logs
    if (_logs.length > maxLogs) {
      _logs.removeRange(0, _logs.length - maxLogs);
    }

    logs.value = List.from(_logs);
  }

  /// Clear all logs
  void clearLogs() {
    _logs.clear();
    logs.value = [];
  }

  /// Get all logs
  List<DebugLog> getAllLogs() => List.from(_logs);

  /// Update API base URL
  void updateApiBaseUrl(String newUrl) {
    apiBaseUrl.value = newUrl;
    developer.log('🔗 API Base URL changed to: $newUrl');
  }
}

enum LogType {
  request,
  response,
  error,
  info,
}

class DebugLog {
  final LogType type;
  final String? method;
  final String? url;
  final DateTime timestamp;
  final Map<String, dynamic>? variables;
  final int? statusCode;
  final Duration? duration;
  final dynamic responseData;
  final String message;
  final StackTrace? stackTrace;

  DebugLog({
    required this.type,
    this.method,
    this.url,
    required this.timestamp,
    this.variables,
    this.statusCode,
    this.duration,
    this.responseData,
    required this.message,
    this.stackTrace,
  });

  @override
  String toString() {
    return '[$type] $message';
  }
}
