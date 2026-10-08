# Meal Prep

Book a verified home cook to come to your kitchen and cook fresh meals: daily lunch or dinner, weekly meal prep, or a party. The app also has ready-made diet charts with nutrition and grocery lists, plus AI agents that plan meals and book cooks for you.

```
Meal_Prep/
├── setup_mac.sh        # one-time: installs Postgres.app, pgAdmin, Firebase CLI, uv, FlutterFire, then runs update_mac.sh
├── update_mac.sh       # run after every code update: deps, icons, tests, analyzer → logs/
├── run_backend.sh      # API on :8000
├── backend/            # FastAPI + SQLAlchemy + PostgreSQL
│   ├── app/
│   │   ├── foods.py          # ~75 Indian dishes: nutrition + ingredients
│   │   ├── plans.py          # 10 curated weekly diet charts, nutrition & grocery maths
│   │   ├── ai/               # providers (Azure OpenAI · Claude · Ollama · offline demo), tools, 4 agents
│   │   └── routers/          # me, cooks, bookings, meal-plans, stats, ai
│   └── tests/
└── app/                # Flutter (Android / iOS / web)
    ├── assets/emoji/   # 3D food artwork (Noto 3D Emoji, OFL)
    ├── assets/fonts/   # Poppins (OFL)
    └── lib/
        ├── theme/      # design system
        ├── widgets/    # cards, charts (fl_chart), skeletons, 3D art
        └── screens/    # intro, login, customer (home/cooks/booking), plans, ai, bookings, insights, cook/*
```

## Run it

```bash
cd ~/Meal_Prep
bash update_mac.sh                 # after each code drop (first time: bash setup_mac.sh)
bash run_backend.sh                # API + Swagger UI at http://localhost:8000/docs
cd app && flutter run -d chrome    # or an Android emulator / iOS simulator
```

Dev login needs no OTP:

- **Customer:** any 10-digit number signs you in as a customer.
- **Cook:** `9000000001` to `9000000003` are the seeded demo cooks.

## Features

**Customers**

- Onboarding carousel and phone login.
- Home screen:
  - greeting with your location, and cook search;
  - an AI banner;
  - quick actions: daily meals, meal prep, party, diet charts;
  - plan carousel, cuisine explorer, top cooks and "how it works".
- Cook search by pincode, cuisine and veg-only, sortable by rating or price.
- Rich cook profiles: rating, verification, languages and signature dishes.
- Booking flow with live price breakdown, date and time pickers, a guests stepper, and an optional diet chart. The booking can also be drafted by AI.
- **Diet charts:** 10 curated weekly plans.
  - Menu by day.
  - Nutrition charts: macro donut, calorie trend, stacked macros per day, protein per day.
  - Grocery checklist scaled to your household, with copy-to-clipboard.
- Bookings split into Upcoming and Past, with a progress tracker, cancel, and rating.
- Insights: spend by month, meal-type and cuisine split, and status overview.

**Cooks**

- Dashboard: availability toggle, profile completeness, earnings chart, new requests and next jobs.
- Profile editor: cuisine and language chips, pincodes, rate, dishes, and "Improve with AI".
- Jobs: accept or decline, start and complete.

**AI agents**

Each agent uses tools against the real database.

| Agent | For | What it does |
|---|---|---|
| Meal Planner | customers | Understands your household, then picks or builds a 7-day plan, adds nutrition and a grocery list, finds a cook, and drafts a booking |
| Cook Finder | customers | Takes a request like "Kerala veg cook near 560034 Saturday 8am under ₹400", shortlists cooks, quotes a price and drafts a booking |
| Nutrition & Grocery | customers | Explains macros, suggests swaps, builds grocery lists and saves improved plans |
| Cook Assistant | cooks | Writes your bio, checks your pricing against nearby cooks, suggests dishes and summarises jobs |

Bookings and profile edits are only **drafts**. They take effect when the user taps **Confirm** or **Apply** in the app.

### AI providers

Set these in `backend/.env`. You can also switch provider in the app: open the AI tab and tap the model chip.

```
AI_PROVIDER=azure            # default: mock | azure | anthropic | ollama

AZURE_OPENAI_ENDPOINT=https://<resource>.openai.azure.com
AZURE_OPENAI_API_KEY=...
AZURE_OPENAI_DEPLOYMENT=<your deployment name>

ANTHROPIC_API_KEY=...
ANTHROPIC_MODEL=claude-sonnet-5-5

OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=llama3.1:8b     # any model with tool calling: `ollama pull llama3.1:8b`
```

`mock` is an offline rule-based demo. It works with no keys, so every card, chart and booking draft can be tried immediately.

## Firebase phone-OTP login

1. Run `firebase login`.
2. Create a project and enable **Authentication → Phone**.
3. Run `cd app && flutterfire configure`. This overwrites `lib/firebase_options.dart`.
4. For Android, add the debug SHA-1 (from `cd android && ./gradlew signingReport`) in the Firebase console.
5. Put the service-account JSON in `backend/` and set `AUTH_MODE=firebase` and `FIREBASE_CREDENTIALS=...` in `backend/.env`.
6. Run `flutter run --dart-define=USE_FIREBASE=true`.

## Notes

- **Real phone:** use `flutter run --dart-define=API_URL=http://<mac-LAN-ip>:8000`. The Android emulator uses `10.0.2.2` automatically.
- **Nutrition values:** approximate, per person.
- **Credits:** 3D artwork is Noto 3D Emoji (SIL OFL), see `app/assets/emoji/LICENSE-Noto-Emoji-OFL.txt`. Font: Poppins (OFL).

## Next up

- Alembic migrations
- Razorpay / UPI payments
- Push notifications (FCM) for new requests and status changes
- Cook KYC flow and admin panel
- Recurring bookings
- Streaming AI responses
