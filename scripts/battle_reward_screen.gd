# battle_reward_screen.gd
extends PanelContainer

@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var rewards_container = $MarginContainer/VBoxContainer/RewardsContainer
@onready var gold_reward_label = $MarginContainer/VBoxContainer/RewardsContainer/GoldReward/AmountLabel
@onready var bonus_container = $MarginContainer/VBoxContainer/RewardsContainer/BonusContainer
@onready var total_label = $MarginContainer/VBoxContainer/TotalLabel
@onready var continue_button = $MarginContainer/VBoxContainer/ContinueButton

var battle_data: Dictionary = {}
var total_gold_earned: int = 0

signal continue_pressed()

func _ready():
	# Style the panel
	setup_panel_style()
	
	# Connect button
	if continue_button:
		continue_button.connect("pressed", Callable(self, "_on_continue_pressed"))
	
	# Start hidden
	hide()

func setup_panel_style():
	# Create a fancy victory panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.8, 0.7, 0.2, 1)  # Gold border
	add_theme_stylebox_override("panel", style)
	
	# Center the panel
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -300
	offset_right = 300
	offset_top = -250
	offset_bottom = 250
	
	# Style the title
	if title_label:
		title_label.add_theme_font_size_override("font_size", 36)
		title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0, 1.0))
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Style the continue button
	if continue_button:
		continue_button.custom_minimum_size = Vector2(200, 50)

func show_rewards(data: Dictionary):
	battle_data = data
	
	# Set title
	if title_label:
		title_label.text = "VICTORY!"
	
	# Clear previous bonuses
	for child in bonus_container.get_children():
		bonus_container.remove_child(child)
		child.queue_free()
	
	# Only show rewards for trainer battles
	if data.get("is_trainer_battle", false):
		# Base trainer battle reward
		var base_reward = GoldManager.BASE_TRAINER_REWARD
		add_bonus_line("Trainer Battle", base_reward)
		total_gold_earned = base_reward
		
		# Enemy defeated bonus
		var enemies_defeated = data.get("enemies_defeated", 1)
		if enemies_defeated > 0:
			var enemy_bonus = enemies_defeated * GoldManager.PER_CRYPTID_BONUS
			add_bonus_line("Enemies Defeated x" + str(enemies_defeated), enemy_bonus)
			total_gold_earned += enemy_bonus
	else:
		# No gold for wild battles
		total_gold_earned = 0
		add_bonus_line("Wild Battle - No Gold Reward", 0)
	
	# Update total display
	if total_label:
		total_label.text = "Total Gold Earned: " + str(total_gold_earned)
		total_label.add_theme_font_size_override("font_size", 28)
		total_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0, 1.0))
		total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Show the panel with animation
	show()
	animate_in()

func add_bonus_line(text: String, amount: int):
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	
	# Bonus name
	var name_label = Label.new()
	name_label.text = text
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.custom_minimum_size = Vector2(200, 0)
	hbox.add_child(name_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	
	# Amount
	var amount_label = Label.new()
	amount_label.text = "+" + str(amount) + " G"
	amount_label.add_theme_font_size_override("font_size", 20)
	amount_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0, 1.0))
	hbox.add_child(amount_label)
	
	bonus_container.add_child(hbox)

func animate_in():
	# Start scaled down and transparent
	scale = Vector2(0.8, 0.8)
	modulate = Color(1, 1, 1, 0)
	
	# Animate to full size and opacity
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3)
	
	# After showing, actually give the gold
	tween.chain().tween_callback(Callable(self, "award_gold"))

func award_gold():
	if GoldManager:
		GoldManager.add_gold(total_gold_earned, "Battle Victory")

func _on_continue_pressed():
	# Animate out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.2)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.2)
	tween.chain().tween_callback(Callable(self, "hide"))
	tween.chain().tween_callback(func(): emit_signal("continue_pressed"))
