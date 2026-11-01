import 'dart:async';

import 'package:flutter/foundation.dart';

/// A device capability a page can ask for.
enum PermissionResource {
  /// Camera capture (`getUserMedia({video: true})`).
  camera,

  /// Microphone capture (`getUserMedia({audio: true})`).
  microphone,

  /// Location (`navigator.geolocation`). Android only; see
  /// [AdvancedWebViewController.onPermissionRequest].
  geolocation,
}

/// A page asking for access to one or more [PermissionResource]s.
@immutable
class PermissionRequest {
  const PermissionRequest({required this.origin, required this.resources});

  /// Origin of the requesting page, for example `https://example.com`.
  final String origin;

  /// What the page wants. A single request can ask for several resources, for
  /// example camera and microphone together; they are granted or denied
  /// together.
  final List<PermissionResource> resources;

  @override
  String toString() => 'PermissionRequest($origin, $resources)';
}

enum PermissionDecision { grant, deny }

/// Decides whether a page may use the requested resources.
typedef PermissionRequestCallback = FutureOr<PermissionDecision> Function(
  PermissionRequest request,
);
