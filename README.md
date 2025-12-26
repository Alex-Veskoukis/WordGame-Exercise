# Word Game — Docker & Low‑Code Microservices (Exercise)

This repository is aligned to the requirements of `apalaktiki_ntinos.pdf`:

- 5 containers started together with Docker Compose:
  - UI: `appsmith/appsmith-ce`
  - Local DB: PostgreSQL
  - DB Admin: Adminer
  - Mock REST API 1: `svenwal/jsonplaceholder` (seeded via volume)
  - Mock REST API 2: custom `json-server` image (Dockerfile)
- External serverless API integration (not a container): `dictionaryapi.dev`

## Quick start

Optional (override defaults):
```bash
cp .env.example .env
```

Start:
```bash
docker compose -f compose.yaml up -d --build
docker compose -f compose.yaml ps
```

Stop:
```bash
docker compose -f compose.yaml down
```

## URLs

| Service | URL |
|---|---|
| Appsmith UI | http://localhost |
| Adminer | http://localhost:8080 |
| Mock API 1 | http://localhost:3000/wordpacks |
| Mock API 2 | http://localhost:3001/powerups |

## Appsmith UI (required flow)

Important networking note:
- `mock-api-1`, `mock-api-2`, and `postgres` are **Docker service names**. They work **inside Docker** (Appsmith server), but they will **not** open in your browser.
- For browser/curl on your machine use `localhost` ports (3000/3001/8080).

1. Open `http://localhost`.
2. Import the app: `appsmith/word-game-app.json`.
3. In the app:
   - Click `Load / Refresh data` (loads wordpacks + powerups and refreshes DB tables).
    - Select a row in `WordpacksTable` or `PowerupsTable` and click the matching “Save … → Favorites”.
    - Use the dictionary lookup (“Lookup + log to DB”) to call the external serverless API and store a log row in `api_logs`.

Dictionary API quick test (expected JSON):
- `https://api.dictionaryapi.dev/api/v2/entries/en/mountain`
(`https://api.dictionaryapi.dev` alone returns `Cannot GET /` and is normal.)

## Database (Adminer)

Open `http://localhost:8080` and connect using:
- System: PostgreSQL
- Server: `postgres`
- Username: `gameuser`
- Password: `gamepass123`
- Database: `wordgame`

Tables used by the UI flow:
- `favorites` (stores selected items from mock APIs)
- `api_logs` (stores dictionary API logs)

## Deliverables (what to submit)

The required files/folders are already in the repo:
- `compose.yaml`
- `rest-apis/` (mock APIs data + Dockerfile)
- `appsmith/word-game-app.json`
- `sql/init.sql` and `sql/export.sql`
- `report.pdf`
- `presentation.pptx`
