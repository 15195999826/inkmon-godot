## InkMonBattle2DAnimationConfig - 动画配置（毫秒 / 速率，全 float）
##
## 平移自 hex frontend（见 docs/adr/0006）。dormant 字段（技能/攻击特效/投射物）保留，
## 待对应机制落地复用。
class_name InkMonBattle2DAnimationConfig
extends RefCounted


# ========== 移动 ==========
var move_duration: float = 500.0
var move_easing: InkMonBattle2DVisualAction.EasingType = InkMonBattle2DVisualAction.EasingType.EASE_IN_OUT_QUAD


# ========== 伤害 ==========
var damage_floating_text_duration: float = 1000.0
## 血条动画延迟（毫秒），等受击特效后再 apply hp delta
var damage_hp_bar_delay: float = 200.0
var damage_hit_vfx_duration: float = 300.0


# ========== 治疗 ==========
var heal_floating_text_duration: float = 1000.0


# ========== 血条插值（visual_hp 朝 target_hp 指数收敛，单位 1/秒） ==========
var hp_lerp_rate: float = 8.0


# ========== 死亡 ==========
var death_duration: float = 1000.0


# ========== 技能 / 攻击特效 / 投射物（dormant） ==========
var skill_basic_attack_duration: float = 1000.0
var skill_basic_attack_hit_frame: float = 500.0
var attack_vfx_duration: float = 300.0
var projectile_size: float = 0.15
var projectile_hit_vfx_duration: float = 200.0
var projectile_default_speed: float = 20.0


# ========== 工厂方法 ==========

static func create_default() -> InkMonBattle2DAnimationConfig:
	return InkMonBattle2DAnimationConfig.new()


static func from_dict(data: Dictionary) -> InkMonBattle2DAnimationConfig:
	var config := InkMonBattle2DAnimationConfig.new()
	if data.has("move"):
		var move_data: Dictionary = data["move"]
		config.move_duration = move_data.get("duration", config.move_duration) as float
	if data.has("damage"):
		var damage_data: Dictionary = data["damage"]
		config.damage_floating_text_duration = damage_data.get("floatingTextDuration", config.damage_floating_text_duration) as float
		config.damage_hp_bar_delay = damage_data.get("hpBarDelay", config.damage_hp_bar_delay) as float
		config.damage_hit_vfx_duration = damage_data.get("hitVfxDuration", config.damage_hit_vfx_duration) as float
	if data.has("heal"):
		var heal_data: Dictionary = data["heal"]
		config.heal_floating_text_duration = heal_data.get("floatingTextDuration", config.heal_floating_text_duration) as float
	if data.has("hp_lerp_rate"):
		config.hp_lerp_rate = data.get("hp_lerp_rate", config.hp_lerp_rate) as float
	if data.has("death"):
		var death_data: Dictionary = data["death"]
		config.death_duration = death_data.get("duration", config.death_duration) as float
	return config
