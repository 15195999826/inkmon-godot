extends Resource
class_name LGFExampleAttributesConfig

const SETS := {
	"ExampleHero": {
		"max_hp": { "baseValue": 120.0 },
		"attack": { "baseValue": 12.0 },
	},
	"ExampleTower": {
		"max_hp": { "baseValue": 350.0 },
		"range": { "baseValue": 6.0 },
	},
	# HexBattle 角色属性集
	"HexBattleCharacter": {
		"hp": { "baseValue": 100.0, "minValue": 0.0 },
		"max_hp": { "baseValue": 100.0, "minValue": 1.0 },
		"atk": { "baseValue": 50.0 },
		"def": { "baseValue": 30.0 },
		"speed": { "baseValue": 100.0 },
	},
}
