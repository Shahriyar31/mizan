# تَدَبُّر · Taddabur

> *"Will they not reflect upon the Quran?"* — Surah Muhammad 47:24

A Flutter mobile application that helps Muslims build a consistent, deep relationship with their deen — breaking the motivation-loss-return cycle through community accountability, structured learning, and daily habit formation.

---

## Table of Contents

- [Problem Statement](#problem-statement)
- [Solution](#solution)
- [Features](#features)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Development Setup](#development-setup)
- [SDLC & Branching Strategy](#sdlc--branching-strategy)
- [Environment Configuration](#environment-configuration)
- [API Documentation](#api-documentation)
- [Database Schema](#database-schema)
- [Testing Strategy](#testing-strategy)
- [Deployment](#deployment)
- [Contributing](#contributing)
- [License](#license)

---

## Problem Statement

Muslims globally experience a recurring cycle: spiritual motivation → engagement with deen → dunya pulls them away → they forget → guilt → return → repeat. Existing Islamic apps address content access but not this behavioral cycle. They are libraries, not companions.

Specific gaps identified through user research:
- Tafseer exists but reads like an encyclopedia — no narrative pull, no context
- No community accountability feature in any existing app
- Quran memorized without understanding meaning (e.g. salah surahs recited 17× daily without comprehension)
- Public Islamic content platforms allow unverified opinions and school-of-thought conflicts
- No app designed around the akhirah orientation as a daily behavioral anchor

---

## Solution

Taddabur is built around three psychological engagement pulls that drive daily return:

| Pull | Mechanism | Feature |
|------|-----------|---------|
| Social | Unresolved social information | Halaqa — someone in your circle shared something |
| Curiosity | Episodic content that cannot be binged | Ayah of the Week — one layer unlocks per day |
| Identity Mirror | Seeing your own growth reflected back | Growth Map — personal knowledge constellation |

---

## Features

### Core Features

| Feature | Description | Phase |
|---------|-------------|-------|
| Home (4 states) | Wird / Returning / Friday / Muhasabah — app reads your state | 3 |
| Quran Tab | Full surah list, interactive ayah with 5-layer tafseer system | 1 |
| Discover Tab | Seerah, 25 Prophets, 100 Sahabah, 99 Names of Allah | 4 |
| Halaqa | Authenticated content sharing, 5-8 members, no opinions | 5 |
| Growth Tab | Growth Map, Vocabulary Bank, Seerah Timeline, Scholar AI | 2 |
| Al-Minbar | Public authenticated content feed, no comments | 5 |

### Tafseer Layer System
Each ayah has 5 layers unlocking one per day — Monday to Friday:
1. **Words** — root, meaning, why this specific word
2. **Context** — Asbab al-Nuzul, historical scene
3. **Scholars** — Ibn Kathir, As-Sa'di, Al-Qurtubi (switchable)
4. **Isnad** — chain of narrators, each tappable to biography
5. **Your Layer** — personal private reflection

### Scholar AI — Citation Lock
- Every answer must cite: Quran ayah, hadith (book/number/grade), or named tafseer
- If no verified source exists, AI refuses and suggests consulting a scholar
- RAG pipeline: Azure AI Search + Azure OpenAI
- Responds in user's chosen language
- Knowledge base: Ibn Kathir tafseer, Quran.com API, Sunnah.com API

### Halaqa Rules (enforced by design, not moderation)
- Authenticated app content only — no user-generated theology
- One optional personal line per share: *why this moved me today*
- Three reactions: 🤲 Du'a · 💙 Resonated · ✨ Moved me
- No text replies ever
- Nudge alerts a circle member, not the person who drifted

---

## Architecture

### System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter App (Client)                  │
│                                                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │  Home    │ │  Quran   │ │ Discover │ │  Halaqa  │  │
│  │ (4states)│ │  + Tafs. │ │ Seerah   │ │ Minbar   │  │
│  │          │ │          │ │ Sahabah  │ │          │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘  │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │              Riverpod State Management            │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │              Service Layer                        │   │
│  │  QuranService │ HadithService │ AIService         │   │
│  │  SupabaseService │ LocalStorageService            │   │
│  └──────────────────────────────────────────────────┘   │
└──────────────┬──────────────────────────────────────────┘
               │
       ┌───────┴────────┐
       │                │
┌──────▼──────┐  ┌──────▼──────────────────────────────┐
│  Supabase   │  │         External APIs                 │
│             │  │                                       │
│ PostgreSQL  │  │  Quran.com API  (free, no auth)      │
│ Auth        │  │  Sunnah.com API (free, no auth)      │
│ Realtime    │  │  Azure OpenAI   (student credits)    │
│ Storage     │  │  Azure AI Search(student credits)    │
│             │  │  Firebase FCM   (free tier)          │
└─────────────┘  └───────────────────────────────────────┘
```

### RAG Pipeline Architecture (Scholar AI)

```
User Question (any language)
         │
         ▼
  Language Detection
         │
         ▼
  Query Embedding
  (Azure OpenAI ada-002)
         │
         ▼
  Azure AI Search
  ┌──────────────────────────────┐
  │  Index 1: Ibn Kathir Tafseer │
  │  Index 2: Hadith Collections │
  │  Index 3: Seerah Content     │
  │  Index 4: Sahaba Biographies │
  └──────────────────────────────┘
         │
         ▼
  Retrieved Chunks + Citations
         │
         ▼
  Azure OpenAI GPT-4o
  (with Citation Lock prompt)
         │
         ▼
  Response + Citations (in user's language)
         │
         ▼
  Citation Verification Layer
  (confirms source exists in index)
         │
         ▼
  Display to User
```

### Database Architecture (Supabase PostgreSQL)

```
users
├── id (uuid, PK)
├── email
├── display_name
├── language_preference (en/bn/hi)
├── created_at
└── last_active_at

user_progress
├── id (uuid, PK)
├── user_id (FK → users)
├── ayah_id (surah_number + ayah_number)
├── layer_completed (1-5)
├── completed_at
└── reflection_text (encrypted)

vocabulary_bank
├── id (uuid, PK)
├── user_id (FK → users)
├── arabic_word
├── root
├── meaning_en
├── times_seen (int)
├── next_review_at (timestamp)
└── saved_at

muhasabah_entries
├── id (uuid, PK)
├── user_id (FK → users)
├── date
├── q1_answer (encrypted)
├── q2_answer (encrypted)
├── q3_answer (encrypted)
└── created_at

halaqas
├── id (uuid, PK)
├── name
├── created_by (FK → users)
├── invite_code (unique)
├── max_members (8)
└── created_at

halaqa_members
├── id (uuid, PK)
├── halaqa_id (FK → halaqas)
├── user_id (FK → users)
├── joined_at
└── last_opened_at

halaqa_shares
├── id (uuid, PK)
├── halaqa_id (FK → halaqas)
├── shared_by (FK → users)
├── content_id (references app content)
├── content_type (quran/hadith/sahabi/name/prophet)
├── personal_note (max 100 chars, optional)
└── shared_at

minbar_shares
├── id (uuid, PK)
├── shared_by (FK → users)
├── content_id
├── content_type
├── dua_count (int)
├── resonated_count (int)
└── shared_at

friday_reflections
├── id (uuid, PK)
├── user_id (FK → users)
├── week_date
├── reflection (encrypted)
└── created_at
```

### Feature-Based Folder Architecture

```
lib/
├── main.dart                        # Entry point only — 10 lines max
├── app.dart                         # MaterialApp, theme, router init
│
├── core/                            # Shared foundation — no business logic
│   ├── theme/
│   │   ├── app_colors.dart          # Every color constant
│   │   ├── app_typography.dart      # Every text style
│   │   └── app_theme.dart           # ThemeData assembly
│   ├── constants/
│   │   ├── api_constants.dart       # Base URLs, endpoints
│   │   ├── app_constants.dart       # Layer count, max members, etc.
│   │   └── asset_constants.dart     # Asset paths
│   ├── router/
│   │   └── app_router.dart          # All GoRouter routes
│   ├── errors/
│   │   ├── app_exception.dart       # Custom exception types
│   │   └── error_handler.dart       # Global error handling
│   └── utils/
│       ├── date_utils.dart          # Hijri date helpers
│       ├── arabic_utils.dart        # RTL and Arabic text helpers
│       └── logger.dart              # Structured logging
│
├── shared/                          # Reusable across features
│   ├── widgets/
│   │   ├── arabic_text.dart         # Amiri font Arabic display
│   │   ├── citation_block.dart      # Reusable citation display
│   │   ├── type_badge.dart          # Content type badges
│   │   ├── loading_shimmer.dart     # Skeleton loaders
│   │   └── reaction_row.dart        # Du'a/Resonated/Moved buttons
│   └── models/
│       ├── ayah.dart                # Ayah data model
│       ├── hadith.dart              # Hadith data model
│       ├── sahabi.dart              # Sahabi data model
│       └── content_card.dart        # Minbar/Halaqa card model
│
├── services/                        # External integrations
│   ├── supabase/
│   │   ├── supabase_client.dart     # Singleton client
│   │   └── supabase_auth.dart       # Auth methods
│   ├── quran/
│   │   └── quran_api_service.dart   # Quran.com API
│   ├── hadith/
│   │   └── hadith_api_service.dart  # Sunnah.com API
│   ├── ai/
│   │   ├── scholar_ai_service.dart  # Azure RAG calls
│   │   └── citation_verifier.dart   # Citation lock logic
│   ├── local/
│   │   ├── database_service.dart    # SQLite setup
│   │   └── vocabulary_service.dart  # Local vocab operations
│   └── notifications/
│       └── fcm_service.dart         # Firebase messaging
│
└── features/                        # One folder per feature
    ├── home/
    │   ├── data/
    │   │   └── wird_repository.dart
    │   ├── domain/
    │   │   └── home_state.dart      # Which of 4 states to show
    │   └── presentation/
    │       ├── home_screen.dart
    │       ├── states/
    │       │   ├── wird_state_view.dart
    │       │   ├── returning_state_view.dart
    │       │   ├── friday_state_view.dart
    │       │   └── muhasabah_state_view.dart
    │       └── widgets/
    │           ├── meezan_strip.dart
    │           ├── aow_card.dart    # Ayah of Week card
    │           └── tomorrow_teaser.dart
    │
    ├── quran/
    │   ├── data/
    │   │   ├── quran_repository.dart
    │   │   └── quran_local_cache.dart
    │   ├── domain/
    │   │   └── layer_unlock_logic.dart  # Which layer is available today
    │   └── presentation/
    │       ├── surah_list_screen.dart
    │       ├── ayah_detail_screen.dart
    │       ├── contemplation_screen.dart
    │       └── widgets/
    │           ├── word_chip.dart
    │           ├── word_popup.dart
    │           ├── layer_tabs.dart
    │           └── layer_panels/
    │               ├── words_panel.dart
    │               ├── context_panel.dart
    │               ├── scholars_panel.dart
    │               ├── isnad_panel.dart
    │               └── reflection_panel.dart
    │
    ├── discover/
    │   ├── data/
    │   │   └── discover_repository.dart
    │   └── presentation/
    │       ├── discover_screen.dart
    │       ├── seerah/
    │       │   ├── seerah_screen.dart
    │       │   └── seerah_timeline.dart
    │       ├── prophets/
    │       │   ├── prophets_list_screen.dart
    │       │   └── prophet_detail_screen.dart
    │       ├── sahabah/
    │       │   ├── sahabah_list_screen.dart
    │       │   └── sahabi_detail_screen.dart
    │       └── names/
    │           ├── names_grid_screen.dart
    │           └── name_detail_screen.dart
    │
    ├── halaqa/
    │   ├── data/
    │   │   └── halaqa_repository.dart
    │   └── presentation/
    │       ├── halaqa_screen.dart
    │       ├── create_halaqa_screen.dart
    │       ├── join_halaqa_screen.dart
    │       └── widgets/
    │           ├── member_ring.dart
    │           ├── nudge_card.dart
    │           └── share_feed_item.dart
    │
    ├── growth/
    │   ├── data/
    │   │   └── growth_repository.dart
    │   └── presentation/
    │       ├── growth_screen.dart
    │       └── widgets/
    │           ├── growth_map.dart
    │           ├── vocabulary_bank.dart
    │           └── seerah_timeline_widget.dart
    │
    ├── scholar_ai/
    │   ├── data/
    │   │   └── ai_chat_repository.dart
    │   └── presentation/
    │       ├── scholar_ai_screen.dart
    │       └── widgets/
    │           ├── chat_bubble.dart
    │           └── citation_display.dart
    │
    └── minbar/
        ├── data/
        │   └── minbar_repository.dart
        └── presentation/
            ├── minbar_screen.dart
            └── widgets/
                ├── minbar_card.dart
                ├── card_types/
                │   ├── quran_card.dart
                │   ├── sahabi_card.dart
                │   ├── hadith_card.dart
                │   ├── name_card.dart
                │   └── prophet_card.dart
                ├── reaction_footer.dart
                └── context_drawer.dart
```

---

## Tech Stack

| Layer | Technology | Reason | Cost |
|-------|-----------|--------|------|
| Mobile App | Flutter (Dart) | Single codebase Android + iOS | Free |
| State Management | Riverpod | Compile-safe, testable, no boilerplate | Free |
| Navigation | GoRouter | Declarative, deep-link ready | Free |
| Backend | Supabase | PostgreSQL + Auth + Realtime | Free tier |
| AI / RAG | Azure OpenAI + AI Search | Student credits, same as Nordex | Student credits |
| Quran Content | Quran.com API | Free, word-level, multilingual verified | Free |
| Hadith Content | Sunnah.com API | Free, all collections, authenticity grades | Free |
| Notifications | Firebase FCM | Free tier, unlimited messages | Free |
| Local Storage | SQLite (sqflite) | Offline vocab bank, chat cache | Free |
| Tafseer Content | Ibn Kathir JSON (GitHub) | Open source, structured, complete | Free |
| Containerization | Docker | Local Supabase + AI dev environment | Free |
| Version Control | GitHub | Private repo, CI/CD later | Free |
| Infrastructure | Terraform | IaC for Azure resources (Phase 3+) | Free |

---

## Development Setup

### Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Ubuntu | 22.04+ | Development OS |
| Flutter | 3.19+ | App framework |
| Dart | 3.3+ | Language (comes with Flutter) |
| Android Studio | Latest | Android SDK + Emulator |
| VS Code | Latest | Code editor |
| Git | 2.40+ | Version control |
| Docker | 24.0+ | Local services |
| Java JDK | 17 | Android compilation |

### Installation (Ubuntu)

```bash
# 1. Update system
sudo apt update && sudo apt upgrade -y

# 2. Install Git
sudo apt install git -y
git config --global user.name "Your Name"
git config --global user.email "your@email.com"

# 3. Install VS Code
sudo snap install code --classic

# 4. Install Flutter
sudo snap install flutter --classic
flutter sdk-path

# 5. Install Java (required for Android)
sudo apt install openjdk-17-jdk -y

# 6. Install Android Studio
sudo snap install android-studio --classic
# Then open Android Studio, complete setup wizard
# Install Android SDK API 34
# Create Pixel 7 emulator

# 7. Accept Android licenses
flutter doctor --android-licenses

# 8. Install Docker
sudo apt install docker.io -y
sudo usermod -aG docker $USER
newgrp docker

# 9. Verify everything
flutter doctor -v
```

### Project Setup

```bash
# Clone repository
git clone https://github.com/YOUR-USERNAME/taddabur.git
cd taddabur

# Install Flutter dependencies
flutter pub get

# Copy environment file
cp .env.example .env
# Fill in your keys (see Environment Configuration)

# Start local Supabase
docker-compose up -d

# Run app
flutter run
```

---

## SDLC & Branching Strategy

### Branch Structure

```
main                    # Production only — protected
├── develop             # Integration branch — all features merge here
│   ├── feature/home-wird-screen
│   ├── feature/quran-surah-list
│   ├── feature/scholar-ai-rag
│   └── feature/halaqa-sharing
├── release/v1.0.0      # Release preparation
└── hotfix/fix-arabic-font   # Emergency production fixes
```

### Branch Naming Convention

```
feature/    → new functionality        feature/quran-layer-system
fix/        → bug fixes                fix/word-tap-popup-overflow
refactor/   → code restructuring       refactor/supabase-service-layer
docs/       → documentation only       docs/api-integration-guide
test/       → adding tests             test/scholar-ai-citation-lock
chore/      → tooling, dependencies    chore/update-flutter-3.19
```

### Commit Message Convention (Conventional Commits)

```
<type>(<scope>): <description>

feat(quran): add word-tap popup with root and meaning
fix(halaqa): prevent text replies in share feed
refactor(scholar-ai): extract citation verifier to separate service
docs(readme): update database schema with friday_reflections table
test(auth): add unit tests for Supabase auth service
chore(deps): upgrade supabase_flutter to 2.3.0
```

**Types:** feat, fix, refactor, docs, test, chore, style, perf

### Pull Request Process (even solo — builds the habit)

1. Create feature branch from `develop`
2. Write code + tests
3. Self-review using PR checklist
4. Merge to `develop`
5. Weekly: merge `develop` → `main` if stable

### PR Checklist (self-review)

```
[ ] Feature works as designed in prototype
[ ] No hardcoded strings (use constants)
[ ] No API keys in code (use .env)
[ ] Arabic text uses ArabicText widget (not raw Text)
[ ] Error states handled (loading, empty, error)
[ ] No print() statements (use logger)
[ ] Widget has been tested on emulator
[ ] Commit messages follow convention
```

---

## Environment Configuration

### .env.example

```env
# Supabase
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key

# Azure OpenAI
AZURE_OPENAI_ENDPOINT=your_azure_endpoint
AZURE_OPENAI_API_KEY=your_azure_key
AZURE_OPENAI_DEPLOYMENT=gpt-4o

# Azure AI Search
AZURE_SEARCH_ENDPOINT=your_search_endpoint
AZURE_SEARCH_API_KEY=your_search_key
AZURE_SEARCH_INDEX=taddabur-knowledge-base

# Firebase
FIREBASE_PROJECT_ID=your_firebase_project_id

# Feature flags (1=on, 0=off)
FEATURE_MINBAR=0
FEATURE_HALAQA=0
FEATURE_SCHOLAR_AI=0
```

Feature flags are critical for enterprise development. You ship code that's turned off. When it's ready, you flip the flag. No big-bang releases.

### Never commit .env

```gitignore
# .gitignore — always include these
.env
*.env
.env.*
!.env.example
```

---

## API Documentation

### Quran.com API

```
Base URL: https://api.quran.com/api/v4

Endpoints used:
GET /chapters                          # All 114 surahs
GET /chapters/{id}                     # Single surah info
GET /verses/by_chapter/{chapter_id}   # All ayat in surah
GET /verses/by_key/{verse_key}        # Single ayah (e.g. 1:1)

Query params:
  language=en              # Translation language
  word_fields=text_uthmani,translation,transliteration
  translations=131         # Translation ID (131=Sahih International)

No API key required for public endpoints.
```

### Sunnah.com API

```
Base URL: https://api.sunnah.com/v1

Endpoints used:
GET /collections                       # All hadith collections
GET /collections/{name}/books          # Books in collection
GET /collections/{name}/hadiths       # Hadith list
GET /hadiths/random                   # Random hadith

Headers required:
  X-API-Key: your_api_key             # Free key from sunnah.com
```

---

## Testing Strategy

### Test Pyramid

```
        ┌─────────────────┐
        │   E2E Tests     │  ← Few, slow, expensive
        │  (Integration)  │    Patrol or integration_test
        ├─────────────────┤
        │  Widget Tests   │  ← Some, medium speed
        │                 │    Flutter widget testing
        ├─────────────────┤
        │   Unit Tests    │  ← Many, fast, cheap
        │                 │    Pure Dart logic tests
        └─────────────────┘
```

### What to Test First (Phase 1-2)

```
Unit tests:
├── layer_unlock_logic.dart     # Is the right layer available today?
├── citation_verifier.dart      # Does Citation Lock work correctly?
├── spaced_repetition_logic.dart # Are vocab reviews scheduled right?
└── home_state_selector.dart    # Is the right home state detected?

Widget tests:
├── arabic_text_widget_test     # Does Arabic display RTL correctly?
├── citation_block_test         # Does citation render with source?
└── word_chip_tap_test          # Does tapping a word show popup?
```

### Test File Convention

```
test/
├── unit/
│   ├── features/
│   │   ├── quran/
│   │   │   └── layer_unlock_logic_test.dart
│   │   └── scholar_ai/
│   │       └── citation_verifier_test.dart
│   └── services/
│       └── quran_api_service_test.dart
├── widget/
│   └── shared/
│       ├── arabic_text_test.dart
│       └── citation_block_test.dart
└── integration/
    └── quran_browsing_flow_test.dart
```

---

## Deployment

### Phase 1-2: Direct APK (no store)
```bash
flutter build apk --release
# Share APK directly to test users via file transfer
```

### Phase 5: F-Droid (free, open-source)
- Submit via https://gitlab.com/fdroid/fdroiddata
- App must be fully open-source
- Build reproducible — F-Droid builds from source

### Phase 5: Google Play Store ($25 one-time)
```bash
flutter build appbundle --release
# Upload to Google Play Console
```

### Phase 6: Apple App Store ($99/year)
```bash
# Requires Mac + Xcode
flutter build ios --release
# Upload via Xcode or Transporter
```

---

## Islamic Content Standards

These are non-negotiable and apply to every line of content in the app:

1. **No machine translation** — only verified scholarly translations
2. **Every hadith must carry** — book name, hadith number, narrator, authenticity grade
3. **Every tafseer quote must carry** — scholar name, work name, volume/page where possible
4. **Scholarly disagreement is preserved** — not flattened into one opinion
5. **Bengali content** — Muhammad Muhiuddin Khan translation via Quran.com API
6. **Hindi content** — Fateh Muhammad Jalandhri translation via Quran.com API
7. **Weak hadith (Da'if)** — displayed with grade clearly marked, never presented as guidance
8. **Halaqa content** — authenticated passages only, no user theology ever

---

## License

MIT License — open source from day one.

See [LICENSE](LICENSE) for full text.

---

## Acknowledgements

- Quran.com — free Quran API with word-level data
- Sunnah.com — free authenticated hadith API
- Ibn Kathir tafseer JSON — open source community
- Supabase — open source Firebase alternative
- Flutter team — enabling cross-platform development

---

*Built with the intention of helping the ummah — li-wajhillah.*