#!/usr/bin/env python3
"""
Find and remove duplicate functions and large blocks of redundant code
"""

import re

# Read the file
with open('tile_map_controller.gd', 'r') as f:
    lines = f.readlines()

# Find all function definitions and their line numbers
functions = {}
for i, line in enumerate(lines):
    match = re.match(r'^func\s+(\w+)\s*\(', line)
    if match:
        func_name = match.group(1)
        if func_name not in functions:
            functions[func_name] = []
        functions[func_name].append(i)

# Print duplicate functions
print("Duplicate functions found:")
for func_name, occurrences in functions.items():
    if len(occurrences) > 1:
        print(f"  {func_name}: lines {[o+1 for o in occurrences]}")

# Look for large blocks of similar code
print("\nLarge functions (>50 lines):")
for func_name, occurrences in functions.items():
    for start_line in occurrences:
        # Find end of function
        indent_level = len(lines[start_line]) - len(lines[start_line].lstrip())
        end_line = start_line + 1
        while end_line < len(lines):
            line = lines[end_line]
            if line.strip() and (len(line) - len(line.lstrip())) <= indent_level and ('func ' in line or line.strip().startswith('var ')):
                break
            end_line += 1
        
        func_length = end_line - start_line
        if func_length > 50:
            print(f"  {func_name}: {func_length} lines (starts at {start_line+1})")

# Look for show_targetable_area variants
print("\nshow_targetable_area variants:")
for func_name in functions:
    if 'show_targetable_area' in func_name:
        print(f"  {func_name}")

# Count total lines by category
movement_lines = 0
pathfinding_lines = 0
visual_lines = 0
for i, line in enumerate(lines):
    if 'path' in line.lower() or 'a_star' in line or 'hex_grid' in line:
        pathfinding_lines += 1
    elif 'animate' in line or 'visual' in line or 'effect' in line or 'tween' in line:
        visual_lines += 1
    elif 'move' in line and 'movement' in line:
        movement_lines += 1

print(f"\nApproximate line counts by category:")
print(f"  Pathfinding related: ~{pathfinding_lines} lines")
print(f"  Visual effects: ~{visual_lines} lines") 
print(f"  Movement related: ~{movement_lines} lines")