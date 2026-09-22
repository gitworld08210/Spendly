import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a client-side UUID v4. Used so new records have stable IDs
/// before they ever reach the server.
String newId() => _uuid.v4();
