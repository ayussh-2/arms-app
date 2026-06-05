import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/debug/debug_service.dart';
import '../core/theme/app_colors.dart';

/// Debug overlay widget that appears in the bottom left corner
class DebugOverlay extends StatefulWidget {
  final DebugService debugService;
  final Widget child;

  const DebugOverlay({
    super.key,
    required this.debugService,
    required this.child,
  });

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  late TextEditingController _urlController;
  bool _showPanel = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: widget.debugService.apiBaseUrl.value,
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _toggleDebugPanel() {
    setState(() {
      _showPanel = !_showPanel;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Debug button
        Positioned(
          bottom: 16,
          left: 16,
          child: GestureDetector(
            onTap: _toggleDebugPanel,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.purple.shade800,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ValueListenableBuilder<List<DebugLog>>(
                valueListenable: widget.debugService.logs,
                builder: (context, logs, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.bug_report_outlined,
                        color: Colors.white,
                      ),
                      if (logs.isNotEmpty)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              logs.length.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        // Debug panel overlay
        if (_showPanel)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showPanel = false;
                });
              },
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: GestureDetector(
                  onTap: () {}, // Prevent closing when tapping inside
                  child: Center(child: _buildDebugPanel()),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDebugPanel() {
    return Material(
      color: Colors.transparent,
      child: DebugPanel(
        debugService: widget.debugService,
        urlController: _urlController,
        onClose: _toggleDebugPanel,
      ),
    );
  }
}

/// Full debug panel showing logs and controls
class DebugPanel extends StatefulWidget {
  final DebugService debugService;
  final TextEditingController urlController;
  final VoidCallback onClose;

  const DebugPanel({
    super.key,
    required this.debugService,
    required this.urlController,
    required this.onClose,
  });

  @override
  State<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
  LogType? _selectedFilter;
  bool _isPinging = false;
  String? _pingMessage;

  Future<void> _pingApi() async {
    setState(() {
      _isPinging = true;
      _pingMessage = null;
    });

    try {
      final url = widget.debugService.apiBaseUrl.value;
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
    return Material(
      color: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade800,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Debug Panel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            // Expanded content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // API URL Configuration
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'API Base URL',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: widget.urlController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.grey.shade800,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  widget.debugService.updateApiBaseUrl(
                                    widget.urlController.text,
                                  );
                                  setState(() {
                                    _pingMessage = null;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('API URL updated'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.onPrimary,
                                ),
                                child: const Text('Update'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _isPinging ? null : _pingApi,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.successText,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: AppColors.successText
                                      .withOpacity(0.6),
                                ),
                                child:
                                    _isPinging
                                        ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                        : const Text('Ping'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.grey),
                    // Logs Controls
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Network Logs',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  widget.debugService.clearLogs();
                                  setState(() {});
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.errorText,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Clear All'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Filter chips
                          Wrap(
                            spacing: 8,
                            children: [
                              FilterChip(
                                label: const Text('All'),
                                selected: _selectedFilter == null,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedFilter = null;
                                  });
                                },
                              ),
                              ...LogType.values.map(
                                (type) => FilterChip(
                                  label: Text(_logTypeLabel(type)),
                                  selected: _selectedFilter == type,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedFilter = selected ? type : null;
                                    });
                                  },
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
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    _pingMessage!.startsWith('✓')
                                        ? AppColors.successBg
                                        : AppColors.errorBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _pingMessage!,
                                style: TextStyle(
                                  color:
                                      _pingMessage!.startsWith('✓')
                                          ? AppColors.successText
                                          : AppColors.errorText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Divider(color: Colors.grey),
                    // Logs list
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ValueListenableBuilder<List<DebugLog>>(
                        valueListenable: widget.debugService.logs,
                        builder: (context, logs, _) {
                          final filteredLogs =
                              _selectedFilter == null
                                  ? logs
                                  : logs
                                      .where(
                                        (log) => log.type == _selectedFilter,
                                      )
                                      .toList();
                          final groupedLogs = _groupLogs(filteredLogs);

                          if (groupedLogs.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: Text(
                                  'No logs yet',
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: List.generate(groupedLogs.length, (
                              index,
                            ) {
                              final group = groupedLogs[index];
                              return _buildLogItem(group);
                            }),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_LogGroup> _groupLogs(List<DebugLog> logs) {
    final groups = <_LogGroup>[];
    final pending = <String, _LogGroup>{};

    for (final log in logs) {
      final key = _logKey(log);
      switch (log.type) {
        case LogType.request:
          final group = _LogGroup(request: log);
          groups.add(group);
          pending[key] = group;
        case LogType.response:
          final group = pending[key] ?? _LogGroup(request: log);
          group.response = log;
          if (!groups.contains(group)) {
            groups.add(group);
          }
          pending.remove(key);
        case LogType.error:
          final group = pending[key] ?? _LogGroup(request: log);
          group.error = log;
          if (!groups.contains(group)) {
            groups.add(group);
          }
          pending.remove(key);
        case LogType.info:
          groups.add(_LogGroup(request: log));
      }
    }

    return groups;
  }

  String _logKey(DebugLog log) {
    return '${log.method ?? 'Unknown'}|${log.url ?? ''}';
  }

  Widget _buildLogItem(_LogGroup group) {
    final request = group.request;
    final response = group.response;
    final error = group.error;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _logColorForGroup(group),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _groupTitle(group),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                _formatTime(request.timestamp),
                style: TextStyle(color: Colors.grey.shade300, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            request.message,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          if (request.variables != null && request.variables!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Variables: ${_formatData(request.variables)}',
              style: TextStyle(color: Colors.grey.shade300, fontSize: 11),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (response != null) ...[
            const SizedBox(height: 8),
            Text(
              'Response: ${response.statusCode ?? '-'}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            if (response.responseData != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatData(response.responseData),
                style: TextStyle(color: Colors.grey.shade200, fontSize: 11),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              'Error: ${error.message}',
              style: const TextStyle(color: Colors.white, fontSize: 11),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (response?.duration != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Duration: ${response!.duration!.inMilliseconds}ms',
                style: TextStyle(color: Colors.grey.shade300, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  String _groupTitle(_LogGroup group) {
    if (group.error != null) {
      return '✗ Error';
    }
    if (group.response != null) {
      return '↔ Request + Response';
    }
    return '→ Request';
  }

  Color _logColorForGroup(_LogGroup group) {
    if (group.error != null) {
      return Colors.red.shade800;
    }
    if (group.response != null) {
      return Colors.green.shade800;
    }
    return Colors.blue.shade800;
  }

  String _formatData(dynamic data) {
    try {
      if (data is String) {
        return data;
      }
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  String _logTypeLabel(LogType type) {
    switch (type) {
      case LogType.request:
        return '→ Request';
      case LogType.response:
        return '← Response';
      case LogType.error:
        return '✗ Error';
      case LogType.info:
        return 'ℹ Info';
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }
}

class _LogGroup {
  _LogGroup({required this.request, this.response, this.error});

  DebugLog request;
  DebugLog? response;
  DebugLog? error;
}
