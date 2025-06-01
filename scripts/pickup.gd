extends Resource
class_name Pickup

enum PickupType {
	FIRE_TRAP,           # Applies 1 stack of burn
	HEAL_ORB,            # Heals for 3 health
	IMMOBILIZE_TRAP,     # Applies 1 stack of immobilize
	DAMAGE_TRAP,         # Deals 2 damage (persistent)
	MOVEMENT_BOOST,      # +1 move distance
	SHIELD_ORB,          # +1 stack of shield
	POISON_CLOUD,        # Applies 2 stacks of poison
	WALL,                # Blocks movement, has 5 health
	STUN_TRAP            # Applies stun effect
}

@export var pickup_type: PickupType = PickupType.FIRE_TRAP
@export var name: String = "Pickup"
@export var description: String = ""
@export var icon: Texture2D = preload("res://Cryptid-Menagerie/assets/icon.svg")  # Default icon that can be changed in inspector
@export var is_persistent: bool = false  # If true, doesn't disappear when triggered
@export var health: int = 0  # For destructible pickups like walls
@export var max_health: int = 0

# Visual properties
@export var icon_color: Color = Color.WHITE
@export var icon_scale: float = 1.0  # 1.0 = 24x24 pixels

func _init():
	# Set default properties based on pickup type
	match pickup_type:
		PickupType.FIRE_TRAP:
			name = "Fire Trap"
			description = "Applies 1 stack of burn"
			icon_color = Color.ORANGE_RED
		PickupType.HEAL_ORB:
			name = "Heal Orb"
			description = "Heals for 3 health"
			icon_color = Color.GREEN
		PickupType.IMMOBILIZE_TRAP:
			name = "Immobilize Trap"
			description = "Applies 1 stack of immobilize"
			icon_color = Color.DARK_GRAY
		PickupType.DAMAGE_TRAP:
			name = "Damage Trap"
			description = "Deals 2 damage"
			icon_color = Color.RED
			is_persistent = true
		PickupType.MOVEMENT_BOOST:
			name = "Movement Boost"
			description = "+1 move distance"
			icon_color = Color.CYAN
		PickupType.SHIELD_ORB:
			name = "Shield Orb"
			description = "+1 stack of shield"
			icon_color = Color.LIGHT_BLUE
		PickupType.POISON_CLOUD:
			name = "Poison Cloud"
			description = "Applies 2 stacks of poison"
			icon_color = Color.PURPLE
		PickupType.WALL:
			name = "Wall"
			description = "Blocks movement (5 HP)"
			icon_color = Color.BROWN
			is_persistent = true
			health = 5
			max_health = 5
		PickupType.STUN_TRAP:
			name = "Stun Trap"
			description = "Applies stun effect"
			icon_color = Color.YELLOW

func trigger(cryptid: Node) -> void:
	# Apply the pickup effect to the cryptid
	var status_manager = cryptid.get_node_or_null("StatusEffectManager")
	if not status_manager:
		print("Warning: Cryptid has no StatusEffectManager")
		return
		
	match pickup_type:
		PickupType.FIRE_TRAP:
			status_manager.add_status_effect(StatusEffect.EffectType.BURN, 1)
		PickupType.HEAL_ORB:
			if cryptid.has_method("heal"):
				cryptid.heal(3)
		PickupType.IMMOBILIZE_TRAP:
			status_manager.add_status_effect(StatusEffect.EffectType.IMMOBILIZE, 1)
		PickupType.DAMAGE_TRAP:
			if cryptid.has_method("take_damage"):
				cryptid.take_damage(2)
		PickupType.MOVEMENT_BOOST:
			# Add temporary movement bonus - this needs to be handled by the tile_map_controller
			# For now, just print a message
			print("Movement boost pickup triggered - TODO: implement movement bonus")
		PickupType.SHIELD_ORB:
			status_manager.add_status_effect(StatusEffect.EffectType.SHIELDED, 1)
		PickupType.POISON_CLOUD:
			status_manager.add_status_effect(StatusEffect.EffectType.POISON, 2)
		PickupType.STUN_TRAP:
			status_manager.add_status_effect(StatusEffect.EffectType.STUN, 1)
		PickupType.WALL:
			# Walls don't trigger effects, they block movement
			pass

func take_damage(damage: int) -> bool:
	# For destructible pickups like walls
	if max_health > 0:
		health -= damage
		return health <= 0  # Return true if destroyed
	return false

func blocks_movement() -> bool:
	# Walls block movement
	return pickup_type == PickupType.WALL and health > 0

func should_remove_on_trigger() -> bool:
	# Return true if pickup should be removed after triggering
	return not is_persistent and pickup_type != PickupType.WALL
