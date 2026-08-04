# 二级建造师学习平台

基于 Flutter 构建的二级建造师考试学习平台，提供完整的题库练习、错题分析、学习笔记和知识点评估功能。

## 🎯 功能特性

### 学习模块
- **首页**：今日练习、学习进度、推荐学习模块
- **大纲与考点**：三科完整章节大纲（法规、管理、市政实务），支持展开/收起
- **章节练习**：按科目章节进行专项练习，实时显示题目数量
- **模拟考试**：模拟真实考试环境，计时答题

### 题库系统
- **庞大题库**：覆盖三科全部章节，约 12,000 道题目
- **题目类型**：单选题、多选题、判断题、填空题
- **智能筛选**：按科目、章节、题型、难度筛选
- **答案解析**：详细的题目解析和知识点说明
- **按需加载**：JSON 题库按章节分割，异步加载，避免内存占用过大

### 错题深度分析
- **错题统计**：按科目、题型、难度统计错题分布
- **趋势分析**：错误趋势图表展示
- **智能建议**：根据错题情况提供针对性复习建议

### 学习笔记
- **笔记管理**：新建、编辑、删除学习笔记
- **分类标签**：支持重点、疑问、总结等分类
- **标签搜索**：按标题、内容、标签搜索笔记
- **关联题目**：笔记可关联到具体题目

### 知识点掌握评估
- **雷达图**：多维度展示知识点掌握程度
- **薄弱点识别**：智能识别薄弱知识点
- **等级评定**：优秀/良好/中等/薄弱/需加强
- **练习推荐**：针对薄弱点推荐练习

### 答题体验
- **震动反馈**：答题正确/错误有不同震动反馈（可开关）
- **进度条**：实时显示答题进度
- **多选题**：支持全选/取消全选
- **填空题**：模糊匹配（忽略空格和标点）
- **自动交卷**：考试模式时间到自动提交

## 🛠️ 技术架构

### 技术栈
- **框架**：Flutter 3.x
- **语言**：Dart
- **状态管理**：Provider
- **数据存储**：SharedPreferences
- **图表库**：fl_chart
- **题库格式**：JSON（按章节分割）

### 架构模式
采用 MVC 架构模式，分离关注点：

```
lib/
├── models/        # 数据模型
├── services/      # 业务逻辑服务
├── providers/     # 状态管理
├── pages/         # 页面组件
├── utils/         # 工具类
└── data/          # 静态数据
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
│   ├── history_item.dart         # 历史记录模型
│   └── study_plan.dart           # 学习计划模型
├── services/
│   ├── question_service.dart     # 题目服务
│   ├── question_loader.dart      # JSON 题库加载器
│   └── storage_service.dart      # 存储服务
├── providers/
│   └── app_provider.dart         # 全局状态管理
├── pages/
│   ├── home_page.dart            # 首页
│   ├── learn_page.dart           # 学习页面
│   ├── practice_page.dart        # 练习页面
│   ├── exam_mode_page.dart       # 模拟考试页面
│   ├── question_bank_page.dart   # 题库页面
│   ├── wrong_questions_page.dart # 错题本页面
│   ├── wrong_analysis_page.dart  # 错题分析页面
│   ├── note_page.dart            # 学习笔记页面
│   ├── knowledge_assessment_page.dart # 知识点评估页面
│   ├── study_plan_page.dart      # 学习计划页面
│   ├── textbook_page.dart        # 大纲与考点页面
│   ├── stats_page.dart           # 统计页面
│   └── profile_page.dart         # 个人中心页面
└── utils/
    └── animations.dart           # 动画工具类

assets/questions/                 # 题库 JSON 文件
├── law/                          # 法规（10章 + 真题）
├── management/                   # 管理（8章 + 真题）
└── practice/                     # 市政实务（18章 + 真题）
```

## 🚀 运行方式

### 环境要求
- Flutter SDK >= 3.24.0
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
使用 Provider 进行全局状态管理，统一管理：
- 题目数据（延迟加载）
- 学习历史
- 笔记数据
- 学习计划
- 收藏题目
- 错题数据
- 统计数据
- 震动反馈设置

### 数据持久化
使用 SharedPreferences 进行本地数据存储，支持：
- 学习历史记录
- 错题记录
- 收藏题目
- 笔记数据
- 章节完成状态
- 用户设置（主题、震动）

### CI/CD
使用 GitHub Actions 自动构建 APK，每次 push 到 main 分支触发：
- 构建 release APK
- 上传构建产物
- 创建 GitHub Release

## 📄 许可证

MIT License

## 👥 贡献

欢迎提交 Issue 和 Pull Request！