extends RefCounted
class_name StandardAttributes

const HP := "hp"
const MAX_HP := "maxHp"
const MP := "mp"
const MAX_MP := "maxMp"
const ATK := "atk"
const DEF := "def"
const SP_ATK := "spAtk"
const SP_DEF := "spDef"
const SPEED := "speed"
const CRIT_RATE := "critRate"
const CRIT_DAMAGE := "critDamage"
const HIT_RATE := "hitRate"
const DODGE_RATE := "dodgeRate"
const PHYSICAL_RES := "physicalRes"
const MAGICAL_RES := "magicalRes"
const HP_REGEN := "hpRegen"
const MP_REGEN := "mpRegen"
const LIFESTEAL := "lifesteal"
const DAMAGE_REDUCTION := "damageReduction"

const BASIC_UNIT_ATTRIBUTE_TEMPLATES := [
	{ "name": HP, "baseValue": 100.0, "minValue": 0.0 },
	{ "name": MAX_HP, "baseValue": 100.0, "minValue": 1.0 },
	{ "name": ATK, "baseValue": 10.0, "minValue": 0.0 },
	{ "name": DEF, "baseValue": 5.0, "minValue": 0.0 },
	{ "name": SPEED, "baseValue": 100.0, "minValue": 0.0 },
]

static var FULL_UNIT_ATTRIBUTE_TEMPLATES: Array = BASIC_UNIT_ATTRIBUTE_TEMPLATES + [
	{ "name": MP, "baseValue": 50.0, "minValue": 0.0 },
	{ "name": MAX_MP, "baseValue": 50.0, "minValue": 0.0 },
	{ "name": SP_ATK, "baseValue": 10.0, "minValue": 0.0 },
	{ "name": SP_DEF, "baseValue": 5.0, "minValue": 0.0 },
	{ "name": CRIT_RATE, "baseValue": 0.05, "minValue": 0.0, "maxValue": 1.0 },
	{ "name": CRIT_DAMAGE, "baseValue": 1.5, "minValue": 1.0 },
	{ "name": HIT_RATE, "baseValue": 1.0, "minValue": 0.0, "maxValue": 2.0 },
	{ "name": DODGE_RATE, "baseValue": 0.0, "minValue": 0.0, "maxValue": 1.0 },
]
