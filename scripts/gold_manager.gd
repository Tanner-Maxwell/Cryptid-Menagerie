# gold_manager.gd
extends Node

# Gold tracking
var current_gold: int = 0
var total_gold_earned: int = 0

# Signals
signal gold_changed(new_amount: int)
signal gold_earned(amount: int)
signal gold_spent(amount: int)
signal insufficient_gold()

# Gold rewards based on battle conditions
const BASE_TRAINER_REWARD = 100
const PER_CRYPTID_BONUS = 25

func _ready():
	print("GoldManager initialized with", current_gold, "gold")

# Add gold with optional reason for tracking
func add_gold(amount: int, reason: String = ""):
	if amount <= 0:
		return
		
	current_gold += amount
	total_gold_earned += amount
	
	print("Added", amount, "gold. Reason:", reason if reason != "" else "Unspecified")
	print("Current gold:", current_gold)
	
	emit_signal("gold_earned", amount)
	emit_signal("gold_changed", current_gold)

# Spend gold if player has enough
func spend_gold(amount: int, reason: String = "") -> bool:
	if amount <= 0:
		return false
		
	if current_gold >= amount:
		current_gold -= amount
		print("Spent", amount, "gold. Reason:", reason if reason != "" else "Unspecified")
		print("Current gold:", current_gold)
		
		emit_signal("gold_spent", amount)
		emit_signal("gold_changed", current_gold)
		return true
	else:
		print("Insufficient gold. Needed:", amount, "Have:", current_gold)
		emit_signal("insufficient_gold")
		return false

# Check if player can afford something
func can_afford(amount: int) -> bool:
	return current_gold >= amount

# Get current gold amount
func get_gold() -> int:
	return current_gold

# Calculate reward for battle victory
func calculate_battle_reward(battle_data: Dictionary) -> int:
	var reward = 0
	
	# Only trainer battles give gold
	if battle_data.get("is_trainer_battle", false):
		reward = BASE_TRAINER_REWARD
		
		# Bonus per enemy cryptid defeated
		var enemies_defeated = battle_data.get("enemies_defeated", 1)
		reward += enemies_defeated * PER_CRYPTID_BONUS
	
	return reward

# Save/Load functions for persistence
func save_data() -> Dictionary:
	return {
		"current_gold": current_gold,
		"total_gold_earned": total_gold_earned
	}

func load_data(data: Dictionary):
	current_gold = data.get("current_gold", 0)
	total_gold_earned = data.get("total_gold_earned", 0)
	emit_signal("gold_changed", current_gold)

# Reset gold (for new game)
func reset():
	current_gold = 0
	total_gold_earned = 0
	emit_signal("gold_changed", current_gold)
