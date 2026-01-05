import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/task.dart';
import '../models/sms_log.dart';

class NativeBridge {
  static const MethodChannel _ch = MethodChannel('sms_forwarder');

  static Future<void> requestSmsPermissionOnNative() async {
    // Android permission is requested in Flutter via permission_handler.
    // This method exists for future expansion.
  }

  static Future<List<Task>> getTasks() async {
    final raw = await _ch.invokeMethod<String>('getTasks');
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(Task.fromJson).toList();
  }

  static Future<void> saveTask(Task task) async {
    await _ch.invokeMethod('saveTask', task.toJson());
  }

  static Future<void> deleteTask(int taskId) async {
    await _ch.invokeMethod('deleteTask', {'taskId': taskId});
  }

  static Future<List<SmsLog>> getLogs({int limit = 200}) async {
    final raw = await _ch.invokeMethod<String>('getLogs', {'limit': limit});
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(SmsLog.fromJson).toList();
  }

  static Future<void> clearLogs() async {
    await _ch.invokeMethod('clearLogs');
  }
}
