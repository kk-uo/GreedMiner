# GreedMiner 美术风格规范（风格 A · 扁平几何）

所有颜色的唯一来源是 `Scripts/Core/Palette.gd`。代码绘制和 AI 生成的素材都遵守这份规范。

## 核心规则

- 严格俯视、正交视角；扁平几何，干净的形状、清晰的剪影。
- 每种材质只有 3 个平涂色调：基色、阴影色、高光色。不用渐变、不描边、不加纹理。
- 光源在左上。所有物体投下同一种硬投影：偏移 `(5, 7)`，颜色为黑色、28% 不透明度。投影统一在引擎里画，不画进素材。
- 形状语言：飞船 = 矩形和倒角；敌人 = 灰色多边形石块堆成的石人 / 石子；矿石 = 六边形晶面。
- 饱和度层级：地面饱和度低、对比度低；飞船用骨白配深灰；敌人是灰色石头，只带紫色眼睛 / 裂缝 / 晶体；**矿石是全游戏最饱和的东西**。
- 朝向：炮管和敌人的正面都朝本地 +X（向右），这样 `look_at()` 和旋转可以直接用。

## 色板

| 用途 | 颜色 |
|---|---|
| 飞船主体 / 阴影 / 接缝 / 零件 | `#E8E1D3` `#C2B7A3` `#CBC1AE` `#CFC5B2` |
| 机械 / 机械高光 / 强调色 | `#3B3530` `#5A524B` `#F08A24` |
| 玩家子弹 / 子弹芯 | `#FFC061` `#FFF2C2` |
| 敌人石头 深缝 / 暗 / 中 / 亮面 / 高光 | `#2F3135` `#44474C` `#686C72` `#8E9298` `#B6BABE` |
| 敌人紫（眼睛 / 裂缝 / 晶体）主 / 亮 / 暗 | `#B45CFF` `#E3BCFF` `#7A35C9` |
| 敌人攻击扬尘 | `#B8A68E` |
| 哥布林皮肤 暗 / 主 / 亮 | `#657F31` `#9CC44C` `#C6E07A` |
| 哥布林装备 皮革 / 毛皮 / 木头 / 铁 / 骨 / 红布 | `#6B4A32` `#7A5A3C` `#8A5A34` `#7D8389` `#E9DFC6` `#B8452F` |
| 哥布林眼睛（威胁色，石头敌人用紫色） | `#FF4A3A` |
| 危险界面色（撤离按钮、警告） | `#FF3D5A` |
| 金矿 亮 / 主 / 暗 | `#FFF2B0` `#FFD23F` `#DC9D17` |
| 钴矿 亮 / 主 / 暗 | `#D6EDFF` `#5FB0FF` `#2F78CC` |
| 界面面板 / 凸起面板 / 文字 / 次要文字 | `#1D1714` `#2A231E` `#F2EAD9` `#A89C88` |
| 锈色荒漠地面 | `#8A6A4D` `#7D5F45` `#967558` 岩石 `#6A4D3A` `#A07F62` |

新星球只在 `Palette.PLANETS` 里加一行地面色，其他颜色永远不动。

## AI 生成提示词

每次生成都用：**主风格提示词 + 分类模板 + 具体物体**，再加上负面提示词。

### 主风格提示词（每次必带）
```
GreedMiner style: 2D game asset, strict top-down orthographic view, flat geometric vector art,
clean simple shapes, strong readable silhouette, exactly 3 flat tones per material
(base, shadow, highlight) with hard edges, no gradients, no outlines, no texture,
light from top-left, restrained limited palette, slightly stylized industrial sci-fi,
minimalist like Thronefall, single centered object, plain solid flat #808080 background,
generous empty margin around the object
```

### 负面提示词（每次必带）
```
photorealistic, 3D render, isometric, perspective, side view, gradient, soft shading,
glow, bloom, texture, grain, noise, outline, line art, sketch, painterly, brush strokes,
pixel art, anime, text, letters, watermark, multiple objects, scene, ground, cast shadow,
bevel, glossy, chrome, reflections, tiny details, greebles, clutter
```

### 分类模板

**飞船模块底座**
```
spaceship module base seen from directly above, fits exactly one square grid cell,
rectangular body with chamfered corners, panel seams,
bone white #E8E1D3 body, #C2B7A3 shadow, dark gunmetal #3B3530 mechanical parts,
one small safety-orange #F08A24 accent, [MODULE]
```

**炮塔头（单独生成，用来旋转）**
```
turret head only, barrel pointing straight to the right (east),
round or hexagonal head centered on the image center as rotation pivot,
dark gunmetal #3B3530, #5A524B highlight, safety-orange #F08A24 muzzle tip, [WEAPON]
```

**敌人**
```
stone creature seen from directly above, facing right (east),
built from a few chunky faceted grey boulders, no mechanical parts,
each chunk: #44474C base, #686C72 inner, #8E9298 lit top-left facet, #B6BABE edge,
small glowing arcane purple #B45CFF eyes / cracks / crystals only, no other colors, [ENEMY]
```

**矿石**
```
faceted crystal cluster seen from above, 2 to 4 hexagonal prism crystals,
each crystal split into a light left face and a dark right face, sharp facets,
the most saturated object in the game,
[gold #FFD23F / #DC9D17 / #FFF2B0 | cobalt #5FB0FF / #2F78CC / #D6EDFF]
```

**地形装饰**
```
flat ground decoration seen from above, irregular angular rock / shallow crater,
low saturation, low contrast, only 3 tones from this palette: [PLANET PALETTE]
```

**界面图标**
```
flat UI icon, 2 colors only, simple bold geometric symbol, centered,
bone white #F2EAD9 on dark #1D1714
```

### 让 AI 写 `_draw()` 代码时附上的规则
```
Draw in GreedMiner flat style: only draw_colored_polygon / draw_circle / draw_rect,
no gradients, no outlines. Each object = base color + one shadow shape + one highlight
shape. Before the object, draw the same silhouette offset by Palette.SHADOW_OFFSET in
Palette.SHADOW_COLOR. Colors must come from Palette.gd only. Shape language: ship =
rectangles/chamfers, enemies = faceted grey stone chunks with purple eyes, minerals = hexagonal facets. Face local +X.
```

## 省空间规则

1. 能用 `_draw()` 或 `Polygon2D` 画的，就不要用图片。这样占用 0 字节。
2. 必须用图片时：PNG，最长边不超过 128px（按 2 倍尺寸绘制），先映射到色板，再用 pngquant 压缩。导入时压缩模式选 Lossless，并关闭 Mipmaps。
3. 星球变体、精英怪不额外出图，用 `modulate` 或调色板替换 shader 实现。
4. 特效用 `FlatBurst`、`CPUParticles2D`（不加贴图）和 `Line2D` 实现。
5. 字体只用一套（`Theme/ChakraPetch-SemiBold.ttf`，约 78KB）。如果加中文，必须做字体子集。
   中文后备字体是子集 `Assets/Fonts/NotoSerifSC-Subset.otf`（约 318KB）；新增中文文本后运行
   `python3 tools/fonts/subset_cjk_font.py` 重新生成（完整字体在 `tools/fonts/source/`，不会被导出），
   `Tests/FontCoverageTest` 会检查翻译里的字是否都在子集里。
6. 音频统一用 OGG 格式。
7. Web 导出不要放在项目根目录，导出到 `build/web/`（这个目录已经被 git 忽略）。

## 生成图片后的处理（需要 ImageMagick 和 pngquant）

```
tools/art/normalize.sh input.png output.png 128
```
