extends Resource
class_name BiomeCryptids

# Define which cryptids belong to each biome
@export var biome_name: String = "Forest"
@export var cryptids: Array[Resource] = []
@export var encounter_weights: Array[int] = [60, 30, 10]  # Weights for 1, 2, or 3 cryptids

# You can create instances of this resource for each biome
# Then load them in the WildEncounterManager

# Sample usage:
# var forest_biome = load("res://biomes/forest_biome.tres")
# var volcano_biome = load("res://biomes/volcano_biome.tres")
# var beach_biome = load("res://biomes/beach_biome.tres")
#
# Then access like: forest_biome.cryptids
