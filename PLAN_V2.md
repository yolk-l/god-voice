# Plan V2: 格子地图 + 地图扩展

## 已实施

### 核心变更

将地图从固定 120×120 噪声地图改为 **chunk-based 动态格子地图**：

1. **Tile 数据模型**：每个 tile 存储地形类型 + 资源属性（类型、存量、再生参数等），使用 `Dictionary{Vector2i: Dictionary}` 存储
2. **Chunk 系统**：16×16 tile 为一个 chunk，初始生成 3×3 chunk（中心 + 周围 8 个），之后按需动态生成
3. **资源并入 tile**：资源不再是独立的 ResourceNode 实体，而是 tile 的属性。采集 = 减少 tile 的 resource_amount
4. **动态扩展**：小人探索到 chunk 边界时自动生成新 chunk，地形通过全局坐标噪声保证连续
5. **无固定边界**：去掉了山脉边界墙，地图可以向任意方向无限生长

### 改动文件

| 文件 | 变更 |
|------|------|
| `scripts/world/world_generator.gd` | 重写：generate_chunk 按区域生成，资源分配进 tile 数据 |
| `scripts/world/world.gd` | 大改：Dictionary 存储、chunk 管理、ResourceLayer 视觉层、gather_tile API、资源再生循环 |
| `scripts/systems/resource_manager.gd` | 重写：从 Node 索引改为 tile 索引，API 返回 Vector2i |
| `scripts/world/fog_of_war.gd` | 修改：去掉硬编码大小，per-chunk 动态迷雾 |
| `scripts/ai/actions/action_explore.gd` | 修改：探索范围从 10→30 tile，去掉 clamp(2,117) 硬编码 |
| `scripts/ai/actions/action_gather_food.gd` | 修改：Node → tile 适配 |
| `scripts/ai/actions/action_gather_mat.gd` | 修改：Node → tile 适配 |
| `scripts/entities/villager.gd` | 修改：_reveal_area 触发 chunk 生成 |
| `scripts/ui/tile_info_panel.gd` | 修改：适配新 tile 资源查询 API |

### 未改动（保持原样）

- 所有其他 action_*.gd（eat, rest, build, deposit, pickup, craft, research, cook, farm, smelt, weave, idle）
- building.gd, building_manager.gd, villager_ai.gd, utility_ai.gd, action.gd
- game_manager.gd, villager_needs.gd, villager_inventory.gd, tech_tree.gd
- ground_item.gd, event_log.gd, camera.gd
- 所有 UI 脚本（hud, villager_panel, tech_panel, storage_panel, history_panel, click_handler）
- resource_node.gd/tscn — 已成为死代码，未删除

---

## 已实施：生产建筑

新增三种生产建筑（与 Farm 模式一致：放置 → 自动产出 → 小人收获）：

| 建筑 | 地形要求 | 产出 | 解锁科技 |
|------|---------|------|---------|
| lumber_camp | FOREST | wood | forestry（前置：石斧） |
| quarry | ROCK | stone | mining_tech（前置：石镐） |
| fishing_dock | GRASS/SAND 邻水 | fish | fishing（无前置） |

### 改动文件

| 文件 | 变更 |
|------|------|
| `scripts/entities/building.gd` | 通用 PRODUCTION 表替代 farm 硬编码，3 个新像素画 |
| `scripts/systems/building_manager.gd` | TERRAIN_REQUIREMENTS，find_build_position 支持地形筛选，get_harvestable_buildings |
| `scripts/world/world.gd` | 新增 is_adjacent_to_water() |
| `scripts/entities/villager_inventory.gd` | 新配方 + fish/cooked_fish 营养值 |
| `scripts/systems/tech_tree.gd` | 3 个新科技：forestry, mining_tech, fishing |
| `scripts/ai/actions/action_build.gd` | 新建筑优先级、find_build_position 传 building_type |
| `scripts/ai/actions/action_farm.gd` | 通用收获：遍历所有 PRODUCTION 建筑 |
| `scripts/ai/actions/action_cook.gd` | COOKABLE 表支持 fish → cooked_fish |
| `scripts/ai/actions/action_gather_mat.gd` | _get_all_building_targets 加入新建筑 |
| `scripts/ui/tile_info_panel.gd` | 新建筑显示名 |

### 新物品

- `fish`：食物，营养值 18
- `cooked_fish`：烹饪鱼，营养值 28

---

## 已实施：AI Bug 修复

### 研究循环修复

`action_research.gd`：`can_execute()` 新增研究台占用检查，防止多个小人同时尝试研究导致快速 `none→research→none→research` 循环。

### 建造超限修复

`building_manager.gd` + `action_build.gd`：新增建造预约系统（`reserve_build` / `release_reservation`），防止多个小人同时启动同类型建造导致超出 `BUILDING_LIMITS`。

### GDScript 类型推断修复

多个文件中 Dictionary 遍历变量为 Variant 类型，`:=` 无法推断算术表达式结果类型。统一改为显式类型标注：
- `world.gd`：`_update_camera_bounds` 中的 origin/end
- `world.gd`：`is_adjacent_to_water` 中的 dirs/neighbor
- `world_generator.gd`：`find_village_center` 中的 neighbor
- `resource_manager.gd`：`find_nearest` / `find_nearest_in_area` 中的 world_pos
- `building_manager.gd`：`can_build_more` / `reserve_build` 中的 total

---

## 待实施

### 新区域 Biome

扩展到远处时引入新 biome（沼泽等），基于距离原点的距离决定 biome 参数。
