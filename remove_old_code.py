#!/usr/bin/env python3
"""
Script to remove old code from tile_map_controller.gd after the optimization
"""

import re

# Read the file
with open('tile_map_controller.gd', 'r') as f:
    lines = f.readlines()

# Functions to clean up
functions_to_clean = [
    'attack_action_selected',
    'move_action_selected', 
    'heal_action_selected',
    'stun_action_selected',
    'poison_action_selected',
    'push_action_selected',
    'pull_action_selected'
]

# Track lines to keep
lines_to_keep = []
skip_mode = False
current_function = None

i = 0
while i < len(lines):
    line = lines[i]
    
    # Check if we're starting a function that needs cleaning
    for func_name in functions_to_clean:
        if f'func {func_name}(' in line:
            current_function = func_name
            # Keep this line and the next few until we hit return
            lines_to_keep.append(line)
            i += 1
            
            # Keep lines until we find return
            while i < len(lines):
                line = lines[i]
                lines_to_keep.append(line)
                if line.strip() == 'return':
                    skip_mode = True
                    i += 1
                    break
                i += 1
            continue
    
    # Check if we're at the start of a new function (to stop skipping)
    if skip_mode and line.strip().startswith('func '):
        skip_mode = False
        current_function = None
    
    # Only keep the line if we're not in skip mode
    if not skip_mode:
        lines_to_keep.append(line)
    
    i += 1

# Write the cleaned file
with open('tile_map_controller_cleaned.gd', 'w') as f:
    f.writelines(lines_to_keep)

# Count the reduction
original_lines = len(lines)
new_lines = len(lines_to_keep)
reduction = original_lines - new_lines

print(f"Original file: {original_lines} lines")
print(f"Cleaned file: {new_lines} lines")
print(f"Removed: {reduction} lines ({reduction/original_lines*100:.1f}% reduction)")
print(f"Saved to: tile_map_controller_cleaned.gd")