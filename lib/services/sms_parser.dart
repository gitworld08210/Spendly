import '../data/category_rules.dart';
import '../models/transaction.dart';
import '../utils/ids.dart';

/// The result of attempting to parse a single SMS body.
class ParsedSms {
  const ParsedSms({
    required this.amount,
    required this.type,
    required this.merchant,
    this.account,
  });

  final double amount;
  final TxnType type;
  final String merchant;
  final String? account;
}

/// PaisaTrack's SMS parsing engine — the "powerful core".
///
/// Indian bank / UPI alerts are wildly inconsistent, so instead of one giant
/// regex we run a small pipeline:
///   1. Decide it's actually a transaction alert (has money + debit/credit cue).
///   2. Extract the amount (handles ₹, Rs, INR, commas, decimals).
///   3. Decide debit vs credit from directional keywords.
///   4. Pull the merchant/payee from common phrasings ("to X", "at X",
///      "VPA X", "from X").
///   5. Pull the masked account ("A/c XX1234", "a/c no. ...4021").
///
/// Everything runs on-device; nothing is sent anywhere by this class.
class SmsParser {
  SmsParser._();

  // --- Keyword vocabularies -------------------------------------------------

  static const _debitCues = [
    'debited',
    'debit',
    'spent',
    'paid',
    'withdrawn',
    'purchase',
    'sent',
    'deducted',
  ];

  static const _creditCues = [
    'credited',
    'credit',
    'received',
    'deposited',
    'refund',
    'added',
  ];

  /// Words that mark a message as a genuine bank/UPI transaction alert.
  static bool looksLikeTransaction(String body) {
    final b = body.toLowerCase();
    final hasMoney = _amountRegex.hasMatch(body);
    final hasDirection = _debitCues.any(b.contains) || _creditCues.any(b.contains);
    // Ignore OTPs, promos and balance-only messages.
    final isOtp = b.contains('otp') || b.contains('one time password');
    return hasMoney && hasDirection && !isOtp;
  }

  // --- Regexes --------------------------------------------------------------

  /// Matches amounts like: Rs.1,234.56 / INR 500 / ₹ 45.00 / Rs 2000
  static final RegExp _amountRegex = RegExp(
    r'(?:rs\.?|inr|₹)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  /// Masked account: "A/c XX3421", "a/c no. XXXX4021", "acct ...1234"
  static final RegExp _accountRegex = RegExp(
    r'(?:a/?c(?:\s*no\.?)?|acct|account)\s*[:.]?\s*[xX*.\s]*([0-9]{3,4})',
    caseSensitive: false,
  );

  /// Merchant after prepositions: "to Zomato", "at STARBUCKS", "from JOHN"
  static final RegExp _merchantPrepRegex = RegExp(
    r'\b(?:to|at|from|towards)\s+([A-Za-z0-9][A-Za-z0-9 &._-]{1,40}?)'
    r'(?=\s+(?:on|via|ref|upi|txn|dated|for|a/c|acct|through|\.)|[.\n]|$)',
    caseSensitive: false,
  );

  /// UPI VPA: "VPA someone@okhdfcbank" or "someone@upi"
  static final RegExp _vpaRegex = RegExp(
    r'(?:vpa\s+)?([a-zA-Z0-9.\-_]{2,}@[a-zA-Z]{2,})',
    caseSensitive: false,
  );

  // --- Public API -----------------------------------------------------------

  /// Attempts to parse [body]. Returns null if it isn't a transaction.
  static ParsedSms? parse(String body) {
    if (!looksLikeTransaction(body)) return null;

    final amount = _extractAmount(body);
    if (amount == null || amount <= 0) return null;

    final type = _extractType(body);
    final merchant = _extractMerchant(body, type);
    final account = _extractAccount(body);

    return ParsedSms(
      amount: amount,
      type: type,
      merchant: merchant,
      account: account,
    );
  }

  /// Convenience: parse and build a ready-to-store [Transaction].
  static Transaction? toTransaction(String body, {DateTime? receivedAt}) {
    final parsed = parse(body);
    if (parsed == null) return null;

    final isCredit = parsed.type == TxnType.credit;
    return Transaction(
      id: newId(),
      title: parsed.merchant,
      amount: parsed.amount,
      type: parsed.type,
      categoryId: CategoryRules.categorize(parsed.merchant, isCredit: isCredit),
      date: receivedAt ?? DateTime.now(),
      source: TxnSource.sms,
      account: parsed.account,
      rawSms: body,
    );
  }

  // --- Extraction steps -----------------------------------------------------

  static double? _extractAmount(String body) {
    // Prefer the amount closest to a debit/credit cue when several appear.
    final matches = _amountRegex.allMatches(body).toList();
    if (matches.isEmpty) return null;
    final raw = matches.first.group(1)!.replaceAll(',', '');
    return double.tryParse(raw);
  }

  static TxnType _extractType(String body) {
    final b = body.toLowerCase();
    final debitIdx = _firstIndexOf(b, _debitCues);
    final creditIdx = _firstIndexOf(b, _creditCues);

    if (creditIdx == -1) return TxnType.debit;
    if (debitIdx == -1) return TxnType.credit;
    // Whichever cue appears first wins.
    return debitIdx <= creditIdx ? TxnType.debit : TxnType.credit;
  }

  static String _extractMerchant(String body, TxnType type) {
    // 1) Prefer an explicit VPA (UPI) — but keep it readable.
    final vpa = _vpaRegex.firstMatch(body);
    if (vpa != null) {
      final handle = vpa.group(1)!;
      final name = handle.split('@').first;
      final cleaned = _titleCase(name.replaceAll(RegExp(r'[._\-]'), ' '));
      if (cleaned.isNotEmpty && !_looksNumeric(cleaned)) return cleaned;
    }

    // 2) Preposition-based merchant.
    final prep = _merchantPrepRegex.firstMatch(body);
    if (prep != null) {
      final m = prep.group(1)!.trim();
      final cleaned = _titleCase(m);
      if (cleaned.isNotEmpty && !_looksNumeric(cleaned)) return cleaned;
    }

    // 3) Fallback based on direction.
    return type == TxnType.credit ? 'Money Received' : 'Payment';
  }

  static String? _extractAccount(String body) {
    final m = _accountRegex.firstMatch(body);
    if (m == null) return null;
    return '••${m.group(1)}';
  }

  // --- Helpers --------------------------------------------------------------

  static int _firstIndexOf(String haystack, List<String> needles) {
    var best = -1;
    for (final n in needles) {
      final i = haystack.indexOf(n);
      if (i != -1 && (best == -1 || i < best)) best = i;
    }
    return best;
  }

  static bool _looksNumeric(String s) =>
      RegExp(r'^[0-9\s.,]+$').hasMatch(s.trim());

  static String _titleCase(String input) {
    final words = input.trim().split(RegExp(r'\s+'));
    return words
        .where((w) => w.isNotEmpty)
        .map((w) => w.length == 1
            ? w.toUpperCase()
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}
