/// Data models for Midjourney MCP results.
///
/// See `docs/midjourney.md` for the verified wire format.

/// A single image from a 2x2 generation grid.
class MidjourneyImage {
  const MidjourneyImage({
    required this.gridIndex,
    required this.cdnUrl,
    required this.resourceUri,
  });

  /// Which cell of the 2x2 grid (0-3).
  final int gridIndex;

  /// Full-resolution JPEG URL on Midjourney's CDN.
  final String cdnUrl;

  /// `midjourney://image/<job>/<index>` reference.
  final String resourceUri;

  factory MidjourneyImage.fromJson(Map<String, dynamic> json) =>
      MidjourneyImage(
        gridIndex: json['grid_index'] as int,
        cdnUrl: json['cdn_url'] as String,
        resourceUri: json['resource_uri'] as String,
      );
}

/// Result of a `generate_image` (or variation/upscale/edit) call.
class MidjourneyJob {
  const MidjourneyJob({
    required this.jobId,
    required this.webUrl,
    required this.images,
  });

  /// UUID of the job — feed into variation/upscale/inpaint/etc.
  final String jobId;

  /// View the job on midjourney.com.
  final String webUrl;

  /// The four generated images.
  final List<MidjourneyImage> images;

  factory MidjourneyJob.fromJson(Map<String, dynamic> json) => MidjourneyJob(
    jobId: json['job_id'] as String,
    webUrl: json['web_url'] as String? ?? '',
    images: (json['images'] as List<dynamic>? ?? [])
        .map((e) => MidjourneyImage.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// OAuth tokens returned by the `/token` endpoint.
class MidjourneyTokens {
  const MidjourneyTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.scope,
  });

  final String accessToken;
  final String? refreshToken;

  /// Absolute expiry time (computed from `expires_in`).
  final DateTime expiresAt;
  final String scope;

  bool get isExpired =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 60)));

  factory MidjourneyTokens.fromTokenResponse(Map<String, dynamic> json) {
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    return MidjourneyTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      scope: json['scope'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_at': expiresAt.toIso8601String(),
    'scope': scope,
  };

  factory MidjourneyTokens.fromJson(Map<String, dynamic> json) =>
      MidjourneyTokens(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String?,
        expiresAt: DateTime.parse(json['expires_at'] as String),
        scope: json['scope'] as String? ?? '',
      );
}

/// Thrown when the MCP server returns a JSON-RPC error or an `isError` result.
class MidjourneyException implements Exception {
  MidjourneyException(this.message, {this.code});
  final String message;
  final int? code;
  @override
  String toString() => 'MidjourneyException(${code ?? ''}): $message';
}
