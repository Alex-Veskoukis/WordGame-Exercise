
DROP TABLE IF EXISTS guesses CASCADE;
DROP TABLE IF EXISTS game_sessions CASCADE;
DROP TABLE IF EXISTS leaderboard CASCADE;
DROP TABLE IF EXISTS player_stats CASCADE;
DROP TABLE IF EXISTS favorites CASCADE;
DROP TABLE IF EXISTS api_logs CASCADE;

CREATE TABLE game_sessions (
    session_id SERIAL PRIMARY KEY,
    player_name VARCHAR(100) NOT NULL,
    target_word VARCHAR(50) NOT NULL,
    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP,
    total_guesses INT DEFAULT 0,
    won BOOLEAN DEFAULT FALSE,
    score INT DEFAULT 0,
    difficulty VARCHAR(20) DEFAULT 'medium',
    hints_used INT DEFAULT 0,
    best_similarity FLOAT DEFAULT 0.0
);

CREATE INDEX idx_player_name ON game_sessions(player_name);
CREATE INDEX idx_start_time ON game_sessions(start_time DESC);

CREATE TABLE guesses (
    guess_id SERIAL PRIMARY KEY,
    session_id INT NOT NULL REFERENCES game_sessions(session_id) ON DELETE CASCADE,
    guess_word VARCHAR(50) NOT NULL,
    similarity_score FLOAT NOT NULL,
    guess_number INT NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_correct BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_session_id ON guesses(session_id);
CREATE INDEX idx_timestamp ON guesses(timestamp DESC);

CREATE TABLE leaderboard (
    player_id SERIAL PRIMARY KEY,
    player_name VARCHAR(100) UNIQUE NOT NULL,
    total_games INT DEFAULT 0,
    games_won INT DEFAULT 0,
    total_guesses INT DEFAULT 0,
    best_score INT DEFAULT 0,
    avg_guesses FLOAT DEFAULT 0.0,
    win_rate FLOAT DEFAULT 0.0,
    last_played TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_best_score ON leaderboard(best_score DESC);
CREATE INDEX idx_win_rate ON leaderboard(win_rate DESC);

CREATE TABLE player_stats (
    stat_id SERIAL PRIMARY KEY,
    player_name VARCHAR(100) NOT NULL,
    stat_date DATE DEFAULT CURRENT_DATE,
    games_today INT DEFAULT 0,
    wins_today INT DEFAULT 0,
    avg_similarity_today FLOAT DEFAULT 0.0,
    perfect_games INT DEFAULT 0,
    UNIQUE(player_name, stat_date)
);

CREATE INDEX idx_stat_date ON player_stats(stat_date DESC);

-- Schema only. Sample rows are loaded separately from sql/export.sql.


CREATE TABLE favorites (
    favorite_id SERIAL PRIMARY KEY,
    player_name VARCHAR(100) NOT NULL,
    source VARCHAR(50) NOT NULL,
    item_type VARCHAR(50) NOT NULL,
    item_id INT NOT NULL,
    item_name TEXT,
    item_payload JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (player_name, source, item_type, item_id)
);

CREATE INDEX idx_favorites_player_name ON favorites(player_name);

CREATE TABLE api_logs (
    log_id SERIAL PRIMARY KEY,
    player_name VARCHAR(100) NOT NULL,
    api_name VARCHAR(100) NOT NULL,
    query TEXT NOT NULL,
    response_payload JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_api_logs_player_name ON api_logs(player_name);
CREATE INDEX idx_api_logs_created_at ON api_logs(created_at DESC);


CREATE VIEW recent_games AS
SELECT 
    gs.session_id,
    gs.player_name,
    gs.target_word,
    gs.total_guesses,
    gs.won,
    gs.score,
    gs.start_time,
    gs.end_time,
    EXTRACT(EPOCH FROM (gs.end_time - gs.start_time))/60 AS duration_minutes
FROM game_sessions gs
ORDER BY gs.start_time DESC
LIMIT 50;

CREATE VIEW top_players AS
SELECT 
    player_name,
    total_games,
    games_won,
    win_rate,
    best_score,
    avg_guesses
FROM leaderboard
ORDER BY best_score DESC, win_rate DESC
LIMIT 10;


CREATE OR REPLACE FUNCTION update_leaderboard()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO leaderboard (player_name, total_games, games_won, total_guesses, best_score, avg_guesses, win_rate, last_played)
    VALUES (
        NEW.player_name,
        1,
        CASE WHEN NEW.won THEN 1 ELSE 0 END,
        NEW.total_guesses,
        NEW.score,
        NEW.total_guesses,
        CASE WHEN NEW.won THEN 100.0 ELSE 0.0 END,
        NEW.end_time
    )
    ON CONFLICT (player_name) DO UPDATE SET
        total_games = leaderboard.total_games + 1,
        games_won = leaderboard.games_won + CASE WHEN NEW.won THEN 1 ELSE 0 END,
        total_guesses = leaderboard.total_guesses + NEW.total_guesses,
        best_score = GREATEST(leaderboard.best_score, NEW.score),
        avg_guesses = (leaderboard.total_guesses + NEW.total_guesses)::FLOAT / (leaderboard.total_games + 1),
        win_rate = ((leaderboard.games_won + CASE WHEN NEW.won THEN 1 ELSE 0 END)::FLOAT / (leaderboard.total_games + 1)) * 100,
        last_played = NEW.end_time;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_leaderboard
AFTER UPDATE OF end_time ON game_sessions
FOR EACH ROW
WHEN (NEW.end_time IS NOT NULL AND OLD.end_time IS NULL)
EXECUTE FUNCTION update_leaderboard();



