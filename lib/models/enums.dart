// 측정 방식 타입
enum GoalMetricType { habit, count, duration }

// 목표 달성 방식
enum GoalTargetMode { frequency, total }

// 카테고리(선택)
enum GoalCategory { health, selfDevelopment, travel, etc }

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

// duration 목표 모드
enum DurationMode { daily, weekly }
