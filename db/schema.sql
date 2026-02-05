PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TEXT
);

CREATE TABLE IF NOT EXISTS players (
  id INTEGER PRIMARY KEY,
  user_id INTEGER UNIQUE NOT NULL,
  health INTEGER,
  max_health INTEGER,
  attack INTEGER,
  defense INTEGER,
  gold INTEGER,
  location TEXT,
  FOREIGN KEY(user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS items (
  id INTEGER PRIMARY KEY,
  name TEXT,
  description TEXT,
  item_type TEXT,
  attack_bonus INTEGER,
  defense_bonus INTEGER,
  heal_amount INTEGER
);

CREATE TABLE IF NOT EXISTS inventories (
  id INTEGER PRIMARY KEY,
  player_id INTEGER,
  item_id INTEGER,
  quantity INTEGER,
  FOREIGN KEY(player_id) REFERENCES players(id),
  FOREIGN KEY(item_id) REFERENCES items(id)
);

CREATE TABLE IF NOT EXISTS enemies (
  id INTEGER PRIMARY KEY,
  name TEXT,
  health INTEGER,
  attack INTEGER,
  defense INTEGER,
  gold_reward INTEGER
);
