require 'sinatra'
require 'sqlite3'
require 'slim'
require 'sinatra/reloader'
require 'bcrypt'



enable :session

post('/register') do
    user = params["user"]
    pwd = params["pwd"]
    pwd_confirm = params["pwd_confirm"]
    
    db = SQLite3::Database.new("db/brutus.db")
    result = db.execute("SELECT id FROM users WHERE name=?",user)

    if result.empty?
        if pwd == pwd_confirm
            pwd_digest = BCrypt::Password.create(pwd)
            db.execute("INSERT INTO users(name, pwd_digest) VALUES(?,?)", [user, pwd_digest])
            redirect('/')
        else
            redirect('/register')
        end
    else
        redirect('/register')
    end

end

get('/') do
    if session[:user_id] == nil
        redirect('/login')
    end
    id = params[:id].to_i
    db = SQLite3::Database.new("db/brutus.db")
    result = db.execute("SELECT * FROM users WHERE name=?",user)
    slim(:home)
end



get('/register') do
    session.clear
    slim(:register)
end

get('/login') do
    session.clear
    slim(:login)
end

post('/login') do
    user = params["user"]
    pwd = params["pwd"]

    db = SQLite3::Database.new("db/brutus.db")
    db.results_as_hash = true
    result = db.execute("SELECT id, pwd_digest FROM users WHERE name=?",user)

    if result.empty?
        redirect('/error')
    end

    user_id = result.first["id"]
    pwd_digest = result.first["pwd_digest"]

    if BCrypt::Password.new(pwd_digest) == pwd
        session[:user_id] = user_id
        redirect('/')
    else
        redirect('/error')
    end

end



COLORS = {
  red: "\e[31m",
  green: "\e[32m",
  yellow: "\e[33m",
  blue: "\e[34m",
  magenta: "\e[35m",
  cyan: "\e[36m",
  reset: "\e[0m"
}

def initialize
  @game_over = false
  @current_room = :battlefield
  @player_inventory = []
  @game_state = {
    robbert_trust: 0,
    knows_about_invasion: false,
    found_parents: false,
    boulder_event: false,
    hearing_fighting_battlefield: false,
    next_to_robbert: true,
    at_battlefield: true,
    equipped_chestplate: false,
    equipped_helmet: false,
    equipped_leggings: false,
    name_lie: false,
    yourself_question: false
  }
  
  @level = 1
  @experience = 0
  @playername = ""
  @health = rand(5..10)
  @time = "afternoon"
  @day = 1
  @thehour = 13
  @theminute = 10
  @enemies = {
    "stragglers" => { hp: 15, damage: 3, xp: 10 },
    "imperialscout" => { hp: 20, damage: 5, xp: 15 },
    "mercenary" => { hp: 25, damage: 6, xp: 20 }
  }
end

def start
  character_creation
  introduction_dialogue  
  puts "\nType 'help' for a list of commands.\n"
  game_loop
end

def character_creation
  system('cls')
  sleep 1
  puts "???: What's your name, kid?"
  sleep 1
  puts "#{colorize('He stretches out his war-torn hand.', :green)}"
  @playername = gets.chomp
  sleep 1
  puts "#{colorize('*You grab his hand and pull yourself up*', :green)}"
  sleep 2
  puts "You: My name is #{player_name}."
  sleep 2
  if @playername.length > 10
    puts "???: What?? That's too long!\n???: At least give me a nickname I can use!"
    @playername = gets.chomp
  end

  while @playername.include?("Brutus") || @playername.length >= 10 || @playername.length <= 2 || @playername.include?(' ')
    puts "???: Stop lying. No parent would name their child that."
    sleep 0.7
    if !@game_state[:name_lie]
      @game_state[:robbert_trust] -= 2
      @game_state[:name_lie] = true
    end
    puts "???: What's your actual name?"
    @playername = gets.chomp
  end

  firstletter = @playername[0]&.upcase
  case firstletter
  when "S"
    puts "???: #{player_name}, huh? Strong name. Don't worry, I've been on more battlefields than you can count. I'll get you out of here."
  when "G"
    puts "???: #{player_name}, huh..?"
    puts "#{colorize('He looks at you strangely', :green)}."
  when "J"
    puts "???: #{player_name}, huh? An honorable name. I can tell you'll be great. Don't worry, I've been on more battlefields than you can count. I'll get you out of here."
  when "H"
    puts "???: #{player_name}, huh? A name of vice. Don't worry, I've been on more battlefields than you can count. I'll get you out of here."
  when "A"
    puts "???: #{player_name}, huh? A wise name. Don't worry, I've been on more battlefields than you can count. I'll get you out of here."
  when "N"
    puts "???: #{player_name}, huh? An interesting name. Don't worry, I've been on more battlefields than you can count. I'll get you out of here."
  when "R"
    puts "???: #{player_name}, huh? Peculiar name. Don't worry, I've been on more battlefields than you can count. I'll get you out of here."
  when "X"
    puts "???: #{player_name}..? Fascinating name. 'X' just so happens to be my favorite letter. I can tell we'll get along well."
  else
    puts "???: #{player_name}, huh? Don't worry, I've been on more battlefields than you can count. I'll get you out of here."
  end
end

def game_loop
  until @game_over
    print "> "
    input = gets.chomp.downcase.strip
    
    next if handle_special_commands(input)
    
    command, *params = input.split
    case command
    when 'look'
      describe_room
    when 'go', 'move'
      direction = params.first
      move_to(direction)
    when 'talk', 'ask'
      topic = params.join(' ')
      handle_dialogue(topic)
    when 'take', 'get'
      item = params.join(' ')
      take_item(item)
    when 'use'
      item = params.join(' ')
      use_item(item)
    when 'equip'
      item = params.join(' ')
      equip(item)
    when 'inventory', 'items'
      show_inventory
    when 'attack'
      enemy = params.join(' ')
      enemy_types = ["Stragglers", "Imperial Scout", "Mercenary"]
      nevermind = ["no", "nevermind", "stop", "quit"]
      if !enemy_types.include?(enemy)
        puts "Who are you attacking?"
        puts "Valid choices:\nStragglers\nMercenary\nImperial Scout"
        print "> "
        enemy = gets.chomp.downcase.strip
        if nevermind.include?(enemy)
          puts "Tragedy averted."
        end
          
      end
      initiate_combat(enemy)
    when 'stats'
      show_stats
    when 'wait'
      advance_time
    when 'unequip'
      item = params.join(' ')
      unequip(item)
    when 'help'
      show_help
    when 'quit', 'exit'
      @game_over = true
    when 'listen'
      ''
    else
      puts "I don't understand that command."
    end
  end
  puts "Thanks for playing, #{player_name}."
end

def introduction_dialogue
  sleep 4
  if @playername[0]&.upcase == "G"
    puts "#{player_name}: ...Who are you?"
  else
    puts "#{player_name}: Who are you?"
  end

  puts "\n???: Who am I? The name's #{colorize('Robbert', :blue)}, a mercenary, nice to meet'cha."
  sleep 4
  puts "#{colorize('Robbert', :blue)}: By the way, how'd you get in this mess? How old are you even?"
  sleep 4
  
  # Player's response options
  puts "\nHow do you respond?"
  puts "1. Tell the full truth"
  puts "2. Lie about your age"
  puts "3. Stay silent"
  print "> "
  answer = gets.chomp.to_i

  case answer
  when 1
    puts "#{player_name}: I'm twelve. Both of my parents went missing some days ago."
    @game_state[:robbert_trust] += 2
    sleep 4
  when 2
    puts "#{player_name}: I'm... sixteen. I got separated from my unit."
    @game_state[:robbert_trust] -= 1
    sleep 3
    puts "#{colorize('Robbert', :blue)}: ...My condolences. Then again, you're probably not the only one."
    sleep 3
    puts "#{colorize('Robbert', :blue)}: Wouldn't surprise me if the churches were working their asses off right now."
    sleep 3
  else
    puts "#{player_name}: ..."
    puts "#{colorize('Robbert', :blue)}: Tough kid, eh? Alright then."
    sleep 3
  end
  puts "#{colorize('*You take a look around*', :green)}"
  @game_state[:knows_about_invasion] = true
  sleep 4
  describe_room
end

def show_help
  puts "Available commands:"
  puts "look - Describe current location"
  puts "go/move [direction] - Move to new area"
  puts "search - Look for items"
  puts "listen - Listen to your surroundings"
  puts "examine - Examine something interesting"
  puts "approach - Get closer to something"
  puts "talk/ask [topic] - Ask about something"
  puts "take/get [item] - Pick up an item"
  puts "use [item] - Use an item from your inventory"
  puts "equip [item] - Equip an item"
  puts "unequip [item] - Unequip an item"
  puts "inventory/items - Show your inventory"
  puts "attack - Fight enemies"
  puts "wait - Pass time"
  puts "stats - Show your status"
  puts "help - Show this menu"
  puts "quit/exit - End the game"
end

def show_stats
  puts "#{player_name}, Level #{@level}"
  puts "health: #{@health}"
  puts "Experience: #{@experience}/#{@level * 10}"
  puts "Weapon: #{current_weapon[:name]} (#{current_weapon[:damage]} damage)"
end

def initiate_combat(enemy)
  nevermind = ["no", "nevermind", "stop", "exit", "quit"]
  
  if nevermind.include?(enemy) || !@enemies.key?(enemy.downcase)
    return false
  end
  
  enemy_key = enemy.downcase  
  puts "\nYou encounter #{enemy}! Battle begins!"
  @game_state[:next_to_robbert] = false
  enemy_stats = @enemies[enemy_key]
  enemy_hp = enemy_stats[:hp]
  
  while enemy_hp > 0
    puts "\nEnemy HP: #{enemy_hp}"
    puts "Your HP: #{@health}"
    puts "\nWhat will you do?"
    puts "1. Attack"
    puts "2. Run"
    print "> "
    choice = gets.strip.to_s.downcase
    
    case choice
    when "1", "attack"
      puts ""
      player_damage = current_weapon[:damage] + rand(1..3)
      puts "You attack with your #{current_weapon[:name]} and deal #{player_damage} damage!"
      enemy_hp -= player_damage
      
      if enemy_hp <= 0
        puts "You defeated the #{enemy}!"
        gain_experience(enemy_stats[:xp])
        loot_chance(enemy)
        @game_state[:next_to_robbert] = true
        break
      end
      
      enemy_damage = enemy_stats[:damage] + rand(0..2)
      puts "The #{enemy} attacks you for #{enemy_damage} damage!"
      @health -= enemy_damage
      
      if @health <= 0
        puts "You have been defeated..."
        @game_over = true
        break
      end
    when "2", "run"
      escape_chance = rand(1..10)
      if escape_chance > 5
        puts "You managed to escape!"
        break
      else
        puts "You couldn't escape!"
        enemy_damage = enemy_stats[:damage] + rand(0..2)
        puts "The #{enemy} attacks you for #{enemy_damage} damage!"
        @health -= enemy_damage
        
        if @health <= 0
          puts "You have been defeated..."
          @game_over = true
          break
        end
      end
    else
      puts "Invalid choice!"
    end
  end
end

def loot_chance(enemy)
  chance = rand(1..10)
  case enemy
  when "stragglers"
    if chance > 7
      puts "You found some bandages!"
      @player_inventory << "bandages"
    end
  when "imperial_scout"
    if chance > 5 && !@player_inventory.include?("spear")
      puts "You found an Imperial Spear!"
      @player_inventory << "spear"
    end
  when "mercenary"
    if chance > 3
      roll = rand(1..3)
      if roll == 1 && !@player_inventory.include?("Iron Helmet")
        puts "You found an iron helmet!"
        @player_inventory << "Iron Helmet"
      else 
        roll = rand(2..3)
      end
      if roll == 2 && !@player_inventory.include?("Iron Chestplate")
        puts "You found an iron chestplate!"
        @player_inventory << "Iron Chestplate"
      else
        roll = 3
      end
      if roll == 3 && !@player_inventory.include?("Iron Leggings")
        puts "You found iron leggings!"
        @player_inventory << "Iron Leggings"
      end
      if @player_inventory.include?("Iron Helmet", "Iron Chestplate", "Iron Leggings")
        puts "Nothing worth taking."
      end
    end
  end
end

def gain_experience(xp)
  @experience += xp
  puts "You gained #{xp} experience points!"
  
  if @experience >= @level * 10
    level_up
  end
end

def level_up
  @level += 1
  @health += 3
  @experience = 0
  puts "You leveled up! You are now level #{@level}!"
  puts "Your health increased to #{@health}!"
end

def describe_room
  case @current_room
  when :battlefield
    puts "\nDay #{@day}, #{@time.capitalize}:  \nA horrendous sight."
    sleep 1.2
    puts "You start to wonder if it was all really worth it in the end."
    sleep 3
    puts "A mercenary is staring at you from the ground."
    sleep 1
    puts "And another."
    sleep 1
    puts "And another."
    sleep 2
    puts "You hold your head high." 
    sleep 1
   
  when :boulder_site
    puts "\n"
    puts "The massive meteor-like boulder dominates the landscape. The boulder, charred and bloody, bears properties of both metal and stone."
    puts "The colossal stone dwarfed the corpses half-buried under the boulder, causing you to miss them at first glance."  
  end
end

def move_to(direction)
  case [@current_room, direction] 
  when [:battlefield, "toward fighting"], [:battlefield, "fighting"], [:battlefield, "toward"]
    if @game_state[:hearing_fighting_battlefield]
    puts "You move toward the sounds of clashing steel..."
    initiate_combat("stragglers")
    else
      "You seem to be a bit out of it."
    end
  
  when [:battlefield, "northeast"], [:battlefield, "ne"], [:battlefield, "boulder"]
    if @game_state[:boulder_event] && !@game_state[:found_parents]
      @current_room = :boulder_site
      puts "You move towards the massive boulder"
    else
      puts "You don't see anything interesting in that direction."
    end
  
  when [:boulder_site, "return"], [:boulder_site, "back"], [:boulder_site, "battlefield"]
    @current_room = :battlefield
    puts "You return to the main battlefield."
  else
    puts "You can't go that way."
  end
end

def take_item(item)
  case [@current_room, item]
  when [:battlefield, 'sword']
    if !@player_inventory.include?('sword')
      @player_inventory << 'sword'
      puts "You take the sword."
    else
      puts "You already have a sword."
    end
  when [:battlefield, 'spear']
    if !@player_inventory.include?('spear')
      @player_inventory << 'spear'
      puts "You take the spear."
    else
      puts "You already have a spear."
    end
  when [:boulder_site, 'pendant']
    if @game_state[:found_parents] && !@player_inventory.include?('pendant')
      @player_inventory << 'pendant'
      puts "You take your family pendant from your parents' remains."
      puts "#{colorize('Robbert', :blue)} watches silently, his face grim with determination."
    else
      puts "I don't see that here."
    end
  else
    puts "I don't see that here."
  end
end

def current_weapon
  if @player_inventory.include?("spear") && @equipped_weapon == "spear"
    {name: "spear", damage: 10}
  elsif @player_inventory.include?("sword") && (@equipped_weapon == "sword" || @equipped_weapon.nil?)
    {name: "sword", damage: 8}
  else
    {name: "fists", damage: 3}
  end
end

def show_inventory
  if @player_inventory.empty?
    puts "Your inventory is empty."
  else
    puts "You are carrying:"
    @player_inventory.each { |item| puts "- #{item}" }
  end
end

def equip(item)
  weapons = ['spear', 'sword', 'fist']
  armor = ['Iron Helmet', 'Iron Chestplate', 'Iron Leggings']
  if @player_inventory.include?(item) && weapons.include?(item)
    puts "You equip the #{item}."
    @equipped_weapon = item
  elsif @player_inventory.include?(item) && armor.include?(item)
    puts "You equip the #{item}."
    if item == 'Iron Helmet' && @game_state[:equipped_helmet] == false
      @game_state[:equipped_helmet] = true
      @health += 3
    elsif item == 'Iron Chestplate' && @game_state[:equipped_chestplate] == false
      @game_state[:equipped_chestplate] = true
      @health += 5
    elsif item == 'Iron Leggings' && @game_state[:equipped_leggings] == false
      @game_state[:equipped_leggings] = true
      @health += 4
    end
  elsif item == "fist"
    puts "#{colorize('You throw your weapon to the ground, now armed and dangerous.', :green)}"
  else
    puts "You can't equip that."
  end
end

def unequip(item)
  weapons = ['spear', 'sword', 'fist']
  armor = ['Iron Helmet', 'Iron Chestplate', 'Iron Leggings']
  if @player_inventory.include?(item) && weapons.include?(item)
    puts "You unequip the #{item}."
    @equipped_weapon = 'fist'
  elsif @player_inventory.include?(item) && armor.include?(item)
    puts "You unequip the #{item}."
    if item == 'Iron Helmet' && @game_state[:equipped_helmet] == true
      @game_state[:equipped_helmet] = false
      @health -= 3
    elsif item == 'Iron Chestplate' && @game_state[:equipped_chestplate] == true
      @game_state[:equipped_chestplate] = false
      @health -= 5
    elsif item == 'Iron Leggings' && @game_state[:equipped_leggings] == true
      @game_state[:equipped_leggings] = false
      @health -= 4
    end
  end
end

def use_item(item)
  if @player_inventory.include?(item)
    case item
    when 'sword'
      puts "You take a stance, imagining an enemy. The only thing they fear is you."
    when 'spear'
      puts "A finely crafted spear glimmers even in the darkest depths."
    when 'bandages'
      heal_amount = rand(3..5)
      @health += heal_amount
      @player_inventory.delete('bandages')
      puts "You use the bandages to heal #{heal_amount} health. Your health is now #{@health}."
    else
      puts "You use the #{item}, but nothing happens."
    end
  else
    puts "You don't have that item."
  end
end



