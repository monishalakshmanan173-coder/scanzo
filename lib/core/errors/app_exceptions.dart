class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, [this.code]);

  @override
  String toString() => message;
}

class ValidationException extends AppException {
  ValidationException(String message) : super(message, 'VALIDATION_ERROR');
}

class DatabaseException extends AppException {
  DatabaseException(String message) : super(message, 'DATABASE_ERROR');
}

class AuthException extends AppException {
  AuthException(String message) : super(message, 'AUTH_ERROR');
}

class ImportException extends AppException {
  final List<String> errors;
  ImportException(String message, [this.errors = const []])
      : super(message, 'IMPORT_ERROR');
}
