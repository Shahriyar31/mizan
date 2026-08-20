/// Custom exception types for structured error handling
/// Never let raw exceptions surface to the UI
library;

abstract class AppException implements Exception {
  const AppException({required this.message, this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'AppException($code): $message';
}

/// Network or API call failed
class NetworkException extends AppException {
  const NetworkException({required super.message, super.code});
}

/// Supabase database operation failed
class DatabaseException extends AppException {
  const DatabaseException({required super.message, super.code});
}

/// Scholar AI could not find a verified source
class CitationNotFoundException extends AppException {
  const CitationNotFoundException({required super.message})
      : super(code: 'CITATION_NOT_FOUND');
}

/// User not authenticated
class AuthException extends AppException {
  const AuthException({required super.message, super.code});
}

/// Content type not recognized
class ContentException extends AppException {
  const ContentException({required super.message, super.code});
}
