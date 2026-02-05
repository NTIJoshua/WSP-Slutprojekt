INSERT INTO items (name, description, item_type, attack_bonus, defense_bonus, heal_amount) VALUES
  ("Bandage", "Restores a small amount of health.", "heal", 0, 0, 5),
  ("Potion", "Restores a moderate amount of health.", "heal", 0, 0, 10),
  ("Rusty Sword", "A basic weapon.", "weapon", 2, 0, 0),
  ("Leather Vest", "Simple protection.", "armor", 0, 1, 0);

INSERT INTO enemies (name, health, attack, defense, gold_reward) VALUES
  ("Straggler", 12, 3, 0, 5),
  ("Scout", 18, 4, 1, 8),
  ("Mercenary", 25, 6, 2, 15);
