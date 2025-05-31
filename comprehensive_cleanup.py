#!/usr/bin/env python3
"""
Comprehensive cleanup of tile_map_controller.gd
"""

import re

# Read the file
with open('tile_map_controller_cleaned.gd', 'r') as f:
    content = f.read()
    lines = content.splitlines()

# Remove specific lines
lines_to_remove = [
    50,   # cur_position_cube
    49,   # current_atlas_coords  
    54,   # attack_path global
]

# Remove lines (working backwards to maintain line numbers)
for line_num in sorted(lines_to_remove, reverse=True):
    if line_num <= len(lines):
        lines.pop(line_num - 1)

# Join back to content
content = '\n'.join(lines)

# Remove the cur_position_cube assignment in _ready
content = re.sub(r'\s*cur_position_cube = axial_to_cube\(local_to_map\(player_pos\)\)\n', '', content)

# Remove handle_movement_card_usage function completely
# Find the function start and end
func_start = content.find('func handle_movement_card_usage(')
if func_start != -1:
    # Find the next function after it
    next_func = content.find('\nfunc ', func_start + 1)
    if next_func != -1:
        # Remove from start of this function to start of next function
        content = content[:func_start] + content[next_func+1:]

# Remove handle_card_action function if it only handles movement
handle_card_pattern = r'func handle_card_action\(pos_clicked\):[^}]+?handle_move_action\(pos_clicked\)\n'
content = re.sub(handle_card_pattern, '', content)

# Update the line that calls handle_card_action to call handle_move_action directly
content = re.sub(
    r'handle_card_action\(pos_clicked\)',
    'handle_move_action(pos_clicked)',
    content
)

# Remove unused helper functions that are never called
# First check if these functions are actually used
unused_patterns = [
    (r'cleanup_after_action', r'func cleanup_after_action\(\):[^}]+?\n(?=func|\Z)'),
    (r'reset_action_state', r'func reset_action_state\(\):[^}]+?\n(?=func|\Z)'),
]

for func_name, pattern in unused_patterns:
    # Check if function is called anywhere (excluding its definition)
    calls = re.findall(func_name + r'\s*\(', content)
    definitions = re.findall(r'func\s+' + func_name, content)
    
    if len(calls) <= len(definitions):  # Only found in definition, not called
        content = re.sub(pattern, '', content, flags=re.DOTALL)

# Clean up any multiple blank lines
content = re.sub(r'\n\n\n+', '\n\n', content)

# Write the cleaned file
with open('tile_map_controller_final.gd', 'w') as f:
    f.write(content)

# Count the reduction
original_lines = 6035
new_lines = len(content.splitlines())
reduction = original_lines - new_lines

print(f"Original file: {original_lines} lines")
print(f"Final cleaned file: {new_lines} lines")
print(f"Total removed: {reduction} lines ({reduction/original_lines*100:.1f}% reduction)")
print(f"Saved to: tile_map_controller_final.gd")