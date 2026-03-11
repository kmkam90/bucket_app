import 'package:flutter/material.dart';

// 버킷 아이템 달성 유형
enum BucketItemType { check, count, time, days }

String bucketItemTypeLabel(BucketItemType type) {
  switch (type) {
    case BucketItemType.check: return '체크';
    case BucketItemType.count: return '횟수';
    case BucketItemType.time: return '시간';
    case BucketItemType.days: return '일수';
  }
}

String bucketItemTypeUnit(BucketItemType type) {
  switch (type) {
    case BucketItemType.check: return '';
    case BucketItemType.count: return '회';
    case BucketItemType.time: return '시간';
    case BucketItemType.days: return '일';
  }
}

IconData bucketItemTypeIcon(BucketItemType type) {
  switch (type) {
    case BucketItemType.check: return Icons.check_circle_outline_rounded;
    case BucketItemType.count: return Icons.tag_rounded;
    case BucketItemType.time: return Icons.timer_outlined;
    case BucketItemType.days: return Icons.calendar_today_rounded;
  }
}

// 측정 방식 타입
enum GoalMetricType { habit, count, duration }

// 목표 달성 방식
enum GoalTargetMode { frequency, total }

// 카테고리(선택)
enum GoalCategory { health, selfDevelopment, travel, finance, hobby, social, etc }

String goalCategoryLabel(GoalCategory cat) {
  switch (cat) {
    case GoalCategory.health: return '건강';
    case GoalCategory.selfDevelopment: return '자기계발';
    case GoalCategory.travel: return '여행';
    case GoalCategory.finance: return '재정';
    case GoalCategory.hobby: return '취미';
    case GoalCategory.social: return '관계';
    case GoalCategory.etc: return '기타';
  }
}

Color goalCategoryColor(GoalCategory cat) {
  switch (cat) {
    case GoalCategory.health: return const Color(0xFF6BCB8B);
    case GoalCategory.selfDevelopment: return const Color(0xFF7B8CDE);
    case GoalCategory.travel: return const Color(0xFFE8A87C);
    case GoalCategory.finance: return const Color(0xFFF7D794);
    case GoalCategory.hobby: return const Color(0xFFCB8BDE);
    case GoalCategory.social: return const Color(0xFF8BD4DE);
    case GoalCategory.etc: return const Color(0xFF9CA3AF);
  }
}

IconData goalCategoryIcon(GoalCategory cat) {
  switch (cat) {
    case GoalCategory.health: return Icons.favorite_rounded;
    case GoalCategory.selfDevelopment: return Icons.auto_stories_rounded;
    case GoalCategory.travel: return Icons.flight_rounded;
    case GoalCategory.finance: return Icons.savings_rounded;
    case GoalCategory.hobby: return Icons.palette_rounded;
    case GoalCategory.social: return Icons.people_rounded;
    case GoalCategory.etc: return Icons.more_horiz_rounded;
  }
}

// 목표 단위
enum GoalUnit { books, times, minutes, hours, custom }

String goalUnitToString(GoalUnit unit) {
	switch (unit) {
		case GoalUnit.books:
			return '권';
		case GoalUnit.times:
			return '회';
		case GoalUnit.minutes:
			return '분';
		case GoalUnit.hours:
			return '시간';
		case GoalUnit.custom:
			return '기타';
	}
}

GoalUnit goalUnitFromString(String str) {
	switch (str) {
		case '권':
			return GoalUnit.books;
		case '회':
			return GoalUnit.times;
		case '분':
			return GoalUnit.minutes;
		case '시간':
			return GoalUnit.hours;
		default:
			return GoalUnit.custom;
	}
}
