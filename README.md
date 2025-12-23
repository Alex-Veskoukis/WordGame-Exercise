# Semantic Word Game

## Overview
Semantic Word Game is a Dockerized word guessing application. The backend selects a noun from a curated word list and evaluates guesses using semantic similarity. The system includes two user interfaces (a static web UI and an Appsmith UI), a PostgreSQL database for persistence, and a mock API for supplemental demo data.

## Architecture

### Components
- FastAPI backend for game logic, hint generation, and persistence
- Static frontend served by the backend
- Appsmith UI (importable application)
- PostgreSQL database for sessions, guesses, and leaderboard
- Adminer for database inspection
- Mock API (json-server) with demo hints, achievements, and powerups
- MongoDB for Appsmith internal state

### Data Flow
1. Player starts a game via the static UI or Appsmith UI.
2. Backend selects a target noun from `backend/nouns.json` and creates a session in PostgreSQL.
3. Player submits guesses; backend computes semantic similarity and stores guesses.
4. Game end updates session and leaderboard via a database trigger.

## Services and URLs

| Service | URL | Purpose |
|---|---|---|
| Appsmith UI | http://localhost | Import and run the Appsmith app |
| Static UI | http://127.0.0.1:8000/ | Game UI served by FastAPI |
| API Docs (Swagger) | http://127.0.0.1:8000/docs | Interactive API documentation |
| Adminer | http://localhost:8080 | Database administration |
| Mock API | http://localhost:3001/hints | Demo data endpoints |

## Prerequisites
- Docker Engine or Docker Desktop
- Docker Compose plugin (recommended) or `docker-compose`
- Ports available: 80, 443, 8000, 8080, 3001, 5432

## Setup

### 1) Environment
Copy the example environment file and adjust if needed:
```bash
cp .env.example .env
```

### 2) Start Services
```bash
docker compose up -d
```
If your system uses legacy Compose, use `docker-compose` instead of `docker compose`.

### 3) Verify
```bash
docker compose ps
```

## Using the Interfaces

### Static UI
Open:
```
http://127.0.0.1:8000/
```
The UI prompts for a player name and handles `/start`, `/guess`, `/hint`, and `/reveal`.

### Appsmith UI
1. Open `http://localhost/applications`.
2. Click Import and select `appsmith/word-game-app.json`.
3. Open the imported app.

If you modify the Appsmith app and want to persist changes in the repo, export and overwrite:
```
appsmith/word-game-app.json
```

## API Reference

### Start Game
```
POST /start
```
Request:
```json
{ "player_name": "Alex" }
```
Response:
```json
{ "message": "New game started! Try to guess the word.", "word_length": 8 }
```

### Submit Guess
```
POST /guess
```
Request:
```json
{ "player_name": "Alex", "word": "mountain" }
```
Response:
```json
{
  "similarity": 0.357,
  "all_guesses": [
    { "word": "mountain", "similarity": 0.357, "guess_number": 1 }
  ],
  "is_correct": false,
  "guesses_count": 1
}
```

### Hint
```
POST /hint
```
Request:
```json
{ "player_name": "Alex" }
```
Response:
```json
{ "hint": "A device used for ...", "hints_used": 1 }
```

### Reveal
```
POST /reveal
```
Request:
```json
{ "player_name": "Alex" }
```
Response:
```json
{ "target_word": "...", "total_guesses": 5, "score": 35 }
```

### Stats
```
GET /stats
GET /stats?player_name=Alex
```

### Leaderboard
```
GET /leaderboard
```

### Health
```
GET /health
```

## Game Logic

### Target Selection
- The backend loads nouns from `backend/nouns.json` at startup.
- Words are lowercase a-z and length >= 3.

### Similarity Scoring
- Uses `sentence-transformers` model `all-MiniLM-L6-v2`.
- Similarity is cosine distance between embeddings.
- A guess is correct if it exactly matches the target or similarity > 0.99.

### Hint System
- Hints are generated via NLTK WordNet.
- Hints 1-10 are definition-focused and remove the exact target word from output.
- Hints 11-15 provide letter/pattern clues:
  - 11: first letter
  - 12: last letter
  - 13: second letter
  - 14: pattern with two letters missing
  - 15: pattern with three letters missing
- Hints never include the exact target word.

### Session Handling
- Active games are stored in memory by `player_name`.
- Finished games and all guesses are persisted in PostgreSQL.
- If the backend restarts, active games are lost, but stored sessions remain.

## Database

### Connection (Adminer)
- System: PostgreSQL
- Server: `postgres`
- User: `gameuser`
- Password: `gamepass123`
- Database: `wordgame`

### Schema
Defined in `sql/init.sql`:
- `game_sessions` (one row per game)
- `guesses` (one row per guess)
- `leaderboard` (aggregated player stats)
- `player_stats` (daily analytics)

### Views and Triggers
- Views: `recent_games`, `top_players`
- Trigger: updates `leaderboard` when a game ends

### Sample Queries
```sql
SELECT * FROM game_sessions ORDER BY start_time DESC LIMIT 10;
SELECT * FROM guesses WHERE session_id = 1 ORDER BY guess_number;
SELECT * FROM leaderboard ORDER BY best_score DESC;
```

### Clearing Leaderboard Data
```sql
TRUNCATE TABLE leaderboard RESTART IDENTITY;
```

## Mock API

The mock API is a json-server container with demo data and is not required by the backend. It can be used for UI prototyping.

Endpoints:
```
http://localhost:3001/hints
http://localhost:3001/achievements
http://localhost:3001/powerups
```

## Configuration

Environment variables in `.env`:
- `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`
- `APPSMITH_ENCRYPTION_PASSWORD`, `APPSMITH_ENCRYPTION_SALT`
- `GROQ_API_KEY` (optional; not used by the backend)

## Operations

Start:
```bash
docker compose up -d
```

Stop:
```bash
docker compose down
```

Rebuild backend after code changes:
```bash
docker compose up -d --build game-backend
```

View logs:
```bash
docker compose logs -f
```

## Troubleshooting

- Appsmith not loading: wait for MongoDB to be healthy, then refresh `http://localhost`.
- API errors: check backend logs with `docker compose logs -f game-backend`.
- Port conflicts: change port mappings in `docker-compose.yaml` and restart services.

## Project Structure
```
WordGame/
├── README.md
├── docker-compose.yaml
├── .env.example
├── backend/
│   ├── app.py
│   ├── nouns.json
│   ├── requirements.txt
│   └── static/index.html
├── sql/
│   ├── init.sql
│   └── export.sql
├── mock-api-2/
│   ├── Dockerfile
│   └── db.json
└── appsmith/
    └── word-game-app.json
```
