# Sekreterim — Financial Tracker for Small Businesses

![Flutter](https://img.shields.io/badge/Flutter-Dart%203-02569B?logo=flutter)
![Platform](https://img.shields.io/badge/platform-Android-3DDC84?logo=android)
![License](https://img.shields.io/badge/license-MIT-blue)
![Status](https://img.shields.io/badge/status-work%20in%20progress-orange)


**Sekreterim** ("My Secretary") is an offline-first Flutter app that helps small business owners and bookkeepers keep track of **post-dated cheques and promissory notes**, counterparties, daily tasks and live FX / gold rates, all in one place.

In Turkey, cheques (*çek*) and notes (*senet*) are a core part of small-business cash flow, and are still commonly tracked on paper or in spreadsheets. This app replaces that with a phone-first workflow: snap a photo of a cheque, let on-device OCR read it, and get reminded before it falls due.

> 🚧 **Work in progress.** Core modules are working; see the [Roadmap](#roadmap) for what is next.

## Screenshots

<!-- Add 4–6 screenshots to docs/screenshots/ and uncomment -->
<!--
| Overview | Cheques | Calendar | Market |
|---|---|---|---|
| ![](docs/screenshots/overview.png) | ![](docs/screenshots/cheques.png) | ![](docs/screenshots/calendar.png) | ![](docs/screenshots/market.png) |
-->

## Features

| Module | What it does |
|---|---|
| **Overview** | Portfolio summary: total receivables vs. payables per currency, TL equivalent at live rates, net position, overdue items and the next 7 days of due dates |
| **Cheques & Notes** | Track receivable (green) and payable (red) items with amount, currency, due date, cheque no. and bank. Search, filter, sort by due date |
| **OCR entry** | Scan a cheque with the camera or gallery. Due date and amount are extracted on-device; manual entry is always available as a fallback |
| **Counterparties** | Company cards linked to cheques, with per-currency receivable/payable totals on the detail screen |
| **Calendar** | Monthly view with colour-coded markers for cheques and tasks |
| **Market** | Live FX, gold (14 types) and silver rates with buy/sell columns |
| **Tasks** | Daily to-do list with optional due dates that also show up on the calendar |
| **Reminders** | Local notifications at 3, 2 and 1 day(s) before a due date |
| **Export** | Share the currently filtered cheque list as CSV (opens correctly in Turkish Excel) |
| **Backup / Restore** | Export all data to a single JSON file and restore it later |

## Technical highlights

- **On-device OCR, no cloud.** Cheque images are processed locally with Google ML Kit text recognition. Financial documents never leave the phone. The parser extracts the due date (latest date on the document) and handles the different Turkish amount formats (`1.234,56`, `1234.56`, etc.).
- **Resilient market data.** Rates come from a primary source (Truncgil, FX + gold + silver) with automatic fallback to the Central Bank of Turkey (TCMB `today.xml`, FX only). The TL conversion handles quirks such as JPY being quoted per 100 units, and uses buy rates for receivables and sell rates for payables.
- **Local-first storage.** All data lives in [Hive](https://pub.dev/packages/hive) boxes. No backend or account is needed, and the app works fully offline except for rate refresh.
- **Referential integrity by design.** Deleting a counterparty does not delete its cheques. The links are cleared instead (`firmaSilVeCekleriAyir`).
- **Testable business logic.** CSV generation, amount parsing/formatting, date input formatting and backup/restore were extracted into pure utilities/services with unit tests. This includes a round-trip test (backup → wipe → restore → identical data) and rejection of invalid backup files.
- **Locale-aware.** Turkish localisation, `dd.MM.yyyy` dates, TR number formats, and CSV in `;`-delimited UTF-8 with BOM so Turkish Excel opens it without garbled characters.
- **Centralised theming.** Material 3 theme defined in one place (`UygulamaRenkleri` + `_temaOlustur()`), so screens use theme tokens rather than hard-coded colours.

## Tech stack

Flutter · Dart · Material 3 · Hive · Google ML Kit (text recognition) · flutter_local_notifications + timezone · table_calendar · http + xml · share_plus · file_picker · path_provider · intl

## Architecture

```
lib/
├── main.dart              # App bootstrap: Hive, notifications, locale, theme
├── views/                 # Screens (login, home shell, overview, cheques, calendar, market, companies, tasks)
├── widgets/               # Reusable UI (cheque card, company form)
├── services/              # Business logic and I/O
│   ├── database_services  # Hive boxes + company helpers
│   ├── ocr_service        # ML Kit + date/amount extraction
│   ├── doviz_service      # Market data with fallback + TL conversion
│   ├── notification_service
│   └── yedekleme_service  # JSON backup / restore
└── utils/                 # Pure helpers: money parsing, CSV builder, date input formatter
test/                      # Unit tests for utils and backup service
```

Navigation flow: `LoginView → HomeView (drawer + tabs) → Overview / Tasks / Cheques / Calendar / Market / Companies`

## Getting started

**Requirements:** Flutter SDK (Dart `^3.12.2`), Android Studio or VS Code, an Android device/emulator.

```bash
git clone https://github.com/KorkutOzdemir/sekreterim-app.git
cd sekreterim-app
flutter pub get
flutter run
```

Run checks:

```bash
flutter analyze
flutter test
```

Build a debug APK:

```bash
flutter build apk --debug
```

> The current login uses a placeholder credential (see [Known limitations](#known-limitations)), so check `lib/views/login_view.dart` to sign in during development.

## Known limitations

Being upfront about the current state of the project:

- **Authentication is a placeholder.** Credentials are hard-coded in `login_view.dart`. This is a development stub, not a security feature. It is being replaced (see roadmap).
- **No cheque editing yet.** Records can be created, marked paid and deleted, but not edited after creation.
- **OCR accuracy depends on photo quality.** Wrinkled or glare-heavy photos may not parse. The form warns and falls back to manual entry.
- **Verified on Android only.** Other Flutter platform folders exist but are untested.
- Uses a free public rates API; availability is not guaranteed (the TCMB fallback mitigates this).

## Roadmap

- [ ] Replace hard-coded login with a local PIN/biometric lock (`local_auth` + secure storage)
- [ ] Edit existing cheques / notes
- [ ] Widget and integration tests for the main flows
- [ ] CI: build APK artifact on release tags
- [ ] Charts for monthly cash-flow forecast
- [ ] Optional encrypted backups
- [ ] English UI localisation


