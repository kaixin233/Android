# 二级建造师学习平台

基于 Flutter 构建的二级建造师考试学习平台，提供完整的题库练习、错题分析、批注笔记、知识点评估与 AI 答疑功能。

## 🎯 功能特性

### 五大模块（底部导航）
- **学习**：今日练习、学习进度、推荐学习模块、学习统计
- **题库**：按科目/章节/题型/难度筛选练习、收藏题目、错题本
- **教材**：三科完整章节大纲（法规、管理、市政实务），知识点卡片、配图放大、书签与继续阅读
- **计划**：学习计划制定与每日打卡进度
- **我的**：个人中心、主题与字号设置、数据导出/导入、本地自动备份

### 题库系统
- **庞大题库**：覆盖三科全部章节，约 12,000 道题目
- **题目类型**：单选题、多选题、判断题、填空题
- **智能筛选**：按科目、章节、题型、难度、收藏筛选
- **答案解析**：详细的题目解析和知识点说明
- **按需加载**：JSON 题库按章节分割，异步加载，避免内存占用过大

### 答题体验
- **左右滑动切题**：在章节练习 / 模拟考试中，左滑进入下一题、右滑返回上一题（与「上一题/下一题」按钮同步）；第一题右滑、最后一题左滑不触发，避免与题目区垂直滚动冲突
- **题目收藏**：练习/考试页顶部一键收藏，错题本与题库可按收藏过滤
- **震动反馈**：答题正确/错误有不同震动反馈（可开关）
- **进度条**：实时显示答题进度
- **多选题**：支持全选/取消全选
- **填空题**：模糊匹配（忽略空格和标点）
- **自动交卷**：考试模式时间到自动提交
- **语音朗读**：TTS 朗读题目与选项（防串台串行播放）

### 错题深度分析
- **错题统计**：按科目、题型、难度统计错题分布
- **趋势分析**：错误趋势图表展示
- **智能建议**：根据错题情况提供针对性复习建议
- **错题本**：按错题次数排序，支持移除后同步清理错误计数

### 批注与笔记
- **批注分类**：重点 / 疑问 / 待背，按分类配色高亮（橙 / 蓝 / 绿）
- **批注管理**：跨题型/字段的批注列表，标注全局生效或仅当前字段
- **学习笔记**：新建、编辑、删除学习笔记，支持重点/疑问/总结分类
- **标签搜索**：按标题、内容、标签搜索笔记，笔记可关联到具体题目

### 知识点掌握评估
- **雷达图**：多维度展示知识点掌握程度
- **薄弱点识别**：智能识别薄弱知识点
- **等级评定**：优秀/良好/中等/薄弱/需加强
- **练习推荐**：针对薄弱点推荐练习

### 阅读体验（教材模块）
- **全局字号缩放**：0.8×–1.4× 全局字号缩放，即时生效
- **护眼主题**：米黄护眼配色主题，与默认绿主题可切换
- **配图放大**：知识点配图支持双指/按钮全屏缩放查看
- **书签**：知识点一键加书签，跨章节保留
- **继续阅读**：首页展示各科目上次阅读进度，一键续读
- **上次进度记忆**：进入章节自动记录阅读位置

### AI 助手
- **知识点问 AI**：教材知识点卡片一键发起 AI 答疑
- **对话历史**：AI 问答历史持久化，可回溯查看
- **题目/批注选区问 AI**：选中题目或批注内容直接问 AI

### 搜索与数据
- **全局搜索**：跨「题目 / 批注 / 笔记」统一检索，结果分组直达对应页面
- **数据导出/导入**：全量导出（题库、历史、收藏、错题、笔记、计划、知识点统计、书签、阅读进度、AI 问答、打卡进度），逐字段容错导入，防止单字段损坏导致整体失败
- **本地自动备份**：每周自动备份到应用私有目录（保留最近 20 份），亦可手动立即备份
- **品牌启动屏**：应用启动展示品牌图标与标题

## 🛠️ 技术架构

### 技术栈
- **框架**：Flutter 3.44
- **语言**：Dart
- **状态管理**：Provider
- **数据存储**：SharedPreferences
- **图表库**：fl_chart
- **题库格式**：JSON（按章节分割）
- **AI 接入**：单一 AI 供应商（非多供应商切换）

### 架构模式
采用关注点分离：

```
lib/
├── main.dart                     # 应用入口（MaterialApp + 主题/字号/启动屏）
├── models/        # 数据模型
├── services/      # 业务逻辑服务（题库/存储/批注/备份/AI/TTS）
├── providers/     # 状态管理（AppProvider）
├── pages/         # 页面组件
├── widgets/       # 可复用组件（批注/AI 气泡/选区问 AI）
├── utils/         # 工具类（动画/AI 启动器）
└── data/          # 静态数据与教材大纲
```

## 📁 项目结构

```
lib/
├── main.dart                     # 应用入口
├── data/
│   ├── default_questions.dart    # 题库接口（异步加载 JSON）
│   └── textbooks.dart            # 教材大纲与章节数据
├── models/
│   ├── question.dart             # 题目模型
│   ├── note.dart                 # 笔记模型
│   ├── knowledge_point.dart      # 知识点模型
│   ├── history_item.dart         # 历史记录模型（含练习模式）
│   └── study_plan.dart           # 学习计划模型
├── services/
│   ├── question_service.dart     # 题目服务
│   ├── question_loader.dart      # JSON 题库加载器
│   ├── storage_service.dart      # 存储服务（导出/导入/收藏/错题/书签/进度）
│   ├── annotation_store.dart     # 批注存储（分类、并发去重加载）
│   ├── backup_service.dart       # 本地自动备份（保留最近 20 份）
│   ├── ai_service.dart           # AI 问答服务
│   ├── ai_qa_storage_service.dart# AI 对话历史持久化
│   ├── knowledge_service.dart    # 知识点统计服务
│   ├── tts_service.dart          # 题目语音朗读（串行防串台）
│   └── web_chat_bridge.dart      # Web 聊天桥接
├── providers/
│   └── app_provider.dart         # 全局状态管理
├── pages/
│   ├── home_page.dart            # 学习（底部导航）
│   ├── learn_page.dart           # 学习页面
│   ├── practice_page.dart        # 练习页面（含左右滑动切题）
│   ├── exam_mode_page.dart       # 模拟考试页面
│   ├── question_bank_page.dart   # 题库页面
│   ├── wrong_questions_page.dart # 错题本页面
│   ├── wrong_analysis_page.dart  # 错题分析页面
│   ├── note_page.dart            # 学习笔记页面
│   ├── knowledge_assessment_page.dart # 知识点评估页面
│   ├── study_plan_page.dart      # 学习计划页面
│   ├── textbook_page.dart        # 大纲与考点页面（书签/继续阅读/配图放大）
│   ├── global_search_page.dart   # 全局搜索页面
│   ├── ai_qa_history_page.dart   # AI 对话历史
│   ├── my_annotations_page.dart  # 我的批注
│   ├── stats_page.dart           # 统计页面
│   └── profile_page.dart         # 个人中心（主题/字号/备份/导出导入）
├── widgets/
│   ├── annotated_text.dart       # 可批注文本（分类配色）
│   ├── annotation_bubble.dart    # 批注气泡
│   ├── ai_assistant_sheet.dart   # AI 助手底部弹层
│   ├── ask_ai_selection_area.dart# 选区问 AI
│   └── deepseek_login_controls.dart # AI 登录控件
└── utils/
    ├── animations.dart           # 动画工具类
    └── ai_assistant_launcher.dart# AI 答疑启动器

assets/questions/                 # 题库 JSON 文件
├── law/                          # 法规（10章 + 真题）
├── management/                   # 管理（8章 + 真题）
└── practice/                     # 市政实务（18章 + 真题）
```

## 🚀 运行方式

### 环境要求
- Flutter SDK >= 3.44.0
- Dart SDK >= 3.0.0

### 安装依赖

```bash
flutter pub get
```

### 启动应用

```bash
# Android
flutter run

# 构建 APK
flutter build apk --release
```

## 📚 科目覆盖

| 科目 | 章节数 | 题目数量 |
|------|--------|----------|
| 建设工程法规及相关知识 | 10章 | ~4,800题 |
| 建设工程施工管理 | 8章 | ~4,400题 |
| 市政公用工程管理与实务 | 18章 | ~2,700题 |
| **合计** | **36章** | **~11,900题** |

## 📝 题库数据结构

每道题包含以下字段：

```json
{
  "id": "law_1_0001",
  "title": "题目简介",
  "prompt": "完整题目内容",
  "type": "singleChoice",
  "subject": "law",
  "difficulty": "medium",
  "options": ["选项A", "选项B", "选项C", "选项D"],
  "answerIndex": 0,
  "explanation": "详细解析",
  "chapter": "1",
  "subsection": "1.0",
  "knowledgePoints": ["建设工程法律体系"]
}
```

## 📝 开发说明

### 状态管理
使用 Provider 进行全局状态管理（AppProvider），统一管理：
- 题目数据（延迟加载）
- 学习历史
- 笔记数据
- 学习计划
- 收藏题目
- 错题数据（与错题计数同步）
- 知识点统计
- 书签与上次阅读进度
- 主题、字号、震动反馈等设置

### 数据持久化
使用 SharedPreferences 进行本地数据存储，支持：
- 学习历史记录
- 错题记录与错误次数
- 收藏题目
- 笔记数据
- 章节完成状态与打卡进度
- 批注（分类、跨字段）
- 书签与上次阅读进度
- AI 问答历史
- 用户设置（主题、字号、震动、自动备份）

数据导出/导入为全量覆盖（题库、历史、收藏、错题、笔记、计划、统计、书签、阅读进度、AI 问答、打卡进度），导入时按字段容错解析。

### CI/CD
使用 GitHub Actions 自动构建 APK，每次 push 到 main 分支触发：
- 构建 release APK
- 上传构建产物
- 创建 GitHub Release

## 📄 许可证

MIT License

## 👥 贡献

欢迎提交 Issue 和 Pull Request！
