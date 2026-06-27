# Plan V2: 神谕系统 + 怪物战斗 + Boss门 + 地图扩展

## Context

当前 demo 实现了小人通过效用 AI 自主发展（采集→建造→科技）。现在要实现**玩家介入系统**和**游戏目标**：

- **玩家介入**：通过"神谕"(God Voice) 给小人方向性指引，修改效用 AI 权重偏移，不是直接命令
- **游戏目标**：打怪 → 开新区域 → 获得更多材料 → 解锁更高科技
- **地图结构**：营地周围是安全区，外围是怪物区，边界山脉上有 Boss 门

设计决策：
- 自动战斗（装备/属性决定）
- 怪物在外围巡逻，小人在"探索远方"神谕下才会触及
- 边界扩展（Boss 死后山脉打开，新区域无缝接入）
- 普通怪 AI 自动清理，Boss 通过"挑战守护者"神谕发起

---

## 游戏节奏

```
自主发展(建营地、科技)
  → 玩家发"探索远方" → 小人范围扩大，遭遇怪物
  → 玩家发"武装起来" → 小人优先做武器装甲
  → 武装后再探索，清理外围怪物
  → 玩家发"挑战守护者" → 小人组队打Boss
  → Boss死 → 山脉打开 → 新区域、新资源、新怪物
  → 循环
```

---

## Step 1: 神谕系统 (God Voice)

核心机制：玩家从预设神谕列表中激活一条，全局修改所有小人的效用 AI 权重。小人仍自主决策，只是优先级发生偏移。

### 1.1 DecreeManager (新 Autoload)

**新建: `scripts/systems/decree_manager.gd`**

```gdscript
extends Node

signal decree_changed(decree_id: String)

enum Decree { NONE, EXPLORE, ARM, RESEARCH, BUILD, CHALLENGE }

var active_decree: int = Decree.NONE
var _decree_data: Dictionary = {
    Decree.NONE:      { "id": "none",      "name": "自由发展", "desc": "小人按自身需求自主行动" },
    Decree.EXPLORE:   { "id": "explore",   "name": "探索远方", "desc": "扩大探索和采集范围" },
    Decree.ARM:       { "id": "arm",       "name": "武装起来", "desc": "优先制作武器装甲，积极战斗" },
    Decree.RESEARCH:  { "id": "research",  "name": "追求知识", "desc": "优先科技研究" },
    Decree.BUILD:     { "id": "build",     "name": "建设家园", "desc": "优先建造和采集材料" },
    Decree.CHALLENGE: { "id": "challenge", "name": "挑战守护者", "desc": "武装小人前往Boss门挑战" },
}
```

提供查询接口：
- `get_utility_modifier(action_name: String) -> float` — 返回当前神谕对某行为的效用加成
- `get_range_multiplier() -> float` — 探索/采集范围倍率
- `is_challenge_active() -> bool`

### 1.2 各神谕的效用修正

| 神谕 | 效用修正 | 范围修正 | 解锁条件 |
|------|---------|---------|---------|
| 自由发展 | 无 | 1.0x | 始终可用 |
| 探索远方 | explore +0.3, gather +0.1 | explore 2.0x, gather 1.5x | 始终可用 |
| 武装起来 | craft(weapon/armor) +0.3, fight +0.2 | 1.0x | 有工作台 |
| 追求知识 | research +0.3 | 1.0x | 有研究台 |
| 建设家园 | build +0.2, gather_mat +0.2 | 1.0x | 始终可用 |
| 挑战守护者 | fight_boss → 0.95 (压过一切) | 1.0x | 有 Boss 门 + 2 名持武器小人 |

### 1.3 Action 层对接

每个 Action 的 `calculate_utility` 末尾加一行：
```gdscript
score += DecreeManager.get_utility_modifier("action_name")
return clampf(score, 0.0, 1.0)
```

范围相关的 Action（explore, gather_food, gather_mat）读取 `DecreeManager.get_range_multiplier()` 乘以 MAX_GATHER_RANGE / MAX_EXPLORE_RANGE。

### 1.4 神谕 UI 面板

**新建: `scripts/ui/decree_panel.gd` + `scenes/ui/decree_panel.tscn`**

- 屏幕右侧竖排按钮面板
- 每条神谕一个按钮，显示名称 + 简短描述
- 当前激活的神谕高亮显示
- 不满足解锁条件的神谕灰显
- 快捷键 V 打开/关闭面板

**修改: `scenes/main.tscn`** — UI 层添加 DecreePanel

**修改: `project.godot`** — 添加 DecreeManager Autoload

### 1.5 修改的现有 Action 文件

需要在 `calculate_utility` 中加入 `DecreeManager` 修正的文件：
- `action_explore.gd` — +decree modifier, 范围乘以 range_multiplier
- `action_gather_food.gd` — 范围乘以 range_multiplier
- `action_gather_mat.gd` — +decree modifier, 范围乘以 range_multiplier
- `action_build.gd` — +decree modifier
- `action_research.gd` — +decree modifier
- `action_craft.gd` — +decree modifier (区分武器/普通)
- `action_rest.gd` — 无变化
- `action_eat.gd` — 无变化

---

## Step 2: 怪物实体 + 外围生成

### 2.1 Monster 实体

**新建: `scripts/entities/monster.gd` + `scenes/entities/monster.tscn`**

场景结构: `CharacterBody2D` (和 Villager 一致) + Sprite2D

属性:
```
monster_type: String       # "wolf", "snake"
max_health: float
health: float
attack_damage: float
attack_speed: float        # 攻击间隔(秒)
detection_range: float     # 发现小人的距离(px)
patrol_range: float        # 巡逻半径(px)
move_speed: float
loot_table: Dictionary     # {"raw_meat": 1, "hide": 1}
spawn_position: Vector2    # 出生点
```

状态机 (enum State { PATROL, CHASE, ATTACK, DEAD }):
- **PATROL**: 在 spawn_position 附近 patrol_range 内随机走动
- **CHASE**: 检测到 detection_range 内的小人 → 追击最近的
- **ATTACK**: 追上后（距离 < 16px）每隔 attack_speed 秒对目标小人调用 `villager.take_damage(attack_damage)`
- **DEAD**: 在自身位置生成 GroundItem 掉落物，queue_free

小人离开检测范围 → 回到 PATROL，但追击最远不超过 `patrol_range * 2` 距离。

像素画: 狼用灰色四脚图案，蛇用绿色蜿蜒图案（类似现有像素画风格）。

### 2.2 怪物生成

**修改: `scripts/world/world_generator.gd`**

新增 `spawn_monsters(terrain, container, village_center, safe_radius)`:
- 安全区: 距 village_center `safe_radius`(30 tiles) 内不生成
- Forest tile: 3% 概率生成 wolf
- Rock tile: 2% 概率生成 snake
- 总数上限 10 只（zone 0）

Zone 0 怪物:

| 类型 | 地形 | HP | 攻击 | 攻击间隔 | 速度 | 检测范围 | 巡逻半径 | 掉落 |
|------|------|-----|------|---------|------|---------|---------|------|
| Wolf | Forest | 30 | 8 | 2.0s | 40 | 80px | 48px | raw_meat x1, hide x1 |
| Snake | Rock | 15 | 12 | 2.5s | 30 | 50px | 32px | raw_meat x1 |

### 2.3 World 层面变更

**修改: `scripts/world/world.gd`**

- 在 World 节点下新增 `Monsters` (Node2D) 子节点容器
- `_ready()` 中调用 `world_generator.spawn_monsters()`
- 添加怪物重生定时器: 每 60 游戏秒检查，若怪物数 < 上限，在外围随机位置补生

---

## Step 3: 小人战斗 + ActionFight

### 3.1 小人战斗属性

**修改: `scripts/entities/villager.gd`**

新增方法:
```gdscript
func get_attack_damage() -> float:
    var weapon: String = get_equipped("weapon")
    if weapon != "":
        return _weapon_damage(weapon)
    var tool: String = get_equipped("tool")
    if tool != "":
        return _tool_as_weapon_damage(tool)
    return 5.0  # 赤手空拳

func _weapon_damage(weapon: String) -> float:
    match weapon:
        "bone_knife": return 12.0
        "iron_sword": return 20.0
        _: return 5.0

func _tool_as_weapon_damage(tool: String) -> float:
    match tool:
        "stone_axe": return 10.0
        "stone_pickaxe": return 8.0
        _: return 5.0

func get_damage_reduction() -> float:
    var armor: String = get_equipped("armor")
    match armor:
        "leather_armor": return 0.3  # 减伤30%
        _: return 0.0

func take_damage(amount: float) -> void:
    var reduction := get_damage_reduction()
    var actual := amount * (1.0 - reduction)
    needs.health = clampf(needs.health - actual, 0.0, 100.0)
    if _ai:
        _ai.force_reevaluate()

func is_armed() -> bool:
    return get_equipped("weapon") != "" or get_equipped("tool") != ""
```

### 3.2 ActionFight

**新建: `scripts/ai/actions/action_fight.gd`**

```
enum Phase { APPROACHING, FIGHTING }

can_execute:
  - health > 30
  - 附近有怪物 (在 120px * range_multiplier 内)
  - 或者正在被怪物攻击 (无论范围)

calculate_utility:
  - 被攻击中: 0.85 (自卫优先)
  - 附近有怪物且有装备: 0.6 + decree_modifier
  - 附近有怪物但无装备: 0.3 (勉强应战)
  - health < 40: 大幅降低 (倾向逃跑)

start: 找最近怪物，navigate_to
tick:
  APPROACHING: 走向怪物，到达后切到 FIGHTING
  FIGHTING: 每 2.0s (attack_speed) 调用 monster.take_damage(get_attack_damage())
            怪物死亡 → completed
            自身 health < 20 → cancel (逃跑)

cancel: 停止攻击，释放目标
```

**修改: `scripts/entities/villager_ai.gd`** — 注册 ActionFight

### 3.3 怪物查找

为 ActionFight 找附近怪物，在 action 中直接遍历 `World/Monsters` 子节点：
```gdscript
func _find_nearest_monster(villager: Villager, max_range: float) -> Node
```

Monster 同样遍历 `World/Villagers` 找附近小人。

---

## Step 4: 战斗相关物品 + 科技

### 4.1 新物品

**修改: `scripts/entities/villager_inventory.gd`**

新增配方:
```gdscript
"bone_knife": return {"bone": 2, "fiber": 1}
"leather_armor": return {"hide": 3, "rope": 1}
"iron_sword": return {"iron_ingot": 2, "wood": 1}
```

### 4.2 新科技

**修改: `scripts/systems/tech_tree.gd`**

```gdscript
_register_tech("combat_basics", "战斗训练", "解锁皮甲制作",
    [], {"hide": 2, "wood": 3}, 15.0, "recipe", {"leather_armor": true})

_register_tech("bone_tools", "骨器", "解锁骨刀制作",
    [], {"bone": 3, "fiber": 2}, 12.0, "recipe", {"bone_knife": true})

_register_tech("weaponry", "武器锻造", "解锁铁剑制作",
    ["smelting"], {"iron_ingot": 2, "bone": 2}, 25.0, "recipe", {"iron_sword": true})
```

### 4.3 Craft 对接

**修改: `scripts/ai/actions/action_craft.gd`**

`_find_recipe` 增加武器/装甲配方检查。制作完成后 equip 到对应 slot：
- `bone_knife`, `iron_sword` → `villager.equip("weapon", _recipe)`
- `leather_armor` → `villager.equip("armor", _recipe)`

---

## Step 5: Boss 门 + Boss 挑战

### 5.1 Boss 门实体

**新建: `scripts/entities/boss_gate.gd`**

放在地图 4 个边界的中点位置。
像素画: 山脉上的发光裂缝/传送门。

### 5.2 Boss 实体

复用 Monster 基础架构:
- 不巡逻 — 原地不动直到挑战激活
- 死亡后触发地图扩展

Zone 0 Boss:

| 方向 | Boss | HP | 攻击 | 攻击间隔 | 掉落 |
|------|------|-----|------|---------|------|
| 4个门统一 | 巨熊 | 200 | 15 | 1.5s | raw_meat x5, hide x3, bear_claw x1 |

### 5.3 挑战守护者神谕

激活"挑战守护者"时:
1. 选择最近的未击败 Boss 门
2. 至少 2 名持武器且 health > 50 的小人
3. ActionFightBoss 效用 0.95 压过一切

**新建: `scripts/ai/actions/action_fight_boss.gd`**

多人同时攻击 Boss，Boss 每次攻击间隔选一名小人攻击。
Boss 死亡 → gate.is_defeated = true → 触发 map expansion
全体挑战者 health < 20 → 挑战失败，神谕自动切回"自由发展"

---

## Step 6: 地图扩展

### 6.1 扩展机制

Boss 死亡时 `expand_map(direction)`:
1. 该方向 terrain_data 增加 80 tiles
2. 旧边界山脉移除
3. 新区域用不同 biome 参数生成
4. 生成新资源 + 新怪物（更强）
5. 新外边界放置新 Boss 门
6. 更新 TileMap、迷雾、摄像机边界

### 6.2 新区域内容

Zone 1 (沼泽):

| 新资源 | 地形 | 用途 |
|--------|------|------|
| herb (药草) | Grass(zone1) | 制药/恢复生命 |
| clay (黏土) | Sand(zone1) | 高级建筑材料 |

Zone 1 怪物:

| 类型 | HP | 攻击 | 掉落 |
|------|-----|------|------|
| 毒蛇 | 25 | 15 | raw_meat x1, bone x1 |
| 沼泽蜥蜴 | 40 | 10 | hide x2, bone x1 |

### 6.3 简化策略

首次只做 **east 方向** 扩展作为概念验证，确认流程跑通后再补充其他方向。

---

## 完整文件清单

| Step | 内容 | 新文件 | 修改文件 |
|------|------|--------|----------|
| 1 | 神谕系统 | `decree_manager.gd`, `decree_panel.gd`, `decree_panel.tscn` | 所有 action_*.gd, `project.godot`, `main.tscn` |
| 2 | 怪物实体 | `monster.gd`, `monster.tscn` | `world_generator.gd`, `world.gd` |
| 3 | 战斗系统 | `action_fight.gd` | `villager.gd`, `villager_ai.gd` |
| 4 | 战斗物品 | — | `villager_inventory.gd`, `tech_tree.gd`, `action_craft.gd` |
| 5 | Boss 门 | `boss_gate.gd`, `action_fight_boss.gd` | `world_generator.gd`, `world.gd`, `game_manager.gd` |
| 6 | 地图扩展 | — | `world.gd`, `world_generator.gd`, `resource_node.gd` |

## 验证方法

每 Step 运行游戏测试:
1. 神谕面板可打开，切换神谕后小人行为偏移可观察（日志中 score 变化）
2. 怪物在外围巡逻，不进入 30 tile 安全区
3. "探索远方"后小人走向外围，遇到怪物自动战斗
4. "武装起来"后小人优先制作武器装甲
5. "挑战守护者"后小人组队走向 Boss 门并战斗
6. Boss 击杀后东侧地图扩展，出现新地形
