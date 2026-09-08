# CraftConnect 🎨
### AI-Driven Market Linkage & Smart Cataloging for Marginalized Artisans
**SIH 2026 · PS 26090 · Ministry of Social Justice and Empowerment (MoSJE)**

> *"We don't teach artisans how to use e-commerce. We make e-commerce understand the artisan."*

---

## 🚀 Quick Start — Flutter App

### Prerequisites
- Flutter 3.44+ (`flutter --version`)
- Android Studio / Xcode for emulator
- **OR** physical Android/iOS device

### Run
```bash
# Install dependencies
flutter pub get

# Run on connected device or emulator
flutter run

# For demo mode (no Firebase needed):
# Tap "Demo Mode (Judges)" on the auth screen
```

### Firebase Setup (Real Auth)
1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Phone Authentication**
3. Register your Android app (package: `com.craftconnect.craft_connect`)
4. Download `google-services.json` → place in `android/app/`
5. For iOS: download `GoogleService-Info.plist` → place in `ios/Runner/`

---

## 🖥️ Quick Start — FastAPI Backend

### With Docker (recommended)
```bash
cd backend

# Copy and configure environment
cp .env.example .env
# Edit .env with your API keys (Groq, Bhashini, Firebase)

# Start all services (PostgreSQL, Redis, FastAPI, Celery)
docker-compose up -d

# API docs available at:
# http://localhost:8000/docs
```

### Without Docker
```bash
cd backend
pip install -r requirements.txt

# Set up PostgreSQL and Redis, update .env

# Run migrations
alembic upgrade head

# Start server
uvicorn main:app --reload --port 8000

# Start Celery worker (separate terminal)
celery -A app.workers.celery_app worker --loglevel=info
```

---

## 🏗️ Project Structure

```
Aakar/
├── lib/                          # Flutter app
│   ├── core/
│   │   ├── theme/               # Design system (colors, typography)
│   │   ├── routing/             # GoRouter navigation
│   │   └── services/            # API, Firebase, Mock AI services
│   ├── features/
│   │   ├── onboarding/          # Splash, Language, Onboarding slides
│   │   ├── auth/                # Phone OTP + Firebase Auth
│   │   ├── profile/             # Artisan setup (name, craft, state)
│   │   ├── dashboard/           # Product list + stats
│   │   ├── photo_capture/       # Guided capture + Enhancement
│   │   ├── cataloging/          # Voice → Listing (adaptive Q&A)
│   │   ├── pricing/             # Labour-aware pricing engine
│   │   └── b2b/                 # B2B readiness + channel connect
│   └── shared/
│       ├── models/              # Data models (Product, Listing, Pricing...)
│       └── widgets/             # Reusable UI components
├── backend/                      # FastAPI backend
│   ├── main.py                  # App factory
│   ├── app/
│   │   ├── core/                # Config, DB, Firebase auth
│   │   ├── routers/             # auth, products, catalog, pricing, b2b
│   │   ├── services/            # ASR (Bhashini), extraction, generation, pricing
│   │   └── models/              # SQLAlchemy ORM models
│   ├── docker-compose.yml       # Full stack: PG + Redis + FastAPI + Celery
│   └── .env.example             # Environment template
└── assets/                       # Images, animations, fonts
```

---

## 🎯 Key Differentiators

| Claim | Technical Backing |
|---|---|
| **Not just another AI cataloger** | Confidence-scored extraction → only asks for genuinely uncertain fields |
| **Craft-authentic photos** | Hue-preserving enhancement; original stored alongside enhanced |
| **Doesn't undervalue handmade labour** | Comparable set is handmade-only; cost floor is a hard constraint |
| **Artisan stays in control** | `verification_status` on every AI entity — nothing publishes without approval |
| **Built for low literacy** | Voice-first at every step, Hindi-primary throughout (not just labels) |

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Mobile App | Flutter 3.44 (Android + iOS) |
| State Management | Riverpod 2 |
| Navigation | GoRouter |
| Backend | FastAPI (Python 3.12) |
| Database | PostgreSQL + pgvector |
| Queue | Celery + Redis |
| Auth | Firebase Phone Auth |
| Storage | Firebase Storage |
| ASR | Bhashini (primary) + IndicConformer (fallback) |
| LLM | Groq/Llama-3.1 (demo) → self-hostable |
| Image ML | U²-Net/MODNet (ONNX) |

---

## 📱 App Flow

```
Splash → Language Select → Onboarding (3 slides)
  → Phone OTP Auth
  → Profile Setup (name, craft, state)
  → Dashboard

Dashboard → New Product:
  → Photo Capture (guided)
  → AI Enhancement (before/after compare)
  → Voice Describe
  → Attribute Extraction (confidence-scored)
  → Follow-up Q&A (only missing fields)
  → Bilingual Listing Preview
  → Artisan Verify & Approve
  → Pricing Input (material + labour + overhead)
  → AI Price Recommendation (with explanation)
  → Artisan Sets Final Price
  → B2B Readiness Check (GeM / ONDC / State Board)
  → Connect to Marketplace
```

---

## 🔑 API Keys Required

| Service | Where to Get | Free? |
|---|---|---|
| Firebase | [console.firebase.google.com](https://console.firebase.google.com) | Yes |
| Groq (LLM) | [console.groq.com](https://console.groq.com) | Yes (generous) |
| Bhashini ASR | [bhashini.gov.in/ulca/model-api-key](https://bhashini.gov.in) | Yes (govt) |

---

## 🏛️ Demo Mode

The app includes a full **demo bypass** — no Firebase or API keys needed:
- On Auth screen → tap **"Demo Mode (Judges)"**
- All AI features use realistic mock responses
- Complete flow: Photo → Catalog → Price → B2B works end-to-end

---

*Built for SIH 2026 · Team Aakar*
