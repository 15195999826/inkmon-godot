class_name InkMonElementChart


const LIGHT := "light"
const DARK := "dark"
const FIRE := "fire"
const WATER := "water"
const WIND := "wind"
const EARTH := "earth"

const ADVANTAGE_MULT := 1.3
const DISADVANTAGE_MULT := 0.7
const NEUTRAL_MULT := 1.0

const _ADVANTAGE := {
	WIND: EARTH,
	EARTH: WATER,
	WATER: FIRE,
	FIRE: WIND,
	LIGHT: DARK,
	DARK: LIGHT,
}


static func damage_multiplier(attacker_element: String, defender_primary: String) -> float:
	if attacker_element == "" or defender_primary == "":
		return NEUTRAL_MULT
	if _ADVANTAGE.get(attacker_element, "") == defender_primary:
		return ADVANTAGE_MULT
	if _ADVANTAGE.get(defender_primary, "") == attacker_element:
		return DISADVANTAGE_MULT
	return NEUTRAL_MULT


static func all_elements() -> Array[String]:
	return [LIGHT, DARK, FIRE, WATER, WIND, EARTH]
