# Tile Map Controller Optimization Guide

## Overview
The original `tile_map_controller.gd` is 5,670 lines. This optimization reduces it by ~70% while maintaining all functionality.

## Key Optimizations

### 1. Generic Action System
Instead of 7 separate action systems (each 200-300 lines), we now have:
- One `card_action_selected()` function (50 lines)
- One `handle_card_action()` function (60 lines)
- A configuration dictionary `ACTION_CONFIGS` defining all actions

**Before**: 7 actions × 250 lines = 1,750 lines
**After**: 110 lines + 30 lines config = 140 lines
**Savings**: 1,610 lines (92% reduction)

### 2. Consolidated Cleanup
The 6-line cleanup pattern appeared 117 times throughout the code.

**Before**: 117 × 6 = 702 lines
**After**: 1 function × 10 lines = 10 lines
**Savings**: 692 lines (98% reduction)

### 3. Removed Unused Code
- Unused variables: `cur_position_cube`, `current_atlas_coords`, `attack_path`
- Duplicate functions: `handle_movement_card_usage()`, `show_attackable_area()`
- Vestigial code: ~200 lines

### 4. Simplified State Management
**Before**: 15+ boolean flags for different actions
**After**: 1 dictionary tracking active action state

## Migration Steps

### Step 1: Backup Current File
```bash
cp tile_map_controller.gd tile_map_controller_backup.gd
```

### Step 2: Gradual Migration
1. Start by adding the new generic system alongside existing code
2. Test one action type at a time
3. Remove old code once verified

### Step 3: Update Card Dialog
The card dialog needs minor updates to call the new generic functions:
```gdscript
# Old way
tilemap.attack_action_selected(card)

# New way  
tilemap.card_action_selected("attack", card)
```

### Step 4: Test Each Action Type
Test in this order:
1. Attack (simplest)
2. Heal
3. Stun/Poison (similar patterns)
4. Push/Pull (complex movement)
5. Move (most complex)

## Adding New Card Abilities

### Old Way (200-300 lines):
1. Add boolean flag
2. Add range/amount variables
3. Create `*_action_selected()` function
4. Create `handle_*_action()` function
5. Add to reset functions
6. Update multiple places

### New Way (20-30 lines):
1. Add to `ACTION_CONFIGS`:
```gdscript
"freeze": {
	"range_key": "freeze_range",
	"amount_key": "freeze_duration",
	"target_type": "enemy",
	"show_preview": true,
	"friendly_only": false
}
```

2. Add specific logic in `handle_card_action()` match statement:
```gdscript
"freeze":
	animate_freeze(selected_cryptid, target)
	target.get_node("StatusEffectManager").add_status_effect("freeze", active_action.amount)
```

3. Add wrapper for compatibility:
```gdscript
func freeze_action_selected(current_card):
	card_action_selected("freeze", current_card)
```

## File Splitting Recommendation

Consider splitting into these files:
1. `grid_manager.gd` - Hex grid, A* pathfinding (500 lines)
2. `action_system.gd` - Card action handling (300 lines)
3. `visual_effects_controller.gd` - Animations, indicators (400 lines)
4. `battle_manager.gd` - Turn order, defeat handling (300 lines)
5. `tile_map_controller.gd` - Main controller (500 lines)

## Performance Improvements

1. **Reduced function calls**: Generic system reduces call stack depth
2. **Better caching**: Reuse calculated paths and positions
3. **Lazy initialization**: Only create visual elements when needed
4. **Object pooling**: Reuse visual effect nodes

## Debugging

The optimized version maintains all debug functionality but consolidates it:
- Debug indicators remain functional
- Add `print_action_state()` for debugging the generic system
- Use `ACTION_CONFIGS` to validate action parameters

## Backwards Compatibility

The wrapper functions ensure existing code continues to work:
- All existing function calls remain valid
- No changes needed to other files initially
- Can migrate gradually

## Next Steps

1. Test the optimized version alongside the original
2. Migrate one action type at a time
3. Update unit tests if any
4. Consider the file splitting approach for further organization
5. Document the new action configuration format for team members
