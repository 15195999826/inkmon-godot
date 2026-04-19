# Slay the Spire — Raw Mechanics Data

> 数据源：https://slaythespire.wiki.gg/ （主），部分补充自 slaythespire.gg / fandom wiki
> 抓取日期：2026-04-18
> 用途：inkmon-godot 技能池设计参考素材（原始数据，未经筛选 / 评论）

---

## 1. Keywords（机制词典）

按大类组织。每个 keyword：英文名 + 精确机制（数值） + 代表卡/代表来源 + 关联 keyword。

### 1.1 资源 / 通用

- **Block**
  所有角色（和部分敌人）用于减伤的资源。回合开始时清零（除非有 Barricade / Blur / Calipers）。
  代表来源: Defend（基础牌）/ 任何防御牌
  关联: Barricade, Blur, Metallicize, Plated Armor, Frail, Dexterity, Calipers

- **Energy**
  每回合开始获得 3 点（默认）。用于打出卡牌。各角色有独立能量符号（红/绿/蓝/紫/无色）。
  代表来源: 所有 Boss relic "Gain 1 Energy at the start of your turn"
  关联: Berserk, Ice Cream, Fasting, Void

- **Upgrade**
  卡牌升级，通常提升数值或减费。篝火 (Smith) / War Paint / Whetstone / Molten Egg 等提供。
  代表来源: Smith (Rest Site)
  关联: Armaments, Apotheosis, Warped Tongs

### 1.2 卡牌修饰词 (Card Modifiers)

- **Exhaust**
  打出或触发后从本场战斗移除（进 Exhaust pile）。仅 Ironclad 的 Exhume 能取回。
  代表卡: Impervious, Sever Soul, Feel No Pain, Corruption
  关联: Feel No Pain, Dark Embrace, Charon's Ashes, Dead Branch

- **Ethereal**
  若回合结束时还在手牌，自动 Exhaust。
  代表卡: Ghostly Armor, Carnage, Apparition, Spirit Shield, Clumsy, Dazed, Void
  关联: Exhaust

- **Innate**
  开局起始手牌必抓。不额外增加手牌数，会占用正常抽牌位（若数量超过起手就额外抽）。
  代表卡: Writhe, Brutality+, Mind Blast (upgraded)
  关联: (Bottled 瓶系 relic 类似但不同机制)

- **Retain**
  回合结束时不丢弃，会留到下一回合（直到打出或被移除）。Watcher 专属修饰。
  代表卡: Deceive Reality, Wish, Nightmare, Pray
  关联: Establishment, Well-Laid Plans, Runic Pyramid (不同但相关)

- **Unplayable**
  无法从手牌打出。大多数 Curse 和大多数 Status 都是 Unplayable。
  代表: Curses (Injury 等), Statuses (Wound 等)
  关联: Blue Candle (让 Curse 可打), Medical Kit (让 Status 可打)

### 1.3 职业专属操作

- **Discard**
  把手牌丢进弃牌堆（主动，换 buff 或循环）。回合结束自动丢弃不触发 Discard 事件。Watcher 的 Scry 也不触发。
  代表职业: Silent
  关联: Tingsha, Tough Bandages, Hovering Kite, Reflex

- **Channel (Orb)**
  把 Orb 放进最右侧空槽。若所有槽已满，最右 Orb 被 Evoke。
  代表职业: Defect
  关联: Evoke, Focus, Lightning/Frost/Dark/Plasma

- **Evoke**
  消耗最右 Orb 触发其爆发效果。
  代表职业: Defect

- **Focus**
  提升 Orb 效果（Plasma 除外）。可为负。
  代表职业: Defect
  关联: Bias (debuff 减 Focus)

- **Stance**
  姿态系统：Neutral / Calm / Wrath / Divinity，每种有独立 buff / drawback。
  代表职业: Watcher
  关联: Mantra, Empty Body/Mind/Fist, Mental Fortress

- **Scry**
  查看抽牌堆顶 X 张，可选择丢弃。
  代表职业: Watcher
  关联: Foresight, Golden Eye, Nirvana

---

## 2. Powers / Buffs / Debuffs（永续状态）

三种堆叠规则：
- **Intensity**（强度型）：层数 = 效果强度，通常战斗持续
- **Duration**（持续型）：层数 = 持续回合，每回合 -1
- **Counter**（计数型）：触发事件时 -1，归零后消失

### 2.1 Buffs（增益）

#### 通用

- **Strength**: 增加 (减少) 攻击卡伤害 X。Intensity。
- **Dexterity**: 增加 (减少) 卡牌获得的 Block X。Intensity。
- **Artifact**: 抵消下 X 次 debuff。Counter。
- **Intangible**: 所有伤害和 HP 损失降为 1，持续 X 回合。Duration。
- **Plated Armor**: 回合结束获得 X Block；受到一次攻击伤害 -1。Intensity。
- **Thorns**: 被攻击时反弹 X 伤害。Intensity。
- **Vigor**: 下一次攻击造成 +X 伤害（用完消失）。Intensity。
- **Regen (玩家)**: 回合结束治疗 X HP，然后 Regen -1。Intensity & Duration。
- **Metallicize**: 回合结束获得 X Block。Intensity。
- **Barricade**: Block 不在回合开始清零。Non-stacking。

#### Ironclad 专属

- **Berserk**: 回合开始获得 X 能量。Intensity。
- **Brutality**: 回合开始失去 X HP 并抽 X 张。Intensity。
- **Combust**: 回合结束失 1 HP 并对全体造成 X 伤害。Intensity。
- **Corruption**: Skills cost 0，打出 Skill 时 Exhaust。Non-stacking。
- **Dark Embrace**: 每次 Exhaust 一张卡，抽 X 张。Intensity。
- **Demon Form**: 回合开始获得 X Strength。Intensity。
- **Double Tap**: 下 X 张 Attack 触发两次。Counter。
- **Evolve**: 每次抽到 Status，抽 X 张。Intensity。
- **Feel No Pain**: 每次 Exhaust，获得 X Block。Intensity。
- **Fire Breathing**: 每次抽到 Status / Curse，对全体造成 X 伤害。Intensity。
- **Flame Barrier**: 被攻击反弹 X 伤害，下回合失效。Intensity。
- **Juggernaut**: 每次获得 Block，对随机敌人造成 X 伤害。Intensity。
- **Rage**: 每次打出 Attack，获得 X Block。Intensity。
- **Rupture**: 因卡牌失 HP 时，获得 X Strength。Intensity。

#### Silent 专属

- **Accuracy**: Shivs 造成额外 X 伤害。Intensity。
- **After Image**: 每次打出卡，获得 X Block。Intensity。
- **Blur**: Block 不清零，持续 X 回合。Duration。
- **Burst**: 下 X 张 Skill 本回合触发两次。Counter。
- **Double Damage**: 攻击双倍伤害，持续 X 回合。Duration。
- **Envenom**: 未格挡的攻击伤害 = 施加 X Poison。Intensity。
- **Infinite Blades**: 回合开始把 X 张 Shiv 加入手牌。Intensity。
- **Next Turn Block**: 下回合获得 X Block。Intensity。
- **Nightmare**: 下回合起手加入 3 张指定卡。分开堆叠。
- **Noxious Fumes**: 回合开始对全体敌人施加 X Poison。Intensity。
- **Phantasmal**: 下 X 回合双倍伤害。Duration。
- **Thousand Cuts**: 每次打出卡，对全体造成 X 伤害。Intensity。
- **Tools of the Trade**: 回合开始抽 X 张 + 弃 X 张。Intensity。
- **Well-Laid Plans**: 回合结束可 Retain 最多 X 张卡。Intensity。

#### Defect 专属

- **Focus**: 提升 (减少) Orb 效果 X。Intensity。
- **Amplify**: 下 X 张 Power 触发两次。Counter。
- **Creative AI**: 回合开始随机加入 X 张 Power。Intensity。
- **Draw Card (buff)**: 下回合多抽 X 张。Intensity。
- **Echo Form**: 每回合打出的前 X 张卡触发两次。Intensity。
- **Electro**: 闪电打全体。Non-stacking。
- **Equilibrium**: 保留手牌 X 回合。Duration。
- **Heatsink**: 打出 Power 时抽 X 张。Intensity。
- **Hello**: 回合开始随机加入 X 张 Common 卡。Intensity。
- **Loop**: 回合开始，下一个 Orb passive 多触发 X 次。Intensity。
- **Rebound**: 下 X 张卡打出后放回牌库顶。Counter。
- **Repair**: 战斗结束治疗 X HP。Intensity。
- **Static Discharge**: 受到攻击伤害时 Channel X Lightning。Intensity。
- **Storm**: 打出 Power 时 Channel X Lightning。Intensity。
- **Energized**: 下回合获得额外 X 能量。Intensity。

#### Watcher 专属

- **Mantra**: 累积到 10，自动进 Divinity。Counter。
- **Battle Hymn**: 回合开始把 X 张 Smite 加入手牌。Intensity。
- **Blasphemer**: 回合开始死亡。Non-stacking（来自 Blasphemy 卡）。
- **Collect**: 下 X 回合，把 Miracle+ 加入手牌。Duration。
- **Deva**: 回合开始，能量增加 X（回合数乘数）。Intensity。
- **Devotion**: 回合开始获得 X Mantra。Intensity。
- **Establishment**: 每次 Retain 一张卡，该卡费用 -X。Intensity。
- **Foresight**: 回合开始 Scry X。Intensity。
- **Free Attack Power**: 下 X 张 Attack 忽略费用。Counter。
- **Like Water**: 以 Calm 结束回合获得 X Block。Intensity。
- **Master Reality**: 战斗中生成的卡自动 Upgrade。Non-stacking。
- **Mental Fortress**: 每次切换 Stance 获得 X Block。Intensity。
- **Nirvana**: 每次 Scry 获得 X Block。Intensity。
- **Rushdown**: 进入 Wrath 时抽 X 张。Intensity。
- **Simmering Rage**: 回合开始进入 Wrath。Non-stacking。
- **Study**: 回合结束把 X 张 Insight 洗入牌库。Intensity。
- **Wave of the Hand**: 获得 Block 时对全体施加 X Weak。Intensity。

#### Colorless

- **Omega**: 回合结束对全体造成 X 伤害。Intensity。
- **Magnetism**: 回合开始加入 X 张随机 Colorless 卡。Intensity。
- **Mayhem**: 回合开始打出抽牌堆顶 X 张。Intensity。
- **Panache**: 每打满 5 张卡对全体造成 X 伤害。Intensity。
- **Sadistic**: 施加 debuff 时造成 X 伤害。Intensity。
- **The Bomb**: 3 回合后爆炸，造成 40/50/60 伤害。分开堆叠。
- **Duplication**: 下 X 张卡触发两次。Counter。
- **Pen Nib**: 下一次 Attack 双倍伤害。Non-stacking。

#### 敌方 Buffs（Enemy-only）

- **Angry**: 受伤 +X Strength。Mad Gremlin。Intensity。
- **Back Attack**: 从后方造成 50% 额外伤害。Spire Shield/Spear。Non-stacking。
- **Beat of Death**: 玩家每打一张卡，受 X 伤害。Corrupt Heart。Intensity。
- **Curious**: 每次玩家打 Power，+X Strength。Awakened One。Intensity。
- **Curl Up**: 受伤时获得 X Block。Louse。Intensity。
- **Enrage**: 玩家打 Skill 时 +X Strength。Gremlin Nob。Intensity。
- **Explosive**: 3 回合后爆炸造成 X 伤害。Exploder。
- **Fading**: X 回合后死亡。Transient。Duration。
- **Flying**: 下 X 次攻击受 50% 减伤。Byrd。Intensity。
- **Invincible**: 本回合最多再失 X HP。Corrupt Heart。Intensity。
- **Life Link**: 若盟友存活则 2 回合后复活。Darkling。Non-stacking。
- **Malleable**: 受伤获得 X Block（递增）。Snake Plant, Writhing Mass。Intensity。
- **Mode Shift**: 受到 X 总伤害后切换为防御模式。Guardian。Intensity。
- **Painful Stabs**: 玩家受伤时把 X 张 Wound 加入弃牌。Corrupt Heart / Book of Stabbing。Intensity。
- **Reactive**: 受伤时改变意图。Writhing Mass。Non-stacking。
- **Regenerate (敌方)**: 回合结束治疗 X HP。Awakened One, Super Elites。Intensity。
- **Sharp Hide**: 玩家打 Attack 时受 X 伤害。Guardian。Intensity。
- **Shifting**: 失 HP 时本回合失等量 Strength。Transient。Non-stacking。
- **Split**: HP ≤ 50% 时分裂为 2 个小 slime。Acid/Spike Slime (L), Boss。Non-stacking。
- **Spore Cloud**: 死亡时施加 X Vulnerable。Fungi Beast。Intensity。
- **Stasis**: 死亡时偷走的卡回到手牌。Bronze Orb。Non-stacking。
- **Strength Up**: 回合结束 +X Strength。Orb Walker。Intensity。
- **Surrounded**: 从后方受 50% 额外伤害。Spire Shield/Spear。Non-stacking。
- **Thievery**: 攻击时偷 X 金币。Looter, Mugger。Intensity。
- **Time Warp**: 玩家打 12 张卡后回合结束并 +2 Strength。Time Eater。Counter。
- **Unawakened**: 尚未觉醒。Awakened One。Non-stacking。
- **Minion**: 首领死亡时放弃战斗。Gremlin Leader, Bronze Orb 等。Non-stacking。

### 2.2 Debuffs（减益）

#### Duration（每回合 -1）

- **Vulnerable**: 受到攻击伤害 +50%，持续 X 回合（BOSS 对玩家为 50% 也）。
- **Weak**: 造成攻击伤害 -25%，持续 X 回合。（Weak 只影响 Attack 牌，不影响 Poison / Thorns；堆叠延长时间）
- **Frail**: 卡牌获得的 Block -25%，持续 X 回合。
- **Lock-On**: Lightning 和 Dark Orb 对该敌人 +50% 伤害，持续 X 回合。
- **Draw Reduction**: 下 X 回合少抽 1 张。
- **No Block**: 下 X 回合不能从卡牌获得 Block。

#### Intensity（层数 = 强度，通常战斗持续）

- **Strength Down**: 回合结束时失去 X Strength。（Flex 等自毁机制）
- **Dexterity Down**: 回合结束时失去 X Dexterity。
- **Focus (Negative)**: Orb 效果 -X。
- **Bias**: 回合开始失去 X Focus。
- **Block Return**: 攻击该敌人时获得 X Block。
- **Fasting**: 每回合少获得 X 能量。
- **Mark**: 打出 Pressure Points 时，所有被 Mark 的敌人失 X HP。
- **Choked**: 本回合每打一张卡，目标失 X HP。
- **Corpse Explosion**: 死亡时对其他所有敌人造成 X × MaxHP 伤害。
- **Hex**: 每次打出非 Attack 卡，把 X 张 Dazed 洗入牌库。
- **Slow**: 本回合每打一张卡，目标受到 10% 更多攻击伤害。
- **Shackled**: 回合结束时获得 X Strength（技术上是 debuff，用于临时削弱敌方 Str）。
- **Constricted**: 回合结束受 X 伤害。

#### Hybrid（Intensity + Duration）

- **Poison**: 回合开始失去 X HP，然后 Poison -1。
  关联: Artifact 可抵消；Snecko Skull +1；Catalyst 翻倍；Envenom 生成。

#### Non-stacking

- **Confusion**: 每次抽牌时随机化其费用（0-3）。战斗持续。来源: Snecko Eye。
- **No Draw**: 本回合不能抽牌。单回合。
- **Entangled**: 本回合不能打 Attack。单回合。

---

## 3. Relics（遗物）

按稀有度分类。格式：**名称** | 职业 | 效果原文。

### 3.1 Starter

- **Burning Blood** | Ironclad | "At the end of combat, heal 6 HP."
- **Ring of the Snake** | Silent | "At the start of each combat, draw 2 additional cards."
- **Cracked Core** | Defect | "At the start of each combat, Channel 1 Lightning."
- **Pure Water** | Watcher | "At the start of each combat, add 1 Miracle into your hand."

### 3.2 Common

- **Akabeko** | Any | "Your first Attack each combat deals 8 additional damage."
- **Anchor** | Any | "Start each combat with 10 Block."
- **Ancient Tea Set** | Any | "Whenever you enter a Rest Site, start the next combat with 2 extra Energy."
- **Art of War** | Any | "If you do not play any Attacks during your turn, gain an additional Energy next turn."
- **Bag of Marbles** | Any | "At the start of each combat, apply 1 Vulnerable to ALL enemies."
- **Bag of Preparation** | Any | "At the start of each combat, draw 2 additional cards."
- **Blood Vial** | Any | "At the start of each combat, heal 2 HP."
- **Bronze Scales** | Any | "Start each combat with 3 Thorns."
- **Centennial Puzzle** | Any | "The first time you lose HP each combat, draw 3 cards."
- **Ceramic Fish** | Any | "Whenever you add a card to your deck, gain 9 Gold."
- **Dream Catcher** | Any | "Whenever you Rest, you may add a card to your deck."
- **Happy Flower** | Any | "Every 3 turns, gain 1 Energy."
- **Juzu Bracelet** | Any | "Regular enemy combats are no longer encountered in ? rooms."
- **Lantern** | Any | "Gain 1 Energy on the first turn of each combat."
- **Maw Bank** | Any | "Whenever you climb a floor, gain 12 Gold. No longer works when you spend any Gold at a shop."
- **Meal Ticket** | Any | "Whenever you enter a shop, heal 15 HP."
- **Nunchaku** | Any | "Every time you play 10 Attacks, gain 1 Energy."
- **Oddly Smooth Stone** | Any | "At the start of each combat, gain 1 Dexterity."
- **Omamori** | Any | "Negate the next 2 Curses you obtain."
- **Orichalcum** | Any | "If you end your turn without Block, gain 6 Block."
- **Pen Nib** | Any | "Every 10th Attack you play deals double damage."
- **Potion Belt** | Any | "Upon pickup, gain 2 Potion slots."
- **Preserved Insect** | Any | "Enemies in Elite combats have 25% less HP."
- **Regal Pillow** | Any | "Whenever you Rest, heal an additional 15 HP."
- **Smiling Mask** | Any | "The merchant's card removal service now always costs 50 Gold."
- **Strawberry** | Any | "Upon pickup, raise your Max HP by 7."
- **The Boot** | Any | "Whenever you would deal 4 or less unblocked Attack damage, increase it to 5."
- **Tiny Chest** | Any | "Every 4th ? room is a Treasure room."
- **Toy Ornithopter** | Any | "Whenever you use a potion, heal 5 HP."
- **Vajra** | Any | "At the start of each combat, gain 1 Strength."
- **War Paint** | Any | "Upon pick up, Upgrade 2 random Skills."
- **Whetstone** | Any | "Upon pickup, Upgrade 2 random Attacks."
- **Damaru** | Watcher | "At the start of your turn, gain 1 Mantra."
- **Red Skull** | Ironclad | "While your HP is at or below 50%, you have 3 additional Strength."
- **Snecko Skull** | Silent | "Whenever you apply Poison, apply an additional 1 Poison."
- **Data Disk** | Defect | "Start each combat with 1 Focus."

### 3.3 Uncommon

- **Blue Candle** | Any | "Unplayable Curse cards can now be played. Whenever you play a Curse, lose 1 HP and Exhaust it."
- **Bottled Flame** | Any | "Upon pickup, choose an Attack card. At the start of each combat, this card will be in your hand."
- **Bottled Lightning** | Any | "Upon pickup, choose a Skill card. At the start of each combat, this card will be in your hand."
- **Bottled Tornado** | Any | "Upon pickup, choose a Power card. At the start of each combat, this card will be in your hand."
- **Darkstone Periapt** | Any | "Whenever you obtain a Curse, increase your Max HP by 6."
- **Eternal Feather** | Any | "For every 5 cards in your deck, heal 3 HP whenever you enter a Rest Site."
- **Frozen Egg** | Any | "Whenever you add a Power card to your deck, Upgrade it."
- **Gremlin Horn** | Any | "Whenever an enemy dies, gain 1 Energy and draw 1 card."
- **Horn Cleat** | Any | "At the start of your 2nd turn, gain 14 Block."
- **Ink Bottle** | Any | "Whenever you play 10 cards, draw 1 card."
- **Kunai** | Any | "Every time you play 3 Attacks in a single turn, gain 1 Dexterity."
- **Letter Opener** | Any | "Every time you play 3 Skills in a single turn, deal 5 damage to ALL enemies."
- **Matryoshka** | Any | "The next 2 non-boss chests you open contain 2 Relics."
- **Meat on the Bone** | Any | "If your HP is at or below 50% at the end of combat, heal 12 HP."
- **Mercury Hourglass** | Any | "At the start of your turn, deal 3 damage to ALL enemies."
- **Molten Egg** | Any | "Whenever you add an Attack card to your deck, Upgrade it."
- **Mummified Hand** | Any | "Whenever you play a Power card, a random card in your hand costs 0 that turn."
- **Ornamental Fan** | Any | "Every time you play 3 Attacks in a single turn, gain 4 Block."
- **Pantograph** | Any | "At the start of Boss combats, heal 25 HP."
- **Pear** | Any | "Upon pickup, raise your Max HP by 10."
- **Question Card** | Any | "Future card rewards have 1 additional card to choose from."
- **Shuriken** | Any | "Every time you play 3 Attacks in a single turn, gain 1 Strength."
- **Singing Bowl** | Any | "When adding cards to your deck, you may raise your Max HP by 2 instead."
- **Strike Dummy** | Any | "Cards containing \"Strike\" deal 3 additional damage."
- **Sundial** | Any | "Every 3 times you shuffle your draw pile, gain 2 Energy."
- **The Courier** | Any | "The Merchant restocks cards, relics, and potions. All prices are reduced by 20%."
- **Toxic Egg** | Any | "Whenever you add a Skill card to your deck, Upgrade it."
- **White Beast Statue** | Any | "Potions always appear in combat rewards."
- **Duality** | Watcher | "Whenever you play an Attack, gain 1 temporary Dexterity."
- **Teardrop Locket** | Watcher | "Start each combat in Calm."
- **Paper Phrog** | Ironclad | "Enemies with Vulnerable take 75% more damage rather than 50%."
- **Self-Forming Clay** | Ironclad | "Whenever you lose HP, gain 3 Block next turn."
- **Ninja Scroll** | Silent | "At the start each combat, add 3 Shivs into your hand."
- **Paper Krane** | Silent | "Enemies with Weak deal 40% less damage rather than 25%."
- **Gold-Plated Cables** | Defect | "Your rightmost Orb triggers its passive an additional time."
- **Symbiotic Virus** | Defect | "At the start of each combat, Channel 1 Dark."

### 3.4 Rare

- **Bird-Faced Urn** | Any | "Whenever you play a Power card, heal 2 HP."
- **Calipers** | Any | "At the start of your turn, lose 15 Block rather than all of your Block."
- **Captain's Wheel** | Any | "At the start of your 3rd turn, gain 18 Block."
- **Dead Branch** | Any | "Whenever you Exhaust a card, add a random card to your hand."
- **Du-Vu Doll** | Any | "For each Curse in your deck, start each combat with 1 Strength."
- **Fossilized Helix** | Any | "Prevent the first time you would lose HP in combat."
- **Gambling Chip** | Any | "At the start of each combat, discard any number of cards, then draw that many cards."
- **Ginger** | Any | "You can no longer become Weakened."
- **Girya** | Any | "You can now gain Strength at Rest Sites (up to 3 times)."
- **Ice Cream** | Any | "Energy is now conserved between turns."
- **Incense Burner** | Any | "Every 6 turns, gain 1 Intangible."
- **Lizard Tail** | Any | "When you would die, heal to 50% of your Max HP instead (works once)."
- **Mango** | Any | "Upon pickup, raise your Max HP by 14."
- **Old Coin** | Any | "Upon pickup, gain 300 Gold."
- **Peace Pipe** | Any | "You can now remove cards from your deck at Rest Sites."
- **Pocketwatch** | Any | "Whenever you play 3 or less cards during your turn, draw 3 additional cards at the start of your next turn."
- **Prayer Wheel** | Any | "Normal enemies drop an additional card reward."
- **Shovel** | Any | "You can now Dig for relics at Rest Sites."
- **Stone Calendar** | Any | "At the end of turn 7, deal 52 damage to ALL enemies."
- **Thread and Needle** | Any | "At the start of each combat, gain 4 Plated Armor."
- **Torii** | Any | "Whenever you would receive 5 or less unblocked Attack damage, reduce it to 1."
- **Tungsten Rod** | Any | "Whenever you would lose HP, lose 1 less."
- **Turnip** | Any | "You can no longer become Frail."
- **Unceasing Top** | Any | "Whenever you have no cards in hand during your turn, draw a card."
- **Wing Boots** | Any | "You may ignore paths when choosing the next room to travel to 3 times."
- **Cloak Clasp** | Watcher | "At the end of your turn, gain 1 Block for each card in your hand."
- **Golden Eye** | Watcher | "Whenever you Scry, Scry 2 additional cards."
- **Champion Belt** | Ironclad | "Whenever you apply Vulnerable, also apply 1 Weak."
- **Charon's Ashes** | Ironclad | "Whenever you Exhaust a card, deal 3 damage to ALL enemies."
- **Magic Flower** | Ironclad | "Healing is 50% more effective during combat."
- **The Specimen** | Silent | "Whenever an enemy dies, transfer any Poison it has to a random enemy."
- **Tingsha** | Silent | "Whenever you discard a card during your turn, deal 3 damage to a random enemy."
- **Tough Bandages** | Silent | "Whenever you discard a card during your turn, gain 3 Block."
- **Emotion Chip** | Defect | "If you lost HP during the previous turn, trigger the passive ability of all Orbs at the start of your turn."

### 3.5 Shop

- **Cauldron** | Any | "When obtained, brews 5 random potions."
- **Chemical X** | Any | "The effects of your cost X cards are increased by 2."
- **Clockwork Souvenir** | Any | "Start each combat with 1 Artifact."
- **Dolly's Mirror** | Any | "Upon pickup, obtain an additional copy of a card in your deck."
- **Frozen Eye** | Any | "When viewing your Draw Pile, the cards are now shown in order."
- **Hand Drill** | Any | "Whenever you break an enemy's Block, apply 2 Vulnerable."
- **Lee's Waffle** | Any | "Upon pickup, raise your Max HP by 7 and heal all of your HP."
- **Medical Kit** | Any | "Unplayable Status cards can now be played. Whenever you play a Status card, Exhaust it."
- **Membership Card** | Any | "50% discount on all products!"
- **Orange Pellets** | Any | "Whenever you play a Power, Attack, and Skill in the same turn, remove all of your debuffs."
- **Orrery** | Any | "Upon pickup, choose and add 5 cards to your deck."
- **Prismatic Shard** | Any | "Combat reward screens now contain Colorless cards and cards from other colors."
- **Sling of Courage** | Any | "Start each Elite combat with 2 Strength."
- **Strange Spoon** | Any | "Cards which Exhaust when played will instead discard 50% of the time."
- **The Abacus** | Any | "Whenever you shuffle your draw pile, gain 6 Block."
- **Toolbox** | Any | "At the start of each combat, choose 1 of 3 random Colorless cards and add the chosen card into your hand."
- **Melange** | Watcher | "Whenever you shuffle your draw pile, Scry 3."
- **Brimstone** | Ironclad | "At the start of your turn, gain 2 Strength and ALL enemies gain 1 Strength."
- **Twisted Funnel** | Silent | "At the start of each combat, apply 4 Poison to ALL enemies."
- **Runic Capacitor** | Defect | "Start each combat with 3 additional Orb slots."

### 3.6 Boss

- **Astrolabe** | Any | "Upon pickup, Transform 3 cards, then Upgrade them."
- **Black Star** | Any | "Elites now drop an additional relic when defeated."
- **Busted Crown** | Any | "Gain 1 Energy at the start of your turn. Future card rewards have 2 less cards to choose from."
- **Calling Bell** | Any | "Upon pickup, obtain a unique Curse and 3 relics."
- **Coffee Dripper** | Any | "Gain 1 Energy at the start of your turn. You can no longer Rest at Rest Sites."
- **Cursed Key** | Any | "Gain 1 Energy at the start of your turn. Whenever you open a non-Boss chest, obtain a Curse."
- **Ectoplasm** | Any | "Gain 1 Energy at the start of your turn. You can no longer gain Gold."
- **Empty Cage** | Any | "Upon pickup, remove 2 cards from your deck."
- **Fusion Hammer** | Any | "Gain 1 Energy at the start of your turn. You can no longer Smith at Rest Sites."
- **Pandora's Box** | Any | "Upon pickup, Transform all Strike and Defend cards."
- **Philosopher's Stone** | Any | "Gain 1 Energy at the start of your turn. ALL enemies start combat with 1 Strength."
- **Runic Dome** | Any | "Gain 1 Energy at the start of your turn. You can no longer see enemy intents."
- **Runic Pyramid** | Any | "At the end of your turn, you no longer discard your hand."
- **Sacred Bark** | Any | "Double the effectiveness of potions."
- **Slaver's Collar** | Any | "During Boss and Elite combats, gain 1 Energy at the start of your turn."
- **Snecko Eye** | Any | "At the start of your turn, draw 2 additional cards. Start each combat Confused."
- **Sozu** | Any | "Gain 1 Energy at the start of your turn. You can no longer obtain potions."
- **Tiny House** | Any | "Upon pickup, obtain 1 Potion. Gain 50 Gold. Raise your Max HP by 5. Obtain 1 card. Upgrade 1 random card."
- **Velvet Choker** | Any | "Gain 1 Energy at the start of your turn. You cannot play more than 6 cards per turn."
- **Holy Water** | Watcher | "Replaces Pure Water. At the start of each combat, add 3 Miracles into your hand."
- **Violet Lotus** | Watcher | "Whenever you exit Calm, gain an additional Energy."
- **Black Blood** | Ironclad | "Replaces Burning Blood. At the end of combat, heal 12 HP."
- **Mark of Pain** | Ironclad | "Gain 1 Energy at the start of your turn. At the start of combat, shuffle 2 Wounds into your draw pile."
- **Runic Cube** | Ironclad | "Whenever you lose HP, draw 1 card."
- **Hovering Kite** | Silent | "The first time you discard a card each turn, gain 1 Energy."
- **Ring of the Serpent** | Silent | "Replaces Ring of the Snake. At the start of your turn, draw 1 additional card."
- **Wrist Blade** | Silent | "Attacks that cost 0 deal 4 additional damage."
- **Frozen Core** | Defect | "Replaces Cracked Core. If you end your turn with any empty Orb slots, Channel 1 Frost."
- **Inserter** | Defect | "Every 2 turns, gain 1 Orb slot."
- **Nuclear Battery** | Defect | "At the start of each combat, Channel 1 Plasma."

### 3.7 Event

- **Bloody Idol** | Any | "Whenever you gain Gold, heal 5 HP."
- **Cultist Headpiece** | Any | "You feel more talkative."
- **Enchiridion** | Any | "At the start of each combat, add a random Power card into your hand. It costs 0 for that turn."
- **Face of Cleric** | Any | "At the end of combat, raise your Max HP by 1."
- **Golden Idol** | Any | "Enemies drop 25% more Gold."
- **Gremlin Visage** | Any | "Start each combat with 1 Weak."
- **Mark of the Bloom** | Any | "You can no longer heal."
- **Mutagenic Strength** | Any | "Start each combat with 3 Strength. At the end of your first turn, lose 3 Strength."
- **N'loth's Gift** | Any | "Triples the chance of finding Rare cards from combat rewards."
- **N'loth's Hungry Face** | Any | "The next non-Boss chest you open is empty."
- **Necronomicon** | Any | "The first Attack played each turn that costs 2 or more is played twice. Upon pickup, obtain a special Curse."
- **Neow's Lament** | Any | "Enemies in your first 3 combats will have 1 HP."
- **Nilry's Codex** | Any | "At the end of each turn, you may shuffle 1 of 3 random cards to shuffle into your draw pile."
- **Odd Mushroom** | Any | "When Vulnerable, take 25% more attack damage rather than 50%."
- **Red Mask** | Any | "At the start of each combat, apply 1 Weak to ALL enemies."
- **Spirit Poop** | Any | "It's unpleasant."
- **Ssserpent Head** | Any | "Whenever you enter a ? room, gain 50 Gold."
- **Warped Tongs** | Any | "At the start of your turn, Upgrade a random card in your hand for the rest of combat."

### 3.8 Blight (debuff relic, from events / curse-style)

- **Accursed** | Any | "Whenever you defeat a Boss, obtain 2 random Curses."
- **Ancient Augmentation** | Any | "Enemies start combat with 1 Artifact, 10 Plated Armor, and 10 Regenerate."
- **Grotesque Trophy** | Any | "Upon pickup, obtain 3 Prides."
- **Hauntings** | Any | "Enemies start combat with 1 Intangible."
- **Mimic Infestation** | Any | "Treasure rooms in future acts are replaced by Elites. Elites no longer drop Relics."
- **Muzzle** | Any | "You can no longer increase your Max HP. All healing is halved."
- **Post-Durian** | Any | "Lose 50% of your Max HP."
- **Scatterbrain** | Any | "Draw 1 less card a turn."
- **Shield of Blight** | Any | "Enemies have 50% more HP."
- **Spear of Blight** | Any | "Enemies deal 100% more damage."
- **Time Maze** | Any | "You cannot play more than 15 cards per turn."
- **Twisting Mind** | Any | "At the end of your turn, add 1 random Status card to the top of your draw pile."
- **Void Essence** | Any | "Lose 1 Energy permanently."

### 3.9 Special

- **Circlet** | Any | "Collect as many as you can."
- **Red Circlet** | Any | "You ran out of relics. Impressive!"

> 注: Blight / Special 分类在部分 wiki 属于 mod / 特殊来源（如连续刷新拒绝奖励）。Base game 的典型分布参见 Wiki。

---

## 4. Statuses（状态卡）

战斗中加入手牌/牌堆的特殊 "垃圾" 卡。大部分 Unplayable。

- **Wound** | 0 费 (no cost) | Status | "Unplayable."
  单纯占位，无其他效果。来源: Bash+, Wild Strike, Power Through, Corrupt Heart, Book of Stabbing, Mark of Pain 等。
- **Dazed** | 0 费 | Status | "Unplayable. Ethereal."
  回合末自动 Exhaust。来源: 飞行敌人、Byrd、Hex debuff。
- **Slimed** | 1 费 | Status | "Exhaust." (可打出，消耗 1 能量然后 Exhaust，不触发任何其它效果)
  来源: Slime 敌人、Slime Boss。注意是唯一可以正常打出的 Status。
- **Burn** | 0 费 | Status | "Unplayable. At the end of your turn, take 2 (4) damage."
  Burn+ 伤害为 4。来源: Lagavulin, Guardian。
- **Void** | 0 费 | Status | "Unplayable. Ethereal. When this card is drawn, lose 1 Energy."
  抽到即失 1 能量，回合末自动消耗。来源: Reptomancer / Shelled Parasite / Nemesis / 部分关卡效果。

---

## 5. Curses（诅咒卡）

Unplayable，通常只能通过特殊方式（Blue Candle、Empty Cage、event）移除。

- **Injury** | Curse | "Unplayable."
  占位，无其他效果。
- **Regret** | Curse | "Unplayable. At the end of your turn, lose HP equal to the number of cards in your hand."
- **Decay** | Curse | "Unplayable. At the end of your turn, take 2 damage."
- **Shame** | Curse | "Unplayable. At the end of your turn, gain 1 Frail."
- **Doubt** | Curse | "Unplayable. At the end of your turn, gain 1 Weak."
- **Clumsy** | Curse | "Unplayable. Ethereal."
  回合末自动 Exhaust，不产生长期影响但占手牌。
- **Writhe** | Curse | "Innate. Unplayable."
  开局必在起手，堵 slot。（wiki 标注为 Innate Curse）
- **Parasite** | Curse | "Unplayable. If transformed or removed from your deck, lose 3 Max HP."
- **Pride** | Curse | "Innate. At the start of your turn, put a copy of this card on top of your draw pile. Exhaust."
  （由 Grotesque Trophy blight 或 event 赠予；是 wiki 记录的 "only curse that can be 'played'" 指其 Exhaust 行为）
- **Normality** | Curse | "Unplayable. You cannot play more than 3 cards this turn."
  战斗内持续到被移除或 Exhaust。
- **Pain** | Curse | "Unplayable. While in hand, lose 1 HP when other cards are played."
- **Curse of the Bell** | Curse | "Unplayable. Cannot be removed from your deck."
  可以战斗中 Exhaust（Blue Candle、Purity 等），只是不能 deck-remove。
- **Necronomicurse** | Curse | "Unplayable. There is no escape from this Curse."
  Cannot be Removed from deck; 战斗中被 Exhaust 时立刻再生一张同名卡到手。
- **Ascender's Bane** | Curse | "Unplayable. Ethereal. Cannot be removed from your deck."
  Ascension 10+ 起始牌组自带一张。Ethereal 所以自动 Exhaust，但战斗后回到牌组。

---

## 6. Orbs（Defect 专属）

格式: 名称 — Passive (end of turn) — Evoke (consume)

- **Lightning** | Passive: 回合结束对随机敌人造成 3 伤害 | Evoke: 对随机敌人造成 8 伤害
  受 Focus 影响（passive + evoke 均加）。
- **Frost** | Passive: 回合结束获得 2 Block | Evoke: 获得 5 Block
  受 Focus 影响。
- **Dark** | Passive: 回合结束其 damage 值 +6 | Evoke: 对当前 HP 最低敌人造成累积 damage
  初始值总是 6（不受 Focus 影响基础值），passive 增量受 Focus 影响。多个最低 HP 时打最左侧。
- **Plasma** | Passive: 回合开始生成 1 能量 | Evoke: 生成 2 能量
  **不受 Focus 影响**。

Orb 堆叠规则: Channel 放最右空槽；满槽时最右 Orb 被强制 Evoke 腾位。Gold-Plated Cables 让最右 Orb passive 额外触发一次。

---

## 7. Stances（Watcher 专属）

- **Neutral / No Stance**: 无加成无惩罚，默认态。Empty Body / Empty Mind / Empty Fist 可从其它 stance 退回。
- **Calm**: 在离开 Calm 时获得 2 能量（有 Violet Lotus 时为 3）。Like Water 等关联 power。
- **Wrath**: 造成双倍伤害，受到双倍伤害。Rushdown 为进入 Wrath 时额外抽牌。
- **Divinity**: 造成三倍伤害，+3 颜色能量。下回合开始自动退出。进入方式: 累积 10 Mantra、Blasphemy、Ambrosia potion。

---

## 8. 代表卡（按 keyword / mechanic 组织）

格式: **卡名** | 职业, X 费, Type, Rarity | 效果 (升级值用 括号)

### 8.1 Poison 类（Silent）

- **Deadly Poison** | Silent, 1 Cost, Skill, Common | "Apply 5 (7) Poison."
- **Bouncing Flask** | Silent, 2 Cost, Skill, Uncommon | "Apply 3 Poison to random enemy 3 (4) times."
- **Bane** | Silent, 1 Cost, Attack, Common | "Deal 7 (10) damage. If the enemy is Poisoned, deal 7 (10) damage again."
- **Catalyst** | Silent, 1 Cost, Skill, Uncommon | "Double (triple) an enemy's Poison." (wiki 未确认精确升级文本，标注)
- **Noxious Fumes** | Silent, 1 Cost, Power, Uncommon | "At the start of your turn, apply 2 (3) Poison to ALL enemies."

### 8.2 Strength / Self-buff 类（Ironclad）

- **Flex** | Ironclad, 0 Cost, Skill, Common | "Gain 2 (4) Strength. At the end of your turn, lose 2 (4) Strength."
- **Inflame** | Ironclad, 1 Cost, Power, Uncommon | "Gain 2 (3) Strength."
- **Demon Form** | Ironclad, 3 Cost, Power, Rare | "At the start of your turn, gain 2 (3) Strength."
- **Limit Break** | Ironclad, 1 Cost, Skill, Rare | "Double your Strength. Exhaust. (Upgraded: no Exhaust.)"

### 8.3 Block / Defense 类

- **Defend** | All, 1 Cost, Skill, Basic | "Gain 5 (8) Block."
- **Iron Wave** | Ironclad, 1 Cost, Attack, Common | "Gain 5 (7) Block. Deal 5 (7) damage."
- **Impervious** | Ironclad, 2 Cost, Skill, Rare | "Gain 30 (40) Block. Exhaust."
- **Entrench** | Ironclad, 2 (1) Cost, Skill, Uncommon | "Double your Block."
- **Barricade** | Ironclad, 3 (2) Cost, Power, Rare | "Block is not removed at the start of your turn."
- **Metallicize** | Ironclad, 1 Cost, Power, Uncommon | "At the end of your turn, gain 3 (4) Block."

### 8.4 Exhaust 协同

- **Feel No Pain** | Ironclad, 1 Cost, Power, Uncommon | "Whenever a card is Exhausted, gain 3 (4) Block."
- **Dark Embrace** | Ironclad, 2 (1) Cost, Power, Uncommon | "Whenever a card is Exhausted, draw 1 card."
- **Corruption** | Ironclad, 3 (2) Cost, Power, Rare | "Skills cost 0. Whenever you play a Skill, Exhaust it."
- **Sever Soul** | Ironclad, 2 Cost, Attack, Uncommon | "Exhaust all non-Attack cards in your hand. Deal 16 (22) damage."

### 8.5 Ethereal

- **Ghostly Armor** | Ironclad, 1 Cost, Skill, Uncommon | "Ethereal. Gain 10 (13) Block."
- **Carnage** | Ironclad, 2 Cost, Attack, Uncommon | "Ethereal. Deal 20 (28) damage."
- **Apparition** | Colorless, 1 Cost, Skill, Special | "Ethereal. Gain 1 Intangible. Exhaust." (升级去掉 Ethereal)

### 8.6 Retain（Watcher）

- **Deceive Reality** | Watcher, 1 Cost, Skill, Uncommon | "Gain 4 (7) Block. Add a Safety to your hand. Retain."
- **Wish** | Watcher, 3 Cost, Skill, Rare | "Choose one: gain 4 (6) Strength, 25 (30) Gold, or heal 5 (8) HP. Retain."
- **Nightmare** | Watcher, 3 (2) Cost, Skill, Rare | "Choose a card. Next turn, add 3 copies of that card into your hand. Exhaust."

### 8.7 Innate

- **Writhe** (curse) | Curse | "Innate. Unplayable."
- **Brutality** | Ironclad, 0 Cost, Power, Rare | "At the start of your turn, lose 1 HP and draw 1 card. (Upgrade: Innate.)"
- **Mind Blast** | Colorless, 2 Cost, Attack, Uncommon | "Innate. Deal damage equal to the number of cards in your draw pile."

### 8.8 Vulnerable 施加

- **Bash** | Ironclad, 2 Cost, Attack, Basic | "Deal 8 (10) damage. Apply 2 (3) Vulnerable."
- **Thunderclap** | Ironclad, 1 Cost, Attack, Common | "Deal 4 (7) damage and apply 1 Vulnerable to ALL enemies."
- **Sword Boomerang** | Ironclad, 1 Cost, Attack, Common | "Deal 3 damage to a random enemy 3 (4) times."（不是 vuln 但常代表随机打击）

### 8.9 Weak 施加

- **Clothesline** | Ironclad, 2 Cost, Attack, Common | "Deal 12 (14) damage. Apply 2 (3) Weak."
- **Cold Snap** | Ironclad, 1 Cost, Attack, Common | "Deal 6 (9) damage. Channel 1 Frost." (Colorless 变体见 Dramatic Entrance)
- **Leg Sweep** | Silent, 2 Cost, Skill, Uncommon | "Apply 2 (3) Weak. Gain 11 (14) Block."
- **Shockwave** | Ironclad, 2 Cost, Skill, Uncommon | "Apply 3 (5) Weak and Vulnerable to ALL enemies. Exhaust."

### 8.10 Orbs / Channel（Defect）

- **Zap** | Defect, 1 Cost, Skill, Basic | "Channel 1 Lightning."
- **Dualcast** | Defect, 1 Cost, Skill, Basic | "Evoke your next Orb twice." (wiki: "Evoke your right-most Orb twice")
- **Ball Lightning** | Defect, 1 Cost, Attack, Common | "Deal 7 (10) damage. Channel 1 Lightning."
- **Streamline** | Defect, 2 Cost, Attack, Common | "Deal 15 (20) damage. Whenever you play this, reduce its cost by 1 for this combat."
- **Chaos** | Defect, 1 Cost, Skill, Common | "Channel 1 (2) random Orbs."
- **Consume** | Defect, 2 Cost, Skill, Uncommon | "Gain 2 (3) Focus. Lose 1 Orb slot."
- **Sunder** | Defect, 3 Cost, Attack, Rare | "Deal 24 (32) damage. Evoke your right-most Orb." (wiki 原文不完全确认，标注)
- **Meteor Strike** | Defect, 5 Cost, Attack, Rare | "Deal 24 (30) damage. Channel 3 Plasma."
- **All for One** | Defect, 2 Cost, Attack, Rare | "Deal 10 (14) damage. Put all 0-cost cards from your Discard Pile into your Hand."

### 8.11 Focus

- **Focus Power** (Focus) | Defect, 1 Cost, Power, Uncommon | "Gain 2 (3) Focus." (wiki 名可能为 "Biased Cognition" / "Focus"，两张不同)
- **Biased Cognition** | Defect, 1 Cost, Power, Rare | "Gain 4 (5) Focus. At the start of your turn, lose 1 Focus."
- **Defragment** | Defect, 1 Cost, Power, Uncommon | "Gain 1 (2) Focus."

### 8.12 Stances / Mantra（Watcher）

- **Eruption** | Watcher, 2 (1) Cost, Attack, Basic | "Deal 9 damage. Enter Wrath."
- **Vigilance** | Watcher, 2 (1) Cost, Skill, Basic | "Gain 8 (12) Block. Enter Calm."
- **Crescendo** | Watcher, 1 (0) Cost, Skill, Uncommon | "Retain. Enter Wrath. Exhaust."
- **Vault** | Watcher, 3 (2) Cost, Skill, Rare | "End your turn. Exhaust." (wiki: Take an additional turn)
- **Tantrum** | Watcher, 1 Cost, Attack, Uncommon | "Deal 3 damage 3 (4) times. Shuffle this card into your draw pile. Enter Wrath."
- **Worship** | Watcher, 1 Cost, Skill, Uncommon | "Gain 5 (7) Mantra."
- **Prostrate** | Watcher, 0 Cost, Skill, Common | "Gain 2 (3) Mantra. Gain 3 (4) Block."
- **Pray** | Watcher, 1 Cost, Skill, Common | "Gain 3 (4) Mantra. Shuffle an Insight into your draw pile. Retain."
- **Devotion** | Watcher, 1 Cost, Power, Uncommon | "At the start of your turn, gain 2 (3) Mantra."

### 8.13 Scry

- **Foreign Influence** | Watcher, 1 Cost, Attack, Uncommon | "Choose 1 of 3 (4) Attack cards. Add it to your hand."（wiki 原文为 Scry 相关? 待核实，标注）
- **Third Eye** | Watcher, 1 Cost, Skill, Common | "Gain 7 (9) Block. Scry 3 (5)."
- **Scrawl** | Watcher, 1 Cost, Skill, Uncommon | "Draw cards until your hand is full. Exhaust." (严格说不是 Scry 但常配合)
- **Foresight** | Watcher, 1 Cost, Power, Uncommon | "At the start of your turn, Scry 3 (4)."
- **Weave** | Watcher, 1 Cost, Attack, Common | "Deal 4 (6) damage. If this card was scried, gain 4 (6) additional damage."（升级精确文本需核实，标注）

### 8.14 Miracle

- **Miracle** | Watcher / Colorless, 0 Cost, Skill, Uncommon | "Retain. Gain 1 (2) Energy. Exhaust."

### 8.15 Damage 倍率 / 自增攻击

- **Searing Blow** | Ironclad, 2 Cost, Attack, Uncommon | "Deal 12 damage. Can be Upgraded any number of times (scaling damage)."
- **Whirlwind** | Ironclad, X Cost, Attack, Uncommon | "Deal 5 (8) damage to ALL enemies X times."
- **Immolate** | Ironclad, 2 Cost, Attack, Rare | "Deal 21 (28) damage to ALL enemies. Add a Burn to your discard pile."

### 8.16 Self-damage / 风险高回报

- **Hemokinesis** | Ironclad, 1 Cost, Attack, Uncommon | "Lose 2 HP. Deal 15 (20) damage."
- **Offering** | Ironclad, 0 Cost, Skill, Rare | "Lose 6 HP. Gain 2 Energy. Draw 3 (5) cards. Exhaust."
- **Reaper** | Ironclad, 2 Cost, Attack, Rare | "Deal 4 (5) damage to ALL enemies. Heal HP equal to unblocked damage dealt. Exhaust."

### 8.17 Shiv（Silent Colorless 协同）

- **Blade Dance** | Silent, 1 Cost, Skill, Uncommon | "Add 3 (4) Shivs to your hand."
- **Cloak and Dagger** | Silent, 1 Cost, Skill, Common | "Gain 6 Block. Add 1 (2) Shivs to your hand."
- **Accuracy** (Power) — 见 Powers 部分

### 8.18 Discard 协同（Silent）

- **Reflex** | Silent, 0 Cost, Skill, Uncommon | "Unplayable. If this card is discarded from your hand, draw 2 (3) cards."
- **Tactician** | Silent, 2 (1) Cost, Skill, Uncommon | "Unplayable. When this card is discarded from your hand, gain 1 Energy."
- **Dagger Throw** | Silent, 1 Cost, Attack, Common | "Deal 9 (12) damage. Draw 1 card. Discard 1 card."
- **Calculated Gamble** | Silent, 1 Cost, Skill, Uncommon | "Discard your hand. Draw that many cards. (Upgrade: no Exhaust)"

### 8.19 Mark / Lock-On / 计数型 debuff

- **Pressure Points** | Watcher, 1 Cost, Attack, Uncommon | "Apply 8 (11) Mark. Deal damage to all enemies equal to their Mark."
- **Rip and Tear** | (wiki 未确认, 标注)

### 8.20 Curse 利用

- **Pride** (curse) — Grotesque Trophy / Necronomicon 给予
- **Blue Candle** (relic) — 让 Curse 可打并 Exhaust

### 8.21 Colorless 代表

- **Apotheosis** | Colorless, 2 (1) Cost, Skill, Rare | "Upgrade ALL cards in your deck for the rest of combat. Exhaust."
- **Bite** | Colorless, 1 Cost, Attack, Special | "Deal 7 (8) damage. Heal 2 (3) HP." (Snecko event)
- **Dramatic Entrance** | Colorless, 0 Cost, Attack, Uncommon | "Innate. Deal 8 (12) damage to ALL enemies. Exhaust."
- **Finesse** | Colorless, 0 Cost, Skill, Uncommon | "Gain 2 (4) Block. Draw 1 card."
- **Mind Blast** — 见 Innate 部分
- **Panacea** | Colorless, 0 Cost, Skill, Uncommon | "Gain 1 (2) Artifact. Exhaust."
- **Transmutation** | Colorless, X Cost, Skill, Rare | "Add X random colorless cards into your hand. They cost 0 this turn. Exhaust."
- **Violence** | Colorless, 0 Cost, Skill, Rare | "Put 3 (4) random Attack cards from your draw pile into your hand."

---

## 9. 数据可疑 / 未完全确认清单

以下项在抓取过程中 wiki 未直接提供或跨源不一致，设计时需自行核对：

1. **Curse "Pride" 准确文本**: wiki 描述为 "Innate. Exhausts at end of turn, reshuffles to top of draw pile."（即战斗内无法摆脱），需核对。
2. **Catalyst 升级文本**: 基础效果 "Double target's Poison"，升级是 "Triple" 还是 "Multiply by 3"——有两种说法。
3. **Sunder / Vault 精确效果**：Vault wiki 原文 "Take an extra turn" vs "End turn"，以实际 wiki 为准。
4. **Foreign Influence / Weave**（Watcher Scry 相关）升级数值需再核。
5. **Dualcast**: "Evoke your right-most Orb twice" — 升级降费还是强化待核。
6. **Scry 的升级普遍是 +2** 但 Third Eye / Foresight 等不完全一致。
7. **Blight relics** 在 base game Slay the Spire（非 Downfall mod）中分类存疑；有几个可能来自 Downfall / mods。
8. **Draw Card / Energized** 作为 buff 和同名卡片效果分别呈现，定义上略有重叠。
9. **Rupture** 升级机制（触发一次性 vs 永续）需核。
10. **Curse of the Bell 的获取方式**: 仅来自 Calling Bell relic，wiki 未在 curse 页明示。

---

## 10. 统计汇总

- **Keywords**: ~30+ (Block / Energy / Exhaust / Ethereal / Innate / Retain / Unplayable / Upgrade / Discard / Channel / Evoke / Focus / Stance / Scry / Poison / Vulnerable / Weak / Frail / Strength / Dexterity / Intangible / Artifact / Barricade / Metallicize / Plated Armor / Thorns / Regen / Vigor / Mantra / Lock-On / Mark / Ritual / Split / ...)
- **Powers (Buffs)**: ~75 (通用 ~12 / Ironclad ~13 / Silent ~15 / Defect ~15 / Watcher ~17 / Colorless ~8 / Enemy ~25+)
- **Powers (Debuffs)**: ~25
- **Relics**: ~180
  - Starter: 4
  - Common: 36
  - Uncommon: 37
  - Rare: 32
  - Shop: 20
  - Boss: 29
  - Event: 18
  - Blight: 13
  - Special: 2
- **Statuses**: 5 (Wound, Dazed, Slimed, Burn, Void)
- **Curses**: 14 (Injury, Regret, Decay, Shame, Doubt, Clumsy, Writhe, Parasite, Pride, Normality, Pain, Curse of the Bell, Necronomicurse, Ascender's Bane)
- **Orbs**: 4 (Lightning / Frost / Dark / Plasma)
- **Stances**: 4 (Neutral / Calm / Wrath / Divinity)
- **代表卡**: ~80 张（跨机制族分布）

---

## 参考源

- [Keywords - Slay the Spire Wiki (wiki.gg)](https://slaythespire.wiki.gg/wiki/Keywords)
- [Buffs - Slay the Spire Wiki (wiki.gg)](https://slaythespire.wiki.gg/wiki/Buffs)
- [Debuffs - Slay the Spire Wiki (wiki.gg)](https://slaythespire.wiki.gg/wiki/Debuffs)
- [Relics_List - Slay the Spire Wiki (wiki.gg)](https://slaythespire.wiki.gg/wiki/Relics_List)
- [Orb - Slay the Spire Wiki (wiki.gg)](https://slaythespire.wiki.gg/wiki/Orb)
- [Stance - Slay the Spire Wiki (wiki.gg)](https://slaythespire.wiki.gg/wiki/Stance)
- [Status cards - slaythespire.gg](https://slaythespire.gg/cards/status)
- [Curse cards - slaythespire.gg](https://slaythespire.gg/cards/curse)


