#!/usr/bin/env python3
"""
Clean up action_selected functions to only keep the wrapper part
"""

import re

# Read the file
with open('tile_map_controller.gd', 'r') as f:
    lines = f.readlines()

# Action functions to clean up (they should only call card_action_selected)
action_functions = [
    'attack_action_selected',
    'push_action_selected',
    'pull_action_selected', 
    'heal_action_selected',
    'stun_action_selected',
    'poison_action_selected',
]

# Build new file content
new_lines = []
i = 0

while i < len(lines):
    line = lines[i]
    
    # Check if we're at an action_selected function to clean
    clean = False
    for func_name in action_functions:
        if f'func {func_name}(' in line:
            # Keep the function definition and the next 3 lines (comment, call, return)
            new_lines.append(line)  # func line
            if i+1 < len(lines) and '# Use the new generic system' in lines[i+1]:
                new_lines.append(lines[i+1])  # comment
                if i+2 < len(lines) and 'card_action_selected(' in lines[i+2]:
                    new_lines.append(lines[i+2])  # call
                    if i+3 < len(lines) and 'return' in lines[i+3]:
                        new_lines.append(lines[i+3])  # return
                        
                        # Skip everything else until the next function
                        indent_level = len(line) - len(line.lstrip())
                        j = i + 4
                        while j < len(lines):
                            next_line = lines[j]
                            next_indent = len(next_line) - len(next_line.lstrip())
                            # Stop at next function or top-level code
                            if next_line.strip() and next_indent <= indent_level and ('func ' in next_line or next_line.strip().startswith('var ') or next_line.strip().startswith('# ') and next_indent == 0):
                                i = j - 1
                                break
                            j += 1
                        else:
                            i = len(lines) - 1
                        clean = True
                        break
    
    if not clean:
        new_lines.append(line)
    
    i += 1

# Write the result
with open('tile_map_controller.gd', 'w') as f:
    f.writelines(new_lines)

print(f"Original: {len(lines)} lines")
print(f"After cleanup: {len(new_lines)} lines")
print(f"Removed: {len(lines) - len(new_lines)} lines ({(len(lines) - len(new_lines))/len(lines)*100:.1f}%)")