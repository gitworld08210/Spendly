import 'package:flutter/foundation.dart' hide Category;

/// The kind of protection issue Paisa Guard detected.
enum GuardKind {
  duplicateCharge, // same merchant + amount within a short window
  hiddenCharge, // bank fees / service charges
  unusedSubscription, // recurring payment the user may not use
  spike, // a bill/category much higher than usual
  unusualTransaction, // large one-off, odd for this user
}

/// How serious the alert is (drives color + sort order).
enum GuardSeverity { high, medium, low }

/// A single protection finding shown on the Paisa Guard screen.
@immutable
class GuardAlert {
  const GuardAlert({
    required this.id,
    required this.kind,
    required this.severity,
    required this.title,
    required this.message,
    this.amountAtRisk = 0,
    this.potentialSaving = 0,
    this.transactionIds = const [],
  });

  final String id;
  final GuardKind kind;
  final GuardSeverity severity;
  final String title;
  final String message;

  /// Money that could be wrong/fraudulent (duplicates, unexpected charges).
  final double amountAtRisk;

  /// Recurring money the user could save (e.g. cancel a subscription).
  final double potentialSaving;

  /// Related transaction ids (for drill-in / mark-safe).
  final List<String> transactionIds;

  int get priority {
    switch (severity) {
      case GuardSeverity.high:
        return 3;
      case GuardSeverity.medium:
        return 2;
      case GuardSeverity.low:
        return 1;
    }
  }
}

/// Aggregate protection status for the header/banner.
@immutable
class GuardSummary {
  const GuardSummary({
    required this.alerts,
    required this.totalAtRisk,
    required this.totalPotentialSaving,
  });

  final List<GuardAlert> alerts;
  final double totalAtRisk;
  final double totalPotentialSaving;

  bool get isProtected => alerts.isEmpty;
  int get count => alerts.length;
}
