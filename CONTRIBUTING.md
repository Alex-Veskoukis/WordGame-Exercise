# Contributing

Thanks for your interest in contributing to WordGame.

## Development Setup
1. Install Docker and Docker Compose.
2. Start services:
   - `docker compose up -d`
3. Verify services:
   - `docker compose ps`

## Making Changes
- Keep changes focused and scoped to a single topic.
- Update `README.md` if behavior or usage changes.
- Rebuild the backend if you change Python code:
  - `docker compose up -d --build game-backend`

## Tests
There is no automated test suite yet. Please do a manual check:
- Start a game in the static UI.
- Make a guess and request a hint.
- Verify leaderboard updates after a game ends.

## Submitting Changes
- Use clear commit messages.
- Open a pull request with a short description of the change.
