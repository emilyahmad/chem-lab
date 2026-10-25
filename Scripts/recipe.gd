class_name Recipe
# The one recipe every customer orders: an ordered list of steps. Each step is
#   type:        which step UI runs once the items are on the placemat
#   instruction: shown at the bottom of the screen while the player gathers the items
#   required:    names of the nodes under Ingredients that must be on the placemat
#   params:      step-specific settings (read by the step UI)
#   renames:     (optional) item name -> what the item is called once the step is done
# Placed items the next step doesn't require go back to the counter.

const STEPS := [
	{
		"type": "pour",
		"instruction": "Grab an empty beaker and the beaker of Reagent B-7, and put them on the placemat",
		"required": ["Beaker", "ReagentB7"],
		"params": {
			"ui_text": "Fill the empty beaker with 150 mL of Reagent B-7",
			"source": "ReagentB7", "target": "Beaker",
			"target_ml": 150.0, "tolerance_ml": 5.0, "capacity_ml": 250.0, "flow_ml_s": 25.0,
		},
		"renames": {"Beaker": "used beaker"},
	},
	{
		"type": "crush",
		"instruction": "Grab the bowl, the Compound K beaker and the mixer, and put them on the placemat",
		"required": ["Bowl", "CompoundK", "Mixer"],
		"params": {
			"ui_text": "Crush the Compound K in the bowl",
			"source": "CompoundK", "bowl": "Bowl", "tool": "Mixer",
			"taps_to_full": 30.0, "min_finish": 0.6,
		},
	},
	{
		"type": "combine",
		"instruction": "Put the flask, the beaker of B-7, the bowl of crushed Compound K and the Catalyst Azure on the placemat",
		"required": ["Erlenmeyer", "Beaker", "Bowl", "CatalystAzure"],
		"params": {
			"ui_text": "Combine everything in the flask and swirl",
			"flask": "Erlenmeyer", "liquid": "Beaker", "powder": "Bowl", "catalyst": "CatalystAzure",
			"swirl_seconds": 5.0,
		},
	},
	{
		"type": "heat",
		"instruction": "Put the flask and the Bunsen burner on the placemat",
		"required": ["Erlenmeyer", "Burner"],
		"params": {
			"ui_text": "Heat the flask. Keep the temperature in the green",
			"flask": "Erlenmeyer", "burner": "Burner",
			"ambient": 20.0, "max_temp": 120.0, "green_from": 70.0, "green_to": 90.0, "boil_temp": 105.0,
			"hold_seconds": 4.0, "heat_rate": 22.0, "cool_rate": 12.0,
		},
	},
	{
		"type": "drop",
		"instruction": "Put the flask, the syringe and the Quench solution on the placemat",
		"required": ["Erlenmeyer", "Syringe", "QuenchSolution"],
		"params": {
			"ui_text": "Add Quench solution drop by drop until the color matches",
			"flask": "Erlenmeyer", "syringe": "Syringe", "quench": "QuenchSolution",
			"drops_min": 10, "drops_max": 14, "max_drops": 24,
		},
	},
	{
		"type": "crystallize",
		"instruction": "Put the flask and the petri dish on the placemat",
		"required": ["Erlenmeyer", "PetriDish"],
		"params": {
			"ui_text": "Let the crystals grow, then harvest them at the right moment",
			"flask": "Erlenmeyer", "dish": "PetriDish",
			"grow_seconds": 14.0, "safe_until": 0.7,
		},
	},
]
