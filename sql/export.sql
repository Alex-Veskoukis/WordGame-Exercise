


INSERT INTO game_sessions (session_id, player_name, target_word, start_time, end_time, total_guesses, won, score, difficulty, hints_used, best_similarity) VALUES
(1, 'Alice', 'mountain', '2024-12-15 10:00:00', '2024-12-15 10:05:00', 8, TRUE, 92, 'medium', 1, 0.95),
(2, 'Bob', 'telescope', '2024-12-15 11:30:00', '2024-12-15 11:40:00', 12, TRUE, 75, 'hard', 2, 0.89),
(3, 'Charlie', 'piano', '2024-12-15 14:00:00', '2024-12-15 14:10:00', 15, FALSE, 45, 'easy', 3, 0.78),
(4, 'Alice', 'elephant', '2024-12-16 09:00:00', '2024-12-16 09:06:00', 6, TRUE, 98, 'medium', 0, 0.98),
(5, 'Diana', 'computer', '2024-12-16 10:00:00', '2024-12-16 10:15:00', 10, TRUE, 85, 'medium', 1, 0.92),
(6, 'Bob', 'ocean', '2024-12-16 11:00:00', '2024-12-16 11:12:00', 9, TRUE, 88, 'medium', 1, 0.94),
(7, 'Charlie', 'guitar', '2024-12-16 12:00:00', '2024-12-16 12:08:00', 7, TRUE, 95, 'easy', 0, 0.96),
(8, 'Eve', 'library', '2024-12-16 13:00:00', '2024-12-16 13:20:00', 18, FALSE, 38, 'hard', 4, 0.72);


INSERT INTO guesses (session_id, guess_word, similarity_score, guess_number, is_correct) VALUES
(1, 'hill', 0.65, 1, FALSE),
(1, 'peak', 0.78, 2, FALSE),
(1, 'summit', 0.82, 3, FALSE),
(1, 'cliff', 0.71, 4, FALSE),
(1, 'valley', 0.68, 5, FALSE),
(1, 'ridge', 0.75, 6, FALSE),
(1, 'alps', 0.85, 7, FALSE),
(1, 'mountain', 1.0, 8, TRUE);

INSERT INTO guesses (session_id, guess_word, similarity_score, guess_number, is_correct) VALUES
(2, 'microscope', 0.72, 1, FALSE),
(2, 'lens', 0.65, 2, FALSE),
(2, 'binoculars', 0.81, 3, FALSE),
(2, 'observatory', 0.75, 4, FALSE),
(2, 'telescope', 1.0, 5, TRUE);

INSERT INTO guesses (session_id, guess_word, similarity_score, guess_number, is_correct) VALUES
(3, 'guitar', 0.68, 1, FALSE),
(3, 'violin', 0.71, 2, FALSE),
(3, 'drums', 0.55, 3, FALSE),
(3, 'flute', 0.62, 4, FALSE),
(3, 'keyboard', 0.78, 5, FALSE),
(3, 'synthesizer', 0.73, 6, FALSE),
(3, 'organ', 0.75, 7, FALSE),
(3, 'accordion', 0.64, 8, FALSE);

INSERT INTO guesses (session_id, guess_word, similarity_score, guess_number, is_correct) VALUES
(4, 'animal', 0.72, 1, FALSE),
(4, 'mammal', 0.81, 2, FALSE),
(4, 'rhino', 0.85, 3, FALSE),
(4, 'hippo', 0.88, 4, FALSE),
(4, 'trunk', 0.91, 5, FALSE),
(4, 'elephant', 1.0, 6, TRUE);

INSERT INTO guesses (session_id, guess_word, similarity_score, guess_number, is_correct) VALUES
(5, 'laptop', 0.88, 1, FALSE),
(5, 'machine', 0.75, 2, FALSE),
(5, 'device', 0.82, 3, FALSE),
(5, 'processor', 0.79, 4, FALSE),
(5, 'technology', 0.71, 5, FALSE),
(5, 'desktop', 0.91, 6, FALSE),
(5, 'pc', 0.93, 7, FALSE),
(5, 'server', 0.85, 8, FALSE),
(5, 'workstation', 0.89, 9, FALSE),
(5, 'computer', 1.0, 10, TRUE);


INSERT INTO leaderboard (player_name, total_games, games_won, total_guesses, best_score, avg_guesses, win_rate, last_played) VALUES
('Alice', 2, 2, 14, 98, 7.0, 100.0, '2024-12-16 09:06:00'),
('Charlie', 2, 1, 22, 95, 11.0, 50.0, '2024-12-16 12:08:00'),
('Bob', 2, 2, 21, 88, 10.5, 100.0, '2024-12-16 11:12:00'),
('Diana', 1, 1, 10, 85, 10.0, 100.0, '2024-12-16 10:15:00'),
('Eve', 1, 0, 18, 38, 18.0, 0.0, '2024-12-16 13:20:00');


INSERT INTO player_stats (player_name, stat_date, games_today, wins_today, avg_similarity_today, perfect_games) VALUES
('Alice', '2024-12-15', 1, 1, 0.95, 0),
('Alice', '2024-12-16', 1, 1, 0.98, 1),
('Bob', '2024-12-15', 1, 1, 0.89, 0),
('Bob', '2024-12-16', 1, 1, 0.94, 0),
('Charlie', '2024-12-15', 1, 0, 0.78, 0),
('Charlie', '2024-12-16', 1, 1, 0.96, 0),
('Diana', '2024-12-16', 1, 1, 0.92, 0),
('Eve', '2024-12-16', 1, 0, 0.72, 0);






