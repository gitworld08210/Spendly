import 'package:flutter/foundation.dart' hide Category;

/// Priority/tone of an insight — drives the color and sort order.
enum InsightSeverity { positive, info, warning, critical }

/// What kind of insight it is (for icon selection + grouping).
enum InsightKind {
  savingsOpportunity,
  trendSpike,
  trendDrop,
  subscriptionAudit,
  monthEndProjection,
  savingsTarget,
  personality,
  budgetOverrun,
}

/// A single generated insight the user sees on the Insights screen.
@immutable
class Insight {
  const Insight({
    required this.kind,
    required this.severity,
    required this.title,
    required this.message,
    this.categoryId,
    this.potentialSaving = 0,
  });

  final InsightKind kind;
  final InsightSeverity severity;
  final String title;
  final String message;

  /// Optional category this insight is about (for the glyph).
  final String? categoryId;

  /// Estimated ₹/month the user could save by acting on this. 0 if N/A.
  final double potentialSaving;

  /// Higher = shown first.
  int get priority {
    switch (severity) {
      case InsightSeverity.critical:
        return 4;
      case InsightSeverity.warning:
        return 3;
      case InsightSeverity.info:
        return 2;
      case InsightSeverity.positive:
        return 1;
    }
  }
}
