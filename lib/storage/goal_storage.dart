import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/goal.dart';

class GoalStorage {
    /// Delete multiple bucket lists by indexes
    static Future<void> deleteBucketListsByIndexes(Set<int> indexes) async {
      final lists = await loadBucketLists();
      final sorted = indexes.toList()..sort((a, b) => b.compareTo(a)); // delete from end
      for (final idx in sorted) {
        if (idx >= 0 && idx < lists.length) {
          lists.removeAt(idx);
        }
      }
      await saveBucketLists(lists);
    }
  static const String _storageKey = 'bucket_lists';

  /// Load all bucket lists from SharedPreferences
  static Future<List<BucketList>> loadBucketLists() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_storageKey);
    if (saved == null) {
      return [];
    }
    final decoded = <BucketList>[];
    for (final entry in saved) {
      try {
        final map = jsonDecode(entry) as Map<String, dynamic>;
        decoded.add(BucketList.fromMap(map));
      } catch (e) {
        continue;
      }
    }
    return decoded;
  }

  /// Save all bucket lists to SharedPreferences
  static Future<void> saveBucketLists(List<BucketList> lists) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = lists.map((list) => jsonEncode(list.toMap())).toList(growable: false);
    await prefs.setStringList(_storageKey, encoded);
  }

  /// Add a new bucket list
  static Future<void> addBucketList(BucketList list) async {
    final lists = await loadBucketLists();
    lists.add(list);
    await saveBucketLists(lists);
  }

  /// Update a bucket list at index
  static Future<void> updateBucketList(int index, BucketList list) async {
    final lists = await loadBucketLists();
    if (index >= 0 && index < lists.length) {
      lists[index] = list;
      await saveBucketLists(lists);
    }
  }

  /// Delete a bucket list at index
  static Future<void> deleteBucketList(int index) async {
    final lists = await loadBucketLists();
    if (index >= 0 && index < lists.length) {
      lists.removeAt(index);
      await saveBucketLists(lists);
    }
  }
}

