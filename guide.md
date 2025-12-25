# Semantic Word Game — Junior-Friendly Guide

This repo can feel “big” at first because it uses several technologies at once (Docker, an API, a database, a UI, and a little bit of AI/ML). This guide explains those pieces from easiest to hardest, with examples you can try, so that when you open `README.md` you’ll understand what it’s telling you and why.

---

## How to use this guide

- Read from top to bottom the first time.
- Don’t try to memorize everything. The goal is: *recognize the moving parts and know where to look*.
- When you see a file path like `backend/app.py`, open it and skim it while you read this guide.

At the end, read `README.md` for the exact “how to run it” commands and URLs.

## What you’ll learn (overview)

- What each folder/service does in this repo
- How the UI calls the backend (HTTP + JSON)
- How the backend calculates similarity and generates hints
- How PostgreSQL stores sessions/guesses and updates the leaderboard
- How to debug issues by checking health, logs, and the database

---

## 1) What this project is (big picture)

This is a **word guessing game**:

- The backend secretly picks a noun (from `backend/nouns.json`).
- You guess words.
- The backend scores your guess using **semantic similarity** (meaning-similarity, not spelling-similarity).
- You can ask for hints.
- Finished games and guesses are saved in **PostgreSQL**, and a **leaderboard** is maintained.

There are multiple ways to interact with it:

- A **static web UI** (a single HTML page) served by the backend.
- An **Appsmith** UI (a low-code tool) that can be imported.
- A **mock API** (json-server) that serves demo data for UI prototyping.

### A mental model (diagram)

```
Browser (static UI)  --->  FastAPI backend  --->  PostgreSQL
                               |
                               +--> WordNet (NLTK) hint generation
                               +--> SentenceTransformer model (embeddings)
                               +--> (optional) OpenAI API for AI hints

Appsmith UI  ---> (talks to backend, stores its own config in MongoDB)

Adminer  ---> (web UI for inspecting PostgreSQL)

Mock API (json-server) ---> demo endpoints for hints/achievements/powerups
```

### Once it’s running (useful URLs)

| What | URL | Notes |
|---|---|---|
| Static UI | http://127.0.0.1:8000/ | The main “game page” served by the backend |
| API docs (Swagger) | http://127.0.0.1:8000/docs | Interactive API documentation |
| Adminer | http://localhost:8080 | Web UI for inspecting PostgreSQL |
| Appsmith | http://localhost | Low-code UI tool (import the JSON app) |
| Mock API (example) | http://localhost:3001/hints | Demo data endpoints (not required by the backend) |

---

## 2) Quick repo tour (what each folder is)

Open the repo root and you’ll see:

- `docker-compose.yaml`  
  Defines all the services (backend, database, Appsmith, etc.) and how they connect.

- `.env.example`  
  A template of environment variables (configuration settings). You usually copy it to `.env`.

- `backend/` (Python backend + static UI)
  - `backend/app.py` — the FastAPI application (API routes + game logic)
  - `backend/requirements.txt` — Python dependencies
  - `backend/Dockerfile` — how the backend container image is built
  - `backend/nouns.json` — the word list
  - `backend/static/index.html` — the static web UI (HTML/CSS/JS)

- `sql/` (database schema + sample data)
  - `sql/init.sql` — creates tables, indexes, views, triggers
  - `sql/export.sql` — sample rows (sessions, guesses, leaderboard, stats)

- `appsmith/`
  - `appsmith/word-game-app.json` — an Appsmith application export you can import

- `mock-api-2/` (demo REST API)
  - `mock-api-2/Dockerfile` — builds a json-server container
  - `mock-api-2/db.json` — the data json-server serves as REST endpoints

---

## 3) The simplest concepts you’ll need

Before Docker and backend code, learn these basics. They appear everywhere in this repo.

### 3.1 Environment variables (config without code changes)

An **environment variable** is a `NAME=value` pair used to configure software.

Example (from `.env.example`):

```bash
POSTGRES_USER=gameuser
POSTGRES_PASSWORD=gamepass123
POSTGRES_DB=wordgame
```

Why it matters here:

- Docker Compose uses these values to configure PostgreSQL.
- The backend builds a database connection string (`DATABASE_URL`) using them.
- Optional AI hinting uses variables like `AI_HINTS_ENABLED` and `OPENAI_API_KEY`.

Important: `.env` is in `.gitignore`, so it should not be committed. Keep secrets (API keys, passwords) private.

### 3.2 Ports (how services are reachable)

Computers can run many servers at once. A **port** is like a “channel number”.

Example: `127.0.0.1:8000` means:

- `127.0.0.1` = your computer (localhost)
- `8000` = port number where the backend listens

In `docker-compose.yaml` you’ll see port mappings like:

```yaml
ports:
  - "8000:8000"
```

That means:

- left side (`8000`) = port on *your* computer
- right side (`8000`) = port inside the container

### 3.3 HTTP + JSON (how the UI talks to the backend)

The UI calls the backend using **HTTP requests**.

- `GET` usually means “read data”
- `POST` usually means “create or perform an action”

Requests and responses use **JSON**, which looks like:

```json
{ "player_name": "Alex", "word": "mountain" }
```

If you understand ports + HTTP + JSON, you can already follow the whole app at a high level.

---

## 4) Docker basics (what you need to understand Compose)

This repo is **fully Dockerized**. That means when you run the project, you are running a set of **containers** (backend, databases, UIs, admin tools), not processes installed directly on your laptop.

Why this is used (academic overview):

- **Reproducibility**: the “environment” (versions + dependencies) is captured in images and config files.
- **Isolation**: each service runs with its own dependencies without polluting your computer.
- **Deployment thinking**: you learn a realistic multi-service architecture (API + DB + admin UI + optional extras).

### 4.0 Prerequisite: Docker Desktop (or Docker Engine)

To run a Dockerized project, you need Docker.

- **macOS / Windows (most common)**: install **Docker Desktop**, then open it so the Docker engine is running.
- **Linux**: install Docker Engine + the Docker Compose plugin.

Quick “is it installed?” check:

```bash
docker --version
docker compose version
```

### 4.1 Containers vs virtual machines (what Docker really is)

Docker uses **OS-level containerization** (not full virtualization).

- A **virtual machine** emulates a whole computer (hardware + guest OS). Powerful, but heavier and slower to boot.
- A **container** shares the host OS kernel but isolates processes using mechanisms like namespaces and cgroups. Lighter and faster to start.

For learning purposes, it’s okay to treat a container as “a small, isolated computer process” that can be started/stopped/deleted safely.

### 4.2 Image vs container (the single most important Docker idea)

- An **image** is a read-only blueprint (built in layers) that contains software + dependencies.
- A **container** is a running instance of an image (with a small writable layer on top).

Analogy:

- Image = recipe
- Container = the cooked meal on your plate

Containers are usually **disposable**:

- Stop/start them anytime.
- If a container is deleted, data inside it is gone unless stored in a **volume**.

### 4.3 Dockerfile (how images are built)

A **Dockerfile** is a recipe that tells Docker how to build an image.

Core idea (academic):

- Each instruction forms a **layer**.
- Docker can reuse layers via **build cache**.
- Good Dockerfiles are written to maximize caching (dependencies first, app code later).

Common instructions you’ll see in this repo:

- `FROM` — choose a base image (like Python or Node)
- `WORKDIR` — choose a working directory inside the image
- `COPY` — copy files from your repo into the image
- `RUN` — run commands at build time (install dependencies, download assets/models)
- `EXPOSE` — document which port the container listens on
- `HEALTHCHECK` — define “is the service alive?” checks
- `CMD` — the default command that starts the service when the container runs

### 4.4 Docker Compose (multi-container apps)

Docker Compose is for running multiple containers that belong together.

Think of Compose as a **declarative description** of:

- which services exist
- how they connect (network)
- where data lives (volumes)
- how your computer can reach them (ports)
- what configuration they get (environment variables)

Compose reads `docker-compose.yaml` and turns it into running containers.

### 4.5 What happens when you run `docker compose up`

When you run:

```bash
docker compose up -d
```

Compose typically:

1. **Builds** images for services that have `build:` (in this repo: `game-backend`, `mock-api-2`).
2. **Pulls** images for services that have `image:` (in this repo: `postgres`, `adminer`, `appsmith`, `mongo`).
3. Creates a shared **network** so containers can reach each other by service name.
4. Creates **volumes** for persistent data.
5. Starts containers and runs **healthchecks** (if configured).

Useful commands:

```bash
docker compose ps
docker compose logs -f game-backend
docker compose logs -f postgres
```

Stop everything:

```bash
docker compose down
```

Reset everything (destructive: removes volumes, so DB data is deleted):

```bash
docker compose down -v
```

### 4.6 Volumes (data that survives restarts)

Volumes are persistent storage managed by Docker.

Academic idea:

- Containers are designed to be ephemeral (throw-away).
- Databases need durable storage.
- Volumes provide durability.

In this repo:

- PostgreSQL uses a named volume for its data directory.
- Appsmith and Mongo also use named volumes.

You’ll also see **bind mounts** (file mounts) that share specific files into containers (for example SQL init scripts).

### 4.7 Networks (containers talking to each other) + the “localhost” gotcha

Inside Docker Compose, services can talk to each other by service name.

Example: the backend connects to Postgres using host `postgres` (the service name), not `localhost`.

Beginner gotcha:

- **Inside a container, `localhost` means “this same container”.**
- To reach another container: use its Compose name (`postgres`, `mongo`, etc.).
- To reach your computer from a container: Docker Desktop often provides `host.docker.internal`.

---

## 5) How *this* repo uses Docker Compose

Open `docker-compose.yaml` and skim it while reading this section.

### 5.0 Everything is Dockerized here (what that really means)

In this project, “running the app” means running multiple services together:

- the **FastAPI backend**
- **PostgreSQL** for persistence
- **Adminer** to inspect the database
- **Appsmith** (plus **MongoDB**) for a low-code UI option
- a **mock API** for demo data

This is why you’ll see multiple ports and multiple containers.

### 5.1 Once it’s running: what you can access from your computer

Docker Compose maps container ports to your computer ports (via `ports:`). That’s why you can open URLs in a browser.

| Component | How you access it from your computer | Why it works |
|---|---|---|
| Static UI | `http://127.0.0.1:8000/` | `game-backend` publishes container port 8000 to host port 8000 |
| FastAPI docs | `http://127.0.0.1:8000/docs` | FastAPI auto-generates Swagger UI |
| Adminer | `http://localhost:8080` | `adminer` publishes container port 8080 to host port 8080 |
| Appsmith | `http://localhost` | `appsmith` publishes container port 80 to host port 80 |
| Mock API | `http://localhost:3001/hints` | `mock-api-2` publishes container port 3001 to host port 3001 |
| PostgreSQL | `localhost:5432` | `postgres` publishes container port 5432 to host port 5432 (DB clients connect here) |

Important note about Postgres:

- Postgres is **not** a website, so there is no browser URL like `http://localhost:5432`.
- You access it with a database client (or Adminer).

Example connection string from your computer:

```
postgresql://gameuser:gamepass123@localhost:5432/wordgame
```

Example: open a Postgres shell inside the container (no local installs needed):

```bash
docker compose exec -it postgres psql -U gameuser -d wordgame
```

### 5.2 Built images vs pulled images (and what “build Postgres” really means)

In Compose, services either:

- **build** from a Dockerfile in your repo, or
- **pull** a prebuilt image from a registry (like Docker Hub)

In this repo:

- Built from this repo’s Dockerfiles:
  - `game-backend` → `backend/Dockerfile`
  - `mock-api-2` → `mock-api-2/Dockerfile`

- Pulled from prebuilt images:
  - `postgres` → `postgres:15-alpine`
  - `adminer` → `adminer:latest`
  - `appsmith` → `appsmith/appsmith-ce:latest`
  - `mongo` / `mongo-init` → `mongo:6`

So when someone says “build Postgres” in this repo, what actually happens is usually:

- Docker **downloads** the official Postgres image (pull)
- then starts a container from it

### 5.3 Services in this repo (what each one contributes)

- `game-backend` (Python + FastAPI)  
  - built locally from `backend/Dockerfile`
  - serves the API and also serves `backend/static/index.html`
  - talks to Postgres via `DATABASE_URL`

- `postgres` (PostgreSQL)
  - stores game sessions, guesses, and leaderboard data
  - runs `sql/init.sql` and `sql/export.sql` the *first time* a fresh volume is created

- `adminer` (DB inspection UI)
  - makes Postgres easy to browse for beginners (tables, rows, SQL queries)

- `appsmith` (low-code UI) + `mongo` (its database)
  - Appsmith stores its configuration/data in MongoDB
  - Appsmith can call the backend API and/or embed the static UI

- `mock-api-2` (json-server)
  - provides demo endpoints (hints/achievements/powerups) from a static JSON file
  - useful for UI prototyping

### 5.4 How to read the most important Compose features in `docker-compose.yaml`

Here are the fields you’ll see most (with what they *mean*, not just what they do):

- `ports`  
  *Theory*: “Expose an internal service to the outside world.”  
  *Practice*: lets you open `http://localhost:8080` for Adminer.

- `environment`  
  *Theory*: “Configure a process without changing code.”  
  *Practice*: `POSTGRES_PASSWORD` configures Postgres; `AI_HINTS_ENABLED` configures optional AI hints.

- `volumes`  
  *Theory*: “Persist state and share files.”  
  *Practice*:
  - named volume keeps DB data across restarts
  - bind mounts inject `sql/init.sql` into Postgres so it can initialize the schema

- `depends_on` + `healthcheck`  
  *Theory*: “Orchestrate startup order so dependencies are ready.”  
  *Practice*: backend waits for Postgres to be healthy before starting.

### 5.5 File mounts you should notice (how files get into containers)

Some mounts in `docker-compose.yaml` are especially important:

- Postgres init scripts:
  - `./sql/init.sql:/docker-entrypoint-initdb.d/01-init.sql`
  - `./sql/export.sql:/docker-entrypoint-initdb.d/02-sample-data.sql`

  These are executed by the official Postgres image **only on first initialization** of a fresh data directory (fresh volume).

- Backend nouns file:
  - `./backend/nouns.json:/app/nouns.json:ro`

  The `:ro` means **read-only**, which is a nice safety practice.

### 5.6 Dockerfiles in this repo (detailed, line-by-line)

This repo contains two custom Dockerfiles. Everything else uses official prebuilt images.

#### 5.6.1 `backend/Dockerfile` (Python backend image)

File: `backend/Dockerfile`

```dockerfile
FROM python:3.10-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

RUN python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('all-MiniLM-L6-v2')"

RUN python -c "import nltk; nltk.download('wordnet', quiet=True); nltk.download('omw-1.4', quiet=True)"

COPY app.py .
COPY nouns.json .

RUN mkdir -p static

COPY static/ ./static/

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/health')" || exit 1

CMD ["python", "app.py"]
```

What each part is doing:

- `FROM python:3.10-slim`  
  Uses an official Python image that is smaller than a full Debian/Ubuntu image. Smaller images download faster and have fewer extra packages.

- `WORKDIR /app`  
  Sets the working directory inside the container. After this, commands run “inside” `/app`.

- `RUN apt-get update && apt-get install ...`  
  Installs OS-level packages:
  - `gcc` is a compiler (sometimes needed to build Python packages with native extensions).
  - `postgresql-client` provides tools like `psql` (useful for debugging).
  - `rm -rf /var/lib/apt/lists/*` cleans up apt metadata to reduce image size.

- `COPY requirements.txt .`  
  Copies dependency list first to maximize Docker build caching.

- `RUN pip install --no-cache-dir -r requirements.txt`  
  Installs Python dependencies inside the image.

- `RUN python -c "... SentenceTransformer('all-MiniLM-L6-v2')"`  
  Pre-downloads the embedding model at image build time so the container doesn’t need to download it on first request.

- `RUN python -c "... nltk.download(...)"`  
  Pre-downloads WordNet datasets used by the hint system.

- `COPY app.py .` and `COPY nouns.json .`  
  Copies the application code and the word list into the image.

- `COPY static/ ./static/`  
  Copies the frontend files served by the backend.

- `EXPOSE 8000`  
  Documents that the container listens on port 8000 (Compose still controls what’s exposed to your computer).

- `HEALTHCHECK ... /health`  
  Defines how Docker/Compose can check if the backend is alive. If this fails repeatedly, Compose will mark the container as unhealthy.

- `CMD ["python", "app.py"]`  
  Starts the backend. In this repo, `backend/app.py` uses Uvicorn to run FastAPI.

Why this image can take time to build the first time:

- It downloads the SentenceTransformer model
- It downloads NLTK WordNet data

That’s a one-time “cost” that makes later container starts faster.

#### 5.6.2 `mock-api-2/Dockerfile` (json-server demo API)

File: `mock-api-2/Dockerfile`

```dockerfile
FROM node:18-alpine

LABEL maintainer="Word Game Team"
LABEL description="REST API for hints and achievements"

WORKDIR /app

RUN npm install -g json-server@0.17.4

COPY db.json /app/db.json

EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3001/hints', (r) => {if(r.statusCode !== 200) throw new Error()})"

CMD ["json-server", "--watch", "/app/db.json", "--host", "0.0.0.0", "--port", "3001"]
```

What’s happening here:

- `FROM node:18-alpine`  
  Uses a small Linux base with Node.js installed.

- `RUN npm install -g json-server@0.17.4`  
  Installs json-server globally. json-server turns a JSON file into REST endpoints automatically.

- `COPY db.json /app/db.json`  
  Provides the data that becomes endpoints like `/hints`, `/achievements`, `/powerups`.

- `EXPOSE 3001`  
  Documents the port used by the service.

- `HEALTHCHECK ... /hints`  
  Checks whether the service responds successfully.

- `CMD ["json-server", ...]`  
  Starts json-server, listening on `0.0.0.0` (so the port is reachable from outside the container).

### 5.7 Practice exercise: connect ports to what you see

1. Run `docker compose up -d`.
2. Run `docker compose ps` and find the `PORTS` column.
3. For each service with a port mapping, open the matching URL in your browser.
4. If something doesn’t load, check the logs for that container.

---

## 6) The static UI (HTML/CSS/JS) — the easiest code to read

If you’re new, start with `backend/static/index.html`. It’s a single page that:

- shows inputs/buttons (HTML)
- looks nice (CSS)
- calls the backend (JavaScript `fetch`)
- draws charts (Plotly, loaded from a CDN)

### 6.1 The key idea: the UI calls API endpoints

In the JavaScript section of `backend/static/index.html`, you’ll find calls like:

```js
await fetch('/start', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ player_name: playerName })
});
```

Because it uses `'/start'` (a relative URL), it calls the same server that served the page — the FastAPI backend.

### 6.2 An easy debugging trick

Open your browser devtools:

- **Network tab** shows every `/start`, `/guess`, `/hint`, `/reveal` request.
- **Console tab** shows JavaScript errors.

This is a great way to “see” how frontend and backend talk to each other.

---

## 7) The backend API (FastAPI) — the heart of the app

When people say “backend” or “API”, they mean: **a server program that waits for requests and sends responses**.

In this repo, the backend is written in Python using **FastAPI**, and it does most of the “real work”:

- chooses the secret word
- scores guesses
- generates hints
- stores finished games in PostgreSQL
- serves the static UI page

### 7.1 The basic theory: client/server, requests, responses

**Client-server model (academic idea)**:

- A **client** (browser, mobile app, curl, Appsmith) sends a request.
- A **server** (your FastAPI backend) receives it, does work, and sends a response.

**HTTP request = method + path + data**

- Method: `GET`, `POST`, etc.
- Path: `/start`, `/guess`, `/leaderboard`
- Data:
  - request body (JSON for POST requests)
  - query params (`?limit=10`)

**HTTP response = status code + data**

- `200` = success
- `400` = client error (bad input)
- `422` = validation error (input didn’t match the expected shape)
- `404` = not found
- `500` = server error

FastAPI returns data as **JSON**, because JSON is the most common “language” APIs speak.

### 7.2 What FastAPI is (and why it’s used)

FastAPI is a **web framework**.

Academic perspective: a web framework’s job is to reliably handle the boring/standard parts of web servers:

- parse incoming HTTP requests
- validate input
- route each request to the correct function
- serialize Python objects into JSON responses
- generate an API schema (OpenAPI)

FastAPI is popular because it also gives you:

- **type-based validation** via Pydantic models (your request/response shapes are explicit)
- **automatic documentation** at `/docs`
- good performance and async support (ASGI)

In practice: it lets you write Python functions and expose them as web endpoints.

### 7.3 A tiny FastAPI example (so you “feel” how it works)

This example is not from the repo — it’s a minimal “toy API” to teach the concepts:

```py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI()

class HelloRequest(BaseModel):
    name: str

@app.get("/ping")
def ping():
    return {"ok": True}

@app.post("/hello")
def hello(req: HelloRequest):
    if not req.name.strip():
        raise HTTPException(status_code=400, detail="Name is required.")
    return {"message": f"Hello, {req.name}!"}
```

What this teaches:

- `@app.get("/ping")` means: “When someone does `GET /ping`, run `ping()`.”
- `@app.post("/hello")` means: “When someone does `POST /hello`, run `hello()`.”
- `HelloRequest` defines what JSON you expect. FastAPI parses JSON into this model automatically.
- `HTTPException` creates an error response with a status code.

If you run this locally (optional learning exercise), you’d typically use Uvicorn:

```bash
uvicorn demo:app --reload --port 8001
```

Then you can try:

```bash
curl -sS "http://127.0.0.1:8001/ping"
curl -sS -X POST "http://127.0.0.1:8001/hello" -H "Content-Type: application/json" -d '{"name":"Alex"}'
```

And you can open:

- `http://127.0.0.1:8001/docs` (interactive docs)

Again: you do **not** need to do this to run this repo. It’s just a clean “learning example”.

### 7.4 How FastAPI becomes “interactive docs” (OpenAPI)

FastAPI generates an **OpenAPI schema** describing your endpoints, inputs, and outputs.

That’s why you get:

- `http://127.0.0.1:8000/docs` — Swagger UI (click buttons, send requests)
- `http://127.0.0.1:8000/openapi.json` — the machine-readable API schema

In this repo, you can use `/docs` to:

1. click an endpoint like `POST /start`
2. click **Try it out**
3. type JSON
4. click **Execute**

This is an excellent beginner workflow because it avoids writing any frontend code.

### 7.5 How to read this repo’s backend (`backend/app.py`)

Open `backend/app.py`. You’ll see the backend is organized around:

- **models** (Pydantic classes) describing input/output shapes
- **routes** (functions decorated with `@app.get(...)` / `@app.post(...)`)
- **game logic** (start game, score guesses, generate hints)
- **database logic** (insert sessions and guesses; update leaderboard)

Also note the “server process”:

- FastAPI is the app, but it needs a server to run it.
- In this repo, `backend/app.py` runs Uvicorn in `if __name__ == "__main__":`.
- In Docker, the backend listens on `0.0.0.0:8000` so the port can be published to your computer.

### 7.6 The endpoints in this repo

From `backend/app.py` (try these first in `/docs`):

- `POST /start`  
  Starts a new game for a player name. Creates a `game_sessions` row in Postgres.

- `POST /guess`  
  Scores a guessed word with semantic similarity. Inserts a `guesses` row.  
  If correct, ends the game and updates `game_sessions` (which triggers leaderboard updates).

- `POST /hint`  
  Increments “hints used” and returns a hint. Uses local WordNet hints, or optional AI hints.

- `POST /reveal`  
  Ends the game as a loss and reveals the answer. Updates the DB.

- `GET /leaderboard`  
  Reads the `leaderboard` table and returns top players.

- `GET /stats`  
  Shows *in-memory* active game state (not the full database history).

- `GET /health`  
  Health check that also tests database connectivity.

- `GET /`  
  Serves the static UI (`backend/static/index.html`).

### 7.7 Try the API without any UI (curl examples)

These are safe, beginner-friendly experiments.

Start a game:

```bash
curl -sS -X POST "http://127.0.0.1:8000/start" \
  -H "Content-Type: application/json" \
  -d '{"player_name":"Alex"}'
```

Example response:

```json
{ "message": "New game started! Try to guess the word.", "word_length": 8 }
```

Make a guess:

```bash
curl -sS -X POST "http://127.0.0.1:8000/guess" \
  -H "Content-Type: application/json" \
  -d '{"player_name":"Alex","word":"mountain"}'
```

Example response shape (values will vary):

```json
{
  "similarity": 0.357,
  "all_guesses": [{ "word": "mountain", "similarity": 0.357, "guess_number": 1 }],
  "is_correct": false,
  "guesses_count": 1
}
```

Ask for a hint:

```bash
curl -sS -X POST "http://127.0.0.1:8000/hint" \
  -H "Content-Type: application/json" \
  -d '{"player_name":"Alex"}'
```

Example response:

```json
{ "hint": "A device used for ...", "hints_used": 1 }
```

Give up (reveal):

```bash
curl -sS -X POST "http://127.0.0.1:8000/reveal" \
  -H "Content-Type: application/json" \
  -d '{"player_name":"Alex"}'
```

Example response:

```json
{ "target_word": "...", "total_guesses": 5, "score": 35 }
```

Leaderboard:

```bash
curl -sS "http://127.0.0.1:8000/leaderboard?limit=10"
```

Example response (a list of players):

```json
[
  {
    "player_name": "Alice",
    "total_games": 2,
    "games_won": 2,
    "total_guesses": 14,
    "best_score": 98,
    "avg_guesses": 7.0,
    "win_rate": 100.0
  }
]
```

### 7.8 A subtle detail: in-memory game state vs database history

In `backend/app.py`, active games are stored in memory:

- `game_states: Dict[str, GameState] = {}`
- keyed by `player_name`

That means:

- If the backend container restarts, **active games disappear** (because RAM is cleared).
- Finished games are still in Postgres (because the DB is persistent).

This is a common “starter architecture” pattern: it’s simple and works well for a demo.

---

## 8) The “semantic” part (ML/NLP, explained simply)

This game does not check “how close the spelling is”. It checks “how close the meaning is”.

### 8.1 Embeddings (turning words into vectors)

The backend loads a SentenceTransformer model:

- model name: `all-MiniLM-L6-v2`
- library: `sentence-transformers`

The model turns a word into a long list of numbers (a **vector**). Similar-meaning words tend to have vectors that point in similar directions.

### 8.2 Cosine similarity (a score between -1 and 1)

In `POST /guess`, the backend computes:

- `1.0` = extremely similar (basically the same)
- `0.0` = unrelated
- negative values = opposite-ish (rare for single nouns, but possible)

The code is basically:

```py
similarity = dot(a, b) / (norm(a) * norm(b))
```

And the game counts a guess as “correct” if:

- the guessed word equals the target, OR
- similarity is greater than `0.99`

Why `0.99`? It’s a “close enough to be essentially identical” threshold for this demo.

---

## 9) Hints (WordNet + optional AI hints)

Hints are designed to help you converge on the answer **without directly revealing it**. In a well-designed word game, hints usually follow a “difficulty ladder”: early hints give *conceptual* help, and later hints give *structural* help (letters/patterns).

### 9.1 Hint systems (game design + information theory intuition)

At a high level, a hint system tries to manage **information**:

- A perfect hint would instantly reveal the answer (too much information).
- No hint gives you nothing (too little information).
- A good hint provides **partial information** that narrows the search space.

This repo uses a common pattern called **progressive disclosure**:

- early hints: meaning-based (definitions)
- later hints: form-based (letters and patterns)

### 9.2 WordNet (academic overview)

**WordNet** is not just a “dictionary”. It’s a **lexical database** for English used in computational linguistics.

Key concepts:

- **Lemma**: a “dictionary form” of a word (like `mountain`).
- **Sense**: a specific meaning of a word (words can have multiple senses).
- **Synset** (synonym set): a group of lemmas that represent one sense/meaning.
- **Gloss**: a short definition for a synset.

WordNet also stores relationships between synsets, such as:

- **hypernym**: a more general “is-a” concept (mountain → landform)
- **hyponym**: a more specific “is-a” concept (landform → mountain)
- (many others exist: meronyms “part-of”, etc.)

Why WordNet is useful for hints:

- It gives you definitions (glosses) that describe what a noun *is*.
- It gives you related concepts (synonyms/hypernyms) that can inspire alternate hints.

Important limitation (good to know as a junior):

- WordNet coverage is not perfect. Some modern words, slang, and proper nouns may not exist.
- Words can have multiple senses, and some definitions may feel surprising.

### 9.3 NLTK (how Python accesses WordNet)

This repo uses WordNet through **NLTK** (Natural Language Toolkit), a popular Python library for NLP.

NLTK ships the *code*, but WordNet data is a *dataset* you download.

That’s why you’ll see WordNet downloads:

- in `backend/Dockerfile` at build time (so containers start ready)
- and in `backend/app.py` as a fallback if WordNet isn’t present yet

### 9.4 Mini WordNet exploration (hands-on learning example)

This is a small “academic lab exercise” you can run in a Python REPL (optional, for learning):

```py
from nltk.corpus import wordnet as wn

word = "mountain"
synsets = wn.synsets(word, pos=wn.NOUN)
print("How many noun senses?", len(synsets))

first = synsets[0]
print("Synset id:", first.name())
print("Definition:", first.definition())
print("Example sentences:", first.examples())
print("Some lemmas:", [l.name() for l in first.lemmas()][:8])
print("Hypernyms:", [h.name() for h in first.hypernyms()])
```

What to notice:

- `wn.synsets(...)` returns a list because a word can have multiple senses.
- `definition()` is the “gloss” used by this repo to create definition-style hints.
- `hypernyms()` are more general categories that can support alternate phrasing.

### 9.5 How this repo uses WordNet for hints (code-level walkthrough)

Open `backend/app.py` and search for “hint” and “wordnet”. The key ideas:

1. **Word list is filtered using WordNet (important!)**  
   In `load_nouns()`, the repo loads words from `backend/nouns.json`, but then keeps only nouns that have WordNet noun synsets.  
   Practical consequence: WordNet isn’t just “nice to have” here — it’s part of making sure chosen words have definitional hints available.

2. **Definitions are turned into multiple hint candidates**  
   The function `_build_definition_hints(word, desired=10)` gathers multiple definition-style hints by:
   - reading WordNet glosses (definitions) from noun synsets
   - creating variations (stripping parentheses, taking useful fragments, etc.)
   - pulling related words (lemmas and hypernyms) to create alternate “subject” phrases

3. **Hints are sanitized so they don’t leak the answer**  
   `_sanitize_hint(text, target_word)` replaces any direct appearance of the target word with `____`.

4. **Hints are deduplicated**  
   The code “canonicalizes” hint strings (lowercase + remove non-letters) and keeps a `seen` set, so you don’t get the same hint wording repeated.

5. **Hints follow a fixed progression**  
   In `generate_hint(word, hint_number)`:
   - hints `1–10` come from WordNet-based definitions
   - hint `11` reveals the first letter
   - hint `12` reveals the last letter
   - hint `13` reveals the second letter
   - hint `14` reveals a pattern with 2 letters hidden
   - hint `15` reveals a pattern with 3 letters hidden

### 9.6 Letter/pattern hints (why they help)

Definition hints help you understand *meaning*, but letter/pattern hints help you narrow down *form*.

Example idea (using “mountain” just as an illustration):

- First letter: `M`
- Last letter: `N`
- Pattern might look like: `M O U _ _ A I N` (underscores hide some letters, usually near the middle)

This kind of hint reduces the number of words that match, even if you’re not sure about the meaning yet.

### 9.7 Optional AI hints (LLM overview + how this repo uses them)

If enabled, `POST /hint` can call an external **LLM (large language model)** endpoint to generate a short, definition-style hint.

Academic viewpoint:

- WordNet is a curated lexical database (retrieval-based knowledge).
- LLM hints are generated by a probabilistic model (generation-based knowledge).
- LLMs can be creative, but they can also be inconsistent or “hallucinate” details.

This repo reduces that risk by:

- asking for one sentence under 20 words
- instructing the model not to include the target word or close spelling variants
- checking for duplicates against recent hints
- falling back to WordNet hints if the AI call fails

Configuration comes from environment variables (see `.env.example`):

- `AI_HINTS_ENABLED` (true/false)
- `OPENAI_API_KEY` (secret)
- `OPENAI_MODEL`
- `OPENAI_CHAT_URL`
- `OPENAI_TIMEOUT_SECONDS`, `OPENAI_MAX_TOKENS`, `OPENAI_TEMPERATURE`

Important safety habit:

- Never commit API keys.
- If a key is accidentally exposed, rotate it immediately.

---

## 10) PostgreSQL (database) — what’s stored and why

The database is where “finished” game history lives.

### 10.1 The schema files

- `sql/init.sql` creates:
  - tables
  - indexes
  - views
  - a trigger to keep the leaderboard updated

- `sql/export.sql` inserts sample rows (so the leaderboard isn’t empty on day one).

### 10.2 Tables (what they represent)

From `sql/init.sql`:

- `game_sessions`  
  One row per game session (player, target word, start/end, score, won/lost).

- `guesses`  
  One row per guess. Linked to a session by `session_id`.

- `leaderboard`  
  Aggregated stats per player (total games, wins, best score, win rate, etc.).

- `player_stats`  
  “Daily stats” style table (analytics). In this repo, it’s mainly sample/demo data.

### 10.3 Keys and relationships (how tables connect)

- `game_sessions.session_id` is the primary key.
- `guesses.session_id` is a foreign key referencing `game_sessions.session_id`.

So: one session has many guesses.

### 10.4 The leaderboard trigger (automatic updates)

In `sql/init.sql` there is a trigger:

- When a session’s `end_time` changes from `NULL` to a timestamp (meaning “the game ended”)
- PostgreSQL runs `update_leaderboard()`
- That function inserts/updates a row in `leaderboard`

This is a classic database feature:

- Application writes a “game finished” row
- Database automatically updates derived stats

### 10.5 Connection strings (how the backend connects)

The backend uses a `DATABASE_URL` like:

```
postgresql://USER:PASSWORD@HOST:PORT/DBNAME
```

Inside Docker Compose:

- `HOST` is `postgres` (service name), not `localhost`

---

## 11) Adminer (database UI you can click)

Adminer is a tiny web app for browsing databases.

When the stack is running:

- open `http://localhost:8080`
- choose system “PostgreSQL”
- server: `postgres`
- user/password/db: from `.env` / `.env.example`

Beginner-friendly SQL queries you can try (same idea as `README.md`):

```sql
SELECT * FROM game_sessions ORDER BY start_time DESC LIMIT 10;
SELECT * FROM guesses WHERE session_id = 1 ORDER BY guess_number;
SELECT * FROM leaderboard ORDER BY best_score DESC;
```

An easy “connect the dots” query (sessions + guesses together):

```sql
SELECT
  gs.session_id,
  gs.player_name,
  g.guess_number,
  g.guess_word,
  g.similarity_score,
  g.is_correct
FROM guesses g
JOIN game_sessions gs ON gs.session_id = g.session_id
ORDER BY g.timestamp DESC
LIMIT 20;
```

---

## 12) Appsmith + MongoDB (low-code UI)

Appsmith is a low-code tool for building dashboards and internal apps.

In this repo:

- Appsmith runs in the `appsmith` container.
- It stores its own internal data in MongoDB (`mongo` container).
- The repo includes an export you can import: `appsmith/word-game-app.json`.

### 12.0 Importing the Appsmith app (typical steps)

1. Open `http://localhost/applications`.
2. Click **Import**.
3. Choose `appsmith/word-game-app.json`.
4. Open the imported application.

If Appsmith takes a while to load the first time, check the container logs (`docker compose logs -f appsmith`) and refresh after Mongo becomes healthy.

### 12.1 Why encryption settings matter

Appsmith stores secrets (like datasource passwords) encrypted in MongoDB.

That’s why the Compose file asks for:

- `APPSMITH_ENCRYPTION_PASSWORD`
- `APPSMITH_ENCRYPTION_SALT`

Set strong values before the first run and do not change them later, or Appsmith won’t be able to decrypt existing secrets.

### 12.2 What’s inside the exported app?

If you peek at the JSON, you’ll see it configures a REST datasource pointing at:

- `http://game-backend:8000` (the backend service inside the Docker network)

It can also embed the static UI in an iframe.

---

## 13) Mock API (json-server) — “fake backend” for demos

The `mock-api-2` service is a Node-based json-server container.

It turns `mock-api-2/db.json` into REST endpoints like:

- `http://localhost:3001/hints`
- `http://localhost:3001/achievements`
- `http://localhost:3001/powerups`

This is useful for:

- front-end prototyping
- demos
- building UI screens before the real backend feature exists

Example:

```bash
curl -sS "http://localhost:3001/hints"
```

json-server also supports common REST patterns:

- get one item by id: `http://localhost:3001/hints/1`
- filter by a field: `http://localhost:3001/hints?type=definition`

---

## 14) “Follow one request” exercise (recommended for beginners)

This is the fastest way to understand the repo end-to-end.

1. Start a game in the UI.
2. Watch the browser Network tab and find the `/start` request.
3. In `backend/app.py`, find `@app.post("/start")` and read what it does.
4. In Adminer, query the database:
   - `SELECT * FROM game_sessions ORDER BY session_id DESC LIMIT 5;`
5. Make a guess.
6. Repeat steps 2–4 with `/guess` and the `guesses` table.

You just learned the whole stack by tracing one path.

---

## 15) Troubleshooting mindset (how to debug calmly)

When something doesn’t work, don’t guess—check the closest observable thing.

### Common checks

- Is the backend alive?
  - `GET http://127.0.0.1:8000/health`
  - or open `http://127.0.0.1:8000/docs`

- Are containers healthy?
  - `docker compose ps`

- What do logs say?
  - `docker compose logs -f game-backend`
  - `docker compose logs -f postgres`
  - `docker compose logs -f appsmith`

- Do you have port conflicts?
  - Something else might already use `80`, `8000`, `8080`, `3001`, `5432`.

### A very common database “gotcha”

Postgres only runs `docker-entrypoint-initdb.d/*` scripts on the *first* startup of a fresh data directory.

So if you change `sql/init.sql` later and don’t see changes:

- you may need to remove the Postgres volume (this deletes your DB data)
- then start again

Only do this if you understand you’re resetting the database.

---

## 16) You’re ready for `README.md`

At this point you should be able to:

- point to each service and say what it does
- understand how the UI calls the API
- understand where data is stored
- recognize where the “semantic similarity” logic lives

Next step: read `README.md` and follow the run instructions. As you do, refer back to this guide when a term feels unfamiliar.

---

## Appendix: Glossary (quick definitions)

- **API**: a set of endpoints you call over HTTP to get work done.
- **Endpoint**: one URL + method (like `POST /guess`) that performs a specific action.
- **HTTP**: the “web request” protocol (methods like GET/POST, status codes like 200/404).
- **JSON**: a common data format for APIs (`{"key":"value"}`).
- **YAML**: a configuration format used by `docker-compose.yaml` (indentation matters).
- **Docker image**: a packaged blueprint containing software + its dependencies.
- **Docker container**: a running instance of an image.
- **Service (Compose)**: one named container configuration in `docker-compose.yaml` (like `postgres`).
- **Port mapping**: exposing a container port on your computer (`8000:8000`).
- **Volume**: persistent storage used by containers (important for databases).
- **Environment variable**: configuration value like `POSTGRES_PASSWORD=...`.
- **Database table**: a structured set of rows and columns (like a spreadsheet, but more powerful).
- **Primary key**: a unique identifier column for a row (like `session_id`).
- **Foreign key**: a column that points to a primary key in another table (like `guesses.session_id`).
- **Trigger**: a database rule that runs automatically when data changes (used here to update the leaderboard).
- **View**: a saved SQL query you can select from like a table.
- **Embedding**: turning a word into a numeric vector so you can compare meanings.
- **Cosine similarity**: a common way to compare vectors (higher = more similar direction).
