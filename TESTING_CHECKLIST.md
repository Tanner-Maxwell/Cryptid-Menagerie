# Testing Checklist for Optimized Actions

## All Actions Migrated ✓
All card actions now use the generic system. Test each one:

### 1. Attack ✓
- [x] Already tested and working
- [x] Enemy AI attacks also working

### 2. Heal
- [ ] Select a heal card
- [ ] Target a friendly cryptid
- [ ] Verify healing animation plays
- [ ] Verify health increases

### 3. Stun
- [ ] Select a stun card
- [ ] Target an enemy cryptid
- [ ] Verify stun effect is applied
- [ ] Verify stunned cryptid skips next turn

### 4. Poison
- [ ] Select a poison card
- [ ] Target an enemy cryptid
- [ ] Verify poison effect is applied
- [ ] Verify poison damage at turn end

### 5. Push
- [ ] Select a push card
- [ ] Target any cryptid
- [ ] Verify push preview shows
- [ ] Verify cryptid is pushed correct distance

### 6. Pull
- [ ] Select a pull card
- [ ] Target any cryptid
- [ ] Verify pull preview shows
- [ ] Verify cryptid is pulled correct distance

### 7. Move
- [ ] Select a move card
- [ ] Click on valid hex
- [ ] Verify movement path shows
- [ ] Verify cryptid moves along path

## After Testing
Once all actions work:
1. Remove the old code (everything after the `return` statements)
2. This will reduce the file by approximately 3,000 lines
3. Check line count: should go from 5,670+ to ~2,500 lines

## Quick Test Commands
If any action fails, you can instantly revert by removing the `return` statement in that action's function.

## Console Output
The system prints debug info:
- "Found [action] action - range: X amount: Y"
- "Handling action: [action]"
- Any errors will be clearly logged