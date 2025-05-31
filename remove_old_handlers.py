#!/usr/bin/env python3
"""
Remove old handler functions after implementing generic system
"""

import re

# Read the file
with open('tile_map_controller.gd', 'r') as f:
    lines = f.readlines()

# Old handler functions to remove (keeping only the content after 'return' in action_selected functions)
handlers_to_remove = [
    'handle_attack_action',
    'handle_push_action', 
    'handle_pull_action',
    'handle_heal_action',
    'handle_stun_action',
    'handle_poison_action',
    'show_attackable_area',
    'show_targetable_area_for_heal',
    'show_targetable_area_for_push',
    'show_targetable_area_for_pull',
    'show_targetable_area_for_stun',
    'show_targetable_area_for_poison',
]

# Build new file content
new_lines = []
skip_until = -1
i = 0

while i < len(lines):
    line = lines[i]
    
    # Check if we're at a function to remove
    remove = False
    for handler in handlers_to_remove:
        if f'func {handler}(' in line:
            # Find the next function
            indent_level = len(line) - len(line.lstrip())
            for j in range(i+1, len(lines)):
                # Check if we've reached another function at same or lower indent level
                next_line = lines[j]
                next_indent = len(next_line) - len(next_line.lstrip())
                if next_line.strip() and next_indent <= indent_level and ('func ' in next_line or next_line.strip().startswith('# ') or next_line.strip().startswith('var ')):
                    skip_until = j - 1
                    break
            else:
                # If we didn't find another function, skip to end
                skip_until = len(lines) - 1
            remove = True
            print(f"Removing {handler} from line {i+1} to {skip_until+1}")
            break
    
    if not remove:
        if i <= skip_until:
            i += 1
            continue
        new_lines.append(line)
    
    i += 1

# Write the result
with open('tile_map_controller.gd', 'w') as f:
    f.writelines(new_lines)

print(f"Original: {len(lines)} lines")
print(f"After removal: {len(new_lines)} lines")
print(f"Removed: {len(lines) - len(new_lines)} lines ({(len(lines) - len(new_lines))/len(lines)*100:.1f}%)")