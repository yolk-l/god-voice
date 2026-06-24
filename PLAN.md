# Free Farm — 游戏设计与开发计划

## 一、项目概述

**引擎**: Godot 4.x (GDScript)  
**类型**: 单机、上帝视角、自治模拟、资源管理  
**核心体验**: 玩家扮演神明，俯瞰一片随机生成的大地，观察小人自主采集、建造、研究、扩张。小人通过效用 AI 自行决策，玩家通过全局性手段（待定）引导文明发展方向。击败地图边界 Boss 后解锁新区域，循环推进科技树。

**灵感来源**:
- Simmiland：上帝视角 + 小人自治（去掉打牌机制）
- 饥荒：资源采集 → 科技解锁 → 生存挑战的成长路线
- Rimworld：效用 AI 驱动的小人决策系统

**Demo 目标**: 实现 **第一阶地图的随机生成** 和 **小人的自主演化**（采集→生存→初级科技），不含玩家干预手段和 Boss 战斗。

---

## 二、核心玩法循环

```
随机地图生成 → 小人出生 → 效用AI自主决策 → 采集资源 → 满足需求 → 解锁科技
     ↑                                                              ↓
  新区域/新资源  ←──  击败边界Boss  ←──  积累高级资源/科技  ←──────┘
```

完整版中，每个"地图阶段"代表一个生态圈，拥有独特的资源、威胁和 Boss。Demo 只做第一阶。

**Demo 中的最小循环**:
```
小人出生(草地中心) → 饥饿上升 → 寻找浆果采集 → 进食 → 体力下降 → 休息
         ↓
  背包满/附近资源减少 → 探索新区域 → 发现新资源点
         ↓
  有足够木材+草纤维 → 建造草棚 → 夜晚有庇护
         ↓
  有足够石头+木材 → 建造工作台 → 制作工具 → 效率提升 → 资源积累加速
```

---

## 三、技术架构

### 3.1 项目目录结构

```
free-farm/
├── project.godot
├── PLAN.md
│
├── scenes/
│   ├── main.tscn                  # 主场景，挂载世界和 UI
│   ├── world/
│   │   ├── world.tscn             # 世界根节点
│   │   ├── tile_map.tscn          # 地形 TileMap
│   │   └── resource_node.tscn     # 可采集资源点（树、石、浆果等）
│   ├── entities/
│   │   ├── villager.tscn          # 小人场景
│   │   └── building.tscn          # 建筑场景
│   └── ui/
│       ├── hud.tscn               # 顶部资源/人口信息
│       └── tech_tree_panel.tscn   # 科技树面板（Demo 中只读展示）
│
├── scripts/
│   ├── world/
│   │   ├── world_generator.gd     # 地图生成算法
│   │   ├── world.gd               # 世界管理：昼夜、时间、全局事件
│   │   └── resource_node.gd       # 资源点行为
│   ├── entities/
│   │   ├── villager.gd            # 小人主脚本
│   │   ├── villager_needs.gd      # 需求系统（饥饿、体力、安全感）
│   │   ├── villager_inventory.gd  # 小人背包
│   │   └── villager_ai.gd         # 效用 AI 决策器
│   ├── ai/
│   │   ├── utility_ai.gd          # 通用效用 AI 框架
│   │   ├── action.gd              # 行为基类
│   │   └── actions/               # 具体行为实现
│   │       ├── action_gather_food.gd
│   │       ├── action_gather_mat.gd
│   │       ├── action_eat.gd
│   │       ├── action_rest.gd
│   │       ├── action_build.gd
│   │       ├── action_explore.gd
│   │       ├── action_craft.gd
│   │       ├── action_deposit.gd
│   │       ├── action_pickup.gd
│   │       └── action_idle.gd
│   ├── systems/
│   │   ├── tech_tree.gd           # 科技树管理
│   │   ├── resource_manager.gd    # 全局资源/库存管理
│   │   └── building_manager.gd    # 建筑放置与管理
│   └── data/
│       └── tech_data.gd           # 科技定义数据
│
├── resources/                     # Godot Resource 文件（.tres）
│   ├── tiles/                     # TileSet 资源
│   └── tech/                      # 科技 Resource
│
└── assets/                        # 美术/音频素材（全部用占位色块）
    ├── sprites/
    ├── tiles/
    └── audio/
```

### 3.2 场景树设计

```
Main (Node2D)
├── World (Node2D)
│   ├── TileMap                    # 地形层
│   ├── ResourceNodes (Node2D)     # 资源点容器
│   ├── Buildings (Node2D)         # 建筑容器
│   └── Villagers (Node2D)         # 小人容器
├── Camera2D                       # 玩家视角摄像机（可拖拽/缩放）
├── DayNightCycle (CanvasModulate) # 昼夜光照
└── UI (CanvasLayer)
    ├── HUD
    └── TechTreePanel
```

### 3.3 自动加载（Autoload/Singleton）

| 单例名           | 职责                                     |
| ---------------- | ---------------------------------------- |
| GameManager      | 游戏状态、时间流速控制、暂停             |
| TechTree         | 全局科技树状态，已解锁科技列表           |
| ResourceManager  | 全局已知资源点注册表，供 AI 查询         |
| BuildingManager  | 已建建筑列表，建筑放置验证               |

---

## 四、模块详细设计

### 4.1 地图生成 (`world_generator.gd`)

**算法**: 基于噪声的分层生成（FastNoiseLite）

**地形类型（第一阶）**:

| 地形     | 噪声值范围   | 特征                 | 可放置资源         |
| -------- | ------------ | -------------------- | ------------------ |
| 深水     | < -0.3       | 不可通行             | 无                 |
| 浅水     | -0.3 ~ -0.1  | 不可通行，可捕鱼(后期) | 鱼群               |
| 沙地     | -0.1 ~ 0.0   | 可通行，移动正常     | 芦苇、贝壳         |
| 草地     | 0.0 ~ 0.3    | 可通行，主要活动区   | 浆果丛、草药       |
| 森林     | 0.3 ~ 0.6    | 可通行，移速降低     | 树木、蘑菇、野兽   |
| 岩地     | 0.6 ~ 0.8    | 可通行，移速降低     | 石头、矿石         |
| 山脉     | > 0.8        | 不可通行（边界墙）   | 无                 |

**生成流程**:
1. 使用 `FastNoiseLite` 生成高度图噪声（type: Simplex, frequency: 0.03~0.05）
2. 根据阈值划分地形类型，写入 TileMap
3. 使用第二层噪声（不同 seed）叠加湿度，影响植被密度
4. 在合适地形上按概率散布资源点（ResourceNode 实例）
5. 选择一块连续草地区域（距中心最近）作为初始村庄位置
6. **连通性验证**: 从初始村庄位置做 flood-fill，计算可达的可通行区域面积。若可达面积 < 总地图面积的 40%，则调整 seed 重新生成。防止深水/山脉将地图割裂为孤岛
7. 地图边缘强制生成山脉环带作为天然边界（后期放置 Boss 门）
8. 确保初始村庄周围有最低数量的浆果丛和树木（保证开局可玩）

**地图尺寸**: 第一阶约 80×80 Tiles，每 Tile 16×16 像素（总可视面积 1280×1280 px）

**种子系统**: 使用随机 seed 或玩家指定 seed，确保可重现性

### 4.2 资源系统

**第一阶资源定义**:

| 资源     | 来源       | 用途                       | 再生   | 采集时间 |
| -------- | ---------- | -------------------------- | ------ | -------- |
| 浆果     | 浆果丛     | 食物（直接食用）           | 是(快) | 2s       |
| 木材     | 树木       | 建筑、工具、燃料           | 是(慢) | 4s       |
| 石头     | 石矿       | 建筑、工具                 | 否     | 5s       |
| 草纤维   | 草地采集   | 绳索、初级衣物             | 是(快) | 1.5s    |
| 蘑菇     | 森林地面   | 食物（有20%概率中毒）      | 是(中) | 1.5s    |
| 生肉     | 猎杀野兽   | 食物（需烹饪，否则恢复少） | 是(慢) | 6s       |

**蘑菇中毒效果**:
- 食用未烹饪蘑菇时 20% 概率触发中毒
- 中毒效果：health -15，hunger +20（呕吐导致饱腹度倒退），持续 30 游戏秒
- 解锁"烹饪"科技后，蘑菇经篝火烹饪再食用可消除毒性风险

**ResourceNode 行为** (`resource_node.gd`):
```
ResourceNode:
  resource_type: String         # 资源类型标识
  max_amount: int               # 最大存量
  current_amount: int           # 当前存量
  gather_time: float            # 单次采集耗时（秒）
  gather_amount: int            # 单次采集获得量
  regenerate: bool              # 是否可再生
  regen_rate: float             # 再生速率（每游戏分钟恢复量）
  regen_delay: float            # 枯竭后再生前的等待时间
  is_depleted: bool             # 是否枯竭
```

- 小人到达后执行采集动作，花费 `gather_time`，获得 `gather_amount` 个资源
- `current_amount` 降为 0 时进入"枯竭"状态，视觉变灰/缩小
- 可再生资源等待 `regen_delay` 后开始恢复，速率为 `regen_rate`
- 不可再生资源枯竭后保持枯竭标记（UI 上显示为空矿）

**资源预约机制**:
- 小人选中目标资源后调用 `reserve(resource_node, villager)` 标记占用
- 其他小人的 `find_nearest` 查询时跳过已预约的资源（或对已预约资源的效用分 ×0.3）
- 小人到达并完成采集、或行为被取消/中断时调用 `release(resource_node)` 释放预约
- 防止多个小人同时瞄准同一资源点，减少无效寻路和"白跑一趟"的情况

**ResourceManager（全局注册表）**:
- 维护所有活跃 ResourceNode 的列表和预约状态
- 提供查询接口：`find_nearest(position, type, max_distance, exclude_reserved)` → 供 AI 快速查找
- 当资源点枯竭/再生时更新注册表
- 管理资源预约的注册与释放

### 4.3 小人系统

#### 4.3.1 属性

```
Villager:
  # 基础属性
  health: float = 100.0      # 生命值 0~100，归零则死亡
  hunger: float = 0.0        # 饥饿度 0~100，持续上升，到80开始扣血
  stamina: float = 100.0     # 体力 0~100，行动消耗，休息恢复
  
  # 状态
  name: String               # 随机生成的名字
  age: float = 0.0           # 年龄（游戏内时间，Demo不用）
  move_speed: float = 50.0   # 基础移速（像素/秒）
  gather_efficiency: float = 1.0  # 采集效率倍率（受科技影响）
  
  # 组件
  inventory: VillagerInventory   # 背包组件
  needs: VillagerNeeds           # 需求组件
  ai: VillagerAI                 # AI决策组件
  nav_agent: NavigationAgent2D   # 寻路组件
  
  # 状态机
  current_action: Action         # 当前执行的行为
  known_area: Dictionary          # 已探索的 tile 坐标集合 {Vector2i: true}，O(1) 查找
  home: Building = null          # 归属住所
```

#### 4.3.2 需求系统 (`villager_needs.gd`)

小人行为由需求系统驱动，每个需求产生一个"不满足度"(urgency)，效用 AI 根据这些值选择行为：

| 需求   | 驱动变量     | 变化规则                                | urgency 计算                          |
| ------ | ------------ | --------------------------------------- | ------------------------------------- |
| 进食   | hunger       | +8/游戏分钟（劳动时+12）               | `hunger / 100`                        |
| 休息   | stamina      | -5/游戏分钟（采集时-10，休息时+20）     | `1.0 - stamina / 100`                 |
| 庇护   | —            | 夜晚 + 无住所 触发                      | `0.8`（固定高优先级）                 |
| 安全   | health       | 被攻击/饥饿过高时下降                   | `1.0 - health / 100`（仅在低于50时计入）|

**健康后果**:
- `hunger >= 80`: 每游戏分钟 health -5
- `stamina <= 0`: 移速降为 50%，无法执行采集/建造
- `health <= 0`: 小人死亡，释放背包物品到地面

#### 4.3.3 背包系统 (`villager_inventory.gd`)

```
VillagerInventory:
  slots: Array[{type: String, amount: int}]
  max_slots: int = 5
  
  func add_item(type, amount) -> int       # 返回实际添加量（可能背包满）
  func remove_item(type, amount) -> int    # 返回实际移除量
  func has_item(type, amount) -> bool      # 检查是否持有足够数量
  func get_amount(type) -> int             # 查询某类资源持有量
  func is_full() -> bool
  func get_food_items() -> Array           # 返回所有可食用物品
```

#### 4.3.4 效用 AI (`utility_ai.gd`)

**架构**: 经典效用 AI — 每个可选行为（Action）计算一个 0~1 的评分（utility score），选择得分最高的执行。

```gdscript
class_name UtilityAI

var actions: Array[Action] = []
var current_action: Action = null
var inertia_bonus: float = 0.1  # 当前行为的惯性加分

func select_action(villager: Villager, world: World) -> Action:
    var best_action: Action = null
    var best_score: float = 0.0
    
    for action in actions:
        if not action.can_execute(villager, world):
            continue
        var score = action.calculate_utility(villager, world)
        # 当前正在执行的行为获得惯性加分，避免频繁切换
        if action == current_action and not current_action.is_completed():
            score += inertia_bonus
        score = clamp(score, 0.0, 1.0)
        if score > best_score:
            best_score = score
            best_action = action
    
    return best_action
```

**Action 基类** (`action.gd`):

```gdscript
class_name Action

func get_name() -> String:
    return "BaseAction"

func can_execute(villager: Villager, world: World) -> bool:
    return true

func calculate_utility(villager: Villager, world: World) -> float:
    return 0.0

func start(villager: Villager, world: World) -> void:
    pass

func tick(villager: Villager, world: World, delta: float) -> bool:
    # 返回 true 表示行为已完成
    return true

func cancel(villager: Villager, world: World) -> void:
    pass

func is_completed() -> bool:
    return true
```

**决策频率**: 每 1.5 秒重新评估一次（Timer 驱动），当前行为未完成时给予惯性加分（+0.1）避免频繁切换。紧急情况（health 急降）触发即时重评估。

**Demo 阶段实现的 Actions**:

| Action            | can_execute 条件                 | 效用计算逻辑                                    | 行为                                 |
| ----------------- | -------------------------------- | ----------------------------------------------- | ------------------------------------ |
| ActionEat         | 背包或可达储物箱有食物 且 hunger > 20 | `hunger / 100 * 1.2`                        | 从背包/储物箱取食物，原地进食        |
| ActionGatherFood  | 已知范围内有未枯竭食物资源点     | 饥饿度 × 食物库存空缺 × 距离反比               | 走向最近食物资源点（浆果/蘑菇），执行采集 |
| ActionGatherMat   | 已知范围内有未枯竭材料资源点     | 材料库存空缺 × 距离反比（有建造/制作需求时加成）| 走向最近材料资源点（木/石/草），执行采集 |
| ActionRest        | stamina < 70                     | `(1.0 - stamina/100) * 1.1`                    | 原地或回家休息，恢复体力             |
| ActionBuild       | 有足够材料(含储物箱) 且 经效用评估需要建造 | 见下方建筑效用计算                      | 走向建筑位置，消耗材料，生成建筑     |
| ActionExplore     | 已知区域资源趋于枯竭             | `0.3 + unexplored_ratio * 0.5`                 | 走向已知区域边缘，扩大探索范围       |
| ActionCraft       | 有可制作配方 且 材料充足(含储物箱)| `0.5`（有需求的工具时提升到0.7）                | 在工作台旁原地制作                   |
| ActionDeposit     | 背包满 且 有储物箱               | `0.6`（背包满时触发）                           | 走向储物箱存放物品                   |
| ActionPickup      | 地面有掉落物品（已知区域内）     | `0.55`（掉落物为食物且饥饿时提升到0.75）        | 走向掉落物位置拾取到背包             |
| ActionIdle        | 始终 true（兜底行为）            | `0.05`（最低优先级）                            | 原地等待或在村庄附近随机漫步         |

**效用计算详细示例 — ActionGatherFood**:
```gdscript
func calculate_utility(villager: Villager, world: World) -> float:
    # 饥饿驱动：越饿越急需采集食物
    var hunger_factor = villager.needs.hunger / 100.0
    
    # 库存判断：背包+可达储物箱中无食物时大幅加成
    var total_food = villager.inventory.get_food_count() + world.building_manager.get_storage_food_count(villager)
    var food_urgency = 0.3 if total_food > 0 else 0.7
    
    var base = hunger_factor * food_urgency
    
    # 距离惩罚：最近食物资源越远，意愿越低
    var nearest = world.resource_manager.find_nearest(
        villager.position, "food", 500.0, true  # exclude_reserved=true
    )
    if nearest == null:
        return 0.0
    var distance_factor = 1.0 - clamp(villager.position.distance_to(nearest.position) / 500.0, 0.0, 0.8)
    
    return clamp(base * distance_factor, 0.0, 1.0)
```

**效用计算详细示例 — ActionGatherMat**:
```gdscript
func calculate_utility(villager: Villager, world: World) -> float:
    # 基础意愿：背包越空越想采集
    var fullness = villager.inventory.get_occupied_slots() / float(villager.inventory.max_slots)
    var base = (1.0 - fullness) * 0.5
    
    # 建造/制作需求加成：如果有可建建筑或可制作配方缺材料，提升意愿
    var build_need = world.building_manager.get_unmet_material_urgency(villager)
    base += build_need * 0.3
    
    # 距离惩罚
    var nearest = world.resource_manager.find_nearest(
        villager.position, "material", 500.0, true  # exclude_reserved=true
    )
    if nearest == null:
        return 0.0
    var distance_factor = 1.0 - clamp(villager.position.distance_to(nearest.position) / 500.0, 0.0, 0.8)
    
    return clamp(base * distance_factor, 0.0, 1.0)
```

#### 4.3.5 寻路

使用 Godot 4 内置的 `NavigationAgent2D` + TileSet 原生导航支持：
- 在 TileSet 中为每种地形 tile 直接配置 navigation polygon（可通行 tile 设置 polygon，不可通行 tile 留空）
- TileMap 会自动将 tile 的导航数据注册到 NavigationServer2D，无需手动创建 NavigationRegion2D 或烘焙 NavigationPolygon
- 不可通行地形（深水、山脉）的 tile 不设置 navigation polygon，自然成为障碍
- 森林/岩地通过 navigation layer 或 travel_cost（cost = 2.0）让小人倾向走草地
- 小人到达目标容忍距离：16px（一个 tile 宽）

#### 4.3.6 探索与视野（迷雾系统）

- 每个小人维护 `known_area: Dictionary`（已探索的 tile 坐标 → true，O(1) 查找）
- 小人移动时自动"揭示"周围半径 5 tile 的区域
- 效用 AI 只能查找 `known_area` 内的资源点
- 未探索区域在视觉上显示为黑色遮罩（TileMap 上层或着色器）
- 全局 `explored_tiles` 为所有小人探索区域的并集

#### 4.3.7 人口（Demo 简化）

- 初始小人数量：3 人
- Demo 中固定 3~5 人，不实现繁殖和死亡（除非 health 归零）
- 后续版本：住所 + 食物充足 → 繁殖；到达年龄上限 → 自然死亡

### 4.4 建筑系统

**第一阶建筑**:

| 建筑     | 材料需求           | 建造时间 | 功能                           |
| -------- | ------------------ | -------- | ------------------------------ |
| 草棚     | 草纤维×5, 木材×3   | 8s       | 提供庇护（夜晚回复体力加速×2） |
| 篝火     | 木材×3, 石头×1     | 4s       | 照明、烹饪（生肉→熟肉）       |
| 储物箱   | 木材×5             | 5s       | 公共仓库，20格共享存储（见下方交互规则） |
| 工作台   | 木材×5, 石头×3     | 6s       | 解锁初级工具制作               |
| 研究台   | 木材×8, 石头×5     | 10s      | 解锁科技研究                   |

**储物箱共享库存交互规则**:
- 储物箱作为公共仓库，所有小人均可存取
- **取材料**: 小人在储物箱旁执行制作（ActionCraft）或建造（ActionBuild）时，可直接消耗储物箱中的材料，不需要先搬到背包
- **取食物**: 小人饥饿时，ActionEat 会同时检查背包和可达储物箱中的食物。若食物在储物箱中，小人需先走到储物箱旁取出再食用
- **库存评估**: AI 评估资源充裕度时，合并计算"背包 + 所有可达储物箱"的总量。例如储物箱中已有 20 木材时，ActionGatherMat 对木材的采集意愿会显著降低
- **存放逻辑**: ActionDeposit 时，小人走向最近的未满储物箱存放物品

**建筑放置逻辑**:
- 小人根据效用 AI 决定"需要建造某建筑"后，自动选择位置：
  1. 优先在已有建筑群附近（形成村落感）
  2. 必须在草地/沙地上（不能建在水里/山上）
  3. 不能与其他建筑/资源点重叠
- 建造过程：小人走到位置 → 播放建造动画 → 消耗材料 → 建筑实例化
- Demo 中不需要玩家手动放置

**建筑需求判断**（效用驱动，集成在 ActionBuild.calculate_utility 内）:

ActionBuild 内部评估每种建筑的效用分，取最高者作为当前 Action 的整体效用。选中后 `start()` 阶段确定具体建造哪个建筑：

```gdscript
func calculate_utility(villager: Villager, world: World) -> float:
    var scores: Array[float] = []
    
    # 草棚：夜晚临近 + 无庇护 → 高优先级
    if not world.building_manager.has_building("shelter"):
        var night_factor = 0.4 + (0.4 if world.is_approaching_night() else 0.0)
        if villager.inventory.has_materials_for("shelter"):
            scores.append(night_factor)
    
    # 篝火：有生肉但无法烹饪
    if not world.building_manager.has_building("campfire"):
        var has_raw_meat = villager.inventory.has_item("raw_meat", 1)
        if has_raw_meat and villager.inventory.has_materials_for("campfire"):
            scores.append(0.45)
    
    # 储物箱：背包经常满
    if not world.building_manager.has_building("chest"):
        if villager.inventory.is_full():
            if villager.inventory.has_materials_for("chest"):
                scores.append(0.5)
    
    # 工作台
    if not world.building_manager.has_building("workbench"):
        if villager.inventory.has_materials_for("workbench"):
            scores.append(0.4)
    
    # 研究台（需前置工作台）
    if world.building_manager.has_building("workbench") and not world.building_manager.has_building("research_table"):
        if villager.inventory.has_materials_for("research_table"):
            scores.append(0.35)
    
    return scores.max() if not scores.is_empty() else 0.0
```

### 4.5 科技树 (`tech_tree.gd`)

**设计理念**: 类似饥荒的原型机，小人在研究台前"研究"消耗资源和时间，解锁新配方/建筑。

**第一阶科技（Demo）**:

```
石器时代
├── 石斧（研究: 木材×3+石头×2 → 解锁: 伐木效率+50%）
├── 石镐（研究: 木材×3+石头×2 → 解锁: 采矿效率+50%）
├── 编织（研究: 草纤维×5 → 解锁: 绳索制作）
│   └── 改良草棚（研究: 绳索×3+木材×5 → 住所容量+1，恢复速度+50%）
├── 烹饪（前置: 已建篝火 → 解锁: 熟肉配方，饱腹值翻倍）
│   └── 干燥架（研究: 木材×5+绳索×2 → 食物保存时间×3）
└── 探索术（研究: 草纤维×3+浆果×5 → 探索时体力消耗-50%）
    └── 制图（研究: 木材×2+石头×1 → 小地图显示已探索区域）
```

**实现方式**:
- 每个科技定义为 `Resource` (.tres)，包含字段：
  ```
  TechResource:
    id: String
    display_name: String
    description: String
    prerequisites: Array[String]    # 前置科技 ID
    research_cost: Dictionary       # {resource_type: amount}
    research_time: float            # 研究所需游戏时间(秒)
    unlock_type: String             # "recipe" / "buff" / "building"
    unlock_data: Dictionary         # 解锁的具体内容
  ```
- 全局 `TechTree` 单例管理已解锁科技
- 科技解锁后发出信号，通知相关系统更新（新配方、效率系数等）
- Demo 中科技由小人自主研究（AI 在研究台时评估哪个科技优先）
- 研究台同一时间只允许一名小人使用（占用机制类似资源预约：使用中的研究台标记为 occupied，其他小人不会选择研究行为）
- 研究优先级由科技的解锁收益决定：直接改善当前瓶颈的科技优先（例如食物不足时优先研究"烹饪"）

### 4.6 昼夜系统

- 一个完整的昼夜循环约 **6 分钟**真实时间
- 时间分配：白天 3 分钟，黄昏 1 分钟，夜晚 2 分钟
- 白天：正常活动，全亮
- 黄昏：色调变暖，ActionRest 的效用在有住所时获得 +0.3 加成（促使小人提前回家），给予足够的返程时间
- 夜晚：视野缩小至 3 tile，无庇护的小人体力恢复减半、移速 -20%
- 通过 `CanvasModulate` 实现全局色调变化（白→橙→深蓝 渐变）
- 内部时间变量：`time_of_day: float` 0.0~1.0（0=日出, 0.5=黄昏开始, 0.67=夜晚开始, 1.0=下一个日出）

### 4.7 摄像机

- 鼠标中键拖拽 / WASD 键移动视角
- 鼠标滚轮缩放（范围 0.5x ~ 3x）
- 点击小人可跟踪并查看其状态面板
- 摄像机限制在地图边界内
- 按 Space 居中回到村庄中心

---

## 五、Demo 开发任务分解

按优先级排列，前后有依赖关系：

### Phase 1: 基础框架 (预计 2~3 天)

- [ ] **T1.1** 创建 Godot 4.x 项目，配置项目设置（2D渲染，像素风格：stretch mode=viewport, aspect=keep）
- [ ] **T1.2** 搭建主场景树结构（Main → World / Camera / UI）
- [ ] **T1.3** 实现摄像机控制脚本（拖拽平移、滚轮缩放、边界限制）
- [ ] **T1.4** 配置 Autoload 单例（GameManager, ResourceManager, TechTree, BuildingManager）
- [ ] **T1.5** 实现 GameManager 基础：游戏时间、时间流速（1x/2x/3x）、暂停

### Phase 2: 地图生成 (预计 4~5 天)

- [ ] **T2.1** 制作基础 TileSet — 7种地形用纯色色块占位（深蓝/浅蓝/黄/绿/深绿/灰/深灰）
- [ ] **T2.2** 实现 `WorldGenerator`：FastNoiseLite 生成高度图 → 阈值切分地形 → 写入 TileMap
- [ ] **T2.3** 实现第二层湿度噪声，影响森林/草地分布的精细度
- [ ] **T2.4** 实现资源点散布逻辑：遍历 TileMap → 按地形类型+概率 → 实例化 ResourceNode
- [ ] **T2.5** 实现初始村庄选点算法（找草地连通区域中心）
- [ ] **T2.6** 实现 ResourceNode 基础行为：被采集、数量减少、枯竭态、再生定时器
- [ ] **T2.7** 在 TileSet 中为各地形 tile 配置 navigation polygon，TileMap 自动注册导航数据
- [ ] **T2.8** ResourceManager 注册表：资源点注册/注销、空间查询接口、资源预约机制
- [ ] **T2.9** 地图连通性验证：从初始村庄做 flood-fill，确保可达面积 ≥ 40%

### Phase 3: 小人基础 (预计 3~4 天)

- [ ] **T3.1** 创建 Villager 场景（CharacterBody2D + CollisionShape + Sprite + NavigationAgent2D）
- [ ] **T3.2** 实现基础移动：NavigationAgent2D 寻路 + move_and_slide，地形移速修正
- [ ] **T3.3** 实现 VillagerNeeds：hunger/stamina 随时间变化，阈值触发健康影响
- [ ] **T3.4** 实现 VillagerInventory：格子系统、增删查、容量限制
- [ ] **T3.5** 小人视觉状态：不同颜色圆形占位 + 头顶状态图标（饿/累/采集中）
- [ ] **T3.6** 小人初始化：3个小人在村庄中心生成，赋予随机名字

### Phase 4: 效用 AI (预计 6~8 天)

- [ ] **T4.1** 实现 UtilityAI 框架：Action 注册、评分循环、惯性机制、决策Timer
- [ ] **T4.2** 实现 Action 基类：生命周期（can_execute → calculate_utility → start → tick → complete/cancel）
- [ ] **T4.3** 实现 ActionEat：评估饥饿度 → 从背包或储物箱取食物 → 播放进食 → 降低hunger（含蘑菇中毒判定）
- [ ] **T4.4** 实现 ActionGatherFood：查询最近食物资源（排除已预约）→ 预约 → 寻路前往 → 采集 → 释放预约
- [ ] **T4.5** 实现 ActionGatherMat：查询最近材料资源（排除已预约）→ 预约 → 寻路前往 → 采集 → 释放预约
- [ ] **T4.6** 实现 ActionRest：评估体力 → 原地/回家 → 恢复stamina（黄昏时有住所则效用+0.3）
- [ ] **T4.7** 实现 ActionExplore：计算未探索方向 → 移动到边缘 → 揭示新区域
- [ ] **T4.8** 实现 ActionBuild：效用驱动的建筑需求评估 → 选址 → 寻路前往 → 消耗材料(含储物箱) → 建筑实例化
- [ ] **T4.9** 实现 ActionCraft：检查可制作配方 → 走到工作台 → 消耗材料(含储物箱) → 等待制作时间 → 获得产物
- [ ] **T4.10** 实现 ActionDeposit：背包满 → 走到最近未满储物箱 → 存放物品
- [ ] **T4.11** 实现 ActionPickup：检测已知区域内地面掉落物 → 寻路前往 → 拾取到背包
- [ ] **T4.12** 实现 ActionIdle：兜底行为 → 原地等待或村庄附近随机漫步（最低优先级 0.05）
- [ ] **T4.13** AI 调参：调整效用曲线斜率和阈值，确保小人行为自然（不会饿死在资源旁边、不会全员抢同一资源）。预留充足时间，此阶段是玩法体验的核心

### Phase 5: 建筑与科技 (预计 3~4 天)

- [ ] **T5.1** 实现 Building 场景和建造流程（未完成态 → 建造动画 → 完成态）
- [ ] **T5.2** 实现各建筑功能：草棚（庇护标记）、篝火（烹饪交互）、储物箱（共享背包）
- [ ] **T5.3** 实现工作台/研究台：制作和研究的交互流程
- [ ] **T5.4** 实现科技树数据（.tres 文件定义所有第一阶科技）
- [ ] **T5.5** 实现科技解锁逻辑和效果应用（效率加成、新配方注入）
- [ ] **T5.6** BuildingManager：建筑注册、选址验证、建筑需求评估接口

### Phase 6: 迷雾与 UI (预计 2~3 天)

- [ ] **T6.1** 实现探索迷雾：未探索区域黑色遮罩，已探索区域正常显示
- [ ] **T6.2** HUD：左上显示游戏时间（第X天）、人口数、已解锁科技数
- [ ] **T6.3** 点击小人显示状态浮窗（名字、需求条、背包内容、当前行为文本）
- [ ] **T6.4** 科技树面板（Tab键打开，展示科技树结构：已解锁=亮/可研究=半亮/锁定=暗）
- [ ] **T6.5** 时间流速控制按钮（1x / 2x / 3x / 暂停）
- [ ] **T6.6** 昼夜循环视觉效果（CanvasModulate 色调渐变）

### Phase 7: 整合与调优 (预计 3~4 天)

- [ ] **T7.1** 完整游戏循环测试：小人能否从零开始存活、采集、建造、研究
- [ ] **T7.2** AI 行为平衡：确保不会出现死循环/饿死/无所事事/全员抢同一资源
- [ ] **T7.3** 性能优化：大量资源点时的查询效率、NavigationAgent 开销
- [ ] **T7.4** Bug 修复和边缘情况处理（含资源预约泄漏、储物箱并发访问等）
- [ ] **T7.5** 添加 Debug 面板：显示每个小人的 AI 评分实时值、资源预约状态、储物箱库存（开发用）

**Demo 总预计工期: 24~34 天**

---

## 六、Demo 验收标准

Demo 完成时，应该能看到以下场景自然发生：

1. 游戏启动后，随机地图生成，3个小人出现在草地中心区域
2. 小人自主散开，寻找附近浆果丛采集食物
3. 饥饿时自动进食，疲劳时自动休息
4. 逐渐采集木材和草纤维，自主决定建造草棚
5. 有了草棚后，夜晚主动回家休息
6. 附近资源减少后，小人开始探索更远区域
7. 积累足够材料后，建造篝火、储物箱、工作台
8. 有工作台后，制作石斧石镐，采集效率可见提升
9. 建造研究台后，开始研究科技
10. 整个过程无需玩家操作，小人自主完成以上所有阶段

---

## 七、Demo 之后的扩展路线

以下内容不在 Demo 范围内，记录作为后续规划：

### 7.1 玩家干预系统（待设计）

可能的方向：
- **神迹系统**: 消耗信仰值施放全局效果（降雨促进作物、雷击点燃篝火、祝福提升效率）
- **信仰图腾**: 放置图腾影响周围小人的行为权重（如"狩猎图腾"提升狩猎效用分）
- **天气/季节控制**: 改变环境条件间接影响小人决策
- **启示**: 直接解锁某个科技的研究选项（但仍需小人去执行研究）
- **禁忌/律法**: 设定全局规则（如"禁止夜间外出"），间接改变效用计算

### 7.2 Boss 与地图解锁

- 地图边界山脉中设置"Boss 门"（视觉上为发光裂缝）
- Boss 需要特定科技等级 + 武器装备才能挑战
- 小人组队（3人以上）前往挑战，需要武器 + 食物储备
- 战斗为自动进行（基于装备和科技等级计算成功率）
- 击败后山脉裂开，新区域地图在边界外生成并接入
- 新区域拥有全新地形、资源、威胁
- 科技树解锁新的分支

### 7.3 多阶段地图

| 阶段 | 主题   | 新资源           | 新威胁     | Boss       |
| ---- | ------ | ---------------- | ---------- | ---------- |
| 1    | 草原   | 木、石、浆果     | 野狼       | 巨熊       |
| 2    | 沼泽   | 铁矿、药草、黏土 | 毒蛇、瘴气 | 沼泽巨蟒   |
| 3    | 雪原   | 冰晶、毛皮       | 严寒、暴风 | 冰霜巨人   |
| 4    | 火山   | 硫磺、黑曜石     | 岩浆、火精 | 熔岩龙     |

### 7.4 小人进化

- 世代传承（父代技能/属性影响子代初始能力）
- 职业分化（长期执行某类行为后获得专精：伐木工、矿工、猎人等）
- 文化/信仰系统（群体行为倾向自然形成）
- 人际关系网（协作加成、冲突减益）

---

## 八、关键设计原则

1. **涌现优于预设**: 游戏趣味来自小人 AI 的涌现行为，而非预编排的脚本事件。效用 AI 的参数调优是游戏体验的核心。

2. **渐进复杂度**: 每个新地图阶段引入 2~3 个新机制，不要一次性堆叠。第一阶段只需要"采集→生存→初级建造"就足够有趣。

3. **可观察性**: 玩家的乐趣在于"看"。小人的决策过程应该可以通过 UI 观察到（当前想法、需求状态）。Debug 面板在开发阶段尤为重要。

4. **数据驱动**: 资源、科技、建筑、Action 参数尽量用 Resource 文件定义，方便迭代调参，避免硬编码。

5. **先占位后美化**: 所有视觉素材先用色块/几何图形占位，确认玩法后再替换美术资源。

6. **失败有趣**: 小人可以死亡、可以做出"蠢事"（比如探索太远回不来），这些是涌现乐趣的一部分，不需要避免。

---

## 九、技术风险与注意事项

| 风险                          | 缓解方案                                       |
| ----------------------------- | ---------------------------------------------- |
| AI 行为不自然（卡死/空转）    | ActionIdle 兜底行为 + 完善 Debug 面板          |
| 导航网格性能                  | 利用 TileSet 原生导航，限制地图尺寸            |
| 大量小人时性能下降            | Demo 限制 5 人，后续做 spatial partition        |
| 资源查询效率                  | ResourceManager 用 Dictionary 按区域分桶      |
| 效用曲线难调                  | 导出参数到 Resource，做运行时 Debug 面板       |
| 地图生成不可玩（全是水/山）   | flood-fill 连通性验证 + 初始区域草地≥40%       |
| 多小人抢同一资源              | 资源预约机制，已预约资源效用分 ×0.3            |
| 资源预约泄漏（小人死亡时）    | 小人死亡/行为取消时强制释放所有预约            |
| 储物箱并发存取冲突            | 储物箱操作加锁或排队（Demo 规模下简单判断即可）|
| known_area 查找性能           | 使用 Dictionary 替代 Array，O(1) 查找          |
