# Spendly 💸

**Automatic expense tracker for India.** Spendly reads your bank & UPI SMS
alerts and turns every debit and credit into a categorized transaction —
automatically. No more manual entry: it tells you exactly *where, when and how
much* your money went.

Built with **Flutter (Android)** + **Supabase** (cloud sync).

---

## ✨ Features (v1)

- 📩 **Automatic SMS capture** — parses bank/UPI alerts (HDFC, SBI, ICICI, Axis,
  PhonePe, GPay, Paytm and more) on-device and logs them instantly.
- 🏷️ **Smart auto-categorization** — Zomato → Food, Uber → Travel,
  Amazon → Shopping, Netflix → Entertainment, and so on.
- 📊 **Dashboard** — balance card, income vs expense split, recent activity.
- 📈 **Statistics** — Week / Month / Year spend chart + Top Spending breakdown.
- 🔍 **Search & filter** — find any merchant or filter income vs expense.
- ✏️ **Manual entry (fallback)** — add cash spends or anything SMS missed.
- 🔒 **Privacy first** — SMS are parsed on your phone; only the extracted
  transaction is synced, never the raw message.

## 🎨 Design

A premium fintech look: near-black "wallet" card with an orange→red gradient
accent, soft rounded white cards, bold typography (Plus Jakarta Sans), and a
bottom nav with a raised center **+** button.

---

## 🏗️ Architecture

```
lib/
├── main.dart                     App entry; boots Supabase only if configured
├── models/                       Immutable models (Transaction, Category)
├── data/                         Mock seed + merchant→category rules
├── services/
│   ├── sms_parser.dart           The parsing engine (pure Dart, unit-tested)
│   ├── sms_service.dart          Inbox backfill + live SMS listener
│   └── supabase_config.dart      Credentials via --dart-define
├── repositories/                 ChangeNotifier singleton, cache + cloud sync
├── screens/                      Home, Statistics, Transactions, Add, Profile
├── widgets/                      WalletCard, SummaryPills, TransactionTile, nav
└── theme/                        Colors, typography, spacing tokens

supabase/migrations/              Postgres schema + RLS + built-in categories
```

The repository keeps an **in-memory cache** seeded from mock data so the UI
works instantly and offline; when Supabase credentials + a session exist it
hydrates from and writes through to the cloud.

---

## 🚀 Running

```bash
flutter pub get

# Mock mode (no backend needed):
flutter run

# With a real Supabase project:
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

### Backend setup
Apply the migrations under `supabase/migrations/` to your Supabase project
(via the SQL editor or `supabase db push`). They create the `transactions`,
`accounts`, `categories` and `budgets` tables with row-level security so each
user can only access their own data.

---

## ✅ Quality

```bash
flutter analyze     # static analysis
flutter test        # unit tests (SMS parser + repository)
```

The SMS parser is covered by tests against real-world HDFC/SBI/ICICI/UPI
message formats, including OTP/promo rejection and auto-categorization.

---

## 🗺️ Roadmap (proposed)

**Phase 2 — Smart**
- 🔔 Budget alerts ("Food is over ₹5,000 this month")
- 🔁 Recurring subscription detection (Netflix, rent…)
- 🎯 Savings goals
- 📅 Monthly email/report summaries

**Phase 3 — Advanced**
- 🏦 Multiple accounts & wallets in one view
- 📷 Receipt scanning for cash spends
- 🤖 AI insights ("you spend more on weekends")
- 👨‍👩‍👧 Shared / family budgets
- 📤 Export to Excel / PDF (tax-friendly)
