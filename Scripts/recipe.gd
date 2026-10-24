class_name Recipe
# The one recipe every customer orders: an ordered list of steps. Each step is
#   type:        which step UI runs once the items are on the placemat
#   instruction: shown at the bottom of the screen while the player gathers the items
#   required:    names of the nodes under Ingredients that must be on the placemat
#   params:      step-specific settings (read by the step UI)
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
	},
]
