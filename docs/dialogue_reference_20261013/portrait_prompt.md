# 透明底立绘清晰化提示词

使用内置 image_gen 编辑图 1；图 2 只用于游戏对话排版。

## 中文提示词

以原图为唯一角色设计基准，对这张蓝发鲸鱼主题女仆全身立绘进行高清重绘。目标为 4K 竖幅，长边 4096 像素，PNG RGBA 真实透明背景。保持角色脸型、蓝色眼睛、笑容、伸出的左手、全身姿势、蓝色长发轮廓、女仆头饰、花朵蝴蝶结、鲸鱼围裙、层叠裙摆、鞋子、鲸尾飘带、黄色星星和蓝色气泡。

清晰流畅的深蓝线稿，轮廓完整，外轮廓稳定、内部线条更细；脸部、五指、发束、褶皱和裙边清楚有序。藏蓝、蓝、浅蓝、白色色块完整统一，以平涂和单层赛璐璐阴影为主，保留必要体积感。去掉头发与衣服上的散碎亮斑、杂乱渐变、零碎反光和模糊光晕；每组发束只保留一条面积克制、形状规整的连续高光，布料为哑光。保留原设计已有的花朵、星星图案，不增添闪光粒子。

单个角色完整入镜，保留所有配件和四周透明安全边距。真正 alpha 透明，无黑底、白底、烘焙棋盘格、地面或投影。边缘干净，抗锯齿自然，无白边或黑边。

负面：模糊、光晕、噪点、散碎高亮、塑料反光、杂乱色块、过度渐变、锐化白边、厚涂笔触、写实材质、改脸、改姿势、改服装、裁切身体、额外物体、文字、水印。

## 实际提交给生成工具的提示词

+Use case: identity-preserve / style-transfer.
Asset type: 大肥鱼 Godot 游戏全身角色立绘，PNG RGBA，真实透明背景，目标 4K 竖幅（长边4096像素），尽可能高的原生分辨率。
Input image 1 is the ONLY edit target and identity/design reference. Carefully redraw and clarify this exact blue-haired whale-themed maid illustration. Preserve the same face identity, blue eyes, cheerful open-mouth smile, full-body pose, outstretched left hand, hair silhouette, maid headband, flower bows, whale apron motif, layered skirt, shoes, whale-tail ribbon, yellow stars and blue bubbles. Preserve the full body and all attached accessories without any cropping. No redesign or extra objects.
Primary request: 线条清晰化，稳定流畅的深蓝细线稿，闭合清楚的轮廓，内部线条有序，五指和手部结构清楚，脸部和裙边细节利落。蓝、浅蓝、藏蓝和白色色块完整统一，以整块平涂与单层赛璐璐阴影为主，保留必要体积感。去掉原图头发与衣服上散碎的亮斑、过多的反光碎片、杂乱渐变和模糊光晕，每组发束只允许一条形状规整、面积克制的连贯高光。布料为哑光，不做塑料反光。保留原设计中的明确花朵和星星图案，但不要增加新的闪光粒子。
Output composition: single isolated full-length character, same original vertical framing, safe transparent margin, no floor, no cast shadow, no background. Background is real alpha transparency, absolutely no black background, no white background, no baked checkerboard. Crisp antialiased edges without black/white halos.
Avoid: blurry edges, airbrush haze, scattered glossy highlights, glowing bloom, painterly brush noise, over-sharpening halos, fragmented color patches, photorealistic rendering, text, watermark, new costume, altered face or pose.
