# Exercise Guide (Docker Compose + Appsmith)

This repo is organized to match the requirements in `apalaktiki_ntinos.pdf`.

## 1) What you run (5 containers)

Started together via `compose.yaml`:
- `appsmith` — Low‑Code UI (`appsmith/appsmith-ce`)
- `postgres` — Local database
- `adminer` — DB admin UI
- `mock-api-1` — Mock REST API based on `svenwal/jsonplaceholder`
- `mock-api-2` — Mock REST API built from `rest-apis/mock-api-2/Dockerfile`

External serverless integration (not a container):
- `dictionaryapi.dev` (public dictionary API; called from Appsmith)

## 2) Start / Stop

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

Reset DB (only if you want a clean Postgres volume):
```bash
docker compose -f compose.yaml down -v
docker compose -f compose.yaml up -d --build
```

## 3) URLs to use

- Appsmith: `http://localhost`
- Adminer: `http://localhost:8080`
- Mock API 1:
  - `http://localhost:3000/wordpacks`
  - `http://localhost:3000/daily_challenges`
- Mock API 2:
  - `http://localhost:3001/powerups`
  - `http://localhost:3001/hints`
  - `http://localhost:3001/achievements`

## 4) Appsmith UI flow (what the exercise asks for)

1. Open Appsmith: `http://localhost`.
2. Import the app export: `appsmith/word-game-app.json`.
3. Click `Load / Refresh data` to fetch from the two mock APIs and refresh DB tables.
4. Select a row in `WordpacksTable` or `PowerupsTable` and click the save button to insert into PostgreSQL `favorites`.
5. Use `Lookup + log to DB` to:
   - call the external serverless API (`dictionaryapi.dev`)
   - insert a row into PostgreSQL `api_logs`

## 5) Adminer checks (for screenshots)

Connect to `http://localhost:8080`:
- System: PostgreSQL
- Server: `postgres`
- Username: `gameuser`
- Password: `gamepass123`
- Database: `wordgame`

Tables to check:
- `favorites`
- `api_logs`

## 6) Submission checklist

Required items already present:
- `compose.yaml`
- `rest-apis/`
- `appsmith/word-game-app.json`
- `sql/init.sql` and `sql/export.sql`
- `report.pdf` (template)
- `presentation.pptx` (template)

Next: open `report.pdf` and `presentation.pptx` and replace the screenshot placeholders with your own screenshots from your run.

