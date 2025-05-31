#!/usr/bin/env python3
"""
Full cleanup to achieve 50% reduction as promised in the optimization guide
"""

import re

# Read the backup file to start fresh
with open('tile_map_controller_backup.gd', 'r') as f:
    lines = f.readlines()

# Find all the action functions and their line ranges
action_functions = {
    'attack_action_selected': {'start': None, 'keep_until': None},
    'move_action_selected': {'start': None, 'keep_until': None},
    'heal_action_selected': {'start': None, 'keep_until': None},
    'stun_action_selected': {'start': None, 'keep_until': None},
    'poison_action_selected': {'start': None, 'keep_until': None},
    'push_action_selected': {'start': None, 'keep_until': None},
    'pull_action_selected': {'start': None, 'keep_until': None},
}

# Also remove the old handler functions completely
handler_functions = [
    'handle_attack_action',
    'handle_heal_action',
    'handle_stun_action',
    'handle_poison_action',
    'handle_push_action',
    'handle_pull_action',
    'handle_movement_card_usage',
    'show_attackable_area',
]

# Find line numbers
for i, line in enumerate(lines):
    # Find action_selected functions
    for func_name in action_functions:
        if f'func {func_name}(' in line:
            action_functions[func_name]['start'] = i
            # Find the return statement
            for j in range(i, min(i+20, len(lines))):
                if lines[j].strip() == 'return':
                    action_functions[func_name]['keep_until'] = j
                    break

# Build new file content
new_lines = []
skip_until = -1
i = 0

while i < len(lines):
    line = lines[i]
    
    # Check if we're at a function to truncate
    truncate = False
    for func_name, info in action_functions.items():
        if info['start'] == i and info['keep_until']:
            # Keep from start to return
            new_lines.extend(lines[i:info['keep_until']+1])
            # Find next function
            for j in range(info['keep_until']+1, len(lines)):
                if lines[j].strip().startswith('func '):
                    skip_until = j - 1
                    break
            i = info['keep_until']
            truncate = True
            break
    
    # Check if we're at an old handler function to remove completely
    remove = False
    for handler in handler_functions:
        if f'func {handler}(' in line:
            # Find the next function
            for j in range(i+1, len(lines)):
                if lines[j].strip().startswith('func '):
                    skip_until = j - 1
                    break
            remove = True
            break
    
    if not truncate and not remove:
        if i <= skip_until:
            i += 1
            continue
        new_lines.append(line)
    
    i += 1

# Write the result
with open('tile_map_controller.gd', 'w') as f:
    f.writelines(new_lines)

print(f"Original: {len(lines)} lines")
print(f"Cleaned: {len(new_lines)} lines")
print(f"Removed: {len(lines) - len(new_lines)} lines ({(len(lines) - len(new_lines))/len(lines)*100:.1f}%)")