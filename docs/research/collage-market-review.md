# iPhone 拼图产品研究与极拼版本决策

## 结论

极拼最值得投入的方向是：**选完照片就有合适的排版，整套风格可以复用，装饰精致而容易找到，编辑结果可靠地保存和导出。** 这比继续增加相互重叠的按钮更可能改善体验。V2.0 优先降低排版与重复编辑的成本；V3.0 建立一套原创、协调、可以直接贴到照片上的素材。

综合修图工具、美学模板工具和截图工具解决的是不同问题。美图秀秀的长处是把工具、素材和流行配方放在一起；PicCollage 把照片组合变成容易开始的日常创作；Unfold 和简拼让不懂排版的人获得协调的成品；Picsew 让长内容更容易整理和交付。极拼应学习这些机制，而不是逐项照搬产品规模。[美图秀秀][s1]、[PicCollage][s7]、[Unfold 官方说明][unfold]、[简拼][s4]、[Picsew][s20]。

这些判断是产品分析，尚不是极拼用户实验的结论。可爱风和酷感风按视觉偏好组织，所有人都能选用；不能从性别推断每个人喜欢粉色、机甲或某一种画风。

## 样本、时间与证据边界

资料于 **2026-09-10** 查询。首轮覆盖中国大陆商店的 6 款产品、美国商店的 14 款产品；补充 LiveCollage、PicFrame、Shuffles 和 Fotor 后，共 **24 款主样本**，另核对 Tailor 和原版 Layout，总计 26 个条目。样本覆盖多功能修图、专用拼图、手账海报、社交内容和长截图。它们累计评分均超过 4.5，但 Diptic 的维护时间明显较早，应作为交互参考，而非无条件推荐安装。

这是一份有边界的市场地图，不声称穷尽所有地区、同名 App、Android 专用产品或网页工具。没有把付费下载、商店排名、累计评分当成实际任务成功率，也没有声称已经购买或逐个实测竞品。功能来自开发者商店介绍、官方网站与帮助中心；负面体验来自公开用户自述，未经独立复现。

评分、数量、版本和更新时间优先采用 Apple 的 **software lookup**，避免把 iPhone、Mac 页面或不同地区混在一起。数值取两位小数便于比较；不是精度达到两位小数的质量测量。[原始事实快照](app-store-snapshot-2026-09-10.json) 保存每个 App 的 ID、开发者、来源、版本和读取时间。

同时请求首轮条目的商店“最近评论”第一页，20 个反馈源返回各 50 条，共 1,000 条评论元数据；Collageable 和 Layout 没有返回评论条目。定向阅读了其中的正负评论，并用网页评价补充 Collageable。**这不是随机样本，也不是对全部 1,000 条正文的人工编码**。某些产品 50 条跨越数年，RSS 按更新而非统一的发表窗口呈现；不能直接比较各产品“差评率”。星级和正文还会矛盾，例如有五星评论实际在报告崩溃。评论统计仅用于发现需要追问的线索。

## 产品地图

下表“价值”是对已列功能的分析；功能是否免费、广告频次和会员权益可能随地区、版本、活动而变。除 Diptic 是付费下载加内购，首轮其他主样本均为免费下载并提供内购；“免费下载”不能理解为“所有功能免费”。本次不拿未经购买核验的价格做购买建议。

| 产品 / 商店 | 评分 / 评分数 | 已确认的有价值功能 | 为什么值得学；需要反问什么 |
| --- | --- | --- | --- |
| [美图秀秀][s1] / CN | 4.89 / 12,570,949 | 模板、自由布局、横竖长拼、截图智能拼接、配方、贴纸文字边框、滤镜调色 | 素材和编辑闭环减少换 App；但工具广度不等于选图到导出的路径短。应学习成套配方和分类，不复制 IP 形象或整个功能体量。 |
| [醒图][s2] / CN | 4.79 / 628,921 | 人像精修、局部微调、滤镜和素材、一站式编辑 | 控制细节且保留个人特征是价值；对拼图来说优先统一画面色调，无需先扩展成全能美颜。Mac 版批量描述不能直接算作 iPhone 已验证能力。 |
| [黄油相机][s3] / CN | 4.85 / 279,065 | 场景模板、原创与授权字体、花字、贴纸和滤镜 | 成片质感来自字体、间距和素材的一致性；更多字体会增加寻找负担。应有真实缩略图、主题入口和收藏。 |
| [简拼][s4] / CN | 4.92 / 177,913 | 留白海报、胶片与拍立得、日签、横竖长拼、照片视频布局 | 设计约束帮助普通用户做出协调版面；约束过强则换照片、长标题后难修。风格应可修改且能撤销。 |
| [拼图酱][s5] / CN | 4.71 / 33,178 | 按照片生成布局、人物居中（官方描述）、创意磁贴、长图整体和大图预览 | 减少无关布局和裁切试错；算法仍可能切掉边缘主体。极拼先做可解释的横竖比例推荐，保留全量布局及手动裁切。 |
| [Piczoo][s6] / CN | 4.80 / 389,009 | 自动匹配布局、像素与手绘贴纸、蕾丝等边框、比例适配 | 装饰能直接建立风格；官方“高清”仍缺具体像素口径。最新查询版本更新于 2025-08，素材数量不等于维护质量。 |
| [PicCollage][s7] / US | 4.79 / 1,836,626 | 网格与自由拼贴、贺卡、场景主题、照片和视频、贴纸 | 生日、旅行等任务入口容易理解；免费体验的正负评论并存，可能涉及不同模板或权益，不能宣布全部免费或全部强制付费。 |
| [PhotoGrid][s8] / US | 4.87 / 117,478 | 多比例、自由手账、照片视频网格、文字边框、定制模板 | 一次编辑适配不同用途；大量布局会增加搜索成本。开发者确认为 JUPITER PALACE，排除同名的其他 PhotoGrid。 |
| [Pic Stitch][s9] / US | 4.67 / 65,825 | 布局、边框包、照片效果、文字、前后对比、比例调整 | 结构化网格和对比任务实用；近期评论中的广告等待说明，保存一个简单对比图也可能因商业流程变慢。 |
| [InCollage][s10] / US | 4.85 / 9,757 | 最多 20 图、网格、自由手账、抠图、文字背景、无裁切展示 | 照片较多时更省反复拼接；高数量不保证小屏易选中或导出清晰。iOS 与 Android 的权益不能混用。 |
| [MOLDIV][s11] / US | 4.74 / 37,820 | 杂志布局、相框、主题滤镜、字体、画中画 | 杂志排版与摄影调色组合完整；截图保存和可继续编辑的项目是两种能力，必须区分。 |
| [Diptic][s12] / US | 4.53 / 3,007 | 拖动内部框线、定制布局复用、边框纹理、照片视频 | 让框适应照片很有价值；查询到的版本仍为 2021 年更新，不用历史口碑替代当前兼容性测试。 |
| [Collageable][s13] / US | 4.76 / 509,994 | 大量网格、相框、背景和编辑工具 | 易开始的家庭拼图有稳定场景；精选评论对自定义功能付费和广告提出意见，不能只看累计高分。 |
| [Canva][s14] / US | 4.87 / 3,523,890 | 模板、图像编辑、设计元素、协作、批量内容、多种交付物 | 模板和复用降低设计门槛；手机一次拼四张图未必需要协作、AI 助手或营销平台。移植应保持任务聚焦。 |
| [Picsart][s15] / US | 4.67 / 1,194,945 | 自由组合、贴纸、背景移除、编辑和模板 | 组合创作空间大、工具集中；编辑自由越大，图层、恢复和导出一致性越要可靠。 |
| [Unfold][s16] / US | 4.86 / 158,530 | 简约、胶片等成套模板、滤镜、字体、品牌素材复用 | 审美约束和成套素材省配色时间；当前官方说明免费模板带水印，不能沿用早期免费推荐文章。 |
| [SCRL][s17] / US | 4.83 / 120,453 | 自由拼贴、连贯轮播、结构布局、精选模板 | 作品以一组图片讲故事；需要明确分图顺序、尺寸及图片跨页的连续性，不只提供长画布。 |
| [Bazaart][s18] / US | 4.80 / 260,417 | 抠图、描边阴影、吸附、微移、图层、批量编辑、透明 PNG | 精确控制与可逆编辑让复杂拼贴可用；不能用更多 AI 工具代替基础触控精度。 |
| [Adobe Express][s19] / US | 4.83 / 367,512 | 模板、品牌风格、跨格式尺寸、多种内容制作 | 重复创作和一致性对持续使用者有价值；极拼可先保存照片无关的风格，避免账号或云服务成为前置条件。 |
| [Picsew][s20] / US | 4.69 / 3,074 | 截图拼接、手动调整、标注、图片/PDF、超长图切片、分享入口 | 导出以阅读和交付为中心；自动拼接应能纠错，长图也应允许分页，不能只有缩到看不清这一条路。 |

20 款产品中，最值得优先借鉴的是美图秀秀的配方组织、黄油相机的整体美学、拼图酱的布局适配、Diptic 的框线控制、SCRL/Picsew 的多图交付，以及 Bazaart 的可逆编辑。这个选择以极拼当前场景为依据，不代表它们对所有人都优于其他软件。

### 补充样本与结论修正

| 产品 / 美国商店 | 评分 / 数量 | 已核实功能与价值 | 对原结论的挑战 |
| --- | --- | --- | --- |
| [LiveCollage](https://apps.apple.com/us/app/collage-maker-livecollage/id530957474) | 4.78 / 176,234 | 可调布局、自由手账、轮播、字体、边框、照片视频等广泛组合 | 功能多未必一定难用，关键是入口与层次。其官方最多 64+ 图的描述是容量参考，不作为极拼也应升到 64 图的依据。 |
| [PicFrame](https://apps.apple.com/us/app/picframe/id433398108) | 4.84 / 17,101 | 可调框线、定制框、16 图/视频、阴影、标签、打印布局预览 | 近期更新仍在改进框线编辑，补强了 Diptic 较老证据的时效性。正确产品开发者为 Active Development，排除同名 App。 |
| [Shuffles](https://apps.apple.com/us/app/shuffles-by-pinterest/id1573869498) | 4.79 / 43,252 | 一键抠图、图层、素材搜索和保存、混搭、协作与社区 | “尽快导出”不是全部价值。审美探索和创作乐趣本身也是目的；有些用户愿意慢慢贴，而不需要默认替他们设计。 |
| [Fotor](https://apps.apple.com/us/app/fotor-ai-photo-editor-video/id440159265) | 4.66 / 42,296 | 图像编辑、增强、替换、生成与营销视觉 | 高分可能主要由生成式修图而非拼图贡献。当前 iPhone 描述聚焦 AI，不能把网页版的全部拼图能力直接计入 iPhone；作为综合编辑参照，降低其拼图决策权重。 |

补充样本只做产品事实和官方页面评价核对，没有纳入前述 RSS 1,000 条样本。它们没有改变 V2 五项交付，却修正了两种过强结论：**“功能越少越好”与“越快完成越好”都不普遍成立。** 工具型用户需要短路径，创作型用户需要可探索的空间；极拼应让两种路径共存。研究因此支持按需打开风格库、可撤销地套用，保留自由画布，而不是给所有人强制自动出图。

### 按任务解释“好用”，而不是评出一款总冠军

| 用户任务 | 真正需要优化的结果 | 借鉴对象 | 极拼的具体取舍 |
| --- | --- | --- | --- |
| 两张前后对比图发给朋友 | 顺序正确、边界清楚、无需研究模板 | Pic Stitch、PicFrame | 直接多选、推荐布局、可调框线；不自动重排照片以提高分数 |
| 把一次旅行拼成四到九图 | 色调协调、重要内容不被裁掉 | 拼图酱、PhotoGrid、简拼 | 几何推荐加人工调整；风格可改，不强制套统一滤镜 |
| 做生日卡或宠物手账 | 有表达、素材彼此协调、摆放有趣 | PicCollage、黄油相机、美图秀秀 | 原创素材成套交付，允许慢慢贴；不拿用户多花创作时间判定失败 |
| 做穿搭/房间灵感板 | 快速收集、抠图、反复组合、灵感关联 | Shuffles、Bazaart | 当前先满足本地自由拼贴；抠图和社区分别评估，不能把联网素材生态伪装成离线已具备 |
| 为一组社交内容保持统一 | 可复用的配色、字体、画幅和交付顺序 | Unfold、Canva、SCRL、Adobe Express | V2 复用风格参数，明确还不是完整的品牌工具或跨页轮播编辑器 |
| 分享长聊天、收据或教程 | 字能读清、内容没有漏、接缝能修 | Picsew、Tailor 对照 | 连续分页先保证完整；保留普通裁切，语义分页和自动去重不夸大为已实现 |

对用户任务进行分层后，极拼当前适合的是“手机上整理照片和做轻量拼贴”。专业营销团队需要协作、字体授权管理、批量品牌交付；它们可能更适合 Canva 或 Adobe Express。宣称无需账号和离线处理天然胜过云服务，是忽视另一类用户需求。本地版本的优势是少前置条件、独立工作，代价是暂无跨设备协作和在线资源规模。

### 商业模式的公平反驳

广告、订阅与付费素材并不自动意味着设计差。长期更新模板、购买字体与 IP 授权、运行模型和服务都需要资金；专业创作者可能愿意为省时付费。用户评论中对收费的不满，也可能来自试用理解偏差或找错账号，不宜把退款相关说法当成已核实事实。

应借鉴的原则是**预期一致**：开始使用资源时就知道限制；完成作品后能理解为什么某个导出选项不可用；曾购权益和恢复路径清楚。极拼的这两个版本不引入广告、内购或账号，但这只是当前实施范围，不是经过验证的长期盈利模式。未来若收费，先保持现有基础导出和本地草稿可用，再明确新增权益，不用保存到最后一步的沉没成本迫使用户付款。

### 证据强弱与可以推翻结论的实验

| 判断 | 当前证据强度 | 最有价值的反驳 / 验证 |
| --- | --- | --- |
| 预览与导出一致、草稿恢复可靠是基础 | 高：跨产品反复出现的任务需求和失败报告；不是失败频率估计 | 让新功能全部通过保存重开与像素接缝测试；若仍有丢失或漏图，应暂停加素材先修复 |
| 按宽高比推荐能减少选布局试错 | 中：竞品功能与几何原理支持，尚无极拼行为数据 | 固定含横竖混图、脸在边缘、截图文字的素材，比较开启/关闭推荐的试排次数；若次数不降或主体更常被切，调整排序或默认关闭 |
| 可复用风格值得独立入口 | 中：多款产品有配方/品牌/模板复用，但它们不完全等同于极拼的简化风格 | 让用户在第二份作品复用，检查是否误以为会恢复文字和布局；若误解，改文案或扩展独立模板功能 |
| 16 个协调贴图比大量散乱贴图更适合当前阶段 | 中低：设计约束与任务分析，没有审美偏好的代表性调查 | 用同一照片比较成套与混合素材选择时间、作品自评和继续使用意愿；不同人群独立观察，不按性别预设答案 |
| 固定连续分页能满足多数长图分享 | 中低：Picsew 有切片机制，但语义断点需求未测 | 让用户阅读含跨页句子/人脸的成品；若频繁手动回退改尺寸，应优先增加手动分页点，而不是更多页形比例 |
| 开始时不加入云端 AI 是合适取舍 | 中：目前本地范围、交付成本与目标任务匹配 | 若真实使用者大量需要抠图，先验证系统本地能力与发丝/透明物体失败集，再决定；不把“无 AI”当品牌教条 |

### 对照与身份排除

[Tailor][tailor] 在美国商店是 3.07 分 / 8,252 个评分；它的自动重叠拼接仍有值得学习的想法，但不应被列为当前高评价推荐。最新查询更新在 2023 年；2026 年评论同时包含流畅易用的肯定和不识别截图、权限处理、系统兼容性问题的批评。对极拼的教训是：自动化失败时必须保留手动路径，而不是让用户被困在等待识别的入口。

原版 Layout from Instagram 的 ID `967351793` 在本次美国区 software lookup 返回空结果，不能据此宣布全球下架，但也不能用搜索到的同名第三方产品冒充 Meta 原作。本报告未给它编造当前评分。[Apple 查询][layout-lookup]。

## 公开评价中的反证

下表是对原始评论的转述，不是对竞品现有缺陷的独立鉴定。多条反馈指向同类风险时，优先把风险转成极拼可测的验收条件，而不是形成“某软件很差”的结论。

| 线索 | 来源与时间 | 反证和产品含义 |
| --- | --- | --- |
| 免费与付费评价互相冲突 | PicCollage RSS，2026-09-05 至 09-08；官方同时列内购 | 有用户肯定可免费创作，也有人表示保存草稿遇到订阅提示。需要按具体资源和步骤复测，不能以一句“免费”承诺整条流程。[评论][r7] |
| 累计高分掩盖近期不满 | 醒图 RSS，本次 50 条中 43 条为 1–2 星，日期集中在 2026-09-07/08 | 正文主要线索是基础功能转付费和多层会员。这个短期便利样本可能受版本变化影响，不是全量用户的满意度估计。[评论][r2] |
| 保存后无法继续原来的编辑 | 美图秀秀 2026-09-08、Picsart 2026-09-08、MOLDIV 2026-09-03 的用户自述 | 草稿恢复比再多十个滤镜更基础。极拼已有原子保存；新增风格、框线和装饰必须进入保存/重开/撤销回归。[美图][r1]、[Picsart][r15]、[MOLDIV][r11] |
| 广告破坏最短路径 | PhotoGrid 2026-08-30、Pic Stitch 2026-09-03/04、黄油相机 2026-09-04 | 这不是“不愿付费”的同义词，而是退出广告困难、误点和等待。极拼继续保留直接编辑与导出，不在中途插营销弹窗。[PhotoGrid][r8]、[Pic Stitch][r9]、[黄油][r3] |
| 预览清楚但保存模糊 | Unfold 2026-07-24 的评论 | 单条反馈不能证明通病，但明确了测试要求：导出像素、跨页完整性、预览和成品一致性要检查。[评论][r16] |
| 手势容易混淆 | 黄油相机 2026-09-04 评论把移动误触为缩放；Canva 商店有触屏控制困难反馈 | 素材添加成功只是第一步；必须能选中、移动、调大小、撤销，另有按钮和滑杆作为手势替代。[黄油][r3]、[Canva 评价][canva-reviews] |
| 买过的权益难理解 | SCRL 2026-09-05、Unfold 2026-08-07、简拼 2026-08-16 | 订阅、旧购买、恢复账号的边界可能不同，不能直接断定违规。极拼目前不接入付费体系，不把商业化复杂度混进两个本地版本。[SCRL][r17]、[Unfold][r16]、[简拼][r4] |
| 算法成功时极省事，失败时完全堵住 | Tailor 最近评论；Picsew 官方提供手动调整与切片 | 不能为了“智能”静默删内容。截图自动去重在缺少真实截图验证集时不作为当前版本卖点；先做好完整分页和手工裁切。[Tailor][tailor-reviews]、[Picsew][s20] |

### 反对自身方案：哪些“好功能”可能做错

| 初始主张 | 最强反对意见 | 本次决策与失败判据 |
| --- | --- | --- |
| 推荐布局一定更省事 | 横竖比例合适仍可能裁掉脸、文字或地标 | 仅称“少裁切推荐”；不宣称识别人脸，不调换照片顺序。保留全部布局，用户可切回。缺尺寸时稳定回退。 |
| 一键风格能统一照片 | 同滤镜对夜景和肤色影响不同，覆盖已有修图会破坏作品 | 可单独调强度、可撤销；批量操作跳过锁定照片，明确只同步效果，不覆盖裁切和遮挡。 |
| 自定义模板应该保存一切 | 保存照片引用会带入隐私和破损依赖；跨数量复用易丢图 | V2 保存“我的风格”，只含配色、边距、圆角、相框和照片效果；不冒充完整自定义模板。照片、文字、布局仍在草稿里。 |
| 框线自由拖动很专业 | 小屏拖错、照片挤成细条、版式出现空洞 | 移动同一条边界上所有相邻格；提供明确的滑杆、最小间隔和重置；撤销按一次手势处理。 |
| 分页总比缩图好 | 固定切片可能把人脸、文字从中间切开 | 导出前显示方向、页数、尺寸和切片预览；最后一页保留全部剩余内容。明确这是连续切片，不是语义分页。 |
| 女生喜欢可爱，所以全改粉色 | 审美偏好并不由性别统一决定，过度装饰会盖住照片 | 建立可爱、清新、酷感入口；主界面维持可读性，贴图可移除，边框保留中间图像区域。 |
| 18 张漂亮图片就是完整素材功能 | 无透明边缘、缩放糊、难搜索、重启后丢失都不可用 | 原创矢量素材共享预览与导出路径；分类、命名、收藏、搜索、撤销、恢复都纳入 V3 验收。 |
| 竞品有 AI，我们也该加 | 抠图、去重、生成可能引入耗时、错误、模型或服务依赖 | 本次不加云端生成、社区、视频或自动去重；先兑现离线静态拼图。后续用真实任务和失败集重新决策。 |

## V2.0：降低试错和重复操作

V1 已有四种模式、基本图层、收藏、滤镜批量应用和草稿。下列项目是增量，不能把原有功能重新计为 V2 完成。

| 交付项 | 对应问题 | 实现边界 | 验收条件 |
| --- | --- | --- | --- |
| 少裁切布局推荐与实图预览 | 选布局靠反复试 | 按照片顺序、宽高比和画布估算裁切，推荐与全部布局均可选 | 横图/竖图候选排序不同；不改照片顺序；换比例重新推荐；候选显示当前照片 |
| 可调模板分隔线 | 模板框不适合照片 | 移动共线格子边界，支持撤销、重置 | 不重叠、不留洞、不出现零尺寸；恢复草稿后位置一致 |
| 一键风格与“我的风格” | 背景、圆角、滤镜反复调 | 六套内置风格；本机保存风格参数供其他作品复用 | 锁定照片不被改；不保存照片与文字引用；跨照片数应用；保存失败有提示 |
| 整组色调同步 | 单独调色重复操作 | 同步当前照片滤镜强度和调色，保留裁切、遮挡、旋转 | 一次撤销全部恢复；锁定对象不变；无照片选中时禁用 |
| 长图分页导出 | 超长成品缩得太小 | 横竖连续切片，逐页渲染，系统分享/文件交付及相册保存 | 所有像素区间连续覆盖；最后一页完整；任务失败不报成功；文件名有序；有大小与页数预览 |

六套风格选择不同使用情境：奶油日记、薄荷旅行、胶片时光、极简留白、落日来信、午夜街头。卡片必须展示成品，不能只是一排颜色名字。新工具放进既有布局、调色和导出流程，风格以独立入口集中展示。

优先级是基于当前代码和研究的判断，并非伪装成统计结论的评分模型。上述五项共同改善一次拼图从选图到交付的闭环；推荐失败有手动候选，风格不合适可撤销，长图过大可分页。

## V3.0：原创装饰素材与风格搭配

交付 **16 个可爱贴图 + 2 个酷感贴图**，另做 **6 款可爱边框**。可爱贴图采用奶油白、草莓粉、黄油黄、薄荷和丁香紫的柔和配色，深棕描线、圆润造型、少量高光；同一套中保持相近的描边和留白。酷感贴图用墨黑、电光蓝与荧光绿，强调速度和锐利轮廓。

素材方向包括兔兔、熊熊、猫咪、草莓、樱桃、蝴蝶结、花朵、云朵、星月、爱心信封、布丁、奶茶、蜜桃、彩虹、糖果和小蛋糕；酷感贴图为闪电徽章和星际飞行。边框为奶油花边、草莓糖纸、樱花信笺、薄荷格纹、星星梦境和蝴蝶结礼物。

学习美图秀秀和黄油相机的是“同风格成套、分类好找、加入即可编辑”的组织方法；不复刻它们的素材或合作 IP。使用仓库原有原生矢量渲染体系制作可放大的原创图形，避免字体 emoji 回退，也便于做真正透明的贴图和镂空边框。授权/来源及可审阅素材板随仓库交付。

## 验证与后续取舍

每个版本都需在模拟器完成核心单测、用户流程、渲染导出和小屏检查，更新版本号并单独 commit；V3 开始前先提交 V2。V1 的修复也独立提交。模拟器通过不能当作 TestFlight、真实相册宿主、共享容器签名、真机内存和照片权限已验收。

后续最有价值的用户实验不是问“你喜欢吗”，而是让首次使用者完成三件事：四图排版并导出、换一套风格再加两个贴图、把多张截图拼成能阅读的分享图。记录完成率、总用时、尝试布局次数、撤销原因及导出失败；对推荐关闭/开启做相同素材的顺序平衡比较。没有测量前，不承诺提高某个百分比。

自动截图去重、电影字幕提取、完整自定义模板、跨页语义避让、人物抠图、视频/Live、云同步和商业化另列候选。前两项须先收集并标注重复空白、固定头尾、半透明栏、不同尺寸和漏截等失败集；其余以用户任务证明收益后再扩展。

## 来源

以下商店和官方页面均于 2026-09-10 查阅；具体版本与发布日期见事实快照。Apple RSS 是动态入口，正文会滚动变化；快照只保存评论 ID、评分和更新时间以标记样本，没有转载整批用户正文。开发者功能描述是第一方声明，评论为用户报告，两者与本报告的分析判断分别使用。

### Apple 数据来源索引

| 发布者 / 产品 | 查询版本 / 更新时间 | 最近评论样本覆盖 | 来源 |
| --- | --- | --- | --- |
| Meitu Technology Co., Ltd. / 美图秀秀 | 12.17.0 / 2026-08-17 | 50 条，2026-09-03–2026-09-08 | [产品事实](https://itunes.apple.com/lookup?id=416048305&country=cn&entity=software) · [评论来源](https://itunes.apple.com/cn/rss/customerreviews/page=1/id=416048305/sortby=mostrecent/json) |
| 深圳市脸萌科技有限公司 / 醒图 | 15.4.0 / 2026-09-04 | 50 条，2026-09-07–2026-09-08 | [产品事实](https://itunes.apple.com/lookup?id=1500526240&country=cn&entity=software) · [评论来源](https://itunes.apple.com/cn/rss/customerreviews/page=1/id=1500526240/sortby=mostrecent/json) |
| 北京缪客科技有限公司 / 黄油相机 | 10.34.3 / 2026-08-29 | 50 条，2025-11-15–2026-09-04 | [产品事实](https://itunes.apple.com/lookup?id=587176822&country=cn&entity=software) · [评论来源](https://itunes.apple.com/cn/rss/customerreviews/page=1/id=587176822/sortby=mostrecent/json) |
| Shanghai Ruishixinyan Information Technology Co., Ltd / 简拼 | 4.6.7 / 2026-07-23 | 50 条，2026-05-08–2026-09-07 | [产品事实](https://itunes.apple.com/lookup?id=891640660&country=cn&entity=software) · [评论来源](https://itunes.apple.com/cn/rss/customerreviews/page=1/id=891640660/sortby=mostrecent/json) |
| ChengDu PinGuo Technology Co., Ltd. / 拼图酱 | 2.9.31 / 2026-01-05 | 50 条，2023-11-30–2026-09-07 | [产品事实](https://itunes.apple.com/lookup?id=1121943475&country=cn&entity=software) · [评论来源](https://itunes.apple.com/cn/rss/customerreviews/page=1/id=1121943475/sortby=mostrecent/json) |
| Xi'an Button Software Technology Co., Ltd. / Piczoo | 4.7.7 / 2025-08-28 | 50 条，2023-01-01–2026-04-21 | [产品事实](https://itunes.apple.com/lookup?id=956441499&country=cn&entity=software) · [评论来源](https://itunes.apple.com/cn/rss/customerreviews/page=1/id=956441499/sortby=mostrecent/json) |
| Cardinal Blue / PicCollage | 8.66.1 / 2026-08-25 | 50 条，2026-09-05–2026-09-08 | [产品事实](https://itunes.apple.com/lookup?id=448639966&country=us&entity=software) · [评论来源](https://itunes.apple.com/us/rss/customerreviews/page=1/id=448639966/sortby=mostrecent/json) |
| JUPITER PALACE PTE. LTD. / PhotoGrid | 9.3.00 / 2026-09-08 | 50 条，2026-08-21–2026-09-08 | [产品事实](https://itunes.apple.com/lookup?id=543577420&country=us&entity=software) · [评论来源](https://itunes.apple.com/us/rss/customerreviews/page=1/id=543577420/sortby=mostrecent/json) |
| Maple Media Apps, LLC / Pic Stitch | 8.4.2 / 2026-08-24 | 50 条，2026-01-24–2026-09-04 | [产品事实](https://itunes.apple.com/lookup?id=454768104&country=us&entity=software) · [评论来源](https://itunes.apple.com/us/rss/customerreviews/page=1/id=454768104/sortby=mostrecent/json) |
| SHANTANU PTE. LTD. / InCollage | 2.2.60 / 2026-08-22 | 50 条，2024-12-19–2026-09-03 | [产品事实](https://itunes.apple.com/lookup?id=1446828002&country=us&entity=software) · [评论来源](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1446828002/sortby=mostrecent/json) |
| JellyBus Inc. / MOLDIV | 7.3.2 / 2026-06-05 | 50 条，2026-08-07–2026-09-07 | [产品事实](https://itunes.apple.com/lookup?id=608188610&country=us&entity=software) · [评论来源](https://itunes.apple.com/us/rss/customerreviews/page=1/id=608188610/sortby=mostrecent/json) |
| Rhia Bucklin / Diptic | 10.1.1 / 2021-02-01 | 50 条，2022-04-07–2026-08-25 | [产品事实](https://itunes.apple.com/lookup?id=377989827&country=us&entity=software) · [评论来源](https://itunes.apple.com/us/rss/customerreviews/page=1/id=377989827/sortby=mostrecent/json) |
| IRONTECH LIMITED / Collageable | 3.22.1 / 2026-08-28 | 本次未返回条目 | [产品事实](https://itunes.apple.com/lookup?id=1085652055&country=us&entity=software) · [评论来源](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1085652055/sortby=mostrecent/json) |
| Canva / Canva | 4.225.1 / 2026-09-03 | 50 条，2026-09-06–2026-09-08 | [产品事实](https://itunes.apple.com/lookup?id=897446215&country=us&entity=software) · [评论来源](https://itunes.apple.com/us/rss/customerreviews/page=1/id=897446215/sortby=mostrecent/json) |
| PicsArt, Inc. / Picsart | 30.7.1 / 2026-09-03 | 50 条，2026-09-06–2026-09-08 | [产品事实](https://itunes.apple.com/lookup?id=587366035&country=us&entity=software) · [评论来源](https://itunes.apple.com/us/rss/customerreviews/page=1/id=587366035/sortby=mostrecent/json) |
| Squarespace, Inc. / Unfold | 8.163.0 / 2026-08-31 | 50 条，2025-07-07–2026-08-07 | [产品事实](https://itunes.apple.com/lookup?id=1247275033&country=us&entity=software) · [评论来源](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1247275033/sortby=mostrecent/json) |
| Appostrophe AB / SCRL | 9.52 / 2026-09-07 | 50 条，2026-08-23–2026-09-08 | [产品事实](https://itunes.apple.com/lookup?id=1289057196&country=us&entity=software) · [评论来源](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1289057196/sortby=mostrecent/json) |
| Bazaart Ltd. / Bazaart | 27.0.0 / 2026-09-09 | 50 条，2026-09-02–2026-09-08 | [产品事实](https://itunes.apple.com/lookup?id=515094775&country=us&entity=software) · [评论来源](https://itunes.apple.com/us/rss/customerreviews/page=1/id=515094775/sortby=mostrecent/json) |
| Adobe Inc. / Adobe Express | 30.8.0 / 2026-08-28 | 50 条，2026-08-05–2026-09-07 | [产品事实](https://itunes.apple.com/lookup?id=1051937863&country=us&entity=software) · [评论来源](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1051937863/sortby=mostrecent/json) |
| Yojio, Ltd. / Picsew | 3.18.1 / 2026-09-08 | 50 条，2025-05-18–2026-09-07 | [产品事实](https://itunes.apple.com/lookup?id=1208145167&country=us&entity=software) · [评论来源](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1208145167/sortby=mostrecent/json) |
| Foundry 63 / Tailor（对照） | 2.1.1 / 2023-02-20 | 50 条，2026-04-12–2026-09-01 | [产品事实](https://itunes.apple.com/lookup?id=926653095&country=us&entity=software) · [评论来源](https://itunes.apple.com/us/rss/customerreviews/page=1/id=926653095/sortby=mostrecent/json) |
| 未确认 / Layout from Instagram（身份核对） | — / — | 本次未返回条目 | [产品事实](https://itunes.apple.com/lookup?id=967351793&country=us&entity=software) · [评论来源](https://itunes.apple.com/us/rss/customerreviews/page=1/id=967351793/sortby=mostrecent/json) |

| VIDEO EDITOR PTE. LTD. / LiveCollage | 16.6.10 / 2026-07-15 | 补充核对，未取 RSS 样本 | [产品事实](https://itunes.apple.com/lookup?id=530957474&country=us&entity=software) |
| Active Development Limited / PicFrame | 15.17 / 2026-09-04 | 补充核对，未取 RSS 样本 | [产品事实](https://itunes.apple.com/lookup?id=433398108&country=us&entity=software) |
| Pinterest, Inc. / Shuffles | 3.7 / 2026-08-04 | 补充核对，未取 RSS 样本 | [产品事实](https://itunes.apple.com/lookup?id=1573869498&country=us&entity=software) |
| Chengdu Everimaging Science and Technology Co., Ltd / Fotor | 11.2.11 / 2026-08-20 | 补充核对，未取 RSS 样本 | [产品事实](https://itunes.apple.com/lookup?id=440159265&country=us&entity=software) |

[s1]: https://apps.apple.com/cn/app/id416048305
[s2]: https://apps.apple.com/cn/app/id1500526240
[s3]: https://apps.apple.com/cn/app/id587176822
[s4]: https://apps.apple.com/cn/app/id891640660
[s5]: https://apps.apple.com/cn/app/id1121943475
[s6]: https://apps.apple.com/cn/app/id956441499
[s7]: https://apps.apple.com/us/app/piccollage-magic-photo-editor/id448639966
[s8]: https://apps.apple.com/us/app/photogrid-video-collage-maker/id543577420
[s9]: https://apps.apple.com/us/app/pic-stitch-collage-editor/id454768104
[s10]: https://apps.apple.com/us/app/photo-collage-maker-incollage/id1446828002
[s11]: https://apps.apple.com/us/app/moldiv-photo-editor-collage/id608188610
[s12]: https://apps.apple.com/us/app/diptic/id377989827
[s13]: https://apps.apple.com/us/app/photo-collage-collageable/id1085652055
[s14]: https://apps.apple.com/us/app/canva-ai-photo-video-editor/id897446215
[s15]: https://apps.apple.com/us/app/picsart-ai-photo-editor-video/id587366035
[s16]: https://apps.apple.com/us/app/unfold-reels-story-maker/id1247275033
[s17]: https://apps.apple.com/us/app/scrl-photo-collage-maker/id1289057196
[s18]: https://apps.apple.com/us/app/bazaart-ai-photo-editor-design/id515094775
[s19]: https://apps.apple.com/us/app/adobe-express-create-anything/id1051937863
[s20]: https://apps.apple.com/us/app/picsew-screenshot-stitching/id1208145167
[unfold]: https://support.squarespace.com/hc/en-us/articles/360054398632-Unfold-mobile-app
[tailor]: https://apps.apple.com/us/app/tailor-screenshot-stitching/id926653095
[tailor-reviews]: https://apps.apple.com/us/app/tailor-screenshot-stitching/id926653095?platform=iphone&see-all=reviews
[layout-lookup]: https://itunes.apple.com/lookup?id=967351793&country=us&entity=software
[canva-reviews]: https://apps.apple.com/us/app/canva-ai-photo-video-editor/id897446215?platform=ipad&see-all=reviews
[r1]: https://itunes.apple.com/cn/rss/customerreviews/page=1/id=416048305/sortby=mostrecent/json
[r2]: https://itunes.apple.com/cn/rss/customerreviews/page=1/id=1500526240/sortby=mostrecent/json
[r3]: https://itunes.apple.com/cn/rss/customerreviews/page=1/id=587176822/sortby=mostrecent/json
[r4]: https://itunes.apple.com/cn/rss/customerreviews/page=1/id=891640660/sortby=mostrecent/json
[r7]: https://itunes.apple.com/us/rss/customerreviews/page=1/id=448639966/sortby=mostrecent/json
[r8]: https://itunes.apple.com/us/rss/customerreviews/page=1/id=543577420/sortby=mostrecent/json
[r9]: https://itunes.apple.com/us/rss/customerreviews/page=1/id=454768104/sortby=mostrecent/json
[r11]: https://itunes.apple.com/us/rss/customerreviews/page=1/id=608188610/sortby=mostrecent/json
[r15]: https://itunes.apple.com/us/rss/customerreviews/page=1/id=587366035/sortby=mostrecent/json
[r16]: https://itunes.apple.com/us/rss/customerreviews/page=1/id=1247275033/sortby=mostrecent/json
[r17]: https://itunes.apple.com/us/rss/customerreviews/page=1/id=1289057196/sortby=mostrecent/json
