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

/// 教材信息（题目大纲，不含PDF）
class Textbook {
  const Textbook({
    required this.title,
    required this.subject,
    required this.color,
    required this.icon,
    this.description = '',
    this.chapters = const [],
    this.questionBankCategories = const [],
  });

  final String title;
  final QuestionSubject subject;
  final int color;
  final IconData icon;
  final String description;
  final List<TextbookChapter> chapters;
  final List<QuestionBankCategory> questionBankCategories;
}

/// 法规教材章节（二建）
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
    title: '建筑市场主体制度',
    page: 62,
    subsections: [
      TextbookChapter(number: '2.1', title: '施工企业从业资格制度', page: 62),
      TextbookChapter(number: '2.2', title: '建造师注册执业制度', page: 70),
      TextbookChapter(number: '2.3', title: '建筑市场信用体系建设', page: 77),
    ],
  ),
  TextbookChapter(
    number: '3',
    title: '建设工程许可法律制度',
    page: 87,
    subsections: [
      TextbookChapter(number: '3.1', title: '建设工程施工许可制度', page: 87),
      TextbookChapter(number: '3.2', title: '建筑企业资质许可制度', page: 95),
    ],
  ),
  TextbookChapter(
    number: '4',
    title: '建设工程发承包法律制度',
    page: 100,
    subsections: [
      TextbookChapter(number: '4.1', title: '建设工程招标投标制度', page: 100),
      TextbookChapter(number: '4.2', title: '建设工程承包制度', page: 113),
      TextbookChapter(number: '4.3', title: '建设工程分包制度', page: 119),
    ],
  ),
  TextbookChapter(
    number: '5',
    title: '建设工程合同法律制度',
    page: 126,
    subsections: [
      TextbookChapter(number: '5.1', title: '建设工程合同制度', page: 126),
      TextbookChapter(number: '5.2', title: '相关合同制度', page: 150),
    ],
  ),
  TextbookChapter(
    number: '6',
    title: '建设工程安全生产法律制度',
    page: 160,
    subsections: [
      TextbookChapter(number: '6.1', title: '施工安全生产许可证制度', page: 160),
      TextbookChapter(number: '6.2', title: '施工安全生产责任和教育培训制度', page: 165),
      TextbookChapter(number: '6.3', title: '施工现场安全防护制度', page: 175),
      TextbookChapter(number: '6.4', title: '施工安全事故应急救援与调查处理', page: 185),
      TextbookChapter(number: '6.5', title: '建设单位和相关单位安全责任制度', page: 192),
    ],
  ),
  TextbookChapter(
    number: '7',
    title: '建设工程质量法律制度',
    page: 204,
    subsections: [
      TextbookChapter(number: '7.1', title: '工程建设标准', page: 204),
      TextbookChapter(number: '7.2', title: '施工单位的质量责任和义务', page: 211),
      TextbookChapter(number: '7.3', title: '建设单位及相关单位的质量责任和义务', page: 218),
      TextbookChapter(number: '7.4', title: '建设工程竣工验收制度', page: 227),
      TextbookChapter(number: '7.5', title: '建设工程质量保修制度', page: 236),
    ],
  ),
  TextbookChapter(
    number: '8',
    title: '建设工程环境保护和历史文化遗产保护法律制度',
    page: 245,
    subsections: [
      TextbookChapter(number: '8.1', title: '施工现场环境保护制度', page: 245),
      TextbookChapter(number: '8.2', title: '施工节约能源制度', page: 253),
      TextbookChapter(number: '8.3', title: '施工文物保护制度', page: 256),
    ],
  ),
  TextbookChapter(
    number: '9',
    title: '建设工程劳动保障法律制度',
    page: 260,
    subsections: [
      TextbookChapter(number: '9.1', title: '劳动合同制度', page: 260),
      TextbookChapter(number: '9.2', title: '劳动保护制度', page: 275),
    ],
  ),
  TextbookChapter(
    number: '10',
    title: '建设工程争议解决法律制度',
    page: 285,
    subsections: [
      TextbookChapter(number: '10.1', title: '建设工程争议和解、调解制度', page: 285),
      TextbookChapter(number: '10.2', title: '仲裁制度', page: 295),
      TextbookChapter(number: '10.3', title: '民事诉讼制度', page: 310),
    ],
  ),
];

/// 法规题库分类
const List<QuestionBankCategory> _lawQuestionBankCategories = [
  QuestionBankCategory(id: 'law_chapter_1', title: '第1章 章节练习', icon: Icons.book_rounded, description: '建设工程基本法律知识', chapterNumber: '1'),
  QuestionBankCategory(id: 'law_chapter_2', title: '第2章 章节练习', icon: Icons.book_rounded, description: '建筑市场主体制度', chapterNumber: '2'),
  QuestionBankCategory(id: 'law_chapter_3', title: '第3章 章节练习', icon: Icons.book_rounded, description: '建设工程许可法律制度', chapterNumber: '3'),
  QuestionBankCategory(id: 'law_chapter_4', title: '第4章 章节练习', icon: Icons.book_rounded, description: '建设工程发承包法律制度', chapterNumber: '4'),
  QuestionBankCategory(id: 'law_chapter_5', title: '第5章 章节练习', icon: Icons.book_rounded, description: '建设工程合同法律制度', chapterNumber: '5'),
  QuestionBankCategory(id: 'law_chapter_6', title: '第6章 章节练习', icon: Icons.book_rounded, description: '建设工程安全生产法律制度', chapterNumber: '6'),
  QuestionBankCategory(id: 'law_chapter_7', title: '第7章 章节练习', icon: Icons.book_rounded, description: '建设工程质量法律制度', chapterNumber: '7'),
  QuestionBankCategory(id: 'law_chapter_8', title: '第8章 章节练习', icon: Icons.book_rounded, description: '环境保护和历史文化遗产保护', chapterNumber: '8'),
  QuestionBankCategory(id: 'law_chapter_9', title: '第9章 章节练习', icon: Icons.book_rounded, description: '建设工程劳动保障法律制度', chapterNumber: '9'),
  QuestionBankCategory(id: 'law_chapter_10', title: '第10章 章节练习', icon: Icons.book_rounded, description: '建设工程争议解决法律制度', chapterNumber: '10'),
  QuestionBankCategory(id: 'law_mock_1', title: '模拟测试一', icon: Icons.assessment_rounded, description: '法规科目综合模拟测试'),
  QuestionBankCategory(id: 'law_mock_2', title: '模拟测试二', icon: Icons.assessment_rounded, description: '法规科目综合模拟测试'),
  QuestionBankCategory(id: 'law_final', title: '考前冲刺', icon: Icons.rocket_rounded, description: '高频考点与易错题目精选'),
];

/// 管理教材章节（二建）
const List<TextbookChapter> _managementChapters = [
  TextbookChapter(
    number: '1',
    title: '施工组织与目标控制',
    page: 1,
    subsections: [
      TextbookChapter(number: '1.1', title: '工程项目投资管理与实施', page: 1),
      TextbookChapter(number: '1.2', title: '施工项目管理组织与项目经理', page: 20),
      TextbookChapter(number: '1.3', title: '施工组织设计', page: 35),
      TextbookChapter(number: '1.4', title: '建设工程项目目标控制', page: 50),
    ],
  ),
  TextbookChapter(
    number: '2',
    title: '施工招标投标与合同管理',
    page: 70,
    subsections: [
      TextbookChapter(number: '2.1', title: '施工招标投标', page: 70),
      TextbookChapter(number: '2.2', title: '施工合同管理', page: 95),
      TextbookChapter(number: '2.3', title: '施工合同计价方式', page: 115),
      TextbookChapter(number: '2.4', title: '施工合同风险管理', page: 130),
      TextbookChapter(number: '2.5', title: '施工合同索赔管理', page: 145),
    ],
  ),
  TextbookChapter(
    number: '3',
    title: '施工进度管理',
    page: 160,
    subsections: [
      TextbookChapter(number: '3.1', title: '施工进度计划', page: 160),
      TextbookChapter(number: '3.2', title: '施工进度控制', page: 180),
    ],
  ),
  TextbookChapter(
    number: '4',
    title: '施工质量管理',
    page: 200,
    subsections: [
      TextbookChapter(number: '4.1', title: '施工质量计划', page: 200),
      TextbookChapter(number: '4.2', title: '施工质量控制', page: 215),
      TextbookChapter(number: '4.3', title: '施工质量验收', page: 235),
      TextbookChapter(number: '4.4', title: '施工质量事故预防与处理', page: 250),
    ],
  ),
  TextbookChapter(
    number: '5',
    title: '施工成本管理',
    page: 270,
    subsections: [
      TextbookChapter(number: '5.1', title: '施工成本计划', page: 270),
      TextbookChapter(number: '5.2', title: '施工成本控制', page: 285),
      TextbookChapter(number: '5.3', title: '施工成本核算', page: 300),
      TextbookChapter(number: '5.4', title: '施工成本分析', page: 310),
      TextbookChapter(number: '5.5', title: '施工成本考核', page: 320),
    ],
  ),
  TextbookChapter(
    number: '6',
    title: '施工安全管理',
    page: 330,
    subsections: [
      TextbookChapter(number: '6.1', title: '施工安全管理体系', page: 330),
      TextbookChapter(number: '6.2', title: '施工安全技术措施', page: 345),
      TextbookChapter(number: '6.3', title: '施工安全事故应急预案', page: 360),
      TextbookChapter(number: '6.4', title: '施工安全事故处理', page: 375),
    ],
  ),
  TextbookChapter(
    number: '7',
    title: '绿色施工及环境管理',
    page: 390,
    subsections: [
      TextbookChapter(number: '7.1', title: '绿色施工', page: 390),
      TextbookChapter(number: '7.2', title: '施工现场环境管理', page: 405),
    ],
  ),
  TextbookChapter(
    number: '8',
    title: '施工文件归档管理及项目管理新发展',
    page: 420,
    subsections: [
      TextbookChapter(number: '8.1', title: '施工文件归档管理', page: 420),
      TextbookChapter(number: '8.2', title: '项目管理新发展', page: 435),
    ],
  ),
];

/// 管理题库分类
const List<QuestionBankCategory> _managementQuestionBankCategories = [
  QuestionBankCategory(id: 'management_chapter_1', title: '第1章 章节练习', icon: Icons.book_rounded, description: '施工组织与目标控制', chapterNumber: '1'),
  QuestionBankCategory(id: 'management_chapter_2', title: '第2章 章节练习', icon: Icons.book_rounded, description: '施工招标投标与合同管理', chapterNumber: '2'),
  QuestionBankCategory(id: 'management_chapter_3', title: '第3章 章节练习', icon: Icons.book_rounded, description: '施工进度管理', chapterNumber: '3'),
  QuestionBankCategory(id: 'management_chapter_4', title: '第4章 章节练习', icon: Icons.book_rounded, description: '施工质量管理', chapterNumber: '4'),
  QuestionBankCategory(id: 'management_chapter_5', title: '第5章 章节练习', icon: Icons.book_rounded, description: '施工成本管理', chapterNumber: '5'),
  QuestionBankCategory(id: 'management_chapter_6', title: '第6章 章节练习', icon: Icons.book_rounded, description: '施工安全管理', chapterNumber: '6'),
  QuestionBankCategory(id: 'management_chapter_7', title: '第7章 章节练习', icon: Icons.book_rounded, description: '绿色施工及环境管理', chapterNumber: '7'),
  QuestionBankCategory(id: 'management_chapter_8', title: '第8章 章节练习', icon: Icons.book_rounded, description: '施工文件归档管理及项目管理新发展', chapterNumber: '8'),
  QuestionBankCategory(id: 'management_mock_1', title: '模拟测试一', icon: Icons.assessment_rounded, description: '管理科目综合模拟测试'),
  QuestionBankCategory(id: 'management_mock_2', title: '模拟测试二', icon: Icons.assessment_rounded, description: '管理科目综合模拟测试'),
  QuestionBankCategory(id: 'management_final', title: '考前冲刺', icon: Icons.rocket_rounded, description: '高频考点与易错题目精选'),
];

/// 实务教材章节（二建市政）
const List<TextbookChapter> _practiceChapters = [
  TextbookChapter(
    number: '1',
    title: '城镇道路工程',
    page: 1,
    subsections: [
      TextbookChapter(number: '1.1', title: '道路结构特征', page: 1),
      TextbookChapter(number: '1.2', title: '城镇道路路基施工', page: 9),
      TextbookChapter(number: '1.3', title: '城镇道路路面施工', page: 16),
      TextbookChapter(number: '1.4', title: '挡土墙施工', page: 30),
    ],
  ),
  TextbookChapter(
    number: '2',
    title: '城市桥梁工程',
    page: 40,
    subsections: [
      TextbookChapter(number: '2.1', title: '城市桥梁结构形式及通用施工技术', page: 40),
      TextbookChapter(number: '2.2', title: '城市桥梁下部结构施工', page: 60),
      TextbookChapter(number: '2.3', title: '城市桥梁上部结构施工', page: 80),
    ],
  ),
  TextbookChapter(
    number: '3',
    title: '城市隧道工程',
    page: 110,
    subsections: [
      TextbookChapter(number: '3.1', title: '施工方法与结构形式', page: 110),
      TextbookChapter(number: '3.2', title: '地下水控制', page: 125),
      TextbookChapter(number: '3.3', title: '明挖法施工', page: 135),
      TextbookChapter(number: '3.4', title: '浅埋暗挖法施工', page: 155),
    ],
  ),
  TextbookChapter(
    number: '4',
    title: '城市管道工程',
    page: 170,
    subsections: [
      TextbookChapter(number: '4.1', title: '城市给水排水管道工程', page: 170),
      TextbookChapter(number: '4.2', title: '城市燃气管道工程', page: 190),
      TextbookChapter(number: '4.3', title: '城市供热管道工程', page: 210),
    ],
  ),
  TextbookChapter(
    number: '5',
    title: '城市综合管廊工程',
    page: 230,
    subsections: [
      TextbookChapter(number: '5.1', title: '综合管廊分类与施工方法', page: 230),
      TextbookChapter(number: '5.2', title: '综合管廊施工技术', page: 240),
    ],
  ),
  TextbookChapter(
    number: '6',
    title: '海绵城市建设工程',
    page: 255,
    subsections: [
      TextbookChapter(number: '6.1', title: '海绵城市建设技术', page: 255),
      TextbookChapter(number: '6.2', title: '海绵城市施工技术', page: 265),
    ],
  ),
  TextbookChapter(
    number: '7',
    title: '城市基础设施更新工程',
    page: 280,
    subsections: [
      TextbookChapter(number: '7.1', title: '道路改造工程', page: 280),
      TextbookChapter(number: '7.2', title: '桥梁改造工程', page: 295),
      TextbookChapter(number: '7.3', title: '管网改造工程', page: 310),
    ],
  ),
  TextbookChapter(
    number: '8',
    title: '施工测量',
    page: 325,
    subsections: [
      TextbookChapter(number: '8.1', title: '施工测量主要内容与常用仪器', page: 325),
      TextbookChapter(number: '8.2', title: '施工测量技术', page: 335),
    ],
  ),
  TextbookChapter(
    number: '9',
    title: '施工监测',
    page: 345,
    subsections: [
      TextbookChapter(number: '9.1', title: '施工监测内容与方法', page: 345),
      TextbookChapter(number: '9.2', title: '监测数据处理与报告', page: 360),
    ],
  ),
  TextbookChapter(
    number: '10',
    title: '相关法规',
    page: 370,
    subsections: [
      TextbookChapter(number: '10.1', title: '城市道路管理的有关规定', page: 370),
      TextbookChapter(number: '10.2', title: '城镇排水和污水处理管理的有关规定', page: 378),
      TextbookChapter(number: '10.3', title: '城镇燃气管理的有关规定', page: 385),
    ],
  ),
  TextbookChapter(
    number: '11',
    title: '相关标准',
    page: 390,
    subsections: [
      TextbookChapter(number: '11.1', title: '相关强制性标准的规定', page: 390),
      TextbookChapter(number: '11.2', title: '技术安全标准', page: 400),
    ],
  ),
  TextbookChapter(
    number: '12',
    title: '市政公用工程企业资质与施工组织',
    page: 410,
    subsections: [
      TextbookChapter(number: '12.1', title: '企业资质管理', page: 410),
      TextbookChapter(number: '12.2', title: '施工组织设计', page: 420),
    ],
  ),
  TextbookChapter(
    number: '13',
    title: '施工招标投标与合同管理',
    page: 435,
    subsections: [
      TextbookChapter(number: '13.1', title: '施工招标投标', page: 435),
      TextbookChapter(number: '13.2', title: '施工合同管理', page: 450),
    ],
  ),
  TextbookChapter(
    number: '14',
    title: '施工进度管理',
    page: 465,
    subsections: [
      TextbookChapter(number: '14.1', title: '施工进度计划编制', page: 465),
      TextbookChapter(number: '14.2', title: '施工进度控制', page: 480),
    ],
  ),
  TextbookChapter(
    number: '15',
    title: '施工质量管理',
    page: 495,
    subsections: [
      TextbookChapter(number: '15.1', title: '施工质量控制', page: 495),
      TextbookChapter(number: '15.2', title: '施工质量验收', page: 515),
    ],
  ),
  TextbookChapter(
    number: '16',
    title: '施工成本管理',
    page: 530,
    subsections: [
      TextbookChapter(number: '16.1', title: '施工成本计划与控制', page: 530),
      TextbookChapter(number: '16.2', title: '施工成本核算与分析', page: 545),
    ],
  ),
  TextbookChapter(
    number: '17',
    title: '施工安全管理',
    page: 560,
    subsections: [
      TextbookChapter(number: '17.1', title: '施工安全管理体系', page: 560),
      TextbookChapter(number: '17.2', title: '施工安全技术措施', page: 575),
    ],
  ),
  TextbookChapter(
    number: '18',
    title: '绿色施工及现场环境管理',
    page: 590,
    subsections: [
      TextbookChapter(number: '18.1', title: '绿色施工', page: 590),
      TextbookChapter(number: '18.2', title: '施工现场环境管理', page: 605),
    ],
  ),
];

/// 实务题库分类
const List<QuestionBankCategory> _practiceQuestionBankCategories = [
  QuestionBankCategory(id: 'practice_chapter_1', title: '第1章 章节练习', icon: Icons.book_rounded, description: '城镇道路工程', chapterNumber: '1'),
  QuestionBankCategory(id: 'practice_chapter_2', title: '第2章 章节练习', icon: Icons.book_rounded, description: '城市桥梁工程', chapterNumber: '2'),
  QuestionBankCategory(id: 'practice_chapter_3', title: '第3章 章节练习', icon: Icons.book_rounded, description: '城市隧道工程', chapterNumber: '3'),
  QuestionBankCategory(id: 'practice_chapter_4', title: '第4章 章节练习', icon: Icons.book_rounded, description: '城市管道工程', chapterNumber: '4'),
  QuestionBankCategory(id: 'practice_chapter_5', title: '第5章 章节练习', icon: Icons.book_rounded, description: '城市综合管廊工程', chapterNumber: '5'),
  QuestionBankCategory(id: 'practice_chapter_6', title: '第6章 章节练习', icon: Icons.book_rounded, description: '海绵城市建设工程', chapterNumber: '6'),
  QuestionBankCategory(id: 'practice_chapter_7', title: '第7章 章节练习', icon: Icons.book_rounded, description: '城市基础设施更新工程', chapterNumber: '7'),
  QuestionBankCategory(id: 'practice_chapter_8', title: '第8章 章节练习', icon: Icons.book_rounded, description: '施工测量', chapterNumber: '8'),
  QuestionBankCategory(id: 'practice_chapter_9', title: '第9章 章节练习', icon: Icons.book_rounded, description: '施工监测', chapterNumber: '9'),
  QuestionBankCategory(id: 'practice_chapter_10', title: '第10章 章节练习', icon: Icons.book_rounded, description: '相关法规', chapterNumber: '10'),
  QuestionBankCategory(id: 'practice_chapter_11', title: '第11章 章节练习', icon: Icons.book_rounded, description: '相关标准', chapterNumber: '11'),
  QuestionBankCategory(id: 'practice_chapter_12', title: '第12章 章节练习', icon: Icons.book_rounded, description: '企业资质与施工组织', chapterNumber: '12'),
  QuestionBankCategory(id: 'practice_chapter_13', title: '第13章 章节练习', icon: Icons.book_rounded, description: '施工招标投标与合同管理', chapterNumber: '13'),
  QuestionBankCategory(id: 'practice_chapter_14', title: '第14章 章节练习', icon: Icons.book_rounded, description: '施工进度管理', chapterNumber: '14'),
  QuestionBankCategory(id: 'practice_chapter_15', title: '第15章 章节练习', icon: Icons.book_rounded, description: '施工质量管理', chapterNumber: '15'),
  QuestionBankCategory(id: 'practice_chapter_16', title: '第16章 章节练习', icon: Icons.book_rounded, description: '施工成本管理', chapterNumber: '16'),
  QuestionBankCategory(id: 'practice_chapter_17', title: '第17章 章节练习', icon: Icons.book_rounded, description: '施工安全管理', chapterNumber: '17'),
  QuestionBankCategory(id: 'practice_chapter_18', title: '第18章 章节练习', icon: Icons.book_rounded, description: '绿色施工及现场环境管理', chapterNumber: '18'),
  QuestionBankCategory(id: 'practice_mock_1', title: '模拟测试一', icon: Icons.assessment_rounded, description: '实务科目综合模拟测试'),
  QuestionBankCategory(id: 'practice_mock_2', title: '模拟测试二', icon: Icons.assessment_rounded, description: '实务科目综合模拟测试'),
  QuestionBankCategory(id: 'practice_final', title: '考前冲刺', icon: Icons.rocket_rounded, description: '高频考点与易错题目精选'),
];

/// 3 本二建电子教材
class Textbooks {
  Textbooks._();

  static const List<Textbook> all = [
    Textbook(
      title: '二建法规电子教材',
      subject: QuestionSubject.law,
      color: 0xFF2196F3,
      icon: Icons.gavel_rounded,
      description: '建设工程法规及相关知识',
      chapters: _lawChapters,
      questionBankCategories: _lawQuestionBankCategories,
    ),
    Textbook(
      title: '二建管理电子教材',
      subject: QuestionSubject.management,
      color: 0xFFFF9800,
      icon: Icons.build_rounded,
      description: '建设工程施工管理',
      chapters: _managementChapters,
      questionBankCategories: _managementQuestionBankCategories,
    ),
    Textbook(
      title: '二建市政实务电子教材',
      subject: QuestionSubject.practice,
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