from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer
import numpy as np
import random
import json
import re
from pathlib import Path
from typing import Dict, List, Optional
from threading import Lock
import uvicorn
import psycopg2
from psycopg2.extras import RealDictCursor
import os
from datetime import datetime

app = FastAPI()

# Database connection
def get_db_connection():
    """Get PostgreSQL database connection"""
    database_url = os.environ.get('DATABASE_URL', 'postgresql://gameuser:gamepass123@postgres:5432/wordgame')
    return psycopg2.connect(database_url)

def get_db_cursor(conn):
    """Get database cursor that returns dict results"""
    return conn.cursor(cursor_factory=RealDictCursor)

# Load embedding model (this will download on first run - ~400MB)
# Using a lightweight model for speed
model = SentenceTransformer('all-MiniLM-L6-v2')

# Import WordNet for hints
try:
    from nltk.corpus import wordnet as wn
    import nltk

    # Try to load wordnet
    try:
        wn.synsets('test')
    except LookupError:
        print("Downloading WordNet for hint feature...")
        nltk.download('wordnet')
        nltk.download('omw-1.4')
    WORDNET_AVAILABLE = True
except ImportError:
    print("âš  NLTK not installed. Hint feature will use basic hints.")
    print("  Install with: pip install nltk")
    WORDNET_AVAILABLE = False

# Load noun list from JSON file
WORD_RE = re.compile(r"^[a-z]+$")
MIN_NOUN_LENGTH = 3
MAX_HINT_STEPS = 15
VOWELS = set("aeiou")
STOPWORDS = {
    "a", "an", "and", "are", "as", "at", "be", "by", "for", "from", "has", "have",
    "in", "is", "it", "its", "of", "on", "or", "that", "the", "to", "was", "were",
    "with", "without", "this", "these", "those", "often", "typically", "usually",
    "used", "use", "using", "such", "not", "also", "may", "can", "like", "into",
    "between", "within", "over", "under", "above", "below", "made", "making",
}

def load_nouns() -> List[str]:
    nouns_path = Path(__file__).with_name("nouns.json")
    if not nouns_path.exists():
        raise RuntimeError(f"nouns.json not found at {nouns_path}")
    data = json.loads(nouns_path.read_text())
    nouns_set = set()
    for item in data:
        if isinstance(item, str):
            word = item.strip().lower()
            if WORD_RE.fullmatch(word) and len(word) >= MIN_NOUN_LENGTH:
                nouns_set.add(word)
    if not nouns_set:
        raise RuntimeError("nouns.json is empty after filtering.")
    if WORDNET_AVAILABLE:
        nouns_set = {word for word in nouns_set if wn.synsets(word, pos=wn.NOUN)}
        if not nouns_set:
            raise RuntimeError("nouns.json has no words with WordNet definitions.")
    else:
        raise RuntimeError("WordNet is required to load nouns with definitions.")
    return list(nouns_set)

NOUNS = load_nouns()


# In-memory game state per player (in production, use proper session management)
class GameState:
    def __init__(self):
        self.session_id: Optional[int] = None
        self.player_name: Optional[str] = None
        self.target_word: Optional[str] = None
        self.target_embedding: Optional[np.ndarray] = None
        self.guesses: List[dict] = []
        self.hints_used: int = 0
        self.start_time: Optional[datetime] = None

    def start_new_game(self, player_name: str, conn):
        """Start a new game and create database session"""
        self.player_name = player_name
        self.target_word = random.choice(NOUNS)
        self.target_embedding = model.encode(self.target_word)
        self.guesses = []
        self.hints_used = 0
        self.start_time = datetime.now()
        
        # Create game session in database
        cursor = get_db_cursor(conn)
        cursor.execute(
            """
            INSERT INTO game_sessions (player_name, target_word, start_time, difficulty)
            VALUES (%s, %s, %s, %s)
            RETURNING session_id
            """,
            (player_name, self.target_word, self.start_time, 'medium')
        )
        self.session_id = cursor.fetchone()['session_id']
        conn.commit()
        cursor.close()
        
        return self.target_word


game_states: Dict[str, GameState] = {}
game_states_lock = Lock()

def normalize_player_name(player_name: str) -> str:
    return player_name.strip()

def require_player_name(player_name: str) -> str:
    normalized = normalize_player_name(player_name)
    if not normalized:
        raise HTTPException(status_code=400, detail="Player name is required.")
    return normalized

def get_or_create_game_state(player_name: str) -> GameState:
    with game_states_lock:
        state = game_states.get(player_name)
        if state is None:
            state = GameState()
            game_states[player_name] = state
    return state

def get_active_game_state(player_name: str) -> GameState:
    state = game_states.get(player_name)
    if state is None or state.target_word is None or state.session_id is None:
        raise HTTPException(status_code=400, detail="No active game. Start a new game first.")
    return state


# Request/Response models
class GameStartRequest(BaseModel):
    player_name: str

class GuessRequest(BaseModel):
    player_name: str
    word: str

class GuessResponse(BaseModel):
    similarity: float
    all_guesses: List[dict]
    is_correct: bool
    guesses_count: int

class GameStartResponse(BaseModel):
    message: str
    word_length: int

class RevealRequest(BaseModel):
    player_name: str

class RevealResponse(BaseModel):
    target_word: str
    total_guesses: int
    score: int

class HintRequest(BaseModel):
    player_name: str

class HintResponse(BaseModel):
    hint: str
    hints_used: int

class LeaderboardEntry(BaseModel):
    player_name: str
    total_games: int
    games_won: int
    total_guesses: int
    best_score: int
    avg_guesses: float
    win_rate: float


# Hint generation function
def _sanitize_hint(text: str, target_word: str) -> str:
    if not text:
        return ""
    pattern = re.compile(re.escape(target_word), re.IGNORECASE)
    sanitized = pattern.sub("____", text)
    return sanitized.strip()


def _canonicalize_hint(text: str) -> str:
    return re.sub(r"[^a-z]+", "", text.lower())


def _add_unique(hints: List[str], seen: set, text: str) -> bool:
    normalized = _canonicalize_hint(text)
    if not normalized or normalized in seen:
        return False
    seen.add(normalized)
    hints.append(text)
    return True


def _normalize_definition(definition: str, target_word: str) -> str:
    text = _sanitize_hint(definition, target_word).strip()
    if not text:
        return ""
    if text[-1] not in ".!?":
        text += "."
    return text


def _word_count(text: str) -> int:
    return len(re.findall(r"[a-z]+", text.lower()))


def _strip_parenthetical(text: str) -> str:
    cleaned = re.sub(r"\s*\([^)]*\)", "", text).strip()
    return cleaned



def _definition_keywords(definition: str, target_word: str, limit: int = 9) -> List[str]:
    if not definition:
        return []
    target = target_word.lower()
    tokens = re.findall(r"[a-z]+", definition.lower())
    keywords = []
    seen = set()
    for token in tokens:
        if token in STOPWORDS:
            continue
        if target in token:
            continue
        if len(token) < 3:
            continue
        if token in seen:
            continue
        seen.add(token)
        keywords.append(token)
        if len(keywords) >= limit:
            break
    return keywords


def _article_for(noun: str) -> str:
    if not noun:
        return "a"
    return "an" if noun[0].lower() in "aeiou" else "a"


def _split_definition_subject(definition: str):
    text = definition.strip()
    if not text:
        return None
    article_match = re.match(
        r"^(a|an|the)\s+(.+?)(\s+(used|that|which|who|with|for|to)\b.*|$)",
        text,
        re.IGNORECASE,
    )
    if article_match:
        return (
            True,
            article_match.group(1).lower(),
            article_match.group(2).strip(),
            article_match.group(3) or "",
        )

    match = re.match(
        r"^(.+?)(\s+(used|that|which|who|with|for|to)\b.*|$)",
        text,
        re.IGNORECASE,
    )
    if match:
        return (False, "", match.group(1).strip(), match.group(2) or "")

    return None


def _subject_alternatives(subject: str) -> List[str]:
    if " or " not in subject:
        return []
    return [part.strip() for part in subject.split(" or ") if part.strip()]


def _definition_fragments(definition: str) -> List[str]:
    fragments = []
    for sep in [";", ":"]:
        if sep in definition:
            parts = [part.strip() for part in definition.split(sep) if part.strip()]
            fragments.extend(parts)
    markers = [
        " that ",
        " which ",
        " with ",
        " used ",
        " especially ",
        " typically ",
        " often ",
        " usually ",
        " including ",
        " such as ",
        " for ",
    ]
    for marker in markers:
        idx = definition.find(marker)
        if idx > 0:
            fragment = definition[:idx].strip()
            if fragment:
                fragments.append(fragment)
    return fragments


def _masked_with_missing(word: str, missing_count: int) -> str:
    missing_count = min(missing_count, len(word))
    if len(word) > 2:
        candidates = list(range(1, len(word) - 1))
    else:
        candidates = list(range(len(word)))
    if missing_count > len(candidates):
        candidates = list(range(len(word)))
    center = (len(word) - 1) / 2
    candidates_sorted = sorted(candidates, key=lambda i: abs(i - center))
    missing_indices = set(candidates_sorted[:missing_count])
    chars = []
    for idx, ch in enumerate(word):
        chars.append("_" if idx in missing_indices else ch.upper())
    return " ".join(chars)


def _format_synset_name(synset) -> str:
    return synset.lemmas()[0].name().replace("_", " ")


def _build_definition_hints(word: str, desired: int = 10) -> List[str]:
    hints: List[str] = []
    seen: set = set()
    if not WORDNET_AVAILABLE:
        return ["No definition available."]

    synsets = wn.synsets(word, pos=wn.NOUN)
    if not synsets:
        return ["No definition available."]

    replacements = []
    seen_replacements = set()
    keywords = []
    seen_keywords = set()

    for syn in synsets:
        for lemma in syn.lemmas():
            name = lemma.name().replace("_", " ")
            if word.lower() in name.lower():
                continue
            if name not in seen_replacements:
                seen_replacements.add(name)
                replacements.append(name)
        for hyper in syn.hypernyms():
            name = _format_synset_name(hyper)
            if word.lower() in name.lower():
                continue
            if name not in seen_replacements:
                seen_replacements.add(name)
                replacements.append(name)
        for kw in _definition_keywords(syn.definition(), word, limit=6):
            if kw not in seen_keywords:
                seen_keywords.add(kw)
                keywords.append(kw)

    replacements = replacements[:6]

    for syn in synsets:
        raw_definition = _sanitize_hint(syn.definition(), word)
        base = _normalize_definition(raw_definition, word)
        if base:
            _add_unique(hints, seen, base)

        stripped = _strip_parenthetical(raw_definition)
        if stripped and stripped != raw_definition:
            candidate = _normalize_definition(stripped, word)
            if candidate:
                _add_unique(hints, seen, candidate)

        for fragment in _definition_fragments(raw_definition):
            candidate = _normalize_definition(fragment, word)
            if _word_count(candidate) >= 4:
                _add_unique(hints, seen, candidate)

        subject_parts = _split_definition_subject(base)
        if subject_parts:
            has_article, article, subject, rest = subject_parts
            for alt in _subject_alternatives(subject):
                if alt.lower() == subject.lower():
                    continue
                prefix = article if has_article else _article_for(alt)
                candidate = _normalize_definition(f"{prefix} {alt}{rest}", word)
                if _word_count(candidate) >= 4:
                    _add_unique(hints, seen, candidate)
            for repl in replacements:
                if repl.lower() == subject.lower():
                    continue
                prefix = article if has_article else _article_for(repl)
                candidate = _normalize_definition(f"{prefix} {repl}{rest}", word)
                if _word_count(candidate) >= 4:
                    _add_unique(hints, seen, candidate)

        if len(hints) >= desired:
            break

    if len(hints) < desired:
        for kw in keywords[:3]:
            candidate = _normalize_definition(f"something related to {kw}", word)
            _add_unique(hints, seen, candidate)
            if len(hints) >= desired:
                break
        for kw in keywords[3:]:
            if len(hints) >= desired:
                break
            candidate = _normalize_definition(f"something associated with {kw}", word)
            _add_unique(hints, seen, candidate)

    if len(hints) < desired and replacements:
        for repl in replacements:
            if len(hints) >= desired:
                break
            candidate = _normalize_definition(f"{_article_for(repl)} {repl}", word)
            _add_unique(hints, seen, candidate)

    if not hints:
        hints.append("No definition available.")
    return hints[:desired]


def generate_hint(word: str, hint_number: int) -> str:
    """
    Generate a contextual hint for the target word without revealing it.
    Hints are definitions (1-10), then letter-based (11-15), and stop.
    """
    if hint_number > MAX_HINT_STEPS:
        return "No more hints available."
    hint_number = max(1, hint_number)

    definitional_unique = _build_definition_hints(word, desired=10)

    if hint_number <= 10:
        idx = hint_number - 1
        if idx < len(definitional_unique):
            return definitional_unique[idx]
        return definitional_unique[-1]

    if hint_number == 11:
        return f"First letter: {word[0].upper()}."
    if hint_number == 12:
        return f"Last letter: {word[-1].upper()}."
    if hint_number == 13:
        return f"Second letter: {word[1].upper()}."
    if hint_number == 14:
        return f"Pattern: {_masked_with_missing(word, 2)}."
    if hint_number == 15:
        return f"Pattern: {_masked_with_missing(word, 3)}."

    return "No more hints available."


# API endpoints
@app.post("/start", response_model=GameStartResponse)
async def start_game(request: GameStartRequest):
    """Start a new game"""
    player_name = require_player_name(request.player_name)
    conn = get_db_connection()
    try:
        state = get_or_create_game_state(player_name)
        target = state.start_new_game(player_name, conn)
        return GameStartResponse(
            message="New game started! Try to guess the word.",
            word_length=len(target)
        )
    finally:
        conn.close()


@app.post("/guess", response_model=GuessResponse)
async def make_guess(guess_req: GuessRequest):
    """Submit a guess and get similarity score"""
    player_name = require_player_name(guess_req.player_name)
    state = get_active_game_state(player_name)

    guess_word = guess_req.word.lower().strip()

    # Encode the guess
    guess_embedding = model.encode(guess_word)

    # Calculate cosine similarity
    similarity = float(np.dot(state.target_embedding, guess_embedding) /
                       (np.linalg.norm(state.target_embedding) * np.linalg.norm(guess_embedding)))

    # Check if correct (exact match or very high similarity)
    is_correct = (guess_word == state.target_word) or (similarity > 0.99)
    
    # Calculate guess number
    guess_number = len(state.guesses) + 1

    # Store guess in memory
    guess_data = {
        "word": guess_word,
        "similarity": round(similarity, 4),
        "guess_number": guess_number
    }
    state.guesses.append(guess_data)
    
    # Save guess to database
    conn = get_db_connection()
    try:
        cursor = get_db_cursor(conn)
        cursor.execute(
            """
            INSERT INTO guesses (session_id, guess_word, similarity_score, guess_number, is_correct)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (state.session_id, guess_word, similarity, guess_number, is_correct)
        )
        
        # If game won, update session
        if is_correct:
            score = max(0, 100 - (guess_number * 5))  # Score decreases with more guesses
            cursor.execute(
                """
                UPDATE game_sessions
                SET end_time = %s, total_guesses = %s, won = TRUE, score = %s, 
                    hints_used = %s, best_similarity = %s
                WHERE session_id = %s
                """,
                (datetime.now(), guess_number, score, state.hints_used, similarity, state.session_id)
            )
        
        conn.commit()
        cursor.close()
    finally:
        conn.close()

    return GuessResponse(
        similarity=similarity,
        all_guesses=state.guesses,
        is_correct=is_correct,
        guesses_count=len(state.guesses)
    )


@app.post("/reveal", response_model=RevealResponse)
async def reveal_word(request: RevealRequest):
    """Give up and reveal the target word"""
    player_name = require_player_name(request.player_name)
    state = get_active_game_state(player_name)

    target = state.target_word
    guesses_count = len(state.guesses)
    
    # Calculate score (lower for giving up)
    score = max(0, 50 - (guesses_count * 3))
    
    # Get best similarity
    best_similarity = max([g['similarity'] for g in state.guesses], default=0.0)
    
    # Update game session in database
    conn = get_db_connection()
    try:
        cursor = get_db_cursor(conn)
        cursor.execute(
            """
            UPDATE game_sessions
            SET end_time = %s, total_guesses = %s, won = FALSE, score = %s,
                hints_used = %s, best_similarity = %s
            WHERE session_id = %s
            """,
            (datetime.now(), guesses_count, score, state.hints_used, best_similarity, state.session_id)
        )
        conn.commit()
        cursor.close()
    finally:
        conn.close()

    return RevealResponse(
        target_word=target,
        total_guesses=guesses_count,
        score=score
    )


@app.post("/hint", response_model=HintResponse)
async def get_hint(request: HintRequest):
    """Get a contextual hint about the target word"""
    player_name = require_player_name(request.player_name)
    state = get_active_game_state(player_name)

    # Increment hint counter
    state.hints_used += 1

    # Generate hint
    hint = generate_hint(state.target_word, state.hints_used)

    return HintResponse(
        hint=hint,
        hints_used=state.hints_used
    )


@app.get("/leaderboard", response_model=List[LeaderboardEntry])
async def get_leaderboard(limit: int = 10):
    """Get leaderboard entries"""
    if limit < 1 or limit > 100:
        raise HTTPException(status_code=400, detail="Limit must be between 1 and 100.")

    conn = get_db_connection()
    try:
        cursor = get_db_cursor(conn)
        cursor.execute(
            """
            SELECT player_name, total_games, games_won, total_guesses, best_score, avg_guesses, win_rate
            FROM leaderboard
            ORDER BY best_score DESC, win_rate DESC, total_games DESC
            LIMIT %s
            """,
            (limit,)
        )
        rows = cursor.fetchall()
        cursor.close()
        return rows
    finally:
        conn.close()


@app.get("/stats")
async def get_stats(player_name: Optional[str] = None):
    """Get current game statistics"""
    if player_name is not None:
        normalized = require_player_name(player_name)
        state = game_states.get(normalized)
        if state is None or state.target_word is None:
            return {"active_game": False}

        return {
            "active_game": True,
            "player_name": normalized,
            "guesses": state.guesses,
            "guesses_count": len(state.guesses)
        }

    with game_states_lock:
        active_players = [
            name for name, state in game_states.items()
            if state.target_word is not None
        ]
        single_state = game_states[active_players[0]] if len(active_players) == 1 else None

    if not active_players:
        return {"active_game": False}

    if single_state is not None:
        return {
            "active_game": True,
            "player_name": active_players[0],
            "guesses": single_state.guesses,
            "guesses_count": len(single_state.guesses)
        }

    return {
        "active_game": True,
        "active_games": active_players,
        "active_games_count": len(active_players)
    }


@app.get("/health")
async def health_check():
    """Health check endpoint with database connectivity"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.close()
        conn.close()
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        return {"status": "unhealthy", "database": "disconnected", "error": str(e)}


# Mount static files directory
app.mount("/static", StaticFiles(directory="static"), name="static")


# Serve static files (frontend)
@app.get("/")
async def read_root():
    index_path = Path("static/index.html")
    if not index_path.exists():
        raise HTTPException(status_code=500, detail=f"index.html not found at {index_path.absolute()}")
    return FileResponse(index_path)


if __name__ == "__main__":
    # Create static directory if it doesn't exist
    Path("static").mkdir(exist_ok=True)

    # Run the server (use PORT env var for cloud deployment)
    import os

    port = int(os.environ.get("PORT", 8000))
    host = "0.0.0.0" if os.environ.get("PORT") else "127.0.0.1"

    uvicorn.run(app, host=host, port=port)
