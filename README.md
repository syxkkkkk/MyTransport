# MyTransport Malaysia 🚆

> **AI-Powered Real-Time Public Transportation Companion for Malaysia**

MyTransport is a full-stack application that helps users navigate Malaysia's public transit system with real-time departures, AI-powered route planning, AR navigation, and a Gemini-powered chatbot assistant.

---

## Project Structure

```
MyTransport/
├── MyTransport/          # Web app (React + TypeScript + Vite)
├── backend/              # REST API (Node.js + Express + TypeScript + Prisma)
└── flutter_mytransport/  # Mobile app (Flutter / Dart)
```

---

## Features

### Screens & Pages
| Screen | Description |
|---|---|
| **Welcome** | Onboarding / splash screen |
| **Home** | Dashboard with quick access to transit options |
| **Location Selection** | Search and pick origin & destination |
| **Route Details** | Step-by-step route with fare, duration, and distance |
| **Chatbot** | Gemini AI-powered assistant for transit queries |
| **Trip Summary** | Review completed or planned trips |
| **AR Navigation** | Camera + compass-based augmented reality navigation |
| **Live Train Notifications** | Real-time departure status and transit alerts |

### Core Capabilities
- **Real-Time Departures** — Live train/transit departure times with ON_TIME / DELAYED / CANCELLED status
- **Route Planning** — Multi-modal route suggestions with fare estimates (MYR)
- **AI Chatbot** — Powered by Google Gemini AI to answer transit questions
- **AR Navigation** — Uses device camera and compass sensors for on-ground guidance
- **Push Notifications** — Trip reminders, service alerts, and system updates
- **User Authentication** — JWT-based auth with access & refresh tokens
- **Saved Locations** — Save Home, Work, and custom frequent destinations
- **Trip History** — Track and rate past journeys

### Supported Transit Lines
| Code | Name | Type | Operator |
|---|---|---|---|
| KJ | Kelana Jaya Line | LRT | Rapid KL |
| KG | Ampang / Sri Petaling Line | LRT | Rapid KL |
| MRT_PY | Putrajaya Line | MRT | Rapid KL |
| BRT | BRT Sunway | BRT | Rapid KL |
| MRL | KTM Komuter | KTM | KTM Berhad |
| ERL | KLIA Transit / Express | ERL | ERL |

---

## Tech Stack

### Web App (`MyTransport/`)
| Technology | Purpose |
|---|---|
| React 19 + TypeScript | UI framework |
| Vite | Build tool & dev server |
| Tailwind CSS v4 | Styling |
| Framer Motion (`motion`) | Screen transitions & animations |
| Google Gemini AI (`@google/genai`) | AI chatbot integration |
| Lucide React | Icons |
| Express | Static file serving |

### Backend (`backend/`)
| Technology | Purpose |
|---|---|
| Node.js + Express + TypeScript | REST API server |
| Prisma ORM | Database access layer |
| PostgreSQL | Relational database |
| JWT (access + refresh tokens) | Authentication |
| Helmet | HTTP security headers |
| express-rate-limit | Rate limiting (100 req / 15 min) |
| morgan + winston | HTTP & application logging |
| Google Gemini AI | Chatbot backend processing |

### Mobile App (`flutter_mytransport/`)
| Technology | Purpose |
|---|---|
| Flutter / Dart | Cross-platform mobile (Android & iOS) |
| google_maps_flutter + flutter_map | Interactive maps |
| geolocator + geocoding | GPS & address lookup |
| camera + flutter_compass + sensors_plus | AR navigation |
| http | REST API calls |
| shared_preferences | Local auth token storage |
| google_fonts | Typography |

---

## Database Schema

Built with **Prisma + PostgreSQL**. Key models:

- **User** — Email/password auth, profile, phone number
- **RefreshToken** — Secure JWT refresh token rotation
- **SavedLocation** — User's saved places (Home, Work, custom)
- **TransitLine** — LRT / MRT / BRT / KTM / ERL / Monorail / Bus lines
- **Station** — Station details, coordinates, facilities, bilingual names (EN + MY)
- **Departure** — Real-time departure schedule per station/line
- **TransitAlert** — Service disruptions with INFO / WARNING / CRITICAL severity
- **Route** — Computed route with steps stored as JSON
- **Trip** — User trip history with status, rating, and feedback
- **ChatSession + ChatMessage** — Full chatbot conversation history

---

## API Endpoints

Base URL: `/api/v1`

| Route Group | Prefix | Description |
|---|---|---|
| Auth | `/auth` | Register, login, refresh token, logout |
| Transit | `/transit` | Lines, stations, departures, alerts |
| Routes | `/routes` | Route search and suggestions |
| Chatbot | `/chatbot` | Send and receive AI messages |
| Notifications | `/notifications` | User notification management |

---

## Getting Started

### Prerequisites
- Node.js 18+
- PostgreSQL
- Flutter SDK (for mobile app)
- Google Gemini API Key

### Web App

```bash
cd MyTransport
npm install
cp .env.example .env.local
# Add your GEMINI_API_KEY to .env.local
npm run dev
```

### Backend

```bash
cd backend
npm install
cp .env.example .env
# Fill in DATABASE_URL, JWT secrets, GEMINI_API_KEY
npx prisma migrate dev
npx prisma db seed
npm run dev
```

### Flutter Mobile App

```bash
cd flutter_mytransport
flutter pub get
flutter run
```

---

## Environment Variables

### Web App (`.env.local`)
```env
GEMINI_API_KEY=your-gemini-api-key
```

### Backend (`.env`)
```env
NODE_ENV=development
PORT=3000
DATABASE_URL=postgresql://postgres:password@localhost:5432/mytransport
JWT_ACCESS_SECRET=your-access-secret
JWT_REFRESH_SECRET=your-refresh-secret
JWT_ACCESS_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d
GEMINI_API_KEY=your-gemini-api-key
CORS_ORIGIN=http://localhost:5173
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX=100
```

---

## Author

**syxkkkkk** — [GitHub](https://github.com/syxkkkkk)
