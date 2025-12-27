# Word Game — Submission README (Docker + Appsmith Microservices Exercise)

This README is written for **submission/grading**: it explains exactly how to run the system and how to verify the exercise requirements (see `apalaktiki_ntinos.pdf`).

It demonstrates:
- **Docker Compose orchestration** of the required services (UI, DB, DB admin, 2 mock APIs).
- A **real, playable word‑guessing game** implemented as a small **FastAPI** backend.
- **Low‑code UI** in **Appsmith** that drives the game and the integrations.
- A **serverless/external API** integration used in gameplay: `https://random-word-api.herokuapp.com`.

For an end-to-end explanation of the concepts (Docker/Compose, REST APIs, Appsmith, FastAPI) and how everything fits together in this repo, see `guide.md`.

## What’s included (services)

The exercise specifies 5 required containers (UI + DB + DB admin + 2 mock APIs). This repo runs **6 containers** to keep the deliverable meaningful (the extra container is the game backend).

| Compose service | Container | Purpose | Required by exercise requirements |
|---|---|---|---|
| `appsmith` | `word-game-ui` | Low‑code UI | ✅ (UI) |
| `postgres` | `word-game-db` | Local DB (game state + logs) | ✅ (DB) |
| `adminer` | `word-game-admin` | DB admin UI | ✅ (DB admin) |
| `mock-api-1` | `mock-wordpacks` | Mock REST API based on `svenwal/jsonplaceholder` | ✅ (mock #1) |
| `mock-api-2` | `mock-hints` | Mock REST API built from our own Dockerfile (`json-server`) | ✅ (mock #2) |
| `backend` | `word-game-backend` | Game API used by Appsmith gameplay | ➕ (extra) |

External serverless integration (not a container):
- `random-word-api.herokuapp.com` — provides random words; calls are **logged into Postgres**.

## How this satisfies the exercise requirements

The exercise requirements (see `apalaktiki_ntinos.pdf`) are satisfied as follows:

- **Low‑code UI container (`appsmith/appsmith-ce`)** → `appsmith`
- **Local DB container (at least 2 tables)** → `postgres` (tables include `game_sessions`, `guesses`, `leaderboard`, `api_logs`, `favorites`)
- **Local DB admin container (Adminer/phpMyAdmin)** → `adminer`
- **Mock REST API #1 based on `svenwal/jsonplaceholder`** → `mock-api-1` (seeded by `rest-apis/mock-api-1/db.json`)
- **Mock REST API #2 built from your own Dockerfile** → `mock-api-2` (built from `rest-apis/mock-api-2/Dockerfile`, serves `rest-apis/mock-api-2/db.json`)
- **External “serverless” API/DB integration** → `https://random-word-api.herokuapp.com` (used to fetch a target word when no wordpack is selected; the call is logged into Postgres `api_logs`)

Note: the exercise brief mentions orchestrating 5 specific containers; this repo includes one additional container (`backend`) to implement the actual application logic (game rules) behind the UI.

## Submission contents (what’s in this directory)

- `compose.yaml` — orchestration for all containers
- `rest-apis/` — mock API data + custom Dockerfile (exercise requirement)
- `appsmith/word-game-app.json` — Appsmith export (exercise requirement)
- `sql/init.sql` + `sql/export.sql` — SQL schema + sample rows (exercise requirement)
- `report.pdf` — filled report document (replace student name + insert your screenshots)
- `presentation.pptx` — filled slide deck (replace student name + insert your screenshots)
- `backend/` — FastAPI “business logic” service that makes the theme an actual game

## Prerequisites

- Docker Desktop (or Docker Engine + Compose v2): `docker compose version`
- ~4GB+ free RAM (Appsmith can be heavy on first run)

## Start / Stop

Optional (override defaults):
```bash
cp .env.example .env
```

Start everything:
```bash
docker compose -f compose.yaml up -d --build
docker compose -f compose.yaml ps
```

Stop everything:
```bash
docker compose -f compose.yaml down
```

Reset to a clean state (deletes **Appsmith + Postgres** data volumes):
```bash
docker compose -f compose.yaml down -v
docker compose -f compose.yaml up -d --build
```

## Validate your setup (quick checks)

After `up -d`, confirm everything is healthy:

1. Containers are running:
   ```bash
   docker compose -f compose.yaml ps
   ```
2. Browser checks:
   - Appsmith loads: `http://localhost`
   - Adminer loads: `http://localhost:8080`
   - Mock API 1 returns JSON: `http://localhost:3000/wordpacks`
   - Mock API 2 returns JSON: `http://localhost:3001/hints`
3. Backend health (run from your terminal; executes inside the backend container):
   ```bash
   docker compose -f compose.yaml exec backend python -c "import requests; print(requests.get('http://localhost:8000/health').json())"
   ```
   You should see `"status": "healthy"` and `"database": "connected"`.

## Ports used (and what to do if something is already running)

This compose stack uses the following host ports:
- `80` → Appsmith (`http://localhost`)
- `8080` → Adminer (`http://localhost:8080`)
- `3000` → Mock API 1 (`http://localhost:3000`)
- `3001` → Mock API 2 (`http://localhost:3001`)
- `5432` → Postgres (`localhost:5432`, optional for host tools)

If `docker compose up` fails with a message like “port is already allocated”:
1. Stop the conflicting service on your machine, **or**
2. Change the port mapping in `compose.yaml` (for example, change `"80:80"` to `"8085:80"` and then use `http://localhost:8085`).

First build note:
- The `backend` image pre-downloads a language model and WordNet data; the first `--build` can take a few minutes.

## URLs (from your browser)

| What | URL |
|---|---|
| Appsmith UI | http://localhost |
| Adminer (DB admin) | http://localhost:8080 |
| Mock API 1 (wordpacks) | http://localhost:3000/wordpacks |
| Mock API 2 (hints) | http://localhost:3001/hints |

Note: the **backend** is not published to your host; Appsmith reaches it via Docker DNS at `http://backend:8000`.

## Appsmith: import + reconnect datasources (required flow)

Appsmith runs **inside Docker**, so it must call other services by **Docker service name**, not `localhost`.
Example: use `http://mock-api-1:3000` inside Appsmith (not `http://localhost:3000`).

Appsmith terminology (1 sentence):
- A **datasource** is a saved connection (to Postgres or a REST API), and a **query/action** is a runnable request that uses that datasource.

### Step 1 — Open Appsmith

Open `http://localhost`.
- First run: Appsmith asks you to create a **local** admin user (no Appsmith Cloud account needed).

### Step 2 — Import the application export

Import `appsmith/word-game-app.json`.
- If you imported an older version before: import again **as a new app** so you get the latest bindings/UI.
- Appsmith does not “live reload” this file from the repo; importing is how you apply UI/query updates.

### Step 3 — Reconnect the datasources

When Appsmith prompts “Reconnect datasources”, configure exactly these:

| Datasource name | Type | Base URL / Host | Notes |
|---|---|---|---|
| `WordGameDB` | PostgreSQL | host `postgres`, port `5432`, db `wordgame` | user `gameuser`, pass `gamepass123`, SSL **disabled** |
| `MockAPI1` | REST | `http://mock-api-1:3000` | base URL only; queries use `/wordpacks` |
| `MockAPI2` | REST | `http://mock-api-2:3001` | base URL only; queries use `/hints` |
| `ServerlessAPI` | REST | `https://random-word-api.herokuapp.com` | base URL only; query uses `/word?...` |
| `GameAPI` | REST | `http://backend:8000` | base URL only; endpoints `/start`, `/guess`, `/hint`, `/reveal`, `/leaderboard` |

Common pitfall:
- If you set `localhost` inside a datasource, it will fail/hang, because Appsmith is not running on your host network.

Troubleshooting:
- `WordGameDB` → “Unable to validate datasource”: ensure **DB name + user + password** are filled and SSL is **disabled**, then “Save & Test”.
- If Appsmith suggests disabling prepared statements, do it in the datasource settings (it can depend on Appsmith version).

## Troubleshooting (common issues)

- Appsmith page doesn’t load at `http://localhost`:
  - Run `docker compose -f compose.yaml ps` and confirm `appsmith` is Up.
  - Check logs: `docker compose -f compose.yaml logs -f --tail=200 appsmith`

- Mock API URLs work in browser but fail inside Appsmith:
  - In Appsmith datasources, use `http://mock-api-1:3000` and `http://mock-api-2:3001` (service names), not `localhost`.

- Backend errors like “Connection refused: backend:8000” from Appsmith:
  - The backend may still be starting (first build can be slow). Check logs:
    - `docker compose -f compose.yaml logs -f --tail=200 backend`
  - Re-run the backend health check from this README once it’s up.

- Postgres connection fails in Appsmith:
  - Ensure Host is `postgres` (not `localhost`), SSL is disabled, and credentials match `.env.example`/`compose.yaml` defaults.
  - Check Postgres logs: `docker compose -f compose.yaml logs -f --tail=200 postgres`

## How to use the app (what each part does)

### Gameplay tab

1. Set **Player name** (required).
2. Set **Target word length** (optional; default 8; minimum 3).
3. Click **Start new game**:
   - If a **wordpack** is selected (Integrations tab), the game picks a word from that pack with the chosen length.
   - Otherwise it fetches a random word from the **external serverless API**.
   - If the external API is unavailable, it falls back to a local word list (still respects length).
4. Enter guesses and click **Submit guess**.
5. Click **Get hint** to use the selected hint type (or automatic hints if none selected).
6. Click **Reveal word** to end the game and log a loss.
7. The **Leaderboard** refreshes after a game ends (win or reveal).

### Integrations & Logs tab

- **Wordpacks (Mock API 1)**:
  - Select a wordpack to drive which words are used by **Start new game**.
  - Select `Random (no wordpack)` to return to external/local word selection.
- **Hint types (Mock API 2)**:
  - Select a hint type to control what **Get hint** returns.
  - Select `Auto (no hint type)` for automatic hints.
- **Load integrations and logs**:
  - Refreshes wordpacks, hint types, and the DB log tables.
- **API logs**:
  - Every external word fetch is logged into Postgres (`api_logs`).

## Verification checklist (what to show for grading)

Use this checklist to confirm the system satisfies the exercise requirements (see `apalaktiki_ntinos.pdf`) and to capture screenshots for `report.pdf` / `presentation.pptx`.

1. **All containers running (Compose orchestration)**
   - Run: `docker compose -f compose.yaml ps`
   - Screenshot: the list showing all services up.
2. **Mock REST APIs respond (exercise requirement)**
   - Open in a browser:
     - `http://localhost:3000/wordpacks` (Mock API 1)
     - `http://localhost:3001/hints` (Mock API 2)
   - Screenshot: the JSON responses (the text format APIs return) or Appsmith tables fed by them.
3. **Appsmith UI works (exercise requirement)**
   - Open: `http://localhost`
   - Import: `appsmith/word-game-app.json`
   - Reconnect datasources as listed above (WordGameDB, MockAPI1, MockAPI2, ServerlessAPI, GameAPI).
   - Screenshot: the working UI (Gameplay + Integrations & Logs).
4. **Database persistence (exercise requirement)**
   - Play at least one game (start → guesses → win or reveal).
   - Open Adminer: `http://localhost:8080` and inspect:
     - `game_sessions` (new row)
     - `guesses` (new rows)
     - `leaderboard` (updated after game ends)
   - Screenshot: Adminer tables showing inserted data.
5. **External serverless integration (exercise requirement)**
   - Start a game with **no wordpack selected** (so the target word comes from the external API).
   - In Adminer, inspect:
     - `api_logs` (a new row showing the external API call)
   - Screenshot: `api_logs` proving the external integration was used.

## Adminer (database verification)

Open `http://localhost:8080` and connect:
- System: PostgreSQL
- Server: `postgres`
- Username: `gameuser`
- Password: `gamepass123`
- Database: `wordgame`

Tables you can inspect after playing:
- `game_sessions` — one row per game
- `guesses` — one row per submitted guess
- `leaderboard` — aggregated stats (updated after games end)
- `api_logs` — external API calls logged from the UI flow
- `favorites` — optional “save favorite” examples

## Serverless API quick test

Expected JSON array:
```bash
curl "https://random-word-api.herokuapp.com/word?number=1&length=8"
```

## Deliverables checklist (matches the exercise requirements)

This repo already contains the required submission artifacts:
- `compose.yaml`
- `rest-apis/` (mock APIs + Dockerfile)
- `appsmith/word-game-app.json`
- `sql/init.sql` and `sql/export.sql`
- `report.pdf`
- `presentation.pptx`

Next step for submission: update `report.pdf` and `presentation.pptx` with screenshots from your own run (Appsmith UI, Adminer tables, and containers running).

Note for the written report: the exercise requirements list 5 specific containers; this repo includes an extra `backend` container to implement the actual application scenario, so include a short justification section for it.

Packaging tip:
- Submit a single `.zip` of the project folder. Avoid including a personal `.env` file if it contains secrets; use `.env.example` instead.
