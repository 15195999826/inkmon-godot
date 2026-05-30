extends Resource
class_name AttributesConfig

const SETS := {
	"Hero": {
		"max_hp": { "baseValue": 100.0 },
		"attack": { "baseValue": 10.0 },
	},
	"Tower": {
		"max_hp": { "baseValue": 300.0 },
		"range": { "baseValue": 5.0 },
	},
	"InkMonUnit": {
		"hp": { "baseValue": 100.0, "minValue": 0.0, "maxRef": "max_hp" },
		"max_hp": { "baseValue": 100.0, "minValue": 1.0 },
		"ad": { "baseValue": 35.0, "minValue": 0.0 },
		"ap": { "baseValue": 35.0, "minValue": 0.0 },
		"armor": { "baseValue": 20.0, "minValue": 0.0 },
		"mr": { "baseValue": 20.0, "minValue": 0.0 },
		"speed": { "baseValue": 100.0, "minValue": 0.0 },
	},
}
