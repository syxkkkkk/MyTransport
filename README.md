# MyTransport Malaysia

> **AI-Powered Real-Time Public Transportation Companion for Malaysia**

MyTransport is a full-stack application that helps users navigate Malaysia's public transit system with real-time departures, GTFS-based bus schedules, AI-powered route planning, AR navigation, and a Gemini-powered chatbot assistant.

---

## Project Structure

```
MyTransport/
├── MyTransport/          # Web app (React + TypeScript + Vite)
├── backend/              # REST API (Node.js + Express + TypeScript + Prisma)
└── flutter_mytransport/  # Mobile app (Flutter / Dart)
```

---

## Mobile App — Screens

| Screen | Description |
|---|---|
| **Welcome** | Onboarding / splash screen |
| **Home** | Dashboard with gradient location card and quick-access shortcuts |
| **Location Selection** | Search and pick origin & destination |
| **Route Details** | Step-by-step route with fare, duration, and distance |
| **Chatbot** | Gemini AI-powered assistant for transit queries |
| **Trip Summary** | Review completed or planned trips |
| **Live Train / Transit** | Real-time departure status and transit alerts |
| **AR Navigation** | Camera + compass-based augmented reality navigation |
| **Nearby Bus Stops** | GPS-based nearby stops with live ETAs auto-loaded for all routes |
| **Bus Route Detail** | Full stop timeline for a route, next departure, scheduled times, direction toggle |
| **All Bus Stops** | Searchable list of all GTFS bus stops |
| **Transit Map** | Official Klang Valley rail transit map |
| **Profile** | User profile, settings, preferences, and sign out |

---

## Features

### Core Capabilities
- **GTFS Live Bus Schedule** — Parses `rapid-bus-kl` GTFS feeds from `data.gov.my` in a background isolate; supports frequency-based headway expansion
- **Nearby Bus ETA** — GPS locates the nearest stops and auto-loads upcoming arrivals for every route (6-hour window)
- **Bus Route Timeline** — Tap any arrival to see the full ordered stop list for that route, with the current stop highlighted and auto-scrolled into view
- **Direction Toggle** — Switch between inbound/outbound directions on any bus route
- **Real-Time Departures** — Live rail departure times with ON_TIME / DELAYED / CANCELLED status
- **Route Planning** — Multi-modal route suggestions with fare estimates (MYR)
- **AI Chatbot** — Powered by Google Gemini AI to answer transit questions in natural language
- **AR Navigation** — Uses device camera and compass sensors for on-ground waypoint guidance
- **Saved Locations** — Save Home, Work, and custom frequent destinations
- **User Profile** — Settings, preferences, and account management

### Supported Transit Lines
| Code | Name | Type | Operator |
|---|---|---|---|
| KJ | Kelana Jaya Line | LRT | Rapid KL |
| KG | Ampang / Sri Petaling Line | LRT | Rapid KL |
| MRT_PY | Putrajaya Line | MRT | Rapid KL |
| BRT | BRT Sunway | BRT | Rapid KL |
| KTM | KTM Komuter | KTM | KTM Berhad |
| ERL | KLIA Transit / Express | ERL | ERL |
| Rapid Bus KL | Rapid Bus (GTFS) | Bus | Rapid KL |

---

## Tech Stack

### Web App (`MyTransport/`)
| Technology | Purpose |
|---|---|
| React 19 + TypeScript | UI framework |
| Vite | Build tool & dev server |
| Tailwind CSS v4 | Styling |
| Framer Motion | Screen transitions & animations |
| Google Gemini AI | AI chatbot integration |
| Lucide React | Icons |

### Backend (`backend/`)
| Technology | Purpose |
|---|---|
| Node.js + Express + TypeScript | REST API server |
| Prisma ORM | Database access layer |
| PostgreSQL | Relational database |
| JWT (access + refresh tokens) | Authentication |
| Helmet | HTTP security headers |
| express-rate-limit | Rate limiting |
| morgan + winston | HTTP & application logging |
| Google Gemini AI | Chatbot backend processing |

### Mobile App (`flutter_mytransport/`)
| Technology | Purpose |
|---|---|
| Flutter / Dart | Cross-platform mobile (Android & iOS) |
| google_maps_flutter + flutter_map | Interactive maps |
| geolocator + geocoding | GPS & address lookup |
| camera + flutter_compass + sensors_plus | AR navigation |
| http | REST API & GTFS feed fetching |
| archive | GTFS zip parsing |
| shared_preferences | Local storage |
| google_fonts | Typography (Inter) |

---

## GTFS Integration

The mobile app fetches the **Rapid Bus KL** GTFS static feed directly from `data.gov.my` and processes it fully on-device in a Flutter `compute()` isolate:

- Parses `routes.txt`, `trips.txt`, `stop_times.txt`, `stops.txt`, `calendar.txt`, `frequencies.txt`
- Builds an in-memory index: stops → routes → trips → ordered stop sequences
- Expands frequency-based headways into individual departure times
- `getArrivals(stopId)` — returns upcoming ETAs for all routes at a stop
- `getRouteDetail(stopId, routeShortName)` — returns full ordered stop list, current stop index, next departure, all scheduled times, and direction info

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
- Flutter SDK 3.x+
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

> No API key is required for the GTFS bus data — it is fetched from the public `data.gov.my` endpoint at runtime.

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
