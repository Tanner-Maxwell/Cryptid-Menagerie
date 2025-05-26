# film_manager.gd
extends Node

# Film tracking
var current_film: int = 5  # Start with 5 film
var total_film_used: int = 0
var max_film: int = 99  # Maximum film that can be carried

# Signals
signal film_changed(new_amount: int)
signal film_used(amount: int)
signal film_added(amount: int)
signal insufficient_film()

# Film costs
const FILM_PER_CATCH_ATTEMPT = 1

func _ready():
	print("FilmManager initialized with", current_film, "film")

# Add film with optional reason for tracking
func add_film(amount: int, reason: String = ""):
	if amount <= 0:
		return
		
	var previous_amount = current_film
	current_film = min(current_film + amount, max_film)
	var actual_added = current_film - previous_amount
	
	print("Added", actual_added, "film. Reason:", reason if reason != "" else "Unspecified")
	print("Current film:", current_film)
	
	emit_signal("film_added", actual_added)
	emit_signal("film_changed", current_film)

# Use film if player has enough
func use_film(amount: int, reason: String = "") -> bool:
	if amount <= 0:
		return false
		
	if current_film >= amount:
		current_film -= amount
		total_film_used += amount
		print("Used", amount, "film. Reason:", reason if reason != "" else "Unspecified")
		print("Current film:", current_film)
		
		emit_signal("film_used", amount)
		emit_signal("film_changed", current_film)
		return true
	else:
		print("Insufficient film. Needed:", amount, "Have:", current_film)
		emit_signal("insufficient_film")
		return false

# Check if player can afford film cost
func has_film(amount: int) -> bool:
	return current_film >= amount

# Get current film amount
func get_film() -> int:
	return current_film

# Save/Load functions for persistence
func save_data() -> Dictionary:
	return {
		"current_film": current_film,
		"total_film_used": total_film_used
	}

func load_data(data: Dictionary):
	current_film = data.get("current_film", 5)
	total_film_used = data.get("total_film_used", 0)
	emit_signal("film_changed", current_film)

# Reset film (for new game)
func reset():
	current_film = 5  # Start with 5 film
	total_film_used = 0
	emit_signal("film_changed", current_film)

# Set film to specific amount (for testing/rewards)
func set_film(amount: int):
	current_film = clamp(amount, 0, max_film)
	emit_signal("film_changed", current_film)
