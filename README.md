# Idir Connect — Full-Stack Platform

A digital platform modernizing Ethiopian community mutual-aid associations (**Idirs**) and rotating savings groups (**Ikub**).

---

## 📁 Repository Structure

```
Idir/
├── frontend/               # Mobile Application (Flutter, Riverpod, Material 3)
│   ├── lib/                # Flutter source code (auth, idir, claims, contributions)
│   ├── android/            # Android native project files
│   ├── web/                # Flutter Web runner
│   ├── assets/             # Fonts (Noto Sans Ethiopic) & icons
│   ├── pubspec.yaml        # Flutter dependencies & metadata
│   └── test/               # Flutter unit & widget tests
│
├── backend/                # REST API & Database (Express, TypeScript, PostgreSQL, Prisma)
│   ├── src/                # Modular monolith (auth, idirs, members, ikub, reports)
│   ├── prisma/             # Relational schema (21 entities) & seed script
│   ├── tests/              # Vitest & Supertest automated test suites
│   ├── docker-compose.yml  # Local PostgreSQL 16 container setup
│   └── package.json        # Node.js backend dependencies & scripts
│
├── .gitignore              # Shared monorepo gitignore
└── README.md               # Monorepo documentation
```

---

## 🚀 Getting Started

### 1. Backend REST API & Database
```bash
cd backend

# Start PostgreSQL database (Docker)
docker-compose up -d postgres

# Install dependencies & run migrations
npm install
npm run prisma:migrate
npm run prisma:seed

# Start development server
npm run dev
# -> API running at http://localhost:5000/api/v1
# -> Swagger Docs at http://localhost:5000/api/docs
```

### 2. Frontend Mobile App (Flutter)
```bash
cd frontend

# Install Flutter dependencies
flutter pub get

# Generate localization files
flutter gen-l10n

# Run mobile app
flutter run
```

---

## 👥 Module Ownership & Architecture
* Backend Architecture & DB Schema: [backend/README.md](file:///c:/Users/HP/Desktop/Idir/backend/README.md)
* Three-Developer Team Ownership: [backend/MODULE_OWNERSHIP.md](file:///c:/Users/HP/Desktop/Idir/backend/MODULE_OWNERSHIP.md)
* Deferred Features & Roadmap: [backend/DEFERRED_FEATURES.md](file:///c:/Users/HP/Desktop/Idir/backend/DEFERRED_FEATURES.md)
