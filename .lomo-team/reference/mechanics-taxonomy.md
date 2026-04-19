# 跨游戏机制分类表 (Mechanics Taxonomy)

> 基于：Into the Breach (ItB) / Slay the Spire (StS) / TFT
> 用途：为 inkmon（hex ATB 自走棋）技能池设计提供机制索引
> 日期：2026-04-18

---

## 目录

1. 空间类 (Spatial — hex grid / 位置核心)
2. 形状 / 范围 (AoE Shapes)
3. 伤害结算类 (Damage Modifiers)
4. 持续伤害 / 状态伤害 (DoT / Status damage)
5. 防御类 (Defense)
6. 增益 (Buff — 自身 / 队友)
7. 减益 (Debuff — 敌方)
8. 硬控 / 软控 (Control)
9. 触发 / 反应 (Triggers / Reactions)
10. 召唤 / 尸体 / 复活 (Summon / Corpse / Revive)
11. 资源 / 能量 / 蓄力 (Resources / Scaling)
12. 变身 / 模式切换 (Transformation / Stance)
13. 地形 / 场地操纵 (Terrain / Field)
14. 元素 / 属性 (Elements)
15. 经济 / 超战斗层 (Meta — 跨战斗)
16. 独特机制 (单游戏独有)

---

## 1. 🎯 空间类 (Spatial — hex grid / 位置核心)

### 1.1 位移-推 (Push / Knockback)

**机制定义**：攻击把目标朝某方向推动 N 格；撞到堵塞 → 碰撞伤害 / 推入地形 → 环境处决。

**游戏例子**:
- **Into the Breach**:
  - *Titan Fist*（Combat Mech）：近战 2 伤 + 推 1 格
  - *Rock Accelerator*（Boulder Mech）：直线石头 2 伤 + 沿直线再推 1 格
  - *Repulse*（Pulse Mech）：四邻同时推 1，无伤
  - *Titanite Blade*：推 3 格（单次使用高伤剑）
  - *Mercury Fist*：砸地 4 伤 + 推所有相邻
  - *Wind Torrent*：把一整行/列沿固定方向推
- **TFT**:
  - *Sion - Decimating Smash*：AoE 击飞 + 晕眩（2.5/3/6s）
  - *Nautilus - Titan's Wrath*（历代）：击飞前排
  - *Pyke - Marked for Death*（Set 17）：先拉钩再瞬移身后
- **Slay the Spire**: ❌（StS 无位置概念）

**设计变体 / 参数轴**:
- 距离：1 格 / N 格 / 推到撞物
- 方向：攻击方向 / 指定方向 / 四邻同时 / 反方向（ItB Unstable Cannon 反推自身）
- 碰撞效果：无 / 1 点碰撞伤害 (ItB) / 额外状态（击晕）
- 附带击飞时长（TFT 侧，ItB 无）
- 自伤：是否自己也被反推（ItB *Unstable Cannon*、*Bouncer Vek*）

**hex 适配建议**：hex 6 方向比方格 4 方向更自然；推轨迹可做锥形、贴边反射。

---

### 1.2 位移-拉 (Pull / Grapple)

**机制定义**：把目标朝施法者方向拉 N 格；部分武器可反拉自己。

**游戏例子**:
- **Into the Breach**:
  - *Grappling Hook*（Hook Mech）：直线无限距离，拉目标到身边或拉自己去墙
  - *Gravity Well*（Gravity Mech）：远程把格内单位向 Gravity Mech 方向拉 1 格，无伤
  - *Attraction Pulse*：直线拉 1 格
  - *Gastropod Vek*：无限距离拉钩；若目标 stable 则拉自己
- **TFT**:
  - *Pyke - Marked for Death*（Set 17）：鱼叉拉过来+瞬移身后
  - *Blitzcrank - Party Crasher*（Set 17）：经典钩子（历代）
- **Slay the Spire**: ❌

**设计变体 / 参数轴**:
- 距离：1 格 / 拉到身边 / 拉到中点
- Fallback：目标 stable 时拉自己 (ItB 风格)
- 是否带伤害：Hook 无伤 / Pyke 有伤
- 是否带后续（瞬移身后）

---

### 1.3 位移-瞬移 / 交换 (Teleport / Swap)

**机制定义**：瞬间改变单位坐标；互换两者位置。

**游戏例子**:
- **Into the Breach**:
  - *Teleporter*（Swap Mech）：Swap Mech 与目标互换
  - *Exchange Shot*（Exchange Mech, AE）：远程把任意两格单位互换
  - *Tele-Shot*：远程传送门
  - Burrower Vek：可钻地瞬移
- **TFT**:
  - *Pyke* Set 17：瞬移到目标身后
  - *Zed - Quantum Clone*（Set 17）：身后创建克隆（不是瞬移但涉及坐标生成）
  - *Yasuo - Last Breath*：跃至最远敌人
- **Slay the Spire**: ❌（位置无意义；*Exhume* 从 exhaust pile 取回卡算"卡牌空间"的瞬移变体）

**设计变体 / 参数轴**:
- 范围：相邻 / 任意格 / 最远敌 / 最低血敌
- 目标：自身 / 单目标 / 双向交换 / 区域整体
- 结果：仅换位 / 伴随打击 / 伴随隐身

---

### 1.4 位移-跳跃 / 冲锋 (Leap / Dash / Charge)

**机制定义**：沿路径快速位移并结算伤害，通常穿越路径而不停留。

**游戏例子**:
- **Into the Breach**:
  - *Hydraulic Legs*（Leap Mech）：跳 4 格内空格，四邻 1 伤 + 自伤 1
  - *Ramming Engines*（Charge Mech）：冲刺撞击 2 伤 + 撞墙自伤
  - *Dash Punch*（Titan Fist upgrade）：冲刺任意距离再击打
  - *Reverse Thrusters*（Thruster Mech）：冲刺离开、留 smoke
- **TFT**:
  - *Yasuo - Steel Tempest*：跃至最远敌人
  - *Talon - Diviner's Judgment*（Set 17）：跃至附近最高血敌
  - *Gwen - Dance n' Dice*：突进最低血敌
  - *Fizz - Meep Bait*：突进穿过目标
- **Slay the Spire**: ❌

**设计变体 / 参数轴**:
- 目标选择：最远 / 最近 / 最低血 / 最高血 / 指定格
- 路径结算：起点/终点伤害 / 沿途 AoE / 穿越伤害
- 自伤：Leap Mech 自伤 1 / Charge 撞墙自伤
- 是否需要空格落点

---

### 1.5 位移-抓取投掷 (Grab & Throw)

**机制定义**：抓起相邻单位后甩到另一格（身后 / 前方 / 任意）。

**游戏例子**:
- **Into the Breach**:
  - *Vice Fist*（Judo Mech）：抓相邻目标甩到身后 + 1 伤
  - *Hydraulic Lifter*（Pitcher Mech, AE）：抓起向前抛，落地 1 伤（配合 cracked tile）
- **TFT**: ❌（无完全对应，Pyke 的拉+瞬移近似）
- **Slay the Spire**: ❌

**设计变体 / 参数轴**:
- 终点位置：身后 / 前方 / 自由选择 / 固定抛物线
- 配合效果：cracked tile / 火坑 / 队友位置

---

### 1.6 方向操纵 (Direction Manipulation)

**机制定义**：不位移目标但改变其朝向 / 攻击指向。

**游戏例子**:
- **Into the Breach**:
  - *Spartan Shield*（Aegis Mech）：近战 2 伤 + 反转目标攻击方向 180°
  - *Control Shot*（Control Mech, AE）：强制 Vek 移动 1 格（改位置使其打到友军）
- **TFT**: ❌（自动战斗无朝向玩家控制）
- **Slay the Spire**: ❌

**设计变体 / 参数轴**:
- 旋转度数：180° / 90° / 随机
- 是否持续：一回合 / 永久直到下次宣告

---

## 2. 💥 形状 / 范围 (AoE Shapes)

### 2.1 直线穿透 (Line / Piercing)

**机制定义**：沿一条直线作用于路径上的所有 / 首个目标。

**游戏例子**:
- **Into the Breach**:
  - *Taurus Cannon*：直线无限距离，命中第一格
  - *Burst Beam*（Laser Mech）：直线激光穿透，3/2/1 递减
  - *Prime Spear*：直线穿刺多格
  - *Frost Beam*：一整列冷冻
  - *AP Cannon*（Pierce Mech）：推第一 + 打第二
- **Slay the Spire**:
  - *Beam Cell* / *Sunder*：实际上是单体，StS 没严格"直线"概念
  - *Whirlwind*（all enemies）：全体非直线
- **TFT**:
  - *Lissandra - Dark Matter*：直线匕首
  - *Aurelion Sol - Deathbeam*：引导直线死亡光束，穿透魔抗
  - *Ahri - Spirit Bomb*（Set 10）：4 hex 直线，去程魔法 + 回程真实

**设计变体 / 参数轴**:
- 命中规则：打第一目标 / 穿透全部 / 伤害递减
- 距离：无限 / N 格
- 穿墙：能 (Burst Beam) / 不能
- 双向：*Janus Cannon* (ItB) 前后同射

### 2.2 扇形 / 圆锥 (Cone / Fan)

**机制定义**：从施法者朝一方向散开一个锥形区域。

**游戏例子**:
- **Into the Breach**:
  - *Flame Thrower*：直线 2 格（近似短扇）
  - *Thermal Discharger*：T 字型（第 1 格侧向推 + 正前直线）
- **TFT**:
  - *Samira - Flair*：扇形 AoE 斩击
  - *Jinx - Fishbones!*：扇形子弹雨
  - *Graves - Collateral Damage*：扇形弹 + 爆炸
  - *Gwen 突进*：突进后扇形伤害
- **Slay the Spire**: ❌

**设计变体 / 参数轴**:
- 扇角：60° / 120° / 180° / 全圆
- 距离：贴身 / 3 格
- 命中衰减：固定 / 距离衰减

### 2.3 圆形 / 十字 / 四邻 (Circle / Cross / Adjacent)

**机制定义**：以某格为中心的规则形状 AoE。

**游戏例子**:
- **Into the Breach**:
  - *Artemis Artillery*：目标 1 伤 + 四邻推
  - *Cluster Artillery*：中心格安全，四邻 1 伤 + 推（甜甜圈）
  - *Repulse*：四邻推 1
  - *Mercury Fist*：砸地，推所有相邻
  - *Explosive Vents*：四邻 1 伤
  - *Starfish Vek*：4 斜向（X 型）
- **TFT**:
  - *Karma - Singularity*（Set 17）：黑洞对目标+附近
  - *Rek'Sai - Upheaval*：相邻击飞
  - *Mordekaiser*：护盾期间对相邻持续伤害
- **Slay the Spire**:
  - *Thunderclap*：全体（相当于"全圆"但无距离概念）
  - *Shockwave*：全体 Weak+Vuln
  - *Whirlwind*：全体 X 次
  - *Immolate*：全体大爆炸

**设计变体 / 参数轴**:
- 形状：单点 / 四邻 / 六邻（hex 本体） / 戒指（中心不伤，外圈伤）
- 中心是否伤害
- 范围：1 环 / 2 环（穿透递减）

### 2.4 弹跳 / 分裂 / 链锁 (Bounce / Chain / Split)

**机制定义**：攻击命中后跳到下一个目标，多段命中。

**游戏例子**:
- **Into the Breach**:
  - *Ricochet Rocket*：L 型折射命中第二目标
  - *Electric Whip*：近战 2 伤 + **链式**传导到所有相邻占格单位（含友军）+ 沿导电体跳
  - *Refractor Laser*：折射激光 + 穿透
- **TFT**:
  - *Zoe - Paddle Star*：弹跳多段命中
  - *Xayah - Stellar Ricochet*（Set 17）：弹跳 X 次留羽毛
  - *Bouncing Flask*（TFT? 其实是 StS）
  - *Milio - ULTRA MEGA TIME KICK*（Set 17）：踢球弹跳
  - *Kai'Sa - Bullet Cluster*：分裂导弹自动寻敌
- **Slay the Spire**:
  - *Bouncing Flask*（Silent）：给随机 3-4 个敌人上 Poison
  - *Sword Boomerang*：随机打 3-4 次
  - *Tingsha*：弃牌打随机敌

**设计变体 / 参数轴**:
- 命中次数：固定 N / 动态（直到打完）
- 目标选择：随机 / 最近 / 最低血 / 最高血
- 伤害递减：固定 / 衰减
- 导体：电 chain 沿 metallic 导通 (ItB)

---

## 3. 💢 伤害结算类 (Damage Modifiers)

### 3.1 斩杀 (Execute)

**机制定义**：达到条件（低血 / 标记 / 特定阈值）时造成额外伤害或直接秒杀。

**游戏例子**:
- **Into the Breach**:
  - 环境处决：*推入水/chasm/lava* → 即死（属于斩杀家族）
  - *Old Earth Mines*、*Air Strike*：踩到即死
  - *Mosquito Leader*（AE）：9999 伤害（实际即死）
- **TFT**:
  - *Dark Star* Set 17：黑洞吞噬 HP ≤ 10% 的敌人
- **Slay the Spire**:
  - *Reaper*（Ironclad）：对全体伤害并吸等量未格挡伤害为 HP
  - *Corpse Explosion*（debuff）：死亡时对其他敌人造成 X×MaxHP
  - *Bane*：若 Poisoned 则 double damage

**设计变体 / 参数轴**:
- 触发条件：低血阈值 / 持特定 debuff / 踩格
- 效果：即死 / 伤害翻倍 / 击杀附加奖励
- 是否秒杀 vs 增伤

### 3.2 真实伤害 / 无视防御 (True Damage / Pierce)

**机制定义**：无视护甲 / MR / Block。

**游戏例子**:
- **Into the Breach**:
  - 环境伤害 (drown / chasm) 无视 armor
  - *Centipede* 的 A.C.I.D. 不"真伤"但翻倍抵消护甲
- **TFT**:
  - *Fiora - Perfect Bladework*（Set 17）：Vital = 真实伤害
  - *Shen - Reality Tear*：攻击叠加魔法/真实伤害
  - *Aurora - Hopped-Up Hacks*：Hack 结束时真实伤害
  - *Aurelion Sol - Deathbeam*：无视 % 魔抗
  - *Kraken's Fury* 装备：普攻叠加 true damage
- **Slay the Spire**:
  - *Apparition / Intangible*：把所有伤害降为 1（反向：防御方真伤抵消）
  - Mark-Pressure Points：按 Mark 层数扣 HP（绕过 Block）
  - Poison：扣 HP 绕过 Block

**设计变体 / 参数轴**:
- 百分比穿透 vs 完全无视
- 条件触发（Fiora 只有 Vital 才真伤）
- 数值 scaling：固定 / 随某属性

### 3.3 吸血 / 生命偷取 (Lifesteal / Omnivamp / Heal-on-kill)

**机制定义**：造成伤害时按比例回血；或击杀时回血。

**游戏例子**:
- **Into the Breach**:
  - *Viscera Nanobots*（Hazardous Mechs）：击杀回 1 HP
  - *Nanofilter Mending*（Mist Eaters AE）：吃 smoke 回 1 HP
- **TFT**:
  - *Bloodthirster* 装备：20% 全能吸血 + 低血护盾
  - *Hand of Justice*：随机 Omnivamp
  - *Hextech Gunblade*：20% 治疗最低血队友
  - *Master Yi Psi-State*：全能吸血
  - *Reaper* 设计模板多次出现
- **Slay the Spire**:
  - *Reaper*（Ironclad）：按未格挡伤害回血
  - *Bite*（Colorless）：造伤治 2 HP
  - *Burning Blood* / *Black Blood*：战后回 6/12 HP

**设计变体 / 参数轴**:
- on-hit 比例 vs on-kill 固定
- 仅限特定来源（Shiv only、Attack only）
- 全队共享 (Hextech Gunblade) vs 自己

### 3.4 反弹 / 反伤 (Thorns / Retaliate)

**机制定义**：被攻击时自动对攻击者造成伤害。

**游戏例子**:
- **Into the Breach**:
  - *Bramble*（类比）：ItB 无直接 thorns，但 Armored 近似减伤
  - *Urgot Mecha*（TFT）的反击被动在 ItB 无对应
- **TFT**:
  - *Bramble Vest* 装备：反弹 100 魔法伤害到相邻
  - *Urgot - Unstoppable Dreadnought*（Set 17）：近战反击爆破
  - *Bronze Scales*（Silent-adjacent）：不是 TFT 的
- **Slay the Spire**:
  - *Thorns* (Buff)：被攻击反弹 X 伤害
  - *Flame Barrier*（Ironclad）：1 回合反伤
  - *Sharp Hide*（Guardian）：打 Attack 受伤
  - *Bronze Scales* relic：开场 3 Thorns
  - *Beat of Death*（Corrupt Heart）：打每张卡受伤（一种反"出牌"反伤）

**设计变体 / 参数轴**:
- 触发：被攻击 / 被特定类型伤害
- 持续：永续 (Thorns) / 单回合 (Flame Barrier)
- 数值 scaling：固定 / 随护甲

### 3.5 连锁 / 爆炸链 (Chain / Explosion chain)

**机制定义**：命中触发连锁反应，波及其他单位或格子。

**游戏例子**:
- **Into the Breach**:
  - *Electric Whip*：连锁所有相邻（含友军）
  - *Bombling*：小炸弹被推/撞触发四邻爆炸
  - *Cracked tile* 系统（Cataclysm）：伤害触发坍塌 → 格内 non-flying 死
  - *Tumblebug Vek*：攻击同时生成 explosive rock
- **TFT**:
  - *Kai'Sa - Bullet Cluster*：子弹在目标间分裂
  - *Blitzcrank - Party Crasher*：撞球触发多目标
- **Slay the Spire**:
  - *Corpse Explosion*（debuff）：死亡 → 所有敌扣 MaxHP%
  - *The Bomb*（Power）：3 回合后全体 40/50/60 伤
  - *Explosive*（敌方 Exploder）：3 回合爆炸
  - *Combust*（Power）：回合结束全体伤

**设计变体 / 参数轴**:
- 触发方式：主动命中 / 死亡触发 / 延迟回合
- 连锁条件：相邻 / 导体（电） / 特定格（cracked tile）
- 衰减：每跳 -X% / 固定

---

## 4. ☠️ 持续伤害 / 状态伤害 (DoT / Status)

### 4.1 中毒 (Poison)

**机制定义**：叠层，回合/tick 开始扣 HP，自身层数 -1 衰减。

**游戏例子**:
- **Slay the Spire**:
  - *Poison* 层数型 Hybrid（Intensity + Duration）：每回合扣等于层数的 HP，然后 -1
  - *Deadly Poison* / *Bouncing Flask* / *Noxious Fumes*（回合开始施放）/ *Catalyst*（翻倍）/ *Envenom*（普攻施毒）
  - *Snecko Skull* relic：施毒 +1
- **Into the Breach**:
  - *A.C.I.D.*：不是 DoT（不扣 HP），是"下次伤害 x2"
  - *Fire*：每回合 1 伤（见 4.2）
- **TFT**:
  - *Teemo - Double Time*（Set 17）：叠加魔法持续伤
  - *Morellonomicon* 装备：Burn + Wound
  - *Red Buff* 装备：普攻 Burn

**设计变体 / 参数轴**:
- 衰减：每回合 -1（StS 经典） / 固定时长
- 叠加：独立计数 vs 刷新 duration
- scaling：自身固定 / 按施法者属性（Envenom = attack dmg）
- 传导：*The Specimen* relic（敌亡 → 转移 poison）

### 4.2 燃烧 / 冰冻状态 (Burn / Freeze / Fire / Chill)

**机制定义**：场地或单位状态 → 每回合扣 HP 或 禁行动。

**游戏例子**:
- **Into the Breach**:
  - *Fire*（status）：每回合 1 伤
  - *Fire* tile：踩入起火；建筑不吃火
  - *Frozen*：本回合不能动/攻击；即使解冻本回合攻击仍被中断
- **TFT**:
  - *Gragas - Chill*：减速 / 减攻速
  - *Morellonomicon*：Burn
  - *Zoe Frost* (Set 6.5 等)：冰冻减速
- **Slay the Spire**:
  - *Burn*（Status card）：回合末扣 2/4 伤害然后消耗
  - *Frost*（Defect Orb）：不是冰冻是加盾
  - *Fire Breathing*：抽到 Status/Curse 对全体伤

**设计变体 / 参数轴**:
- 火：地面持续 vs 单位状态
- 冰冻：完全停机 vs 减速
- 清除条件：再被攻击 / 固定回合 / 消耗

### 4.3 酸蚀 / 易伤标记型 DoT (Acid-like, 增伤而非扣血)

**机制定义**：挂上后"下次受伤加成"，区别于直接扣血的毒。

**游戏例子**:
- **Into the Breach**:
  - *A.C.I.D.*（最纯粹）：受武器伤害 x2；剥 shield；踩水变酸池
- **TFT**:
  - *Vulnerable* 系列（见下方 debuff）
  - *Evenshroud* 装备：附近敌易伤
- **Slay the Spire**:
  - *Vulnerable* 本质相同：+50% Attack 伤害

**设计变体 / 参数轴**:
- 倍率：50% / 100% (A.C.I.D.)
- 范围：单体 / AoE
- 持续：永久直到清除 / duration
- 清除条件：被 shield 剥除 / 特殊卡

### 4.4 失血 / 持续扣血非衰减 (Bleed-like)

**机制定义**：持续 X 回合每回合固定扣 HP（不像 poison 衰减）。

**游戏例子**:
- **Slay the Spire**:
  - *Constricted*：回合结束受 X 伤（层数不变）
  - *Burn* 本质也是
- **TFT**:
  - *Talon - Diviner's Judgment*（Set 17）：流血
  - *Akali - Star Strike*：Wound + 流血
  - *Mordekaiser*：DoT + 盾
- **Into the Breach**: ❌ （ItB 基本没有"每回合固定扣血不衰减"的独立状态）

---

## 5. 🛡️ 防御类 (Defense)

### 5.1 格挡 / 护盾 (Block / Shield)

**机制定义**：消耗型数值层，吸收下一次 / 下 X 次伤害。

**游戏例子**:
- **Into the Breach**:
  - *Shield* (status)：吸收一次非致死伤害 + 挡 status effect（fire/acid/web/smoke）
  - *Shield Projector*（Defense Mech）：远程给任何单位上 shield
  - *Mafan* (Zoltan)：每回合自动上 Shield（+固定 1 HP）
- **TFT**:
  - 大量：*Leona - Shield of Daybreak*、*Poppy*、*Ornn Disco Inferno*、*Mordekaiser*、*Nunu*、*Riven*、*Diana - Pale Cascade*、*Illaoi*、*Rammus*、*Urgot*
  - 装备：*Crownguard*、*Protector's Vow*、*Steadfast Heart*
  - *Bastion* 羁绊：团队护甲/魔抗
  - *Vanguard* 羁绊：开战最大 HP 护盾
- **Slay the Spire**:
  - *Block*：核心资源，回合开始清零
  - *Barricade*：不清零
  - *Calipers*：清零改为 -15
  - *Blur*：Block 不清零 X 回合
  - *Metallicize*：每回合末 +X Block
  - *Plated Armor*：受攻击 -1（但受一次后层数减）

**设计变体 / 参数轴**:
- 是否持续：单次消耗 (ItB) / 数值池 (StS) / 时间衰减
- 回合结束是否清零
- 覆盖范围：自身 / 队友 / 全体
- 吸收类型：物理 / 魔法 / 全部 / status 额外

### 5.2 无敌 / 无形 / 减伤百分比 (Invulnerable / Intangible / Damage Reduction)

**机制定义**：所有伤害降为 0 或 1（无敌）；或按百分比减免。

**游戏例子**:
- **Into the Breach**:
  - *Armored*：武器伤害 -1（最低 0）
  - *Abe Isamu* pilot：Armored
  - *Ariadne* pilot：免疫 Fire
  - *Edge of Night* 装备（TFT，非 ItB）
- **TFT**:
  - *Riven* 自适应减伤
  - *Pantheon - Advanced Defences*
  - *Brawler* 羁绊（HP 加成）
  - *Dragon's Claw*：+60 MR + 回血
  - *Tahm Kench*：血阈值以下被动触发
  - *Quicksilver*：前 X 秒免疫控制（移控免疫）
- **Slay the Spire**:
  - *Intangible*（Buff）：所有伤害和 HP 损失降为 1
  - *Invincible*（Corrupt Heart）：本回合最多失 X HP
  - *Tungsten Rod*：每次失血 -1
  - *Torii*：5 以下伤害降至 1
  - *Odd Mushroom*：Vuln 只受 25% 而非 50%
  - *Paper Phrog* / *Paper Krane*：加强己方施加的 vuln/weak

**设计变体 / 参数轴**:
- 减免类型：固定 -N / 百分比 / 降至 1
- 持续：永久 / Duration / 阈值触发
- 免疫类型：物理 / 魔法 / 状态 / 控制

### 5.3 反击 / 格挡反伤 (Counter / Riposte)

**机制定义**：挡住伤害后立即反击或反弹。

**游戏例子**:
- **Into the Breach**: Shield 不反击，但 Armored 近似（受伤 -1）
- **TFT**:
  - *Urgot - Unstoppable Dreadnought*：反击爆破
  - *Jax - Counter Star-ike*：防御姿态后击晕
  - *Rammus*：X 次命中后反击
- **Slay the Spire**:
  - *Flame Barrier*：反伤 1 回合
  - *Thorns* / *Bronze Scales*：每次被攻击反

### 5.4 免控 / 净化 (Cleanse / Tenacity)

**机制定义**：清除或抵消负面状态。

**游戏例子**:
- **Into the Breach**:
  - Shield 挡 status effects
  - *Thick Skin* pilot skill：免疫 A.C.I.D. 和 Fire
  - *Pilot_Soldier* (Camila)：免疫 Web 和 Smoke
  - *Ginger* 类概念无直接对应
- **TFT**:
  - *Quicksilver* 装备：前 X 秒免控
  - *Adaptive Helm*：前/后排不同 buff（含部分抗性）
- **Slay the Spire**:
  - *Artifact*（buff）：抵消下 X 次 debuff
  - *Ginger*：不会 Weak
  - *Turnip*：不会 Frail
  - *Orange Pellets*：打满 3 类卡移除所有 debuff
  - *Panacea*：+1/2 Artifact

---

## 6. ⬆️ 增益 (Buff — 自身 / 队友)

### 6.1 攻击力增益 (Strength / AD / AP)

**机制定义**：提升基础伤害或某属性。

**游戏例子**:
- **Slay the Spire**:
  - *Strength*（Intensity）：所有 Attack +X
  - *Inflame* / *Demon Form* / *Flex*（临时）/ *Limit Break*（翻倍）
  - *Rupture*：因卡失 HP → +Str
  - *Vajra* relic：+1 Str
  - *Vigor*：下一 Attack +X
  - *Dexterity*：所有 Block +X
  - 敌方 *Enrage*、*Angry*、*Strength Up*
- **TFT**:
  - *Kindred - Cosmic Pursuit*（N.O.V.A. +AD/AP）
  - *Rogue* 羁绊：+AD/AP
  - *Vajra* 对应装备：*Deathblade*（+AD）
  - *Inflame* 对应：*Demon Form*（TFT 没直接，但 *Aurelion Sol 的 Stardust* 同类）
- **Into the Breach**:
  - *Boost*（boosted 状态）：下一攻击 +1 伤害
  - *Heat Engines*：吃 fire → Boosted
  - *Pilot_Chemical* (Morgan)：每杀 +Boosted
  - Kai Miller (Arrogant)：满血自动 Boosted

**设计变体 / 参数轴**:
- 单次 (Boost / Vigor) vs 持续 (Strength 层数)
- 回合开始叠加 (Demon Form) / 条件触发 (Rupture)
- 自毁机制：*Flex* 回合末 -X / *Mutagenic Strength* 3 回合后 -3

### 6.2 攻速 / 行动加速 (Attack Speed / Move)

**机制定义**：单位时间内做更多次行动。

**游戏例子**:
- **Into the Breach**:
  - *Pilot_Youth* (Lily)：第一回合 +3 Move
  - *Pilot_Aquatic* (Archimedes)：开火后再移动一次
  - *Pilot_Leader* (Chen Rong)：攻击后 +1 免费移动
  - *Pilot_Miner* (Silica)：不动则攻击两次
  - *Adrenaline* skill：每杀 +1 Move
- **TFT**:
  - *Briar - Fish Frenzy*：缺血获攻速
  - *Challenger* 羁绊 / *Guinsoo's Rageblade*（每攻 +AS 无上限）
  - *Teemo - Double Time*：X 次攻击内 +AS
  - *Draven* 轴斧式叠层
- **Slay the Spire**:
  - *Berserk*：回合开始 +X 能量（类似"行动次数"）
  - *Double Tap* / *Burst* / *Duplication*：触发两次
  - *Nunchaku*：10 attacks → +1 能量
  - *Echo Form*：每回合前 X 张卡触发两次

### 6.3 多次触发 / 双倍 (Multi-trigger / Double)

**机制定义**：让一次效果结算两次甚至多次。

**游戏例子**:
- **Slay the Spire**:
  - *Double Tap* (Ironclad)、*Burst* (Silent)、*Amplify* (Defect)、*Duplication*、*Echo Form*
  - *Dualcast*：Evoke 最右 Orb 两次
  - *Gold-Plated Cables*：最右 Orb passive 额外触发
  - *Necronomicon*：≥2 费的首张 Attack 触发两次
- **TFT**:
  - *Replicator* 羁绊（Set 17）：技能以 X% 强度重复一次
- **Into the Breach**: ❌（ItB 一个武器每回合固定 1 次）

### 6.4 暴击 / Lucky (Crit / Lucky)

**机制定义**：按概率放大单次伤害 / 触发特殊效果。

**游戏例子**:
- **TFT**:
  - *Sparring Gloves* 类装备：+10% 暴击
  - *Infinity Edge*：+35% 暴击率
  - *Jeweled Gauntlet*：技能可暴击
  - *Fateweaver* 羁绊：概率效果 Lucky 双重检查
  - *Caitlyn - Aim For The Head*：Lucky 爆头
  - *Milio* 100% Lucky 弹跳
  - *Corki* mega 导弹 Lucky
- **Slay the Spire**: ❌ （无暴击，只有 Double Tap 类确定性倍伤）
- **Into the Breach**: ❌（纯确定性，无暴击）

**设计变体 / 参数轴**:
- 暴击率 / 暴击伤害分离
- Lucky 机制：多次检查取最好
- 技能是否可暴击（需特定装备解锁）

### 6.5 单体强化队友 (Buff Ally Target)

**机制定义**：技能作用于友军而非敌人。

**游戏例子**:
- **Into the Breach**:
  - *Shield Projector*：给任意单位（含友军/建筑）上盾
  - *Pilot_Caretaker* (Rosie)：Move 后给相邻机甲 Repair
- **TFT**:
  - *Lulu - Wild Growth*（经典）：最低血友军变巨型
  - *Poppy - Huddle Up!*：附近友军护盾+双抗
  - *Shen - Reality Tear*：友军获攻速
  - *Bulwark*（Shen 专属）：relic 相邻友军增益
- **Slay the Spire**: ❌（单人战斗）

---

## 7. ⬇️ 减益 (Debuff — 敌方)

### 7.1 易伤 (Vulnerable / 伤害放大)

**机制定义**：目标受到的伤害 +X%。

**游戏例子**:
- **Slay the Spire**:
  - *Vulnerable*（Duration）：+50% 攻击伤害
  - *Bash*、*Thunderclap*、*Shockwave*、*Bag of Marbles*（开场全体）
  - *Paper Phrog*：vuln 改为 75%
  - *Hand Drill*：破盾施 2 vuln
  - *Spore Cloud*：死亡上 vuln
- **Into the Breach**:
  - *A.C.I.D.*：本质 +100% 武器伤害
- **TFT**:
  - *Evenshroud* 装备：附近敌受损 +X% 易伤
  - *Sunder*（Last Whisper 装备）：-30% 护甲

### 7.2 虚弱 / 输出下降 (Weak)

**机制定义**：目标造成的攻击伤害 -X%。

**游戏例子**:
- **Slay the Spire**:
  - *Weak*：-25% 攻击伤害
  - *Clothesline*、*Leg Sweep*、*Shockwave*、*Doubt*（curse 回合末上 weak）
  - *Red Mask*：开场全体 weak
  - *Wave of the Hand*（Watcher）：获盾上 weak
  - *Paper Krane*：weak 改 40%
- **TFT**:
  - 无直接 Weak，部分减攻速等效
- **Into the Breach**:
  - *Frozen*：实际上是 0 伤害（完全禁用）
  - *Smoke*：格内不能攻击

### 7.3 破甲 / 护甲削减 (Shred / Sunder)

**机制定义**：永久或临时降低目标护甲 / MR。

**游戏例子**:
- **TFT**:
  - *Akali - Star Strike*：移除护甲
  - *Samira - Flair*：-5/10/15 护甲
  - *Last Whisper* 装备：Sunder -30% 护甲 5s
  - *Eradicator* 羁绊：-14% 敌方双抗
  - *Ionic Spark*：附近敌 -MR
- **Slay the Spire**:
  - *Strength Down*（对敌）：-X Str
  - *Shackled*（类似）
- **Into the Breach**:
  - *A.C.I.D.* 剥离 shield / psion armor

### 7.4 沉默 / 封技能 (Silence / Mana Reave)

**机制定义**：禁止释放技能，或增加施法门槛。

**游戏例子**:
- **TFT**:
  - *Ahri - Essence Theft*：Mana Reave 35% 目标下次施法门槛 +35%
  - *Void Staff* 装备：Mana Reave
- **Slay the Spire**:
  - *Entangled*：本回合不能打 Attack
  - *Fasting*：每回合少 X 能量
  - *Velvet Choker*：每回合最多 6 张
- **Into the Breach**:
  - *Smoke*：不能攻击不能 repair
  - *Frozen*：不能攻击

### 7.5 标记 / 计数器 (Mark / Lock-On)

**机制定义**：先打标记，条件满足 / 再次攻击时触发额外效果。

**游戏例子**:
- **Slay the Spire**:
  - *Mark*：Pressure Points 打出 → 所有 mark 敌人失 X HP
  - *Lock-On*（Defect）：Lightning/Dark 对该敌 +50%
  - *Choked*：每打一张卡目标失 X HP
- **TFT**:
  - *N.O.V.A. Strike* 羁绊：标记敌人受额外伤害
  - *Kindred - Cosmic Pursuit*：标记 → 狼消耗标记
  - *Ahri - Essence Theft*：第二次 AoE 对被吸目标增伤
- **Into the Breach**:
  - Vek *attack markers*：不是 debuff 是宣告（下回合攻击预告）

---

## 8. 🔒 控制类 (Hard / Soft CC)

### 8.1 眩晕 / 冻结 (Stun / Freeze / Root)

**机制定义**：禁止目标行动一段时间。

**游戏例子**:
- **Into the Breach**:
  - *Frozen*：本回合不动不攻击
  - *Webbed*：下回合不能移动但仍可攻击（= Root）
  - *Cryo-Launcher*（同时冻己）
  - *Ice Storm*：3x3 全员冻
  - *Stable* trait：反控（免疫所有位移）
- **TFT**:
  - *Sion - Decimating Smash*：击飞 + 晕眩 2.5/3/6s
  - *Leona - Shield of Daybreak*：晕
  - *Maokai - Grasp of Convergence*：藤蔓晕
  - *Jax*、*Sona*、*Fizz*（Mega Meep）、*Rek'Sai*、*Rhaast*：击飞
- **Slay the Spire**:
  - *No Block*、*No Draw*（敌给玩家）是类"控制"
  - *Time Warp*（Time Eater）：玩家打 12 张 → 强制回合结束
  - 无经典 Stun（单人战斗）

**设计变体 / 参数轴**:
- Stun：完全停机 vs 只禁技能 vs 只禁移动
- 时长：固定秒 / 回合数 / 直到受击
- 抗性：stable / tenacity / QSS

### 8.2 减速 / Chill (Slow)

**机制定义**：攻速 / 移速降低，软控。

**游戏例子**:
- **TFT**:
  - *Gragas - Chemical Rage* (Chill)
  - *Shen - Reality Tear*：敌减速
  - *Zoe* Frost 减速
- **Into the Breach**:
  - *Webbed*（算 root 非 slow）
  - 无纯减速
- **Slay the Spire**:
  - *Slow*：每打一张卡目标受 +10% 攻击伤（设计上是"越打越弱"对玩家）
  - 敌方有"本回合只 X 张"概念

### 8.3 嘲讽 / 强制目标 (Taunt)

**机制定义**：强制敌方单位攻击特定目标或改变目标选择。

**游戏例子**:
- **Into the Breach**:
  - *Control Shot*：强制 Vek 移动，间接改变其攻击方向
  - *Rogue* 类（TFT 有 Rogue → 影子重定向 taunt 反向）
- **TFT**:
  - *Rogue* 羁绊：低血转影子重定向敌方仇恨（反 taunt = 脱离目标）
  - *Yorick Minion of Light* 等近战单位自然吸引
- **Slay the Spire**: ❌（单人）

### 8.4 恐惧 / 驱散 (Fear / Displacement control)

**机制定义**：强制移动方向非物理而是"意图"级。

**游戏例子**:
- **TFT**:
  - *Nunu - Calamity*：向场地尽头推进击飞
- **Into the Breach**: ItB 的 push/pull 已覆盖
- **Slay the Spire**:
  - *Fade*（Transient 自毁）不算恐惧

---

## 9. ⚡ 触发 / 反应 (Triggers / Reactions)

### 9.1 On Hit / On Damage Taken

**游戏例子**:
- **Slay the Spire**:
  - *Centennial Puzzle*：首次失 HP → 抽 3
  - *Self-Forming Clay*：失 HP → 下回合 +3 Block
  - *Fossilized Helix*：第一次失 HP prevent
  - *Curl Up*（敌）：受伤获 Block
  - *Malleable*（Snake Plant）：受伤获 Block 递增
  - *Sharp Hide*：玩家打 Attack 受 X
  - *Static Discharge*（Defect）：受攻击 Channel Lightning
  - *Runic Cube*：失 HP 抽 1
- **TFT**:
  - *Mordekaiser* 血阈值以下触发
  - *Tahm Kench* 血阈值
  - *Party Animal*（Blitzcrank）：血 <45% 触发
- **Into the Breach**:
  - *Burrower Vek*：受伤取消攻击

### 9.2 On Death (尸爆 / 遗产)

**游戏例子**:
- **Slay the Spire**:
  - *Corpse Explosion*：死亡 → 其他敌 %MaxHP
  - *The Specimen*：敌亡 → 转移 poison
  - *Spore Cloud*（Fungi Beast）：亡 → vuln 玩家
  - *Split*（Slime）：HP ≤ 50% 分裂
  - *Life Link*（Darkling）：同伴活则 2 回合复活
  - *Gremlin Horn*：敌亡 → +1 能量 +1 抽
- **Into the Breach**:
  - *Goo*：死亡分裂成 2 个小 Goo
  - *Arachnoid Injector*：KO 生成 Arachnoid
  - *Smoldering Psion*（AE）：Vek 死留 fire tile
  - *Drill Mech*：击杀 Vek 产 cracked tile
- **TFT**:
  - *Yorick - Awakening*：友军亡 → Minion of Light
  - *Senna* 灵魂链：队友死 → 本体强化
  - *Briar*（Anima）：缺血机制附带

### 9.3 On Attack / On Spell (施法反应)

**游戏例子**:
- **Slay the Spire**:
  - *Curious*（Awakened One）：打 Power +Str
  - *Enrage*（Gremlin Nob）：打 Skill +Str
  - *Beat of Death*（Corrupt Heart）：每卡受 X
  - *Hex*：打非 Attack → 洗 Dazed
  - *Heatsink*（Defect）：打 Power 抽 X
  - *Bird-Faced Urn*：打 Power 回 2
  - *Mummified Hand*：打 Power 手牌某卡费 0
  - *After Image*（Silent）：每打一张卡 +X Block
  - *Thousand Cuts*：每打一张卡全体 X
- **TFT**:
  - 被动式：*Akali*、*Fiora*（每 X 攻击触发强化）
  - *Kindred*（N.O.V.A. 攻击/技能标记）
- **Into the Breach**:
  - *Vek Hormones*：Vek 对 Vek +1 伤（被动属于战场逻辑）

### 9.4 条件触发 (HP% / 回合数 / 次数)

**游戏例子**:
- **Slay the Spire**:
  - *Happy Flower*：每 3 回合 +1 能量
  - *Incense Burner*：每 6 回合 +1 Intangible
  - *Mercury Hourglass*：回合开始全体 3
  - *Stone Calendar*：回合 7 对全体 52
  - *Horn Cleat*：第 2 回合 +14 Block
  - *Captain's Wheel*：第 3 回合 +18 Block
  - *Nunchaku*：10 Attack → +1 能量
  - *Pen Nib*：每 10 Attack 双倍
  - *Red Skull*：HP ≤ 50% → +3 Str
  - *Meat on the Bone*：战末 HP ≤ 50% 回 12
- **TFT**:
  - *Tahm Kench* HP 阈值
  - *Mordekaiser* 持续时间
  - Set 17 Timebreaker：胜/败分支
- **Into the Breach**:
  - *Kai Miller (Arrogant)*：满血 Boosted 不满血 -1 Move
  - Map Events（下回合触发）

---

## 10. 🧟 召唤 / 尸体 / 复活 (Summon / Corpse / Revive)

### 10.1 召唤物 (Summon)

**游戏例子**:
- **Into the Breach**:
  - *Bombling Deployer*：放小狗样炸弹
  - *Arachnoid*：击杀生成蜘蛛
  - *Spider Vek*：抛 egg → Spiderling
  - *Digger*：造 rock 阻挡
  - *Tumblebug*：造 explosive rock
  - *Blobber*：放 HP 1 炸弹
  - *Plasmodia*：放孢子
- **TFT**:
  - *Meeple* 羁绊：伴随 Meeps
  - *Mega Meep*（Fizz）
  - *Shepherd*：Bia/Bayin
  - *Primordian*：Swarmling
  - *Diana - Pale Cascade*：3 环绕球
  - *LeBlanc*：分身协同
  - *Jhin - Space Opera*：幽灵之手
  - *Zed - Quantum Clone*：递归克隆
- **Slay the Spire**: ❌（单人；Shivs/Smite/Miracle 是"加卡"而非召唤生物）

### 10.2 复活 (Revive / Resurrect)

**游戏例子**:
- **TFT**:
  - *Life Link* 类概念
  - *Lizard Tail* 装备（StS）→ TFT 类似 *Edge of Night* 不死
- **Slay the Spire**:
  - *Lizard Tail*：死亡 → 50% HP 复活（一次）
  - *Darkling - Life Link*：盟友活则 2 回合复活
  - *Invulnerable* pilot skill（ItB）近似
- **Into the Breach**:
  - *Pilot_Rock* (Ariadne) +3 HP 非复活
  - *Invulnerable* pilot skill：机甲被破 pilot 不死

### 10.3 尸体交互 (Corpse / Exhaust 回收)

**游戏例子**:
- **Slay the Spire**:
  - *Exhaust* 池 + *Exhume*（从 exhaust 取回）
  - *Dead Branch*：Exhaust 随机加手牌
  - *Charon's Ashes*：Exhaust 全体 3 伤
- **Into the Breach**:
  - *Cataclysm cracked tile*：尸体格位继续利用
- **TFT**:
  - *The Specimen* 的 poison 转移概念（StS 装备但思路类似）

---

## 11. 🔋 资源 / 能量 / 蓄力 (Resources / Scaling)

### 11.1 蓄力 (Charge / Windup)

**机制定义**：施法前需要若干回合/秒的准备。

**游戏例子**:
- **TFT**:
  - *Sion - Decimating Smash*：1 秒蓄力后砸地
  - *Zeri - Lightning Crash*：蓄电 6 秒
- **Into the Breach**:
  - Vek 的 attack marker 本质是"蓄力宣告"（下回合打）
  - *Air Strike*、*Falling Rocks*、*Seismic* 等 map events
- **Slay the Spire**:
  - *The Bomb*：3 回合后爆炸
  - *Nightmare*：下回合 3 张复制
  - *Next Turn Block*

### 11.2 无限缩放 (Infinite Scaling)

**机制定义**：没有上限的属性累加，战斗越长越强。

**游戏例子**:
- **Slay the Spire**:
  - *Searing Blow*：可无限升级
  - *Demon Form*：每回合 +Str 累积
  - *Ritual*（设计上是敌方的 Demon Form）
  - *Strength Up*（敌）
  - *Noxious Fumes*：每回合 +Poison
  - *Juggernaut*：获 Block → 伤害
  - *Thousand Cuts*：每卡伤
- **TFT**:
  - *Aurelion Sol - Voice of Light*（Set 6）：Stardust 无上限
  - *Guinsoo's Rageblade*：每攻 +AS 无上限
  - *Archangel's Staff*：每 X 秒 +AP
  - *Zed - Quantum Clone*（Set 17）：递归克隆
  - *Space Groove*：持续战斗越久越强
  - *Draven* 轴斧叠层
- **Into the Breach**: ❌（每 battle 独立，reactor core 属于 meta 层而非单场）

### 11.3 消耗 HP 换收益 (Self-damage for gain)

**机制定义**：花自己血量换其他资源。

**游戏例子**:
- **Slay the Spire**:
  - *Hemokinesis*：-2 HP + 15 伤害
  - *Offering*：-6 HP + 2 能量 + 抽 3
  - *Brutality*：回合开始 -1 HP + 抽 1
  - *Combust*：回合末 -1 HP + 对全体伤
  - *Rupture*：因卡失 HP → +Str
- **Into the Breach**:
  - *Unstable Cannon*：自伤 1
  - *Hydraulic Legs*：自伤 1
  - *Cryo-Launcher*：自冻
  - *Reverse Thrusters*：自伤 1
  - *Mafan* (Zoltan)：HP 固定 1 换 +1 core
- **TFT**:
  - *Glass Cannon II* augment：后排 80% HP 换 30% DA
  - *Briar*：缺血强度

### 11.4 法力 / 能量池 (Mana / Energy)

**游戏例子**:
- **Slay the Spire**:
  - *Energy*：每回合 3（默认）
  - *Ice Cream*：保留能量
  - *Berserk*、*Lantern*、*Busted Crown* 等
  - *Fasting* 减能量
  - *Void Essence*（blight）：-1 能量永久
- **TFT**:
  - *Mana* 技能条：*Spear of Shojin* +5/攻；*Blue Buff* 技能后 +20；*Void Staff* 减敌方回蓝
  - *Conduit* 羁绊：团队 mana regen
- **Into the Breach**:
  - *Reactor Core*：meta 升级货币，非战斗内资源
  - 每把武器可能有 battle 级 use 次数（single-use weapons）

### 11.5 连击 / 节奏 (Combo / Rating)

**游戏例子**:
- **TFT**:
  - *Samira Style Rating* E→S
  - *Dark Star Constellation*：7 种星座
- **Slay the Spire**:
  - *Panache*：每 5 张卡全体伤
  - *Nunchaku*：10 attacks → energy
- **Into the Breach**: ❌

---

## 12. 🦋 变身 / 模式切换 (Transformation / Stance)

### 12.1 姿态切换 (Stance)

**游戏例子**:
- **Slay the Spire**:
  - *Stance* (Watcher)：Neutral / Calm / Wrath / Divinity
  - 每个 stance 有加成和代价
- **TFT**:
  - *Aphelios*（Set 8）：武器 Arsenal 3 种
  - *Miss Fortune - Gun Goddess* (Set 17)：3 模式
  - *Sona* (Set 10)：多曲子轮换
  - *Space Groove*：进入 Groove 状态
- **Into the Breach**: ❌

### 12.2 变身 / 巨大化 (Transform)

**游戏例子**:
- **TFT**:
  - *Akali* (Set 10)：K/DA 灯区变身
  - *Nasus - Groovin' Susan*：变身
  - *Morgana - Dark Form*
  - *Mecha* 羁绊 3 件套：变身 +60% HP
  - *Rhaast Alien Scythe*：形态展开
  - *Twitch - Spray and Pray*：远程形态
  - *Lulu - Wild Growth*：变巨型
- **Slay the Spire**:
  - *Demon Form*（视作持续变身）
  - *Simmering Rage*：自动进 Wrath
- **Into the Breach**: ❌

### 12.3 分身 / 镜像 (Clone / Mirror)

**游戏例子**:
- **TFT**:
  - *LeBlanc - Fracture Reality*：分身协同 + 最终一击
  - *Zed - Quantum Clone*：递归克隆
  - *Bard - UFO*：绑架敌创建复制体
- **Slay the Spire**:
  - *Nightmare*：下回合加 3 复制
  - *Dolly's Mirror*：再 +1 牌
  - *Bottled* 系列：起手必带
- **Into the Breach**: ❌（但 *Janus Cannon* 双向射击算"镜像投射"）

---

## 13. 🗺️ 地形 / 场地操纵 (Terrain / Field)

### 13.1 场地伤害格 (Damage Tile)

**游戏例子**:
- **Into the Breach**:
  - *Fire tile*：每回合 1 伤
  - *Lava*：推入即死 + 存活点火
  - *A.C.I.D. Pool*、*Tentacles*、*Cracked tile*、*Old Earth Mine*
  - *Conveyor*：回合末推
- **TFT**:
  - *Gangplank - Powder Keg*（历代）
  - *Teemo Noxious Trap*（历代）
  - *Stargazer Constellation hex*：Set 17 每局随机
- **Slay the Spire**: ❌（卡牌游戏）

### 13.2 阻挡 / 制造掩体 (Block / Wall)

**游戏例子**:
- **Into the Breach**:
  - *Mountain*（2 击破）
  - *Digger Vek*：四邻造 rock
  - *Tumblebug*：爆炸 rock
- **TFT**:
  - *Shen - Reality Tear*：切裂隙
  - *Nautilus* 等近战位置阻挡（被动）
- **Slay the Spire**: ❌

### 13.3 烟雾 / 视野 / 干扰 (Smoke / Fog)

**游戏例子**:
- **Into the Breach**:
  - *Smoke*：格内不能攻击也不能 repair
  - *Storm Generator*：Smoke +1 伤
  - *Sand → Smoke*
  - *Aerial Bombs*、*Rocket Artillery* 等产 smoke
- **TFT**: ❌
- **Slay the Spire**:
  - *Runic Dome*：看不到敌意图（视野干扰）

### 13.4 Hex 增益 (Hex-based Buffs)

**游戏例子**:
- **TFT**:
  - *Stargazer Constellation*：每局随机 hex 图案给增益
  - *Yasuo Space God*：生成特殊 hex
  - *K/DA 灯区*（Set 10）
- **Into the Breach**: ❌（无增益地形，全是伤害地形）
- **Slay the Spire**: ❌

---

## 14. 🌋 元素 / 属性 (Elements)

**机制定义**：给伤害/状态一个"属性"分类，作为协同/克制。

**游戏例子**:
- **Into the Breach**:
  - Fire / A.C.I.D. / Ice / Smoke / Electric（Whip 导通）— 几乎每个 squad 对应一个元素
- **TFT**:
  - 基本没有严格元素系统，但 Lightning/Frost/Dark/Plasma (Defect Orb?) — 其实这是 StS
  - TFT 的"羁绊"很多是主题化（N.O.V.A.、Dark Star 等）
- **Slay the Spire**:
  - *Defect Orbs*：Lightning / Frost / Dark / Plasma 是核心元素系统
  - Fire Breathing、Burn、Poison 有元素感但无显性相克

**设计变体 / 参数轴**:
- 相克：无 / 简单二元 / 全矩阵
- 共鸣：堆叠同属性触发额外（Lightning + Storm）
- 环境互动：Fire 烧 Forest 变 Fire（ItB 强）

---

## 15. 💰 经济 / 超战斗层 (Meta / Cross-battle)

> 这些是 inkmon 可选要不要做，但三游戏都重度依赖。

### 15.1 升级 / 成长 (Upgrade / Progression)

- **StS**：Smith / War Paint / Whetstone / Molten Egg / Frozen Egg / Toxic Egg / Apotheosis / Warped Tongs
- **ItB**：Reactor Core 升级武器 / HP / Move；Pilot XP
- **TFT**：单位升星、装备合成、Augment 选择、*Factory New*（Graves）永久升级

### 15.2 奖励 / 经济循环

- **StS**：Gold / Potions / Shop
- **ItB**：Rep / Corporation Funds / Mission objectives
- **TFT**：Gold 利息 / 经验刷新 / Space Gods Marketplace

### 15.3 风险机制 (Curse / Blight / 连败)

- **StS**：14 Curses / 13 Blights
- **ItB**：Power Grid（全局 HP），失败撤一个 pilot
- **TFT**：*Anima*（连败 +Tech）、*Comeback Story* augment、*Evelynn Space God*（血换）

---

## 16. 🌟 独特机制 (单游戏独有 / 难归类)

### 16.1 只在 Slay the Spire

- **Exhaust / Ethereal / Innate / Retain / Unplayable** 卡牌修饰词：只有卡牌游戏才有
- **Scry / Discard 协同 / Orb Channel-Evoke** 三种职业专属操作
- **Status 卡 / Curse 卡**：负面卡填塞牌堆
- **Confusion** (Snecko Eye)：随机化费用
- **Mantra / Stance 切换**：Watcher 独有累积条
- **Double Damage / Phantasmal / Intangible** 的数值型"伤害乘数"机制

### 16.2 只在 Into the Breach

- **宣告系统** (attack markers)：敌方下回合攻击完全可见，玩家"解谜"破局
- **Power Grid** 全局血条：失败不重来
- **Time Travelers**：跨时间线撤回 pilot
- **Cracked Tile 系统**（Cataclysm）：伤害触发二次死亡
- **Stable trait**：完全免疫位移（反 displacement 根本性规则）
- **反向攻击方向**（Spartan Shield）：改变敌意图方向
- **Vek Hormones**：友方/敌方阵营判定可改（让 Vek 打 Vek）
- **单次使用武器**（*Titanite Blade*、*Missile Barrage*、*Fissure Fist*）：每 battle 限数
- **Reset Turn**：悔棋（每 battle 1 次）

### 16.3 只在 TFT

- **羁绊系统**（Traits）：多单位激活共同 buff，阵容构建核心
- **星级系统**（1/2/3 星）：3 同 1 合成更强
- **Augments 三档选择**（Silver / Gold / Prismatic）：2-1 / 3-2 / 4-2 阶段性选择
- **Hero Augments**：英雄专属增益
- **Constellation / Space Gods Marketplace**：元素级随机事件
- **Carousel**：按血量反向选英雄
- **Encounter (PvE 回合)**：Krugs / Wolves / Raptors / Dragons 阶段性 PvE
- **Emblem**（Spatula 合成）：给单位加临时羁绊
- **Tactician's Cape/Crown/Shield**：扩队伍位
- **Artifact**（Portable Forge）：独特装备池
- **胜利/连败 streak**：连胜连败加利息
- **Senna 灵魂链**：双单位共享伤害

### 16.4 跨两游戏共有但第三无

| 机制 | 有 | 无 |
|---|---|---|
| 位置 / 位移 | ItB, TFT | StS |
| 卡牌 / 牌堆 | StS | ItB, TFT |
| 羁绊 / 协同 buff | TFT (StS 的 synergy 是卡组) | ItB 基本无 |
| Exhaust / 资源消耗池 | StS | ItB, TFT |
| 宣告敌意图 | ItB | StS (intent) 有但简化；TFT 无 |
| 装备合成 | TFT | StS (relic 不合成), ItB (core 升级非合成) |
| 元素地形 | ItB | TFT / StS |
| 无限 scaling | StS, TFT | ItB (限制在 battle 内) |

---

## 附录 A：共识机制 (三游戏都有)

1. **护盾 / 格挡** (5.1)
2. **增伤 buff** (6.1) — Strength / AD / Boosted
3. **易伤 debuff** (7.1) — Vulnerable / A.C.I.D.
4. **AoE 圆形 / 多目标** (2.3)
5. **On Death 触发** (9.2) — 尸爆 / 分裂 / 回蓝
6. **条件触发** (9.4) — HP% / 回合数
7. **自伤换收益** (11.3)
8. **斩杀** (3.1) — 环境 / 阈值 / 标记
9. **召唤物 / 衍生单位** (10.1) — ItB 有，TFT 大量，StS 通过 Shiv/Smite/Miracle 等"卡"体现

## 附录 B：hex ATB 原生机制 (ItB + TFT, StS 无)

1. 位移-推 / 拉 / 跳 / 瞬移 / 抓投
2. 形状 AoE（line / cone / circle / cross）
3. 链锁 / 弹跳
4. 地形伤害格
5. 嘲讽 / 仇恨操控（TFT 自动，ItB 半手动）

## 附录 C：卡牌独有 (StS, 其他两者无或弱)

1. 卡牌修饰词 (Exhaust / Ethereal / Innate / Retain / Unplayable)
2. Curse / Status 负面填塞
3. 暂存牌堆 / Scry 洗顶 / Discard 协同
4. Confusion 随机费用

---

## 附录 D：抓取一致性说明

以下是在合并时发现的 raw 数据疑点 / 标签冲突，供后续核对：

1. **ItB raw 第 1 行声明"hex-like 方格"但其实是正交 8×8**：术语冲突，hex 化是 inkmon 的目标。
2. **ItB *Janus Cannon* 归为 Brute class 起手**，但文档 2.2 Brute 列表中没再次出现（只有 Mirror Mech 提到）—— 合并到"直线穿透双向"变体。
3. **ItB *Vulcan Artillery* 伤害与描述冲突**（raw 里 1.6 节明说 "0 伤害但点火"，武器池 2.3 又说"2 伤"）：raw 自己标注冲突，分类时归"伤害 + 点火"复合，具体数值以 wiki 为准。
4. **StS *Foreign Influence* / *Weave* 原文不确定**（raw 第 663、667 行自标"待核实"）：归入 *Scry 协同*。
5. **StS *Dazed* 在 Status 章和 Ethereal 章都出现**：分类归 Status（Ethereal 只是其 tag）。
6. **TFT *Vex* 在 Set 17 1 费和 5 费列表都列出**（raw 第 87 行和第 333 行）：应为 5 费专属，1 费位置是 raw 抓取错误。
7. **TFT *Gun Goddess* 三模式数值 wiki 未提供**：分类时归 *变身 / 模式切换*。
8. **StS *Pride* 描述 "Innate. Exhaust."** 但 raw 标为"唯一能 play 的 curse"—— 实际 "play" 指 Exhaust 行为，归 Curse 即可。
9. **StS *Rupture* / *Catalyst* / *Sunder* / *Vault* / *Dualcast* 升级文本**：raw 已标注疑点，分类按基础效果归族即可。
10. **TFT 装备 *Hextech Gunblade* 在 raw 中效果描述为"20% 治疗全队最低血量友军"**：这是跨游戏 heal-on-dmg 的范式，注意 ≠ 传统 lifesteal（不治自己）。

---

> **用法提示**：inkmon 技能池设计时，建议优先从 **附录 A 共识机制** + **附录 B hex 原生机制** 抽取；卡牌独有机制（附录 C）除非 inkmon 引入卡牌层否则不适用；独特机制（第 16 章）作为"亮点单品"参考，不要批量复刻。
