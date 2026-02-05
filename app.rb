require "sinatra"
require "sinatra/reloader"
require "slim"
require "sqlite3"
require "bcrypt"
require "time"

configure do
  set :root, File.expand_path(__dir__)
  set :views, File.expand_path("app/views", __dir__)
  set :slim, escape_html: true
  enable :sessions
  set :session_secret, "change_me"
end

configure :development do
  register Sinatra::Reloader
end

module DB
  def self.connection
    return @connection if @connection

    db_path = File.expand_path("db/rpg.sqlite3", __dir__)
    @connection = SQLite3::Database.new(db_path)
    @connection.results_as_hash = true
    @connection.execute("PRAGMA foreign_keys = ON;")
    @connection
  end

  def self.row_to_hash(row)
    return nil unless row

    hash = {}
    row.each do |key, value|
      next if key.is_a?(Integer)

      hash[key.to_sym] = value
    end
    hash
  end

  def self.rows_to_hashes(rows)
    rows.map { |row| row_to_hash(row) }
  end

  def self.query_one(sql, params = [])
    stmt = connection.prepare(sql)
    row = stmt.execute(*params).next
    stmt.close
    row_to_hash(row)
  end

  def self.query_all(sql, params = [])
    stmt = connection.prepare(sql)
    rows = stmt.execute(*params).to_a
    stmt.close
    rows_to_hashes(rows)
  end

  def self.execute(sql, params = [])
    stmt = connection.prepare(sql)
    stmt.execute(*params)
    stmt.close
  end

  def self.create_user(username, password_hash)
    execute(
      "INSERT INTO users (username, password_hash, created_at) VALUES (?, ?, ?)",
      [username, password_hash, Time.now.utc.iso8601]
    )
    connection.last_insert_row_id
  end

  def self.find_user_by_username(username)
    query_one("SELECT * FROM users WHERE username = ?", [username])
  end

  def self.find_user_by_id(user_id)
    query_one("SELECT * FROM users WHERE id = ?", [user_id])
  end

  def self.create_player_for_user(user_id)
    execute(
      "INSERT INTO players (user_id, health, max_health, attack, defense, gold, location) VALUES (?, ?, ?, ?, ?, ?, ?)",
      [user_id, 20, 20, 4, 1, 0, "battlefield"]
    )
    connection.last_insert_row_id
  end

  def self.load_player(user_id)
    query_one("SELECT * FROM players WHERE user_id = ?", [user_id])
  end

  def self.update_player(player_hash)
    execute(
      "UPDATE players SET health = ?, max_health = ?, attack = ?, defense = ?, gold = ?, location = ? WHERE id = ?",
      [
        player_hash[:health],
        player_hash[:max_health],
        player_hash[:attack],
        player_hash[:defense],
        player_hash[:gold],
        player_hash[:location],
        player_hash[:id]
      ]
    )
  end

  def self.get_inventory(player_id)
    query_all(
      "SELECT inventories.id AS inventory_id, items.*, inventories.quantity
       FROM inventories
       JOIN items ON items.id = inventories.item_id
       WHERE inventories.player_id = ?",
      [player_id]
    )
  end

  def self.find_item_by_id(item_id)
    query_one("SELECT * FROM items WHERE id = ?", [item_id])
  end

  def self.add_item(player_id, item_id, quantity = 1)
    row = query_one(
      "SELECT * FROM inventories WHERE player_id = ? AND item_id = ?",
      [player_id, item_id]
    )
    if row
      execute(
        "UPDATE inventories SET quantity = ? WHERE id = ?",
        [row[:quantity] + quantity, row[:id]]
      )
    else
      execute(
        "INSERT INTO inventories (player_id, item_id, quantity) VALUES (?, ?, ?)",
        [player_id, item_id, quantity]
      )
    end
  end

  def self.remove_item(player_id, item_id, quantity = 1)
    row = query_one(
      "SELECT * FROM inventories WHERE player_id = ? AND item_id = ?",
      [player_id, item_id]
    )
    return unless row

    new_qty = row[:quantity] - quantity
    if new_qty <= 0
      execute("DELETE FROM inventories WHERE id = ?", [row[:id]])
    else
      execute("UPDATE inventories SET quantity = ? WHERE id = ?", [new_qty, row[:id]])
    end
  end

  def self.spawn_enemy(_location)
    query_one("SELECT * FROM enemies ORDER BY RANDOM() LIMIT 1")
  end
end

module CombatEngine
  def self.resolve(player, enemy)
    log = []

    player_attack = [player[:attack] - enemy[:defense], 1].max
    enemy_attack = [enemy[:attack] - player[:defense], 1].max

    enemy_health = enemy[:health] - player_attack
    log << "You strike the #{enemy[:name]} for #{player_attack} damage."

    if enemy_health <= 0
      log << "The #{enemy[:name]} falls."
      updated_player = player.merge(
        gold: player[:gold] + enemy[:gold_reward]
      )
      return {
        player: updated_player,
        enemy: enemy.merge(health: 0),
        log: log,
        enemy_defeated: true,
        outcome: :win
      }
    end

    player_health = player[:health] - enemy_attack
    log << "The #{enemy[:name]} hits you for #{enemy_attack} damage."

    outcome = player_health <= 0 ? :lose : :draw
    {
      player: player.merge(health: player_health),
      enemy: enemy.merge(health: enemy_health),
      log: log,
      enemy_defeated: false,
      outcome: outcome
    }
  end
end

module InventoryEngine
  def self.use_item(player, item)
    case item[:item_type]
    when "heal"
      heal = item[:heal_amount].to_i
      new_health = [player[:health] + heal, player[:max_health]].min
      {
        player: player.merge(health: new_health),
        log: "You use #{item[:name]} and recover #{new_health - player[:health]} health.",
        consumed: true
      }
    else
      {
        player: player,
        log: "Nothing happens.",
        consumed: false
      }
    end
  end
end

helpers do
  def current_user
    return nil unless session[:user_id]

    DB.find_user_by_id(session[:user_id])
  end

  def current_player
    return nil unless session[:user_id]

    DB.load_player(session[:user_id])
  end

  def require_login
    return if current_user

    redirect "/login"
  end

  def flash_message
    msg = session.delete(:flash)
    msg unless msg.to_s.empty?
  end
end

before do
  pass if ["/login", "/register"].include?(request.path_info)
  require_login
end

get "/" do
  redirect "/game"
end

get "/register" do
  slim :register
end

post "/register" do
  username = params[:username].to_s.strip
  password = params[:password].to_s

  if username.empty? || password.empty?
    @error = "Username and password are required."
    return slim :register
  end

  existing = DB.find_user_by_username(username)
  if existing
    @error = "That username is taken."
    return slim :register
  end

  password_hash = BCrypt::Password.create(password)
  user_id = DB.create_user(username, password_hash)
  DB.create_player_for_user(user_id)

  session[:user_id] = user_id
  redirect "/game"
end

get "/login" do
  slim :login
end

post "/login" do
  username = params[:username].to_s.strip
  password = params[:password].to_s

  user = DB.find_user_by_username(username)
  if user && BCrypt::Password.new(user[:password_hash]) == password
    session[:user_id] = user[:id]
    redirect "/game"
  else
    @error = "Invalid credentials."
    slim :login
  end
end

post "/logout" do
  session.clear
  redirect "/login"
end

get "/game" do
  # Load from DB on every request
  @player = current_player
  @inventory = DB.get_inventory(@player[:id])
  slim :game
end

get "/combat" do
  # Load player, then pick enemy based on current DB state
  @player = current_player
  @enemy = DB.spawn_enemy(@player[:location])
  slim :combat
end

post "/combat/attack" do
  # Load -> compute -> persist -> render
  @player = current_player
  enemy_id = params[:enemy_id].to_i
  @enemy = DB.query_one("SELECT * FROM enemies WHERE id = ?", [enemy_id])

  unless @enemy
    @error = "Enemy not found."
    return slim :combat
  end

  result = CombatEngine.resolve(@player, @enemy)
  @combat_log = result[:log]
  @enemy_defeated = result[:enemy_defeated]
  @player = result[:player]

  # Always persist updated state
  DB.update_player(@player)
  slim :combat
end

get "/inventory" do
  # Load from DB each time
  @player = current_player
  @inventory = DB.get_inventory(@player[:id])
  slim :inventory
end

post "/use_item/:id" do
  # Load -> compute -> persist -> redirect
  @player = current_player
  item_id = params[:id].to_i
  item = DB.find_item_by_id(item_id)

  unless item
    @error = "Item not found."
    return redirect "/inventory"
  end

  result = InventoryEngine.use_item(@player, item)
  @player = result[:player]
  # Persist player changes
  DB.update_player(@player)

  # Persist inventory changes
  DB.remove_item(@player[:id], item_id, 1) if result[:consumed]

  session[:flash] = result[:log]
  redirect "/inventory"
end
