import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../debug/debug_service.dart';
import '../debug/logging_http_link.dart';

/// Provides a configured GraphQL client pointing at the ARMS mock backend.
class ArmsGraphQLClient {
  ArmsGraphQLClient._();

  // Change this to your machine's local IP when testing on a physical device.
  static const String _defaultEndpoint = 'http://192.168.29.188:4000/graphql';

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
    final httpLink = LoggingHttpLink(
      endpoint,
      debugService: service,
    );

    return GraphQLClient(
      link: httpLink,
      cache: GraphQLCache(store: InMemoryStore()),
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
