/// VocabRepository — all database operations for Vocabulary Bank
library;

import 'package:sqflite/sqflite.dart';
import '../../../core/utils/logger.dart';
import '../../../services/database/database_service.dart';
import '../../../shared/models/vocab_word.dart';

class VocabRepository {
  VocabRepository({DatabaseService? db}) : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;
  static const String _tag = 'VocabRepository';
  static const String _table = 'vocab_words';

  Future<int> saveWord(VocabWord word) async {
    final db = await _db.database;
    AppLogger.info('Saving word: ${word.arabic}', tag: _tag);
    final id = await db.insert(
      _table,
      word.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    AppLogger.info('Saved with id: $id', tag: _tag);
    return id;
  }

  Future<List<VocabWord>> getAllWords() async {
    final db = await _db.database;
    final maps = await db.query(_table, orderBy: 'saved_at DESC');
    return maps.map(VocabWord.fromMap).toList();
  }

  Future<List<VocabWord>> getWordsForReview({int limit = 3}) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    final maps = await db.query(
      _table,
      where: 'next_review_at IS NULL OR next_review_at <= ?',
      whereArgs: [now],
      orderBy: 'saved_at ASC',
      limit: limit,
    );
    AppLogger.info('Found ${maps.length} words due for review', tag: _tag);
    return maps.map(VocabWord.fromMap).toList();
  }

  Future<int> getWordCount() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_table',
    );
    return result.first['count'] as int? ?? 0;
  }

  Future<bool> isWordSaved(String arabic) async {
    final db = await _db.database;
    final result = await db.query(
      _table,
      where: 'arabic = ?',
      whereArgs: [arabic],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> markReviewed(VocabWord word) async {
    final db = await _db.database;
    final updated = word.markReviewed();
    await db.update(
      _table,
      {
        'review_count': updated.reviewCount,
        'next_review_at': updated.nextReviewAt?.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [word.id],
    );
    AppLogger.info(
      'Marked ${word.arabic} reviewed — next in ${updated.nextInterval.inDays} days',
      tag: _tag,
    );
  }

  Future<void> deleteWord(int id) async {
    final db = await _db.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    AppLogger.info('Deleted word id: $id', tag: _tag);
  }

  Future<void> clearAll() async {
    final db = await _db.database;
    await db.delete(_table);
    AppLogger.info('Cleared all vocab words', tag: _tag);
  }
}
