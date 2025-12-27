# Student Guide — Understand the Word Game Microservices (Docker Compose + Appsmith)

This guide is written for a student reading the project for the first time. It explains the key terms (Docker, containers, Compose, REST APIs, Appsmith datasources/queries, PostgreSQL tables) and how this system works end‑to‑end to satisfy `apalaktiki_ntinos.pdf`.

If you only want the “how do I run it / what do I submit?” instructions, use `README.md`.

## Learning objectives (what you should understand after reading)

By the end of this guide you should be able to:
- Explain the difference between a **Docker image** and a **container**, and why we use containers.
- Read `compose.yaml` and describe how services are connected (ports, volumes, environment variables, dependencies).
- Explain why Appsmith uses service names like `postgres` / `backend` (inside Docker) instead of `localhost`.
- Describe what a **REST API** is and how the UI calls endpoints like `/start` and `/guess`.
- Explain what is stored in Postgres tables like `game_sessions`, `guesses`, `leaderboard`, and `api_logs`.

## Contents (quick navigation)

- 1) What the exercise asks for (and how this repo satisfies it)
- 2) Directory structure (what lives where)
- 3) Conceptual architecture (how the microservices relate)
- 4) Docker fundamentals (student primer)
- 5) Appsmith fundamentals (low‑code UI)
- 6) FastAPI + REST fundamentals
- 7) How to run (and what to screenshot)
- 8) Academic notes (why the design is defensible)
- 9) Glossary (plain-language definitions)

## 1) What the exercise asks for (and how this repo satisfies it)

The exercise brief (`apalaktiki_ntinos.pdf`) requires a composed application with:
1. **Low‑code UI**: `appsmith/appsmith-ce` container.
2. **Local database**: one DB container (with at least 2 tables).
3. **DB admin tool**: `adminer` or `phpMyAdmin` container.
4. **Two mock REST APIs**:
   - One based on `svenwal/jsonplaceholder` (seeded via volumes).
   - One built from your own Dockerfile (example: `json-server`).
5. **External “serverless” integration**: a cloud API/DB used for extra functionality.
6. A **report** + **presentation** with installation and runtime screenshots.

This repo includes the required 5 containers and adds **one extra container**:
- `backend` (FastAPI) is the **actual application logic** for a playable word game. The exercise does not forbid extra containers; the required set is still present.
  - Tip for the report: explicitly justify this extra service as the “domain microservice” that implements the scenario’s business logic.

## 2) Directory structure (what lives where)

This is a tour of the repository. Use it to understand “where things are” before you dive into implementation details.

### Directory tree (key files)

```
word-game-complete/
├─ apalaktiki_ntinos.pdf            # The exercise brief (requirements)
├─ CONTRIBUTING.md                  # Optional: contribution notes (not required for submission)
├─ LICENSE                          # Optional: license file (not required for submission)
├─ README.md                        # Submission/grading instructions (run + verify)
├─ guide.md                         # Student guide (this file)
├─ compose.yaml                     # Docker Compose orchestration (all containers)
├─ .env                             # Optional local overrides (not usually committed)
├─ .env.example                     # Environment variable template (safe defaults)
├─ appsmith/
│  └─ word-game-app.json            # Appsmith export (UI + actions + datasource templates)
├─ backend/
│  ├─ Dockerfile                    # Builds the backend image
│  ├─ requirements.txt              # Python dependencies for the backend
│  ├─ app.py                        # FastAPI application (game endpoints + DB logic)
│  ├─ nouns.json                    # Local fallback word list (used when external API unavailable)
│  └─ static/
│     └─ index.html                 # Minimal landing page for backend root (not the main UI)
├─ rest-apis/
│  ├─ mock-api-1/
│  │  └─ db.json                    # Seed data for Mock API 1 (svenwal/jsonplaceholder)
│  └─ mock-api-2/
│     ├─ Dockerfile                 # Builds Mock API 2 image (json-server)
│     └─ db.json                    # Seed data for Mock API 2 (hint types, achievements, etc.)
├─ sql/
│  ├─ init.sql                      # DB schema: tables, views, triggers
│  └─ export.sql                    # Sample rows inserted on first DB init
├─ report.pdf                       # Filled report (replace student name + insert screenshots)
└─ presentation.pptx                # Filled slides (replace student name + insert screenshots)
```

### What each top-level file is for

- `apalaktiki_ntinos.pdf`
  - The “source of truth” for what must be included (UI container, DB container, DB admin, 2 mock APIs, external integration, deliverables).

- `CONTRIBUTING.md`
  - Optional developer notes (not required by the exercise requirements), useful if you plan to extend the project.

- `LICENSE`
  - Optional licensing information (not required by the exercise requirements).

- `compose.yaml`
  - The one file that defines the runnable system: images, builds, ports, environment variables, volumes.
  - The service names (`appsmith`, `postgres`, `mock-api-1`, etc.) become the **hostnames** containers use to talk to each other.

- `.env`
  - Optional file for local environment variable overrides.
  - Usually **not committed**; use `.env.example` as the template.

- `.env.example`
  - A template of environment variables used by `compose.yaml` and the backend.
  - For local runs you typically copy it to `.env`. In a submission, `.env.example` is the safe file to include.

- `README.md`
  - Written as a submission handoff: how to run, how to reconnect Appsmith datasources, and what to screenshot to prove requirements.

- `guide.md`
  - Written as a learning resource: explains the concepts and the “why” behind the architecture and files.

### `appsmith/` (the UI deliverable)

- `appsmith/word-game-app.json`
  - This is the Appsmith **Export application** JSON file required by the exercise requirements.
  - It contains:
    - widgets (tables, buttons, inputs, text)
    - actions (SQL queries and REST calls)
    - datasource *templates* (names/types) that must be reconnected after import
  - Important: importing this file recreates the app UI, but you still need to “Reconnect datasources” because credentials/hosts are environment-specific.

### `backend/` (the game “business logic” service)

The backend exists to implement a meaningful scenario (a playable word game). Appsmith is the UI, but the backend is where rules are enforced.

- `backend/app.py`
  - Defines the FastAPI endpoints used by the UI (`/start`, `/guess`, `/hint`, `/reveal`, `/leaderboard`).
  - Connects to Postgres via `DATABASE_URL`.
  - Computes similarity scores and writes gameplay history to tables.

- `backend/Dockerfile`
  - Builds the backend image and installs dependencies.
  - Pre-downloads resources (embedding model + WordNet data) so the container is usable immediately after build.

- `backend/requirements.txt`
  - Exact Python libraries used (FastAPI, Uvicorn, psycopg2, httpx, sentence-transformers, nltk, etc.).

- `backend/nouns.json`
  - Local fallback nouns list used to start a game when the external API is unavailable.

- `backend/static/index.html`
  - A minimal file served at `/` by the backend. The “real UI” is Appsmith; this exists mainly so the backend root isn’t empty.

### `rest-apis/` (the two mock APIs required by the exercise)

Mock APIs exist because the exercise requires two mock REST API services that provide initial data.

- `rest-apis/mock-api-1/db.json`
  - Seed dataset for the container based on `svenwal/jsonplaceholder`.
  - The Appsmith UI reads `/wordpacks` from this API and uses it to pick word lists.

- `rest-apis/mock-api-2/Dockerfile` + `rest-apis/mock-api-2/db.json`
  - Our custom mock API image (exercise requires that one mock API is built from your own Dockerfile).
  - It runs `json-server` and serves endpoints like `/hints`.
  - The UI reads hint type definitions from `/hints`.

### `sql/` (database schema + sample data)

- `sql/init.sql`
  - Creates the Postgres schema: tables for sessions/guesses/leaderboard/logs, plus views/triggers.

- `sql/export.sql`
  - Inserts a small set of sample rows so tables are not empty on first boot.
  - You still generate new real rows by playing the game.

### `report.pdf` and `presentation.pptx` (submission templates)

These are placeholders/templates:
- Replace the screenshots with your own (containers running, Appsmith UI flows, Adminer tables).
- In the report text, justify your architecture choices (the exercise requires justification).

## 3) Conceptual architecture (how the microservices relate)

At a high level:

1. **Appsmith** is the UI “orchestrator”: it calls APIs, renders tables, and triggers SQL queries.
2. The **backend** contains game logic: start game, compute similarity of guesses, generate hints, end game, update leaderboard.
3. **Postgres** persists all meaningful state (sessions, guesses, leaderboard, logs).
4. Two **mock APIs** provide “external” domain data (wordpacks + hint types).
5. A **serverless API** provides supplemental gameplay functionality (random word generation).

### Services and addresses: host machine vs Docker network (very important)

This section answers the question: **“Why do I sometimes use `localhost`, and other times use names like `postgres` or `mock-api-1`?”**

When you run:
```bash
docker compose -f compose.yaml up -d
```
Docker Compose creates a *small private network* for your project and attaches every service container to it.

That gives you two different “worlds” where requests can originate:

1) **Your host machine** (your laptop/desktop)
- Your browser and your terminal are here.
- When you type `http://localhost:3000`, you are connecting to a port on *your host*.

2) **Inside Docker** (inside containers)
- Appsmith runs inside a container.
- The backend runs inside a container.
- From inside a container, `localhost` means “this same container”, not your host.

#### Why `localhost` breaks inside Appsmith

Appsmith is a container. So:
- `http://localhost:3000` from Appsmith means: “connect to port 3000 on the Appsmith container”.
- But the mock API is a *different* container (`mock-api-1`), so that request will fail or hang.

To reach other containers, you use **Docker DNS service names**:
- `mock-api-1` is the hostname of the mock API 1 container.
- `postgres` is the hostname of the Postgres container.
- `backend` is the hostname of the FastAPI backend container.

So inside Appsmith, the correct base URLs are:
- `http://mock-api-1:3000`
- `http://mock-api-2:3001`
- `postgres:5432`
- `http://backend:8000`

#### What `ports:` means (how your browser reaches containers)

Some services include a `ports:` section in `compose.yaml`. Example:
- `3000:3000`

This means:
- The **left** number is the host port (your machine).
- The **right** number is the container port (inside Docker).

So when you open:
- `http://localhost:3000/wordpacks`

the request flow is:
- Browser (host) → host port `3000` → Docker forwards to container `mock-api-1` port `3000` → response back to browser.

Visual mental model:
```
Host machine (your browser)                      Docker Compose network
-------------------------                       ---------------------
http://localhost:3000/wordpacks   ---> (port forward) ---> http://mock-api-1:3000/wordpacks
http://localhost:3001/hints       ---> (port forward) ---> http://mock-api-2:3001/hints
http://localhost:8080             ---> (port forward) ---> http://adminer:8080
http://localhost                  ---> (port forward) ---> http://appsmith:80
```

#### Why the backend has no host URL in this repo

In `compose.yaml`, the backend service does not publish `8000:8000` to the host.
That’s why you cannot open `http://localhost:8000` in a browser.

This is intentional:
- Only the Appsmith UI needs to call the backend, and Appsmith is already in the same Docker network.

(If you wanted to expose it for debugging, you could add a `ports:` mapping under `backend`.)

#### Addressing cheat sheet

| Component | From your host machine (browser/CLI) | From Appsmith (inside Docker) | Why it exists |
|---|---:|---:|---|
| Appsmith UI | `http://localhost` | `http://appsmith` | Low‑code UI required by the exercise requirements |
| Adminer | `http://localhost:8080` | `http://adminer:8080` | DB admin UI required by the exercise requirements |
| Mock API 1 | `http://localhost:3000` | `http://mock-api-1:3000` | Mock REST API service (based on `svenwal/jsonplaceholder`) |
| Mock API 2 | `http://localhost:3001` | `http://mock-api-2:3001` | Mock REST API service (built from our own Dockerfile) |
| Postgres | `localhost:5432` (DB client) | `postgres:5432` | Local database required by the exercise requirements |
| Backend API | *(not exposed to host)* | `http://backend:8000` | Application “business logic” service used by the UI |

If you remember only one rule:
- **Host machine → `localhost`**, **Appsmith datasource → service name**.

#### “Prove it” (simple experiments you can run)

From your host (your normal terminal):
```bash
curl "http://localhost:3000/wordpacks"
```
This works because `compose.yaml` publishes `mock-api-1` on host port `3000`.

Now try to use a Docker service name from your host:
```bash
curl "http://mock-api-1:3000/wordpacks"
```
This fails because your host does not have DNS entries for Compose service names.

But from *inside the Docker network* it works. For example, run this inside the backend container:
```bash
docker compose -f compose.yaml exec backend python -c "import httpx; print(httpx.get('http://mock-api-1:3000/wordpacks').status_code)"
```
This works because containers can resolve `mock-api-1` via Docker DNS.

### Service-by-service breakdown (what each container does)

This section explains the `services:` defined in `compose.yaml` in plain language. Think of it as “what is each container, how is it configured, and how does the rest of the system use it?”.

If you see new Docker words like “volume”, “bind mount”, or “environment variable”, they are explained in detail in section **4) Docker fundamentals** below.

#### `appsmith` (UI container)

What it is:
- The low‑code UI platform required by the exercise requirements.

How it is created:
- Runs a prebuilt image: `appsmith/appsmith-ce:latest`.

How you access it:
- `ports: "80:80"` → open `http://localhost` in your browser.

What it stores:
- `volumes: appsmith_data:/appsmith-stacks` → this is where Appsmith keeps:
  - the local admin user you create on first run
  - imported applications (including this one)
  - datasource configs (hosts, usernames, passwords you enter)

Why the encryption variables exist:
- `APPSMITH_ENCRYPTION_PASSWORD` and `APPSMITH_ENCRYPTION_SALT` are used by Appsmith to encrypt secrets it stores (like DB passwords).
- In real deployments you must keep them stable. In this exercise they are set via `.env` / defaults.

How it talks to other services:
- Appsmith calls other containers over Docker DNS:
  - `postgres:5432` (database)
  - `mock-api-1:3000` and `mock-api-2:3001` (mock APIs)
  - `backend:8000` (game API)
- It also calls an external API over the internet:
  - `https://random-word-api.herokuapp.com`

#### `postgres` (local database container)

What it is:
- PostgreSQL database required by the exercise requirements.

How it is created:
- Runs a prebuilt image: `postgres:15-alpine`.

How you access it:
- From containers: `postgres:5432`
- From your host (optional): `localhost:5432` because `ports: "5432:5432"` is set.

How it is initialized:
- On first start **only** (when the `postgres_data` volume is empty), Postgres executes all `*.sql` files in:
  - `/docker-entrypoint-initdb.d/`
- This repo bind-mounts:
  - `./sql/init.sql` → creates tables/views/triggers
  - `./sql/export.sql` → inserts a few sample rows

Where the data lives:
- `volumes: postgres_data:/var/lib/postgresql/data` → persistent DB storage.

How it is used by the application:
- The backend writes game sessions and guesses here.
- Appsmith reads tables directly (SQL queries) to display logs/tables.

#### `adminer` (database admin UI container)

What it is:
- A lightweight database administration web UI (required by the exercise requirements).

How it is created:
- Runs a prebuilt image: `adminer:latest`.

How you access it:
- `ports: "8080:8080"` → open `http://localhost:8080` in your browser.

How it connects to Postgres:
- It is configured with `ADMINER_DEFAULT_SERVER=postgres`, so you can connect using the service name `postgres` from inside Docker.

Why it exists in this project:
- It provides the easiest way to prove DB persistence (screenshots of tables populated after using the UI).

#### `mock-api-1` (mock REST API based on `svenwal/jsonplaceholder`)

What it is:
- A mock REST API container required by the exercise requirements, explicitly asking for an API based on the `svenwal/jsonplaceholder` image.

How it is created:
- Runs a prebuilt image: `svenwal/jsonplaceholder:latest`.

How you access it:
- From your browser: `http://localhost:3000`
- From containers: `http://mock-api-1:3000`

Where its data comes from:
- A read-only bind mount:
  - `./rest-apis/mock-api-1/db.json:/usr/src/app/db.json:ro`
- Editing `rest-apis/mock-api-1/db.json` and restarting the service changes the served data.

How the app uses it:
- Appsmith reads `/wordpacks`.
- If you select a wordpack in the UI, the Gameplay tab can start games using words from that pack.

#### `mock-api-2` (mock REST API built from our own Dockerfile)

What it is:
- The second mock REST API required by the exercise requirements, built from a Dockerfile.

How it is created:
- `build:` points to `rest-apis/mock-api-2/Dockerfile`.
- The Dockerfile installs `json-server` and serves `rest-apis/mock-api-2/db.json`.

How you access it:
- From your browser: `http://localhost:3001`
- From containers: `http://mock-api-2:3001`

How the app uses it:
- Appsmith reads `/hints` (hint type catalog).
- The selected hint type controls what the backend returns when you click “Get hint”.

#### `backend` (FastAPI game API container)

What it is:
- The application’s “business logic” service. It makes the theme (word game) a real application instead of only a dashboard.

How it is created:
- `build:` points to `backend/Dockerfile`.
- That Dockerfile:
  - installs Python dependencies (FastAPI, psycopg2, httpx, etc.)
  - pre-downloads the embedding model and WordNet data so first startup is faster
  - runs `python app.py`

How you access it:
- Not exposed to the host by default (no `ports:`).
- Called by Appsmith at `http://backend:8000`.

How it uses the database:
- It connects using `DATABASE_URL` (defaults to `postgresql://gameuser:gamepass123@postgres:5432/wordgame`).
- It inserts/updates rows in:
  - `game_sessions` and `guesses` (core gameplay history)
  - it also updates leaderboard data after games end

How it uses external systems:
- The backend can read mock API base URLs from `MOCK_API_1_URL` and `MOCK_API_2_URL` (primarily for proxy/favorites endpoints).
- The UI (Appsmith) is what calls the serverless API for random words and logs it into `api_logs`.

### What about the serverless/external service?

The external service is **not** a Compose service (so it is not “a container you run”).
It is a public API on the internet:
- `https://random-word-api.herokuapp.com`

In this project it is used in gameplay:
- If no wordpack is selected, **Start new game** fetches a random word of the chosen length from this API and then starts a backend session with that target word.

### Mock APIs: what they contain (and how they relate to the game)

These APIs exist to satisfy the “two mock REST API services” requirement **and** to make the game configurable:

- **Mock API 1** (`mock-api-1` → `svenwal/jsonplaceholder`)
  - Seeded by `rest-apis/mock-api-1/db.json`
  - Key endpoints used by the UI:
    - `/wordpacks` (lists wordpacks and their word lists)
    - `/daily_challenges` (example extra dataset)
  - Example `wordpacks` item (shape):
    ```json
    {
      "id": 1,
      "name": "Nature Pack",
      "difficulty": "easy",
      "description": "Nouns related to nature and landscapes.",
      "words": ["mountain", "river", "forest"]
    }
    ```

- **Mock API 2** (`mock-api-2` → `rest-apis/mock-api-2/Dockerfile` + `json-server`)
  - Seeded by `rest-apis/mock-api-2/db.json`
  - Key endpoints used by the UI:
    - `/hints` (lists hint “types” the user can pick)
    - `/achievements` (example extra dataset)
  - Example `hints` item (shape):
    ```json
    {
      "id": 1,
      "type": "first_letter",
      "name": "First Letter Reveal",
      "description": "Shows the first letter of the target word",
      "cost_points": 5
    }
    ```

How to modify mock data (useful for extensions / demos):
- Mock API 1 (`mock-api-1`) uses a **bind mount** for `db.json`, so editing `rest-apis/mock-api-1/db.json` changes what the container sees. Restart the service to be safe:
  - `docker compose -f compose.yaml restart mock-api-1`
- Mock API 2 (`mock-api-2`) copies `db.json` into the image at build time, so editing `rest-apis/mock-api-2/db.json` requires a rebuild:
  - `docker compose -f compose.yaml up -d --build mock-api-2`

### Database schema: what we store (and why)

The database is not just “a requirement”; it is where the application proves it processed data.

The schema is defined in `sql/init.sql` and sample rows are in `sql/export.sql`. On a fresh volume, Postgres executes both automatically.

Database terminology (quick definitions):
- A **table** is like a spreadsheet that stores one kind of thing (e.g. games, guesses).
- A **row** is one record in a table (e.g. one specific game session).
- A **column** is one attribute of each row (e.g. `player_name`, `won`, `score`).
- A **primary key** is a unique identifier for each row (e.g. `session_id` in `game_sessions`).
- A **foreign key** stores the primary key of another table to link related rows (e.g. `guesses.session_id` points to `game_sessions.session_id`).
- A **trigger** is a database rule that runs automatically when something changes (this schema updates the `leaderboard` when a game ends).
- A **view** is a saved read-only query that behaves like a table (this schema includes convenience views like “recent games”).

How that applies here:
- `guesses` references `game_sessions` so each guess is tied to exactly one game.
- `leaderboard` stores aggregated stats so the UI can display rankings quickly.
- `api_logs` stores evidence that the external serverless API was called as part of the workflow.

Core tables (used by the Appsmith flow):
- `game_sessions` — one row per game session (start/end, score, win/loss)
- `guesses` — one row per guess with similarity score and correctness
- `leaderboard` — aggregated player statistics for display
- `api_logs` — audit trail of serverless API calls (external integration evidence)
- `favorites` — example “save favorite” pattern (UI → DB persistence)

### Table-by-table details (columns and meaning)

This section is intentionally explicit so you can explain the schema in your report.

#### `game_sessions` (one row per game)

Columns (from `sql/init.sql`):
- `session_id` (SERIAL, primary key): unique id for the game session
- `player_name` (VARCHAR): who played the game
- `target_word` (VARCHAR): the word to guess (stored for auditing/reporting)
- `start_time` (TIMESTAMP): when the game started
- `end_time` (TIMESTAMP, nullable): when the game ended (win or reveal)
- `total_guesses` (INT): number of guesses taken
- `won` (BOOLEAN): whether the session ended as a win
- `score` (INT): session score (simple scoring rule in backend)
- `difficulty` (VARCHAR): a stored label (defaults to `medium`)
- `hints_used` (INT): number of hints used in the session
- `best_similarity` (FLOAT): highest similarity reached in the session (useful even for losses)

#### `guesses` (one row per guess)

- `guess_id` (SERIAL, primary key): unique id for each guess record
- `session_id` (INT, foreign key → `game_sessions.session_id`): which game session this guess belongs to
- `guess_word` (VARCHAR): the guessed word
- `similarity_score` (FLOAT): cosine similarity to the target word embedding
- `guess_number` (INT): 1, 2, 3… (order of guesses within the session)
- `timestamp` (TIMESTAMP): when the guess was recorded
- `is_correct` (BOOLEAN): whether this guess ended the game

#### `leaderboard` (aggregated per player)

- `player_id` (SERIAL, primary key): internal id
- `player_name` (VARCHAR, UNIQUE): player identifier
- `total_games`, `games_won`, `total_guesses` (INT): totals
- `best_score` (INT): best score achieved
- `avg_guesses` (FLOAT): average guesses per game
- `win_rate` (FLOAT): percentage of games won
- `last_played` (TIMESTAMP): last finished game time
- `created_at` (TIMESTAMP): when the row was created

Note:
- The schema includes a trigger that updates the leaderboard when a game ends.
- The backend also upserts leaderboard rows when `/leaderboard` is called. For the exercise, either approach demonstrates DB-side processing; this repo uses both for robustness.

#### `favorites` (saved “favorite” items from mock APIs)

This table demonstrates the required pattern “UI selects API data → store selection in local DB”.

- `favorite_id` (SERIAL, primary key)
- `player_name` (VARCHAR): who saved the favorite
- `source` (VARCHAR): which API it came from (e.g. `mock-api-1` / `mock-api-2`)
- `item_type` (VARCHAR): what kind of item it is (e.g. `wordpack`, `powerup`)
- `item_id` (INT): the item’s id from the mock API dataset
- `item_name` (TEXT): human-readable name
- `item_payload` (JSONB): full JSON payload saved for auditing/debugging
- `created_at` (TIMESTAMP)
- Unique constraint: (`player_name`, `source`, `item_type`, `item_id`) so “save” behaves like an upsert.

#### `api_logs` (external API call log)

This table is the “evidence” table for the external/serverless integration.

- `log_id` (SERIAL, primary key)
- `player_name` (VARCHAR): who triggered the call
- `api_name` (VARCHAR): which external API was called (`random-word-api.herokuapp.com`)
- `query` (TEXT): what was requested (here it stores the requested word length)
- `response_payload` (JSONB): the raw response from the external API
- `created_at` (TIMESTAMP)

#### `player_stats` (daily stats; optional/extra)

The schema includes a `player_stats` table to demonstrate “additional DB tables beyond the minimum”.
It is not currently required by the main UI flow, but it is valid for the exercise requirement “at least two tables”.

#### Views and triggers (advanced DB features)

For reporting convenience, the schema also includes:
- `recent_games` view (recent sessions)
- `top_players` view (leaderboard-like view)

And it defines:
- `update_leaderboard()` function + trigger `trigger_update_leaderboard` that runs automatically when a session ends.

### Data flow (runtime)

**Start new game**
- Appsmith reads:
  - Player name
  - Desired word length
  - Selected wordpack (optional)
- Then it chooses the target word source:
  1) If a wordpack is selected, pick a word from that pack (same length).  
  2) Else call the serverless API `random-word-api` to get a word with that length.  
  3) If the external API is down, fall back to a local word list (still respects length).
- Appsmith calls the backend `POST /start` to create a new session row in Postgres.

**Submit guess**
- Appsmith calls backend `POST /guess`.
- Backend computes semantic similarity (embedding cosine similarity) and logs the guess in `guesses`.
- If correct, backend ends the game and finalizes `game_sessions` (won/score/end_time).

**Get hint**
- Appsmith calls backend `POST /hint`, optionally passing a hint type selected from Mock API 2.
- Backend returns a hint and increments the in‑memory hint counter.

**Logs / verification**
- Appsmith reads Postgres tables directly (SQL queries) to show:
  - Recent game sessions
  - Guess log
  - External API logs (`api_logs`)

This is a classic microservices integration pattern: **UI → APIs → DB**, with the DB as the durable source of truth.

## 4) Docker fundamentals (student primer)

### What is Docker?

**Docker** is a toolchain for packaging and running applications in **containers**.

At a practical level, Docker gives you:
- A repeatable way to run the same application on different machines (your laptop, a server, CI) with the same dependencies.
- Isolation between services (each service runs with its own filesystem and process space).
- Easy local “microservices” setups (multiple containers that talk to each other over a private network).

Docker is not “a programming language”; it’s infrastructure tooling. You typically interact with it by:
- **pulling images** (download prebuilt software like Postgres)
- **building images** (create your own image from a `Dockerfile`)
- **running containers** (start/stop instances of those images)

Containers vs virtual machines (VMs), in one sentence:
- A VM runs a whole guest OS; a container runs processes isolated from each other but sharing the host OS kernel (lighter weight, faster startup).

### Image vs container (why the wording matters)
- An **image** is a reusable blueprint (like a class).
- A **container** is a running instance of an image (like an object).

In this repo:
- `mock-api-2` is built from a **Dockerfile** → you produce an image locally.
- Other services use prebuilt images from registries (e.g. `postgres`, `adminer`, `appsmith`).

### Docker Compose (what it is, and what `compose.yaml` does)

**Docker Compose** is a tool for running a multi-container application using a single YAML file.

In `compose.yaml`, each `services.<name>` entry defines:
- **How to start** that container (either `image:` or `build:`).
- **How it connects** to other containers (shared network + service names).
- **What data is persistent** (named volumes).
- **Which ports** (if any) are published to your machine.

Key Compose concepts used in this repo:
- `build:` vs `image:`  
  `build:` means “build a local image from a Dockerfile”. `image:` means “pull/run this prebuilt image”.
- `ports:`  
  Publishes a container port to your host (browser access). Example: Adminer publishes `8080:8080`.
- `environment:`  
  Passes configuration into the container. Example: Postgres reads `POSTGRES_USER/POSTGRES_PASSWORD/POSTGRES_DB`.
- `volumes:`  
  Mounts persistent storage or files into the container.
  - Named volumes (e.g. `postgres_data`) survive `docker compose down`.
  - Bind mounts (e.g. `./sql/init.sql:/docker-entrypoint-initdb.d/...`) inject files from this repo.
- `depends_on:`  
  Controls startup ordering (it is not a full readiness guarantee, but it avoids obvious races).

### Environment variables (how `.env` affects `compose.yaml`)

Docker Compose automatically loads a file named `.env` from the project directory (if present).

In `compose.yaml` you will see expressions like:
- `${POSTGRES_USER:-gameuser}`

This means:
- If `POSTGRES_USER` is set in your environment (or in `.env`), use it.
- Otherwise use the default `gameuser`.

This is why `cp .env.example .env` is optional: the compose file already has defaults, but `.env` lets you override them without editing YAML.

The most important variables in this project are:
- `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` (database credentials)
- `APPSMITH_ENCRYPTION_PASSWORD`, `APPSMITH_ENCRYPTION_SALT` (Appsmith internal encryption keys; required for stable operation)
- `DATABASE_URL` (backend → Postgres connection string; defaults to the local Postgres service)
- `AI_HINTS_ENABLED` and `OPENAI_API_KEY` (optional; AI hints are disabled by default)

### Networking: why Appsmith can’t use `localhost`

Inside Appsmith, `localhost` refers to the **Appsmith container itself**, not your laptop.

So in Appsmith datasources you must use Docker DNS service names:
- `postgres` (DB)
- `mock-api-1`, `mock-api-2` (mock APIs)
- `backend` (game API)

But in your browser (host machine) you use the published ports:
- `http://localhost` (Appsmith)
- `http://localhost:8080` (Adminer)
- `http://localhost:3000` / `http://localhost:3001` (mock APIs)

### Volumes: why data survives restarts

Two named volumes are used:
- `postgres_data` — Postgres data directory
- `appsmith_data` — Appsmith state (users, imported apps, datasource configs)

As long as you don’t run `docker compose ... down -v`, you keep your data.

### Debugging basics (commands you should know)

These are the standard Docker/Compose commands you’ll use to troubleshoot:

- List running containers: `docker compose -f compose.yaml ps`
- Tail logs: `docker compose -f compose.yaml logs -f --tail=200 backend`
- Restart a single service: `docker compose -f compose.yaml restart backend`
- Rebuild a single service: `docker compose -f compose.yaml up -d --build backend`
- Remove and recreate everything (clean slate): `docker compose -f compose.yaml down -v && docker compose -f compose.yaml up -d --build`

When something “hangs” in Appsmith, it’s usually one of:
- A datasource is pointing to `localhost` instead of a Docker service name (inside Docker).
- Postgres credentials/SSL are misconfigured in `WordGameDB`.
- A container is not healthy yet (check logs and wait a bit on first boot).

## 5) Appsmith fundamentals (low‑code UI)

### What is Appsmith?

**Appsmith** is a low‑code platform for building internal tools and dashboards.
Instead of writing a full frontend from scratch, you:
- place **widgets** (buttons, inputs, tables) on a canvas
- connect to **datasources** (databases and REST APIs)
- write small snippets of JavaScript in `{{ ... }}` bindings to connect UI actions to data

In this project, Appsmith is the main UI required by the exercise (`appsmith/appsmith-ce`).

### Key Appsmith terms used in this repo

- **Widget**: a UI component such as a Button, Input, Table, or Text.
- **Datasource**: saved connection details to a system you talk to.
  - Examples here: `WordGameDB` (Postgres), `GameAPI` (backend REST), `MockAPI1`, `MockAPI2`, `ServerlessAPI`.
- **Query / Action**: an executable operation that uses a datasource.
  - REST actions: call an HTTP endpoint (method + path) and get JSON back.
  - SQL queries: run SQL against Postgres and get rows back.
- **Binding**: `{{ ... }}` is Appsmith’s “evaluate this JavaScript and insert the result here” syntax.
- **Store**: `appsmith.store` is a small key/value state store for the UI.
  - `storeValue('key', value)` writes into the store so multiple widgets can share state.

### How this Appsmith app works (in simple terms)

1. You click a button (e.g. **Start new game**).
2. The button’s `onClick` runs one or more actions:
   - fetch data from a REST API (mock API or serverless API)
   - call the backend (`/start`, `/guess`, `/hint`, `/reveal`)
   - insert/read rows in Postgres (logs and tables)
3. Tables render the results of those actions, and text widgets show status from `appsmith.store`.

Concrete examples from this project:
- The external serverless call is a REST action against `ServerlessAPI` with a path like:
  - `/word?number=1&length={{ ... }}`
- Game actions call the backend through `GameAPI`:
  - `POST /start`, `POST /guess`, `POST /hint`, `POST /reveal`, `GET /leaderboard`
- Logs are stored in Postgres via `WordGameDB` SQL queries (e.g. insert into `api_logs`).

### Appsmith datasources in this project (what you reconnect after import)

When you import `appsmith/word-game-app.json`, Appsmith creates datasource *definitions* (names + types).
You then “Reconnect datasources” so those definitions point to the correct hosts/URLs in your environment.

This project uses 5 datasources:

| Datasource | Type | Used to talk to | What it provides to the UI |
|---|---|---|---|
| `WordGameDB` | PostgreSQL | `postgres:5432` inside Docker | SQL queries for logs/tables (`game_sessions`, `guesses`, `api_logs`, `favorites`) |
| `GameAPI` | REST API | `http://backend:8000` inside Docker | Game endpoints (`/start`, `/guess`, `/hint`, `/reveal`, `/leaderboard`) |
| `MockAPI1` | REST API | `http://mock-api-1:3000` inside Docker | Wordpacks dataset (`/wordpacks`) |
| `MockAPI2` | REST API | `http://mock-api-2:3001` inside Docker | Hint types dataset (`/hints`) |
| `ServerlessAPI` | REST API (external) | `https://random-word-api.herokuapp.com` | Random word generator (`/word?...`) |

Why the hostnames look “weird”:
- These hostnames are correct *from inside containers* (Appsmith runs in Docker).
- In your browser you still use `localhost` ports because those are host port mappings.

### Appsmith actions/queries in this project (what each one does)

An Appsmith **action** is a runnable request (REST call or SQL query). This export contains the following key actions:

**External serverless integration**
- `ServerlessLookup` (datasource `ServerlessAPI`): `GET /word?number=1&length=...` → returns `["word"]`
- `LogServerlessLookup` (datasource `WordGameDB`): inserts a row into `api_logs` with the length and full response payload

**Game backend integration (FastAPI)**
- `StartGame` (datasource `GameAPI`): `POST /start` with local-word mode (fallback)
- `StartGameExternal` (datasource `GameAPI`): `POST /start` with `target_word` from `ServerlessLookup`
- `StartGameFromWordpack` (datasource `GameAPI`): `POST /start` with `target_word` picked from the selected wordpack list
- `MakeGuess` (datasource `GameAPI`): `POST /guess` → returns similarity and whether correct
- `GetHint` (datasource `GameAPI`): `POST /hint` → returns a hint string (optionally controlled by selected hint type)
- `RevealWord` (datasource `GameAPI`): `POST /reveal` → ends game as a loss and returns the target
- `GetLeaderboard` (datasource `GameAPI`): `GET /leaderboard` → refreshes leaderboard table

**Mock API integration**
- `GetWordpacks` (datasource `MockAPI1`): `GET /wordpacks` → list of wordpacks (name, difficulty, words[])
- `GetPowerups` (datasource `MockAPI2`): `GET /hints` → list of hint types (name, type, description, etc.)

**Database (Postgres) logs/tables**
- `GetGameSessions` (datasource `WordGameDB`): selects latest sessions from `game_sessions`
- `GetGuessLog` (datasource `WordGameDB`): selects latest guesses from `guesses`
- `GetApiLogs` (datasource `WordGameDB`): selects latest external API logs from `api_logs`
- `GetFavorites` (datasource `WordGameDB`): selects latest favorites from `favorites`
- `SaveWordpackFavorite` / `SavePowerupFavorite` (datasource `WordGameDB`): upserts the currently selected item into `favorites`

### UI event map (which widgets trigger which actions)

This is the practical mapping between what you click in the UI and what runs behind the scenes:

- **Start new game** button:
  - If a wordpack is selected: runs `StartGameFromWordpack`.
  - Else: runs `ServerlessLookup` → (best-effort) `LogServerlessLookup` → `StartGameExternal`.
  - If the external API is down: falls back to `StartGame` (local word list).

- **Submit guess** button:
  - runs `MakeGuess`, updates `appsmith.store.guesses`, then refreshes the leaderboard (`GetLeaderboard`).

- **Get hint** button:
  - runs `GetHint`, appends to `appsmith.store.hints`, and updates the status line.

- **Reveal word** button:
  - runs `RevealWord` and then refreshes leaderboard (`GetLeaderboard`).

- **Load integrations and logs** button:
  - runs `GetWordpacks`, `GetPowerups`, and the DB log queries (`GetGameSessions`, `GetGuessLog`, `GetApiLogs`).

- Selecting a row in **Wordpacks** table:
  - stores the selected wordpack into `appsmith.store.selectedWordpack`.

- Selecting a row in **Hint types** table:
  - stores the selected hint type into `appsmith.store.selectedHintType`.

### Appsmith UI state (what is stored in `appsmith.store`)

The export uses `appsmith.store` as a lightweight state store shared across widgets:

| Store key | Meaning in this app |
|---|---|
| `playerName` | Player name used for backend calls and logs |
| `gameActive` | Whether a game is currently active (enables/disables actions) |
| `sessionId` | Current game session id from Postgres (shown in the UI) |
| `wordLength` | Target word length for the current session |
| `guesses` | List of guesses returned by the backend (rendered in a table) |
| `hints` | List of hints received so far (rendered in a table) |
| `status` | A human-readable status line shown in the UI |
| `selectedWordpack` | Selected wordpack object from Mock API 1 (or `null` for random) |
| `selectedHintType` | Selected hint type object from Mock API 2 (or `null` for auto) |
| `backendSource` | Backend-reported word source (e.g. local/wordpack/external) |
| `wordSource` | Legacy/fallback source label used by older bindings (kept for compatibility) |
| `wordpackInUse` | Backend-reported wordpack label (shown in the UI) |
| `activeTab` | Which tab is visible (`game` or `data`) |

### Why “Reconnect datasources” happens after import

An Appsmith export (`appsmith/word-game-app.json`) includes the *structure* of the app (widgets + actions),
but it does not include working credentials to your local environment.

So after importing, Appsmith asks you to “Reconnect datasources” so you can provide:
- Postgres host/user/password/db name
- REST base URLs for each API

### Common beginner mistakes (and why they happen)

1. **Using `localhost` in a datasource**
   - Inside Appsmith, `localhost` means “the Appsmith container”, not your laptop.
   - Use service names (`postgres`, `backend`, `mock-api-1`, `mock-api-2`) for internal calls.
2. **JavaScript errors inside `{{ ... }}` bindings**
   - Many widget properties expect a single JavaScript *expression*.
   - If you need multiple steps (variables/conditions), wrap them in a function:
     - `{{ (function () { /* multi-step JS */ return value; })() }}`

## 6) FastAPI + REST fundamentals

### What is FastAPI?

**FastAPI** is a Python web framework for building **REST APIs**.

In this repo, FastAPI runs in the `backend` container and exposes endpoints that Appsmith calls to:
- start a game
- submit guesses
- request hints
- reveal the answer
- fetch the leaderboard

It’s served by **Uvicorn** (the Python web server process that runs the FastAPI app) inside the container (see `backend/Dockerfile` + `backend/app.py`).

### What is a REST API (in practical terms)?

REST is a style for web APIs where you call URLs (“endpoints”) using HTTP methods:
- `GET` → read data (e.g. `/leaderboard`)
- `POST` → create/perform an action (e.g. `/start`, `/guess`)

Requests and responses are JSON.

### Backend endpoints used by the UI

Appsmith calls these endpoints via the `GameAPI` datasource (base URL `http://backend:8000` inside Docker):

| Endpoint | Method | UI action | What it does | DB effect |
|---|---|---|---|---|
| `/start` | POST | Start new game | Creates a `game_sessions` row and selects a target word | INSERT `game_sessions` |
| `/guess` | POST | Submit guess | Computes similarity and records the guess | INSERT `guesses`, may UPDATE `game_sessions` on win |
| `/hint` | POST | Get hint | Returns a hint (optionally controlled by selected hint type) | Updates in-memory state; session row updated when game ends |
| `/reveal` | POST | Reveal word | Ends the game as a loss and returns the target | UPDATE `game_sessions` |
| `/leaderboard` | GET | Refresh leaderboard | Returns aggregated leaderboard data | Updates/UPSERTs `leaderboard` |
| `/health` | GET | (debug) | Confirms backend + DB connectivity | Read-only |

### Backend request/response examples (what the JSON looks like)

These examples are simplified for learning; Appsmith sends the same *shape* of JSON.

**Start a new game** (`POST /start`)

Request JSON:
```json
{
  "player_name": "Alice",
  "word_length": 8,
  "target_word": "mountain",
  "wordpack_name": "External API"
}
```

Important notes:
- `target_word` is optional.
  - If it is provided, the backend uses it as the target.
  - If it is not provided, the backend chooses a word from its local list.
- `wordpack_name` is informational (used for labeling “source” in responses/UI).

Response JSON (example):
```json
{
  "message": "New game started with external word. Try to guess it.",
  "word_length": 8,
  "session_id": 42,
  "word_source": "external",
  "wordpack_name": "External API"
}
```

**Submit a guess** (`POST /guess`)

Request JSON:
```json
{
  "player_name": "Alice",
  "word": "hill"
}
```

Response JSON (example):
```json
{
  "similarity": 0.6523,
  "all_guesses": [
    { "word": "hill", "similarity": 0.6523, "guess_number": 1 }
  ],
  "is_correct": false,
  "guesses_count": 1
}
```

**Get a hint** (`POST /hint`)

Request JSON:
```json
{
  "player_name": "Alice",
  "hint_type": "definition"
}
```

Response JSON (example):
```json
{
  "hint": "A large natural elevation of earth.",
  "hints_used": 2
}
```

**Reveal the word (give up)** (`POST /reveal`)

Request JSON:
```json
{
  "player_name": "Alice"
}
```

Response JSON (example):
```json
{
  "target_word": "mountain",
  "total_guesses": 3,
  "score": 41
}
```

### Backend state model (why “start new game” matters)

The backend keeps *active* game state in memory per `player_name` (current target word, guesses so far, hints used).
Postgres is used for persistence and history, but the active target word is not meant to be fetched from the DB by the UI.

Practical implications:
- You must press **Start new game** before guessing/hints/reveal.
- After you win or reveal, the backend clears the active session for that player (so you need to start again).

### Similarity scoring (why the game is “semantic”)

This game does not only check exact equality. It also computes a **semantic similarity score**:
- The backend converts words into vectors (“embeddings”) using a pretrained model.
- It compares vectors with **cosine similarity** (range roughly 0..1).
- A guess is treated as “correct” if it matches the target exactly or has extremely high similarity.

This is why you can see similarity scores increasing as you guess related words.

## 7) How to run (and what to screenshot)

### Run commands

Start:
```bash
docker compose -f compose.yaml up -d --build
docker compose -f compose.yaml ps
```

Stop:
```bash
docker compose -f compose.yaml down
```

Reset everything (only when you want a clean system):
```bash
docker compose -f compose.yaml down -v
docker compose -f compose.yaml up -d --build
```

### UI + datasource configuration (must match README)

1. Open Appsmith: `http://localhost`.
2. Import: `appsmith/word-game-app.json`.
3. Reconnect datasources:
   - `WordGameDB` (PostgreSQL): host `postgres`, port `5432`, db `wordgame`, user `gameuser`, pass `gamepass123`, SSL **disabled**
   - `MockAPI1` (REST): `http://mock-api-1:3000`
   - `MockAPI2` (REST): `http://mock-api-2:3001`
   - `ServerlessAPI` (REST): `https://random-word-api.herokuapp.com`
   - `GameAPI` (REST): `http://backend:8000`

### What screenshots prove you satisfy the exercise

For your `report.pdf` and `presentation.pptx`, capture:
- Docker: `docker compose ps` showing all containers running.
- Appsmith: the Gameplay tab running (start game + guesses).
- Appsmith: Integrations & Logs tab showing mock data + DB logs.
- Adminer: tables populated (`game_sessions`, `guesses`, `api_logs`).

## 8) Academic notes (why the design is defensible)

This implementation intentionally separates concerns:
- **UI layer (Appsmith)**: interaction logic + visualization; no heavy compute.
- **Service layer (backend)**: domain rules (game mechanics) exposed as a REST API.
- **Data layer (Postgres)**: durable state; enables inspection and reporting (Adminer).
- **External integrations**:
  - Mock APIs provide stable, local “external” datasets for integration scenarios.
  - A serverless public API provides an actual external dependency and a logging use case.

This separation is a common approach in cloud architectures because it:
- Improves modularity (UI can change without rewriting business logic).
- Encourages explicit contracts (API endpoints + SQL schema).
- Makes observability and grading easier (DB tables show evidence of flows).

## 9) Glossary (plain-language definitions)

- **API (Application Programming Interface)**: a way for software to talk to other software. In this project we mainly use web APIs over HTTP.
- **REST API**: a common style of web API where you call URLs (“endpoints”) with methods like `GET` and `POST` and exchange JSON.
- **Endpoint**: a specific URL path on an API, such as `/start` or `/leaderboard`.
- **HTTP**: the protocol browsers and many APIs use. A request has a method (like `GET`/`POST`), a URL, headers, and sometimes a JSON body.
- **JSON**: a text format for structured data (objects/arrays) used by most web APIs.
- **Microservice**: a small service that does one job and communicates with other services over the network (usually via REST APIs).
- **CI (Continuous Integration)**: automated pipelines that build/test code when you push changes (often runs in containers too).

- **Docker**: tooling for packaging and running applications in containers.
- **Image**: a packaged filesystem + metadata used to start containers (the blueprint).
- **Container**: a running instance of an image (the process).
- **Docker Compose**: a tool and file format (`compose.yaml`) for running multiple containers together.
- **Service (Compose)**: one named container definition in `compose.yaml` (e.g. `postgres`, `backend`).
- **Port mapping**: exposing a container port to your machine, like `8080:8080` (host:container).
- **Volume**: persistent storage managed by Docker (data survives restarts). This repo uses volumes for Postgres and Appsmith state.
- **Bind mount**: mounting a file/folder from this repo into a container (e.g. SQL files loaded by Postgres).
- **Environment variable**: configuration passed into a container process (e.g. DB credentials).
- **Service name (Docker DNS)**: the hostname Docker assigns inside the Compose network (e.g. `postgres`); containers can reach each other by these names.

- **PostgreSQL (Postgres)**: a relational database system. It stores data in tables and is queried with SQL.
- **SQL**: the language used to create tables and query/update data in a relational database.
- **Table / row / column**: table = collection of records, row = one record, column = one field of a record.
- **Primary key**: the unique identifier for rows in a table (e.g. `session_id`).
- **Foreign key**: a column that references another table’s primary key to link data (e.g. `guesses.session_id` → `game_sessions.session_id`).
- **UPSERT**: “insert or update”; a DB operation that creates a row if it doesn’t exist, otherwise updates it.

- **Serverless service / API**: an external managed service you call over the internet (no container is running in your Compose). Here it’s the public random-word API.
- **Low‑code**: building software mostly by configuration and UI building blocks, with small code snippets where needed (Appsmith).
- **Datasource (Appsmith)**: saved connection to an API or database.
- **Query/Action (Appsmith)**: a runnable operation against a datasource (HTTP request or SQL query).
- **Widget (Appsmith)**: a UI element such as a button, input, text, or table.

- **Health check**: a simple endpoint or command that indicates whether a service is running correctly (this project uses `/health` on the backend).
- **Embedding**: a numeric vector representation of a word or sentence used for similarity comparisons.
- **Cosine similarity**: a method to compare two vectors; higher means “more similar”.
