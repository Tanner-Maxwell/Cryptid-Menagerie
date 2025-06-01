class_name VisualEffectsManager
extends Node2D

signal attack_animation_finished
signal movement_animation_finished
signal heal_animation_finished
signal effect_animation_finished(effect_type: String)

# References
var tile_map: TileMapLayer

# Effect tracking
var active_effects: Array = []
var current_tween: Tween

# Colors for different effects
const ATTACK_COLOR = Color(1, 0, 0, 0.8)
const HEAL_COLOR = Color(0, 1, 0, 0.8)
const STUN_COLOR = Color(1, 1, 0, 0.8)
const POISON_COLOR = Color(0.5, 0, 0.5, 0.8)
const PUSH_COLOR = Color(1, 0.5, 0, 0.8)
const PULL_COLOR = Color(0, 0.5, 1, 0.8)
const VULNERABLE_COLOR = Color(1, 0.8, 0, 0.8)
const BURN_COLOR = Color(1, 0.3, 0, 0.8)
const SHIELD_COLOR = Color(0, 0.7, 1, 0.8)

# Initialize with tile map reference
func initialize(map: TileMapLayer):
	tile_map = map
	z_index = 100  # Ensure effects appear above everything

# ==== ATTACK EFFECTS ====
func animate_attack(attacker: Node, target: Node):
	print("Starting attack animation from", attacker.cryptid.name, "to", target.cryptid.name)
	
	# Store original position
	var original_position = attacker.position
	
	# Calculate direction and bump position
	var direction = (target.position - original_position).normalized()
	var bump_distance = min((target.position - original_position).length() * 0.4, 60.0)
	var bump_position = original_position + direction * bump_distance
	
	# Create attack visual
	create_attack_effect(attacker.position, target.position)
	
	# Animate the attacker
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	
	# Bump forward and back
	tween.tween_property(attacker, "position", bump_position, 0.2)
	tween.tween_property(attacker, "position", original_position, 0.3)
	
	# Connect completion signal
	tween.finished.connect(_on_attack_animation_finished)

func create_attack_effect(start_pos: Vector2, end_pos: Vector2):
	# Create attack line
	var attack_line = Line2D.new()
	attack_line.width = 8
	attack_line.default_color = ATTACK_COLOR
	attack_line.add_point(start_pos)
	attack_line.add_point(end_pos)
	attack_line.name = "attack_effect"
	add_child(attack_line)
	
	# Create impact effect
	var impact = ColorRect.new()
	impact.color = ATTACK_COLOR
	impact.size = Vector2(40, 40)
	impact.position = end_pos - Vector2(20, 20)
	impact.name = "attack_effect"
	add_child(impact)
	
	# Animate effects
	var effect_tween = create_tween()
	effect_tween.set_parallel(true)
	
	# Pulse line
	effect_tween.tween_property(attack_line, "width", 15, 0.15)
	effect_tween.tween_property(attack_line, "width", 3, 0.35)
	
	# Expand and fade impact
	effect_tween.tween_property(impact, "scale", Vector2(2.0, 2.0), 0.4)
	effect_tween.tween_property(impact, "modulate:a", 0.0, 0.4)
	
	# Schedule cleanup
	effect_tween.finished.connect(func(): clean_up_effects("attack_effect"))

# ==== MOVEMENT EFFECTS ====
func animate_movement(cryptid: Node, path: Array):
	print("Animating movement along path with", path.size(), "points")
	
	# Convert path IDs to world positions
	var world_positions = []
	for point_id in path:
		var hex_pos = tile_map.a_star_hex_grid.get_point_position(point_id)
		world_positions.append(tile_map.map_to_local(hex_pos))
	
	# Create movement trail
	var trail = create_movement_trail(world_positions)
	
	# Animate movement
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Move through each point
	var movement_speed = 0.2  # seconds per hex
	for i in range(1, world_positions.size()):
		tween.tween_property(cryptid, "position", world_positions[i], movement_speed)
	
	# Add bounce at end
	tween.tween_property(cryptid, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(cryptid, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Connect completion and cleanup
	tween.finished.connect(_on_movement_animation_finished)
	tween.finished.connect(func(): fade_out_trail(trail))

func create_movement_trail(path: Array) -> Line2D:
	var trail = Line2D.new()
	trail.width = 5
	trail.default_color = Color(0.2, 0.8, 0.2, 0.7)
	trail.z_index = -1
	trail.name = "movement_trail"
	
	for point in path:
		trail.add_point(point)
	
	add_child(trail)
	return trail

func fade_out_trail(trail: Line2D):
	var fade_tween = create_tween()
	fade_tween.tween_property(trail, "modulate:a", 0.0, 0.5)
	fade_tween.finished.connect(func(): trail.queue_free())

# ==== HEAL EFFECTS ====
func animate_heal(caster: Node, target: Node):
	print("Starting heal animation")
	
	create_heal_effect(caster.position, target.position)
	
	# Animate caster
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Pulse caster
	tween.tween_property(caster, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(caster, "scale", Vector2(1.0, 1.0), 0.2)
	
	# Glow target
	var original_modulate = target.modulate
	tween.tween_property(target, "modulate", Color(0.5, 1, 0.5, 1), 0.3)
	tween.tween_property(target, "modulate", original_modulate, 0.3)
	
	tween.finished.connect(_on_heal_animation_finished)

func create_heal_effect(start_pos: Vector2, end_pos: Vector2):
	# Create heal line
	var heal_line = Line2D.new()
	heal_line.width = 6
	heal_line.default_color = HEAL_COLOR
	heal_line.add_point(start_pos)
	heal_line.add_point(end_pos)
	heal_line.name = "heal_effect"
	add_child(heal_line)
	
	# Create heal particles
	var particles = ColorRect.new()
	particles.color = Color(0, 1, 0, 0.6)
	particles.size = Vector2(40, 40)
	particles.position = end_pos - Vector2(20, 20)
	particles.name = "heal_effect"
	add_child(particles)
	
	# Animate
	var effect_tween = create_tween()
	effect_tween.set_parallel(true)
	
	# Pulse line
	effect_tween.tween_property(heal_line, "width", 12, 0.2)
	effect_tween.tween_property(heal_line, "width", 3, 0.3)
	
	# Expand and fade particles
	effect_tween.tween_property(particles, "scale", Vector2(2.0, 2.0), 0.5)
	effect_tween.tween_property(particles, "modulate:a", 0.0, 0.5)
	
	effect_tween.finished.connect(func(): clean_up_effects("heal_effect"))

# ==== STUN EFFECTS ====
func animate_stun(caster: Node, target: Node):
	print("Starting stun animation")
	
	create_stun_effect(caster.position, target.position, target)
	
	# Animate caster
	var tween = create_tween()
	tween.tween_property(caster, "scale", Vector2(1.15, 1.15), 0.15)
	tween.tween_property(caster, "scale", Vector2(1.0, 1.0), 0.15)
	
	# Spin target
	tween.tween_property(target, "rotation", TAU, 0.5)
	tween.tween_property(target, "rotation", 0.0, 0.0)
	
	# Flash yellow
	var original_modulate = target.modulate
	tween.tween_property(target, "modulate", Color.YELLOW, 0.2)
	tween.tween_property(target, "modulate", original_modulate, 0.2)
	
	tween.finished.connect(func(): effect_animation_finished.emit("stun"))

func create_stun_effect(start_pos: Vector2, end_pos: Vector2, target: Node):
	# Create stun line
	var stun_line = Line2D.new()
	stun_line.width = 6
	stun_line.default_color = STUN_COLOR
	stun_line.add_point(start_pos)
	stun_line.add_point(end_pos)
	stun_line.name = "stun_effect"
	add_child(stun_line)
	
	# Create rotating stars on the target
	var star_container = Node2D.new()
	star_container.name = "stun_stars"
	star_container.position = Vector2(0, -30)
	target.add_child(star_container)
	
	# Add stars
	for i in range(3):
		var star = ColorRect.new()
		star.color = STUN_COLOR
		star.size = Vector2(20, 20)
		var angle = (TAU / 3) * i
		star.position = Vector2(cos(angle), sin(angle)) * 30 - Vector2(10, 10)
		star_container.add_child(star)
	
	# Rotate stars
	var star_tween = create_tween()
	star_tween.set_loops()
	star_tween.tween_property(star_container, "rotation", TAU, 2.0).as_relative()
	
	# Fade out line
	var line_tween = create_tween()
	line_tween.tween_property(stun_line, "modulate:a", 0.0, 0.5).set_delay(0.5)
	line_tween.finished.connect(func(): stun_line.queue_free())

# ==== POISON EFFECTS ====
func animate_poison(caster: Node, target: Node):
	print("Starting poison animation")
	
	create_poison_effect(caster.position, target.position)
	
	# Animate caster
	var tween = create_tween()
	tween.tween_property(caster, "scale", Vector2(1.1, 1.1), 0.15)
	tween.tween_property(caster, "scale", Vector2(1.0, 1.0), 0.15)
	
	# Apply poison tint to target
	var original_modulate = target.modulate
	tween.tween_property(target, "modulate", Color(0.5, 0.2, 0.5, 1), 0.3)
	tween.tween_property(target, "modulate", original_modulate, 0.3)
	
	tween.finished.connect(func(): effect_animation_finished.emit("poison"))

# ==== VULNERABLE EFFECTS ====
func animate_vulnerable(caster: Node, target: Node):
	print("Starting vulnerable animation")
	
	create_vulnerable_effect(caster.position, target.position)
	
	# Animate caster
	var tween = create_tween()
	tween.tween_property(caster, "scale", Vector2(1.1, 1.1), 0.15)
	tween.tween_property(caster, "scale", Vector2(1.0, 1.0), 0.15)
	
	# Apply vulnerable tint to target
	var original_modulate = target.modulate
	tween.tween_property(target, "modulate", Color(1, 0.8, 0.3, 1), 0.3)
	tween.tween_property(target, "modulate", original_modulate, 0.3)
	
	tween.finished.connect(func(): effect_animation_finished.emit("vulnerable"))

func create_vulnerable_effect(start_pos: Vector2, end_pos: Vector2):
	# Create vulnerable line
	var vulnerable_line = Line2D.new()
	vulnerable_line.width = 6
	vulnerable_line.default_color = VULNERABLE_COLOR
	vulnerable_line.add_point(start_pos)
	vulnerable_line.add_point(end_pos)
	vulnerable_line.name = "vulnerable_effect"
	add_child(vulnerable_line)
	
	# Create vulnerable effect particles
	for i in range(3):
		var particle = ColorRect.new()
		particle.color = VULNERABLE_COLOR
		particle.size = Vector2(20, 20)
		var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		particle.position = end_pos + offset - particle.size / 2
		particle.name = "vulnerable_effect"
		add_child(particle)
		
		# Animate particles
		var particle_tween = create_tween()
		particle_tween.set_parallel(true)
		particle_tween.tween_property(particle, "scale", Vector2(1.5, 1.5), 0.5)
		particle_tween.tween_property(particle, "modulate", Color(1, 0.8, 0, 0), 0.5)
	
	# Clean up after animation
	await get_tree().create_timer(1.0).timeout
	for child in get_children():
		if child.name == "vulnerable_effect":
			child.queue_free()

# ==== IMMOBILIZE EFFECTS ====
func animate_immobilize(caster: Node, target: Node):
	print("Starting immobilize animation")
	
	create_immobilize_effect(caster.position, target.position)
	
	# Animate caster
	var tween = create_tween()
	tween.tween_property(caster, "scale", Vector2(1.1, 1.1), 0.15)
	tween.tween_property(caster, "scale", Vector2(1.0, 1.0), 0.15)
	
	# Apply immobilize effect to target (chain/root visual)
	var original_modulate = target.modulate
	tween.tween_property(target, "modulate", Color(0.7, 0.4, 0.2, 1), 0.3)
	tween.tween_property(target, "modulate", original_modulate, 0.3)
	
	tween.finished.connect(func(): effect_animation_finished.emit("immobilize"))

func create_immobilize_effect(start_pos: Vector2, end_pos: Vector2):
	# Create immobilize line
	var immobilize_line = Line2D.new()
	immobilize_line.width = 6
	immobilize_line.default_color = Color(0.7, 0.4, 0.2, 0.8)  # Brown color for roots/chains
	immobilize_line.add_point(start_pos)
	immobilize_line.add_point(end_pos)
	immobilize_line.name = "immobilize_effect"
	add_child(immobilize_line)
	
	# Create chain/root effects around target
	for i in range(4):
		var chain = ColorRect.new()
		chain.color = Color(0.5, 0.3, 0.1, 0.8)  # Dark brown
		chain.size = Vector2(8, 30)  # Thin chain links
		var angle = (TAU / 4) * i
		var offset = Vector2(cos(angle), sin(angle)) * 35
		chain.position = end_pos + offset - chain.size / 2
		chain.rotation = angle + PI/2  # Rotate chains
		chain.name = "immobilize_effect"
		add_child(chain)
		
		# Animate chains tightening
		var chain_tween = create_tween()
		chain_tween.set_parallel(true)
		chain_tween.tween_property(chain, "position", end_pos + offset * 0.7 - chain.size / 2, 0.5)
		chain_tween.tween_property(chain, "modulate", Color(0.5, 0.3, 0.1, 0), 2.0)
		chain_tween.finished.connect(func(): chain.queue_free())
	
	# Fade line
	var line_tween = create_tween()
	line_tween.tween_property(immobilize_line, "width", 12, 0.2)
	line_tween.tween_property(immobilize_line, "width", 3, 0.3)
	line_tween.tween_property(immobilize_line, "modulate:a", 0.0, 0.5).set_delay(0.5)
	line_tween.finished.connect(func(): immobilize_line.queue_free())

func create_poison_effect(start_pos: Vector2, end_pos: Vector2):
	# Create poison line
	var poison_line = Line2D.new()
	poison_line.width = 6
	poison_line.default_color = POISON_COLOR
	poison_line.add_point(start_pos)
	poison_line.add_point(end_pos)
	poison_line.name = "poison_effect"
	add_child(poison_line)
	
	# Create poison bubbles
	for i in range(3):
		var bubble = ColorRect.new()
		bubble.color = POISON_COLOR
		bubble.size = Vector2(20, 20)
		var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		bubble.position = end_pos + offset - Vector2(10, 10)
		bubble.name = "poison_effect"
		add_child(bubble)
		
		# Animate bubble floating up
		var bubble_tween = create_tween()
		bubble_tween.set_parallel(true)
		bubble_tween.tween_property(bubble, "position:y", bubble.position.y - 30, 1.0)
		bubble_tween.tween_property(bubble, "modulate:a", 0.0, 1.0)
		bubble_tween.tween_property(bubble, "scale", Vector2(0.5, 0.5), 1.0)
		bubble_tween.finished.connect(func(): bubble.queue_free())
	
	# Fade line
	var line_tween = create_tween()
	line_tween.tween_property(poison_line, "width", 12, 0.2)
	line_tween.tween_property(poison_line, "width", 3, 0.3)
	line_tween.tween_property(poison_line, "modulate:a", 0.0, 0.5).set_delay(0.5)
	line_tween.finished.connect(func(): poison_line.queue_free())

# ==== PUSH/PULL EFFECTS ====
func animate_push(caster: Node, target: Node, start_pos: Vector2i, end_pos: Vector2i):
	create_push_pull_effect(caster.position, target.position, PUSH_COLOR, "push")
	
	# Animate the push movement
	var start_world = tile_map.map_to_local(start_pos)
	var end_world = tile_map.map_to_local(end_pos)
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(target, "position", end_world, 0.4)
	tween.tween_property(target, "scale", Vector2(0.9, 0.9), 0.1)
	tween.tween_property(target, "scale", Vector2(1.0, 1.0), 0.1)
	
	tween.finished.connect(func(): effect_animation_finished.emit("push"))

func animate_pull(caster: Node, target: Node, start_pos: Vector2i, end_pos: Vector2i):
	create_push_pull_effect(caster.position, target.position, PULL_COLOR, "pull")
	
	# Animate the pull movement
	var start_world = tile_map.map_to_local(start_pos)
	var end_world = tile_map.map_to_local(end_pos)
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(target, "position", end_world, 0.4)
	tween.tween_property(target, "rotation", 0.1, 0.1)
	tween.tween_property(target, "rotation", -0.1, 0.1)
	tween.tween_property(target, "rotation", 0.0, 0.1)
	
	tween.finished.connect(func(): effect_animation_finished.emit("pull"))

func create_push_pull_effect(start_pos: Vector2, end_pos: Vector2, color: Color, effect_name: String):
	# Create line
	var line = Line2D.new()
	line.width = 6
	line.default_color = color
	line.add_point(start_pos)
	line.add_point(end_pos)
	line.name = effect_name + "_effect"
	add_child(line)
	
	# Create impact/swirl
	var impact = ColorRect.new()
	impact.color = color
	impact.size = Vector2(40, 40)
	impact.position = (start_pos if effect_name == "pull" else end_pos) - Vector2(20, 20)
	impact.name = effect_name + "_effect"
	add_child(impact)
	
	# Animate
	var effect_tween = create_tween()
	effect_tween.set_parallel(true)
	
	effect_tween.tween_property(line, "width", 12, 0.2)
	effect_tween.tween_property(line, "width", 3, 0.3)
	
	if effect_name == "pull":
		effect_tween.tween_property(impact, "rotation", TAU, 0.5)
	else:
		effect_tween.tween_property(impact, "scale", Vector2(1.5, 1.5), 0.3)
	
	effect_tween.tween_property(impact, "modulate:a", 0.0, 0.5)
	effect_tween.finished.connect(func(): clean_up_effects(effect_name + "_effect"))

# ==== UTILITY FUNCTIONS ====
func clean_up_effects(effect_name: String):
	for child in get_children():
		if child.name == effect_name:
			child.queue_free()

func clean_up_all_effects():
	for child in get_children():
		if child.name.ends_with("_effect") or child.name.ends_with("_trail"):
			child.queue_free()

# Signal callbacks
func _on_attack_animation_finished():
	attack_animation_finished.emit()

func _on_movement_animation_finished():
	movement_animation_finished.emit()

func _on_heal_animation_finished():
	heal_animation_finished.emit()

# ==== RANGE DISPLAY FUNCTIONS ====
func show_movement_range(center_pos: Vector2, range: int):
	# This would show movement tiles - simplified for example
	pass

func show_attack_range(center_pos: Vector2, range: int):
	# This would show attack range indicators
	pass

func show_heal_range(center_pos: Vector2, range: int):
	# This would show heal range with friendly highlights
	pass

func show_target_range(center_pos: Vector2, range: int):
	# Generic target range display
	pass

func clear_all_highlights():
	# Clear any range indicators
	pass

# ==== BURN EFFECTS ====
func animate_burn(caster: Node, target: Node):
	print("Starting burn animation")
	
	create_burn_effect(caster.position, target.position)
	
	# Animate caster
	var tween = create_tween()
	tween.tween_property(caster, "scale", Vector2(1.1, 1.1), 0.15)
	tween.tween_property(caster, "scale", Vector2(1.0, 1.0), 0.15)
	
	# Apply burn tint to target
	var original_modulate = target.modulate
	tween.tween_property(target, "modulate", Color(1, 0.5, 0.2, 1), 0.3)
	tween.tween_property(target, "modulate", original_modulate, 0.3)
	
	tween.finished.connect(func(): effect_animation_finished.emit("burn"))

func create_burn_effect(start_pos: Vector2, end_pos: Vector2):
	# Create burn line
	var burn_line = Line2D.new()
	burn_line.width = 8
	burn_line.default_color = BURN_COLOR
	burn_line.add_point(start_pos)
	burn_line.add_point(end_pos)
	burn_line.name = "burn_effect"
	add_child(burn_line)
	
	# Create fire particles
	for i in range(5):
		var particle = ColorRect.new()
		particle.color = BURN_COLOR
		particle.size = Vector2(15, 15)
		particle.position = end_pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		particle.name = "burn_effect"
		add_child(particle)
		
		# Animate particles upward like fire
		var particle_tween = create_tween()
		particle_tween.set_parallel(true)
		particle_tween.tween_property(particle, "position:y", particle.position.y - 30, 0.6)
		particle_tween.tween_property(particle, "scale", Vector2(0.5, 0.5), 0.6)
		particle_tween.tween_property(particle, "modulate", Color(1, 0.3, 0, 0), 0.6)
	
	# Clean up after animation
	await get_tree().create_timer(1.0).timeout
	for child in get_children():
		if child.name == "burn_effect":
			child.queue_free()

# ==== SHIELD EFFECTS ====
func animate_shield(caster: Node, target: Node):
	print("Starting shield animation")
	
	create_shield_effect(caster.position, target.position)
	
	# Animate caster
	var tween = create_tween()
	tween.tween_property(caster, "scale", Vector2(1.1, 1.1), 0.15)
	tween.tween_property(caster, "scale", Vector2(1.0, 1.0), 0.15)
	
	# Apply shield shimmer to target
	var original_modulate = target.modulate
	tween.tween_property(target, "modulate", Color(0.5, 0.8, 1, 1), 0.3)
	tween.tween_property(target, "modulate", original_modulate, 0.3)
	
	tween.finished.connect(func(): effect_animation_finished.emit("shield"))

func create_shield_effect(start_pos: Vector2, end_pos: Vector2):
	# Create shield line
	var shield_line = Line2D.new()
	shield_line.width = 8
	shield_line.default_color = SHIELD_COLOR
	shield_line.add_point(start_pos)
	shield_line.add_point(end_pos)
	shield_line.name = "shield_effect"
	add_child(shield_line)
	
	# Create shield bubble effect
	var shield_bubble = ColorRect.new()
	shield_bubble.color = Color(SHIELD_COLOR.r, SHIELD_COLOR.g, SHIELD_COLOR.b, 0.3)
	shield_bubble.size = Vector2(60, 60)
	shield_bubble.position = end_pos - Vector2(30, 30)
	shield_bubble.name = "shield_effect"
	add_child(shield_bubble)
	
	# Animate shield bubble
	var bubble_tween = create_tween()
	bubble_tween.set_parallel(true)
	bubble_tween.tween_property(shield_bubble, "scale", Vector2(1.3, 1.3), 0.5)
	bubble_tween.tween_property(shield_bubble, "modulate:a", 0.0, 0.5)
	
	# Create shield particles
	for i in range(4):
		var particle = ColorRect.new()
		particle.color = SHIELD_COLOR
		particle.size = Vector2(10, 10)
		var angle = i * TAU / 4.0
		particle.position = end_pos + Vector2(cos(angle), sin(angle)) * 25
		particle.name = "shield_effect"
		add_child(particle)
		
		# Animate particles rotating around target
		var particle_tween = create_tween()
		particle_tween.set_loops(2)
		particle_tween.tween_property(particle, "position", end_pos + Vector2(cos(angle + TAU), sin(angle + TAU)) * 25, 0.5)
		particle_tween.finished.connect(func(): particle.queue_free())
	
	# Clean up after animation
	await get_tree().create_timer(1.0).timeout
	for child in get_children():
		if child.name == "shield_effect":
			child.queue_free()
