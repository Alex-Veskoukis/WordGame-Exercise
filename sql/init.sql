-- ============================================
-- Semantic Word Game - Database Schema
-- ============================================
-- This file initializes the PostgreSQL database
-- with the required tables for the word game
-- ============================================

-- Drop existing tables (for clean reinstall)
DROP TABLE IF EXISTS guesses CASCADE;
DROP TABLE IF EXISTS game_sessions CASCADE;
DROP TABLE IF EXISTS leaderboard CASCADE;
DROP TABLE IF EXISTS player_stats CASCADE;

-- ============================================
-- Table 1: game_sessions
-- ============================================
-- Stores each game session with metadata
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

-- Index for faster queries by player
CREATE INDEX idx_player_name ON game_sessions(player_name);
CREATE INDEX idx_start_time ON game_sessions(start_time DESC);

-- ============================================
-- Table 2: guesses
-- ============================================
-- Stores individual guesses for each game session
CREATE TABLE guesses (
    guess_id SERIAL PRIMARY KEY,
    session_id INT NOT NULL REFERENCES game_sessions(session_id) ON DELETE CASCADE,
    guess_word VARCHAR(50) NOT NULL,
    similarity_score FLOAT NOT NULL,
    guess_number INT NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_correct BOOLEAN DEFAULT FALSE
);

-- Index for faster queries by session
CREATE INDEX idx_session_id ON guesses(session_id);
CREATE INDEX idx_timestamp ON guesses(timestamp DESC);

-- ============================================
-- Table 3: leaderboard (aggregated stats)
-- ============================================
-- Stores aggregated statistics for each player
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

-- Index for leaderboard queries
CREATE INDEX idx_best_score ON leaderboard(best_score DESC);
CREATE INDEX idx_win_rate ON leaderboard(win_rate DESC);

-- ============================================
-- Table 4: player_stats (detailed analytics)
-- ============================================
-- Stores detailed statistics per player
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

-- ============================================
-- Sample Data for Testing
-- ============================================

-- Insert sample game sessions
INSERT INTO game_sessions (player_name, target_word, start_time, end_time, total_guesses, won, score, difficulty, hints_used, best_similarity)
VALUES 
    ('Alice', 'mountain', '2024-12-15 10:00:00', '2024-12-15 10:05:00', 8, TRUE, 92, 'medium', 1, 0.95),
    ('Bob', 'telescope', '2024-12-15 11:30:00', '2024-12-15 11:40:00', 12, TRUE, 75, 'hard', 2, 0.89),
    ('Charlie', 'piano', '2024-12-15 14:00:00', '2024-12-15 14:10:00', 15, FALSE, 45, 'easy', 3, 0.78),
    ('Alice', 'elephant', '2024-12-16 09:00:00', '2024-12-16 09:06:00', 6, TRUE, 98, 'medium', 0, 0.98),
    ('Diana', 'computer', '2024-12-16 10:00:00', '2024-12-16 10:15:00', 10, TRUE, 85, 'medium', 1, 0.92);

-- Insert sample guesses for Alice's first game (session_id = 1)
INSERT INTO guesses (session_id, guess_word, similarity_score, guess_number, is_correct)
VALUES 
    (1, 'hill', 0.65, 1, FALSE),
    (1, 'peak', 0.78, 2, FALSE),
    (1, 'summit', 0.82, 3, FALSE),
    (1, 'cliff', 0.71, 4, FALSE),
    (1, 'valley', 0.68, 5, FALSE),
    (1, 'ridge', 0.75, 6, FALSE),
    (1, 'alps', 0.85, 7, FALSE),
    (1, 'mountain', 1.0, 8, TRUE);

-- Insert sample guesses for Bob's game (session_id = 2)
INSERT INTO guesses (session_id, guess_word, similarity_score, guess_number, is_correct)
VALUES 
    (2, 'microscope', 0.72, 1, FALSE),
    (2, 'lens', 0.65, 2, FALSE),
    (2, 'binoculars', 0.81, 3, FALSE),
    (2, 'observatory', 0.75, 4, FALSE),
    (2, 'telescope', 1.0, 5, TRUE);

-- Insert leaderboard data
INSERT INTO leaderboard (player_name, total_games, games_won, total_guesses, best_score, avg_guesses, win_rate)
VALUES 
    ('Alice', 2, 2, 14, 98, 7.0, 100.0),
    ('Bob', 1, 1, 5, 75, 5.0, 100.0),
    ('Charlie', 1, 0, 15, 45, 15.0, 0.0),
    ('Diana', 1, 1, 10, 85, 10.0, 100.0);

-- Insert player stats
INSERT INTO player_stats (player_name, stat_date, games_today, wins_today, avg_similarity_today, perfect_games)
VALUES 
    ('Alice', '2024-12-15', 1, 1, 0.95, 0),
    ('Alice', '2024-12-16', 1, 1, 0.98, 1),
    ('Bob', '2024-12-15', 1, 1, 0.89, 0),
    ('Charlie', '2024-12-15', 1, 0, 0.78, 0),
    ('Diana', '2024-12-16', 1, 1, 0.92, 0);

-- ============================================
-- Useful Views
-- ============================================

-- View for recent games
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

-- View for top players
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

-- ============================================
-- Functions for automatic updates
-- ============================================

-- Function to update leaderboard after game ends
CREATE OR REPLACE FUNCTION update_leaderboard()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert or update player in leaderboard
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

-- Trigger to automatically update leaderboard
CREATE TRIGGER trigger_update_leaderboard
AFTER UPDATE OF end_time ON game_sessions
FOR EACH ROW
WHEN (NEW.end_time IS NOT NULL AND OLD.end_time IS NULL)
EXECUTE FUNCTION update_leaderboard();

-- ============================================
-- Verification Queries (for testing)
-- ============================================

-- Test query 1: Count sessions
-- SELECT COUNT(*) as total_sessions FROM game_sessions;

-- Test query 2: View leaderboard
-- SELECT * FROM leaderboard ORDER BY best_score DESC;

-- Test query 3: Recent games
-- SELECT * FROM recent_games;

-- Test query 4: Player game history
-- SELECT * FROM game_sessions WHERE player_name = 'Alice' ORDER BY start_time DESC;

-- ============================================
-- End of Schema
-- ============================================
