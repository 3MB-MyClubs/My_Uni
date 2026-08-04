/// Returns a cache key that identifies the Supabase Storage object behind a
/// signed URL, without including its expiring token.
///
/// Signed URLs change when they are regenerated. The object path does not, so
/// using it as the on-device cache key lets the image cache reuse bytes across
/// app launches while the URL itself still controls access to the download.
String? stableSupabaseSignedUrlCacheKey(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;

  const marker = '/storage/v1/object/sign/';
  final markerIndex = uri.path.indexOf(marker);
  if (markerIndex == -1) return null;

  final objectPath = uri.path.substring(markerIndex + marker.length);
  if (objectPath.isEmpty) return null;
  return '${uri.host}/$objectPath';
}

/// Adds a new URL identity for an object whose bytes have been replaced.
///
/// The storage path remains stable, while the query value makes Flutter and
/// the CDN treat the replacement as a new cache entry.
String versionedStorageUrl(String publicUrl, {String? version}) {
  final uri = Uri.tryParse(publicUrl);
  if (uri == null) return publicUrl;
  return uri
      .replace(
        queryParameters: {
          ...uri.queryParameters,
          'v': version ?? DateTime.now().microsecondsSinceEpoch.toString(),
        },
      )
      .toString();
}
