import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../constants/app_constants.dart';
import '../debug/debug_service.dart';
import '../debug/logging_http_link.dart';
import 'retry_link.dart';

class ArmsGraphQLClient {
  ArmsGraphQLClient._();

  static const String _defaultEndpoint = AppConstants.defaultApiEndpoint;

  static String _normalizeEndpoint(String url) {
    final uri = Uri.parse(url);
    final segments = List<String>.from(uri.pathSegments);

    if (segments.isEmpty) {
      segments.add('graphql');
    } else if (segments.last != 'graphql') {
      segments.add('graphql');
    }

    return uri.replace(pathSegments: segments).toString();
  }

  static GraphQLClient _buildClient(DebugService service) {
    final endpoint = _normalizeEndpoint(service.apiBaseUrl.value);
    final httpLink = LoggingHttpLink(endpoint, debugService: service);
    final retryLink = RetryLink(maxRetries: 3);

    final link = Link.from([retryLink, httpLink]);

    return GraphQLClient(
      link: link,
      cache: GraphQLCache(store: HiveStore()),
    );
  }

  static ValueNotifier<GraphQLClient> initClient({DebugService? debugService}) {
    final service = debugService ?? DebugService();

    // Initialize with default endpoint if not already set
    if (service.apiBaseUrl.value.isEmpty) {
      service.updateApiBaseUrl(_defaultEndpoint);
    }

    final client = ValueNotifier<GraphQLClient>(_buildClient(service));

    // Rebuild the client when the API base URL changes.
    service.apiBaseUrl.addListener(() {
      client.value = _buildClient(service);
    });

    return client;
  }
}
