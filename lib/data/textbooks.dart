import 'package:flutter/material.dart';

import '../models/question.dart';

/// 教材章节
class TextbookChapter {
  const TextbookChapter({
    required this.number,
    required this.title,
    required this.page,
    this.subsections = const [],
  });

  final String number;
  final String title;
  final int page;
  final List<TextbookChapter> subsections;
}

/// 项目题库分类
class QuestionBankCategory {
  const QuestionBankCategory({
    required this.id,
    required this.title,
    required this.icon,
    this.description = '',
    this.chapterNumber,
  });

  final String id;
  final String title;
  final IconData icon;
  final String description;
  final String? chapterNumber;
}

/// 教材信息
class Textbook {
  const Textbook({
    required this.title,
    required this.subject,
    required this.fileName,
    required this.color,
    required this.icon,
    this.description = '',
    this.chapters = const [],
    this.questionBankCategories = const [],
  });

  final String title;
  final QuestionSubject subject;
  final String fileName;
  final int color;
  final IconData icon;
  final String description;
  final List<TextbookChapter> chapters;
  final List<QuestionBankCategory> questionBankCategories;

  /// Web 端访问 URL
  String get webUrl => 'PDF/$fileName';
}

/// 法规教材章节
const List<TextbookChapter> _lawChapters = [
  TextbookChapter(
    number: '1',
    title: '建设工程基本法律知识',
    page: 1,
    subsections: [
      TextbookChapter(number: '1.1', title: '建设工程法律体系', page: 1),
      TextbookChapter(number: '1.2', title: '建设工程法人制度', page: 7),
      TextbookChapter(number: '1.3', title: '建设工程代理制度', page: 11),
      TextbookChapter(number: '1.4', title: '建设工程物权制度', page: 16),
      TextbookChapter(number: '1.5', title: '建设工程债权制度', page: 25),
      TextbookChapter(number: '1.6', title: '建设工程知识产权制度', page: 29),
      TextbookChapter(number: '1.7', title: '建设工程担保制度', page: 37),
      TextbookChapter(number: '1.8', title: '建设工程保险制度', page: 48),
      TextbookChapter(number: '1.9', title: '建设工程法律责任制度', page: 53),
    ],
  ),
  TextbookChapter(
    number: '2',
    title: '施工许可法律制度',
    page: 62,
    subsections: [
      TextbookChapter(number: '2.1', title: '建设工程施工许可制度', page: 62),
      TextbookChapter(number: '2.2', title: '施工企业从业资格制度', page: 70),
      TextbookChapter(number: '2.3', title: '建造师注册执业制度', page: 77),
    ],
  ),
  TextbookChapter(
    number: '3',
    title: '建设工程发承包法律制度',
    page: 87,
    subsections: [
      TextbookChapter(number: '3.1', title: '建设工程招标投标制度', page: 87),
      TextbookChapter(number: '3.2', title: '建设工程承包制度', page: 100),
      TextbookChapter(number: '3.3', title: '建设工程分包制度', page: 106),
    ],
  ),
  TextbookChapter(
    number: '4',
    title: '合同与劳动合同法律制度',
    page: 113,
    subsections: [
      TextbookChapter(number: '4.1', title: '建设工程合同制度', page: 113),
      TextbookChapter(number: '4.2', title: '劳动合同及劳动关系制度', page: 143),
      TextbookChapter(number: '4.3', title: '相关合同制度', page: 157),
    ],
  ),
  TextbookChapter(
    number: '5',
    title: '建设工程施工环境保护、节约能源和文物保护法律制度',
    page: 168,
    subsections: [
      TextbookChapter(number: '5.1', title: '施工现场环境保护制度', page: 168),
      TextbookChapter(number: '5.2', title: '施工节约能源制度', page: 176),
      TextbookChapter(number: '5.3', title: '施工文物保护制度', page: 179),
    ],
  ),
  TextbookChapter(
    number: '6',
    title: '建设工程安全生产法律制度',
    page: 183,
    subsections: [
      TextbookChapter(number: '6.1', title: '施工安全生产许可证制度', page: 183),
      TextbookChapter(number: '6.2', title: '施工安全生产责任和安全生产教育培训制度', page: 187),
      TextbookChapter(number: '6.3', title: '施工现场安全防护制度', page: 195),
      TextbookChapter(number: '6.4', title: '施工安全事故的应急救援与调查处理', page: 205),
      TextbookChapter(number: '6.5', title: '建设单位和相关单位的建设工程安全责任制度', page: 212),
    ],
  ),
  TextbookChapter(
    number: '7',
    title: '建设工程质量法律制度',
    page: 224,
    subsections: [
      TextbookChapter(number: '7.1', title: '工程建设标准', page: 224),
      TextbookChapter(number: '7.2', title: '施工单位的质量责任和义务', page: 231),
      TextbookChapter(number: '7.3', title: '建设单位及相关单位的质量责任和义务', page: 238),
      TextbookChapter(number: '7.4', title: '建设工程竣工验收制度', page: 247),
      TextbookChapter(number: '7.5', title: '建设工程质量保修制度', page: 256),
    ],
  ),
];

/// 法规教材项目题库分类
const List<QuestionBankCategory> _lawQuestionBankCategories = [
  QuestionBankCategory(
    id: 'law_chapter_1',
    title: '第1章 章节练习',
    icon: Icons.book_rounded,
    description: '建设工程基本法律知识',
    chapterNumber: '1',
  ),
  QuestionBankCategory(
    id: 'law_chapter_2',
    title: '第2章 章节练习',
    icon: Icons.book_rounded,
    description: '施工许可法律制度',
    chapterNumber: '2',
  ),
  QuestionBankCategory(
    id: 'law_chapter_3',
    title: '第3章 章节练习',
    icon: Icons.book_rounded,
    description: '建设工程发承包法律制度',
    chapterNumber: '3',
  ),
  QuestionBankCategory(
    id: 'law_chapter_4',
    title: '第4章 章节练习',
    icon: Icons.book_rounded,
    description: '合同与劳动合同法律制度',
    chapterNumber: '4',
  ),
  QuestionBankCategory(
    id: 'law_chapter_5',
    title: '第5章 章节练习',
    icon: Icons.book_rounded,
    description: '环境保护、节约能源和文物保护法律制度',
    chapterNumber: '5',
  ),
  QuestionBankCategory(
    id: 'law_chapter_6',
    title: '第6章 章节练习',
    icon: Icons.book_rounded,
    description: '建设工程安全生产法律制度',
    chapterNumber: '6',
  ),
  QuestionBankCategory(
    id: 'law_chapter_7',
    title: '第7章 章节练习',
    icon: Icons.book_rounded,
    description: '建设工程质量法律制度',
    chapterNumber: '7',
  ),
  QuestionBankCategory(
    id: 'law_mock_1',
    title: '模拟测试一',
    icon: Icons.assessment_rounded,
    description: '法规科目综合模拟测试',
  ),
  QuestionBankCategory(
    id: 'law_mock_2',
    title: '模拟测试二',
    icon: Icons.assessment_rounded,
    description: '法规科目综合模拟测试',
  ),
  QuestionBankCategory(
    id: 'law_final',
    title: '考前冲刺',
    icon: Icons.rocket_rounded,
    description: '高频考点与易错题目精选',
  ),
];

/// 管理教材章节
const List<TextbookChapter> _managementChapters = [
  TextbookChapter(
    number: '1',
    title: '建设工程项目管理概述',
    page: 1,
    subsections: [
      TextbookChapter(number: '1.1', title: '建设工程项目的组织与管理', page: 1),
      TextbookChapter(number: '1.2', title: '建设工程项目管理的目标和任务', page: 8),
      TextbookChapter(number: '1.3', title: '建设工程项目的组织', page: 15),
    ],
  ),
  TextbookChapter(
    number: '2',
    title: '建设工程项目成本管理',
    page: 35,
    subsections: [
      TextbookChapter(number: '2.1', title: '成本管理的任务和程序', page: 35),
      TextbookChapter(number: '2.2', title: '成本计划', page: 42),
      TextbookChapter(number: '2.3', title: '成本控制', page: 52),
      TextbookChapter(number: '2.4', title: '成本核算', page: 65),
      TextbookChapter(number: '2.5', title: '成本分析和成本考核', page: 75),
    ],
  ),
  TextbookChapter(
    number: '3',
    title: '建设工程项目进度控制',
    page: 88,
    subsections: [
      TextbookChapter(number: '3.1', title: '建设工程项目进度控制与进度计划系统', page: 88),
      TextbookChapter(number: '3.2', title: '建设工程项目总进度目标的论证', page: 95),
      TextbookChapter(number: '3.3', title: '建设工程项目进度计划的编制和调整方法', page: 102),
      TextbookChapter(number: '3.4', title: '建设工程项目进度控制的措施', page: 125),
    ],
  ),
  TextbookChapter(
    number: '4',
    title: '建设工程项目质量控制',
    page: 135,
    subsections: [
      TextbookChapter(number: '4.1', title: '建设工程项目质量控制的内涵', page: 135),
      TextbookChapter(number: '4.2', title: '建设工程项目质量控制体系', page: 142),
      TextbookChapter(number: '4.3', title: '建设工程项目施工质量控制', page: 155),
      TextbookChapter(number: '4.4', title: '建设工程项目质量验收', page: 175),
      TextbookChapter(number: '4.5', title: '建设工程项目质量不合格的处理', page: 188),
      TextbookChapter(number: '4.6', title: '数理统计方法在工程质量管理中的应用', page: 195),
      TextbookChapter(number: '4.7', title: '建设工程项目质量的政府监督', page: 205),
    ],
  ),
  TextbookChapter(
    number: '5',
    title: '建设工程职业健康安全与环境管理',
    page: 215,
    subsections: [
      TextbookChapter(number: '5.1', title: '职业健康安全管理体系与环境管理体系', page: 215),
      TextbookChapter(number: '5.2', title: '建设工程安全生产管理', page: 225),
      TextbookChapter(number: '5.3', title: '建设工程生产安全事故应急预案和事故处理', page: 245),
      TextbookChapter(number: '5.4', title: '建设工程施工现场环境保护的要求', page: 258),
    ],
  ),
  TextbookChapter(
    number: '6',
    title: '建设工程合同与合同管理',
    page: 268,
    subsections: [
      TextbookChapter(number: '6.1', title: '建设工程施工招标与投标', page: 268),
      TextbookChapter(number: '6.2', title: '建设工程合同的内容', page: 285),
      TextbookChapter(number: '6.3', title: '合同计价方式', page: 300),
      TextbookChapter(number: '6.4', title: '建设工程施工合同风险管理、工程保险和工程担保', page: 312),
      TextbookChapter(number: '6.5', title: '建设工程施工合同实施', page: 325),
      TextbookChapter(number: '6.6', title: '建设工程索赔', page: 340),
    ],
  ),
  TextbookChapter(
    number: '7',
    title: '建设工程项目信息管理',
    page: 360,
    subsections: [
      TextbookChapter(number: '7.1', title: '建设工程项目信息管理的目的和任务', page: 360),
      TextbookChapter(number: '7.2', title: '建设工程项目信息的分类、编码和处理方法', page: 365),
      TextbookChapter(number: '7.3', title: '建设工程管理信息化及建设工程项目管理信息系统的功能', page: 375),
      TextbookChapter(number: '7.4', title: '工程项目管理信息系统的应用', page: 385),
    ],
  ),
];

/// 管理教材项目题库分类
const List<QuestionBankCategory> _managementQuestionBankCategories = [
  QuestionBankCategory(
    id: 'management_chapter_1',
    title: '第1章 章节练习',
    icon: Icons.book_rounded,
    description: '建设工程项目管理概述',
    chapterNumber: '1',
  ),
  QuestionBankCategory(
    id: 'management_chapter_2',
    title: '第2章 章节练习',
    icon: Icons.book_rounded,
    description: '建设工程项目成本管理',
    chapterNumber: '2',
  ),
  QuestionBankCategory(
    id: 'management_chapter_3',
    title: '第3章 章节练习',
    icon: Icons.book_rounded,
    description: '建设工程项目进度控制',
    chapterNumber: '3',
  ),
  QuestionBankCategory(
    id: 'management_chapter_4',
    title: '第4章 章节练习',
    icon: Icons.book_rounded,
    description: '建设工程项目质量控制',
    chapterNumber: '4',
  ),
  QuestionBankCategory(
    id: 'management_chapter_5',
    title: '第5章 章节练习',
    icon: Icons.book_rounded,
    description: '职业健康安全与环境管理',
    chapterNumber: '5',
  ),
  QuestionBankCategory(
    id: 'management_chapter_6',
    title: '第6章 章节练习',
    icon: Icons.book_rounded,
    description: '建设工程合同与合同管理',
    chapterNumber: '6',
  ),
  QuestionBankCategory(
    id: 'management_chapter_7',
    title: '第7章 章节练习',
    icon: Icons.book_rounded,
    description: '建设工程项目信息管理',
    chapterNumber: '7',
  ),
  QuestionBankCategory(
    id: 'management_mock_1',
    title: '模拟测试一',
    icon: Icons.assessment_rounded,
    description: '管理科目综合模拟测试',
  ),
  QuestionBankCategory(
    id: 'management_mock_2',
    title: '模拟测试二',
    icon: Icons.assessment_rounded,
    description: '管理科目综合模拟测试',
  ),
  QuestionBankCategory(
    id: 'management_final',
    title: '考前冲刺',
    icon: Icons.rocket_rounded,
    description: '高频考点与易错题目精选',
  ),
];

/// 经济教材章节
const List<TextbookChapter> _economyChapters = [
  TextbookChapter(
    number: '1',
    title: '资金时间价值的计算及应用',
    page: 1,
    subsections: [
      TextbookChapter(number: '1.1', title: '资金时间价值的概念', page: 1),
      TextbookChapter(number: '1.2', title: '利息与利率的概念', page: 5),
      TextbookChapter(number: '1.3', title: '等值计算', page: 12),
      TextbookChapter(number: '1.4', title: '名义利率与有效利率的计算', page: 25),
    ],
  ),
  TextbookChapter(
    number: '2',
    title: '技术方案经济效果评价',
    page: 35,
    subsections: [
      TextbookChapter(number: '2.1', title: '经济效果评价的内容', page: 35),
      TextbookChapter(number: '2.2', title: '经济效果评价指标体系', page: 42),
      TextbookChapter(number: '2.3', title: '投资收益率分析', page: 50),
      TextbookChapter(number: '2.4', title: '投资回收期分析', page: 58),
      TextbookChapter(number: '2.5', title: '财务净现值分析', page: 65),
      TextbookChapter(number: '2.6', title: '财务内部收益率分析', page: 72),
      TextbookChapter(number: '2.7', title: '基准收益率的确定', page: 82),
      TextbookChapter(number: '2.8', title: '偿债能力分析', page: 88),
    ],
  ),
  TextbookChapter(
    number: '3',
    title: '技术方案不确定性分析',
    page: 100,
    subsections: [
      TextbookChapter(number: '3.1', title: '不确定性分析', page: 100),
      TextbookChapter(number: '3.2', title: '盈亏平衡分析', page: 105),
      TextbookChapter(number: '3.3', title: '敏感性分析', page: 115),
    ],
  ),
  TextbookChapter(
    number: '4',
    title: '技术方案现金流量表的编制',
    page: 125,
    subsections: [
      TextbookChapter(number: '4.1', title: '技术方案现金流量表', page: 125),
      TextbookChapter(number: '4.2', title: '技术方案现金流量表的构成要素', page: 135),
    ],
  ),
  TextbookChapter(
    number: '5',
    title: '设备更新分析',
    page: 150,
    subsections: [
      TextbookChapter(number: '5.1', title: '设备磨损与补偿', page: 150),
      TextbookChapter(number: '5.2', title: '设备更新方案的比选原则', page: 158),
      TextbookChapter(number: '5.3', title: '设备更新方案的比选方法', page: 162),
    ],
  ),
  TextbookChapter(
    number: '6',
    title: '价值工程在工程建设中的应用',
    page: 175,
    subsections: [
      TextbookChapter(number: '6.1', title: '提高价值的途径', page: 175),
      TextbookChapter(number: '6.2', title: '价值工程在工程建设应用中的实施步骤', page: 182),
    ],
  ),
  TextbookChapter(
    number: '7',
    title: '建设工程项目总投资',
    page: 195,
    subsections: [
      TextbookChapter(number: '7.1', title: '建设工程项目总投资的组成', page: 195),
      TextbookChapter(number: '7.2', title: '设备及工器具购置费的组成', page: 205),
      TextbookChapter(number: '7.3', title: '工程建设其他费用项目组成', page: 215),
      TextbookChapter(number: '7.4', title: '预备费的组成', page: 225),
      TextbookChapter(number: '7.5', title: '建设期利息的计算', page: 230),
    ],
  ),
  TextbookChapter(
    number: '8',
    title: '成本与费用',
    page: 238,
    subsections: [
      TextbookChapter(number: '8.1', title: '费用与成本的关系', page: 238),
      TextbookChapter(number: '8.2', title: '工程成本的确认和计算方法', page: 245),
      TextbookChapter(number: '8.3', title: '工程成本的核算', page: 255),
      TextbookChapter(number: '8.4', title: '期间费用的核算', page: 265),
    ],
  ),
  TextbookChapter(
    number: '9',
    title: '收入',
    page: 272,
    subsections: [
      TextbookChapter(number: '9.1', title: '收入的分类及确认', page: 272),
      TextbookChapter(number: '9.2', title: '建造(施工)合同收入的核算', page: 280),
    ],
  ),
  TextbookChapter(
    number: '10',
    title: '利润和所得税费用',
    page: 295,
    subsections: [
      TextbookChapter(number: '10.1', title: '利润的计算', page: 295),
      TextbookChapter(number: '10.2', title: '所得税费用的确认', page: 305),
    ],
  ),
];

/// 经济教材项目题库分类
const List<QuestionBankCategory> _economyQuestionBankCategories = [
  QuestionBankCategory(
    id: 'economy_chapter_1',
    title: '第1章 章节练习',
    icon: Icons.book_rounded,
    description: '资金时间价值的计算及应用',
    chapterNumber: '1',
  ),
  QuestionBankCategory(
    id: 'economy_chapter_2',
    title: '第2章 章节练习',
    icon: Icons.book_rounded,
    description: '技术方案经济效果评价',
    chapterNumber: '2',
  ),
  QuestionBankCategory(
    id: 'economy_chapter_3',
    title: '第3章 章节练习',
    icon: Icons.book_rounded,
    description: '技术方案不确定性分析',
    chapterNumber: '3',
  ),
  QuestionBankCategory(
    id: 'economy_chapter_4',
    title: '第4章 章节练习',
    icon: Icons.book_rounded,
    description: '技术方案现金流量表的编制',
    chapterNumber: '4',
  ),
  QuestionBankCategory(
    id: 'economy_chapter_5',
    title: '第5章 章节练习',
    icon: Icons.book_rounded,
    description: '设备更新分析',
    chapterNumber: '5',
  ),
  QuestionBankCategory(
    id: 'economy_chapter_6',
    title: '第6章 章节练习',
    icon: Icons.book_rounded,
    description: '价值工程在工程建设中的应用',
    chapterNumber: '6',
  ),
  QuestionBankCategory(
    id: 'economy_chapter_7',
    title: '第7章 章节练习',
    icon: Icons.book_rounded,
    description: '建设工程项目总投资',
    chapterNumber: '7',
  ),
  QuestionBankCategory(
    id: 'economy_chapter_8',
    title: '第8章 章节练习',
    icon: Icons.book_rounded,
    description: '成本与费用',
    chapterNumber: '8',
  ),
  QuestionBankCategory(
    id: 'economy_chapter_9',
    title: '第9章 章节练习',
    icon: Icons.book_rounded,
    description: '收入',
    chapterNumber: '9',
  ),
  QuestionBankCategory(
    id: 'economy_chapter_10',
    title: '第10章 章节练习',
    icon: Icons.book_rounded,
    description: '利润和所得税费用',
    chapterNumber: '10',
  ),
  QuestionBankCategory(
    id: 'economy_mock_1',
    title: '模拟测试一',
    icon: Icons.assessment_rounded,
    description: '经济科目综合模拟测试',
  ),
  QuestionBankCategory(
    id: 'economy_mock_2',
    title: '模拟测试二',
    icon: Icons.assessment_rounded,
    description: '经济科目综合模拟测试',
  ),
  QuestionBankCategory(
    id: 'economy_final',
    title: '考前冲刺',
    icon: Icons.rocket_rounded,
    description: '高频考点与易错题目精选',
  ),
];

/// 实务教材章节
const List<TextbookChapter> _practiceChapters = [
  TextbookChapter(
    number: '1',
    title: '城镇道路工程',
    page: 1,
    subsections: [
      TextbookChapter(number: '1.1', title: '城镇道路工程结构与材料', page: 1),
      TextbookChapter(number: '1.2', title: '城镇道路路基施工', page: 15),
      TextbookChapter(number: '1.3', title: '城镇道路基层施工', page: 28),
      TextbookChapter(number: '1.4', title: '城镇道路面层施工', page: 45),
    ],
  ),
  TextbookChapter(
    number: '2',
    title: '城市桥梁工程',
    page: 65,
    subsections: [
      TextbookChapter(number: '2.1', title: '城市桥梁结构形式及通用施工技术', page: 65),
      TextbookChapter(number: '2.2', title: '城市桥梁下部结构施工', page: 85),
      TextbookChapter(number: '2.3', title: '城市桥梁上部结构施工', page: 105),
      TextbookChapter(number: '2.4', title: '管涵和箱涵施工', page: 130),
    ],
  ),
  TextbookChapter(
    number: '3',
    title: '城市轨道交通工程',
    page: 145,
    subsections: [
      TextbookChapter(number: '3.1', title: '城市轨道交通工程结构与特点', page: 145),
      TextbookChapter(number: '3.2', title: '明挖基坑施工', page: 155),
      TextbookChapter(number: '3.3', title: '盾构法施工', page: 175),
      TextbookChapter(number: '3.4', title: '喷锚暗挖(矿山)法施工', page: 200),
    ],
  ),
  TextbookChapter(
    number: '4',
    title: '城市给水排水工程',
    page: 225,
    subsections: [
      TextbookChapter(number: '4.1', title: '给水排水厂站工程结构与特点', page: 225),
      TextbookChapter(number: '4.2', title: '给水排水厂站工程施工', page: 240),
      TextbookChapter(number: '4.3', title: '给水排水管道工程施工', page: 265),
    ],
  ),
  TextbookChapter(
    number: '5',
    title: '城市管道工程',
    page: 290,
    subsections: [
      TextbookChapter(number: '5.1', title: '城市给水排水管道工程施工', page: 290),
      TextbookChapter(number: '5.2', title: '城市供热管道工程施工', page: 310),
      TextbookChapter(number: '5.3', title: '城市燃气管道工程施工', page: 330),
    ],
  ),
  TextbookChapter(
    number: '6',
    title: '生活垃圾填埋处理工程',
    page: 350,
    subsections: [
      TextbookChapter(number: '6.1', title: '生活垃圾填埋处理工程施工', page: 350),
      TextbookChapter(number: '6.2', title: '生活垃圾填埋场填埋区防渗层施工技术', page: 365),
    ],
  ),
  TextbookChapter(
    number: '7',
    title: '施工测量与监控量测',
    page: 380,
    subsections: [
      TextbookChapter(number: '7.1', title: '施工测量', page: 380),
      TextbookChapter(number: '7.2', title: '监控量测', page: 395),
    ],
  ),
  TextbookChapter(
    number: '8',
    title: '市政公用工程施工安全管理',
    page: 410,
    subsections: [
      TextbookChapter(number: '8.1', title: '市政公用工程施工安全管理', page: 410),
      TextbookChapter(number: '8.2', title: '明挖基坑施工安全事故预防', page: 425),
      TextbookChapter(number: '8.3', title: '城市桥梁工程施工安全事故预防', page: 440),
      TextbookChapter(number: '8.4', title: '隧道工程施工安全事故预防', page: 455),
    ],
  ),
  TextbookChapter(
    number: '9',
    title: '市政公用工程施工质量管理',
    page: 475,
    subsections: [
      TextbookChapter(number: '9.1', title: '市政公用工程施工质量管理', page: 475),
      TextbookChapter(number: '9.2', title: '城镇道路工程施工质量检查与验收', page: 485),
      TextbookChapter(number: '9.3', title: '城市桥梁工程施工质量检查与验收', page: 500),
      TextbookChapter(number: '9.4', title: '给水排水构筑物施工质量检查与验收', page: 515),
      TextbookChapter(number: '9.5', title: '给水排水管道工程施工质量检查与验收', page: 530),
    ],
  ),
  TextbookChapter(
    number: '10',
    title: '市政公用工程施工成本管理',
    page: 545,
    subsections: [
      TextbookChapter(number: '10.1', title: '市政公用工程施工成本管理', page: 545),
      TextbookChapter(number: '10.2', title: '市政公用工程施工成本核算', page: 555),
    ],
  ),
];

/// 实务教材项目题库分类
const List<QuestionBankCategory> _practiceQuestionBankCategories = [
  QuestionBankCategory(
    id: 'practice_chapter_1',
    title: '第1章 章节练习',
    icon: Icons.book_rounded,
    description: '城镇道路工程',
    chapterNumber: '1',
  ),
  QuestionBankCategory(
    id: 'practice_chapter_2',
    title: '第2章 章节练习',
    icon: Icons.book_rounded,
    description: '城市桥梁工程',
    chapterNumber: '2',
  ),
  QuestionBankCategory(
    id: 'practice_chapter_3',
    title: '第3章 章节练习',
    icon: Icons.book_rounded,
    description: '城市轨道交通工程',
    chapterNumber: '3',
  ),
  QuestionBankCategory(
    id: 'practice_chapter_4',
    title: '第4章 章节练习',
    icon: Icons.book_rounded,
    description: '城市给水排水工程',
    chapterNumber: '4',
  ),
  QuestionBankCategory(
    id: 'practice_chapter_5',
    title: '第5章 章节练习',
    icon: Icons.book_rounded,
    description: '城市管道工程',
    chapterNumber: '5',
  ),
  QuestionBankCategory(
    id: 'practice_chapter_6',
    title: '第6章 章节练习',
    icon: Icons.book_rounded,
    description: '生活垃圾填埋处理工程',
    chapterNumber: '6',
  ),
  QuestionBankCategory(
    id: 'practice_chapter_7',
    title: '第7章 章节练习',
    icon: Icons.book_rounded,
    description: '施工测量与监控量测',
    chapterNumber: '7',
  ),
  QuestionBankCategory(
    id: 'practice_chapter_8',
    title: '第8章 章节练习',
    icon: Icons.book_rounded,
    description: '市政公用工程施工安全管理',
    chapterNumber: '8',
  ),
  QuestionBankCategory(
    id: 'practice_chapter_9',
    title: '第9章 章节练习',
    icon: Icons.book_rounded,
    description: '市政公用工程施工质量管理',
    chapterNumber: '9',
  ),
  QuestionBankCategory(
    id: 'practice_chapter_10',
    title: '第10章 章节练习',
    icon: Icons.book_rounded,
    description: '市政公用工程施工成本管理',
    chapterNumber: '10',
  ),
  QuestionBankCategory(
    id: 'practice_mock_1',
    title: '模拟测试一',
    icon: Icons.assessment_rounded,
    description: '实务科目综合模拟测试',
  ),
  QuestionBankCategory(
    id: 'practice_mock_2',
    title: '模拟测试二',
    icon: Icons.assessment_rounded,
    description: '实务科目综合模拟测试',
  ),
  QuestionBankCategory(
    id: 'practice_final',
    title: '考前冲刺',
    icon: Icons.rocket_rounded,
    description: '高频考点与易错题目精选',
  ),
];

/// 4 本电子教材
class Textbooks {
  Textbooks._();

  static const List<Textbook> all = [
    Textbook(
      title: '一建法规电子教材',
      subject: QuestionSubject.law,
      fileName: '2026版一建法规电子教材.pdf',
      color: 0xFF2196F3,
      icon: Icons.gavel_rounded,
      description: '建设工程法规及相关知识',
      chapters: _lawChapters,
      questionBankCategories: _lawQuestionBankCategories,
    ),
    Textbook(
      title: '一建管理电子教材',
      subject: QuestionSubject.management,
      fileName: '2026版一建管理电子教材.pdf',
      color: 0xFFFF9800,
      icon: Icons.build_rounded,
      description: '建设工程项目管理',
      chapters: _managementChapters,
      questionBankCategories: _managementQuestionBankCategories,
    ),
    Textbook(
      title: '一建经济电子教材',
      subject: QuestionSubject.economy,
      fileName: '2026版一建经济电子教材.pdf',
      color: 0xFF4CAF50,
      icon: Icons.trending_up_rounded,
      description: '建设工程经济',
      chapters: _economyChapters,
      questionBankCategories: _economyQuestionBankCategories,
    ),
    Textbook(
      title: '一建市政实务电子教材',
      subject: QuestionSubject.practice,
      fileName: '2026版一建市政实务电子教材.pdf',
      color: 0xFF9C27B0,
      icon: Icons.construction_rounded,
      description: '市政公用工程管理与实务',
      chapters: _practiceChapters,
      questionBankCategories: _practiceQuestionBankCategories,
    ),
  ];

  static Textbook? bySubject(QuestionSubject subject) {
    for (final t in all) {
      if (t.subject == subject) return t;
    }
    return null;
  }
}
