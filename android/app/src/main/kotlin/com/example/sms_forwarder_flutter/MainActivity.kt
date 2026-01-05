package com.example.sms_forwarder_flutter

import android.content.Context
import android.content.SharedPreferences
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.atomic.AtomicLong

class MainActivity : FlutterActivity() {
    private val CHANNEL = "sms_forwarder"
    private val PREFS_NAME = "sms_forwarder_prefs"
    private val TASKS_KEY = "tasks"
    private val NEXT_TASK_ID_KEY = "next_task_id"
    private val LOGS_KEY = "logs"
    private val NEXT_LOG_ID_KEY = "next_log_id"
    
    private lateinit var prefs: SharedPreferences
    private val tasks = mutableListOf<JSONObject>()
    private val logs = mutableListOf<JSONObject>()
    private val nextTaskId = AtomicLong(1)
    private val nextLogId = AtomicLong(1)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        loadTasks()
        loadLogs()
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getTasks" -> {
                    result.success(tasksToJson())
                }
                "saveTask" -> {
                    try {
                        val taskData = call.arguments as? Map<*, *>
                        if (taskData != null) {
                            saveTask(taskData)
                            result.success(null)
                        } else {
                            result.error("INVALID_ARGUMENTS", "Invalid arguments for saveTask", null)
                        }
                    } catch (e: Exception) {
                        result.error("SAVE_ERROR", "Failed to save task: ${e.message}", null)
                    }
                }
                "deleteTask" -> {
                    try {
                        val args = call.arguments as? Map<*, *>
                        val taskIdValue = args?.get("taskId")
                        val taskId = when (taskIdValue) {
                            is Int -> taskIdValue.toLong()
                            is Long -> taskIdValue
                            is Number -> taskIdValue.toLong()
                            else -> null
                        }
                        if (taskId != null) {
                            deleteTask(taskId)
                            result.success(null)
                        } else {
                            result.error("INVALID_ARGUMENTS", "Invalid arguments for deleteTask", null)
                        }
                    } catch (e: Exception) {
                        result.error("DELETE_ERROR", "Failed to delete task: ${e.message}", null)
                    }
                }
                "getLogs" -> {
                    try {
                        val args = call.arguments as? Map<*, *>
                        val limit = args?.get("limit") as? Int ?: 200
                        result.success(logsToJson(limit))
                    } catch (e: Exception) {
                        result.error("LOGS_ERROR", "Failed to get logs: ${e.message}", null)
                    }
                }
                "clearLogs" -> {
                    clearLogs()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // MARK: - Task management
    
    private fun loadTasks() {
        val tasksJson = prefs.getString(TASKS_KEY, "[]")
        try {
            val array = JSONArray(tasksJson)
            for (i in 0 until array.length()) {
                tasks.add(array.getJSONObject(i))
            }
        } catch (e: Exception) {
            // If parsing fails, start with empty list
            tasks.clear()
        }
        
        nextTaskId.set(prefs.getLong(NEXT_TASK_ID_KEY, 1))
    }
    
    private fun saveTasks() {
        val editor = prefs.edit()
        editor.putString(TASKS_KEY, tasksToJson())
        editor.putLong(NEXT_TASK_ID_KEY, nextTaskId.get())
        editor.apply()
    }
    
    private fun tasksToJson(): String {
        return JSONArray(tasks).toString()
    }
    
    private fun saveTask(taskData: Map<*, *>) {
        val taskJson = JSONObject(taskData)
        
        // If task has no ID, assign a new one
        if (!taskJson.has("id") || taskJson.isNull("id")) {
            taskJson.put("id", nextTaskId.getAndIncrement())
            tasks.add(taskJson)
        } else {
            // Get task ID as Long (handle both Int and Long)
            val taskId = when (val idValue = taskJson.get("id")) {
                is Int -> idValue.toLong()
                is Long -> idValue
                is Number -> idValue.toLong()
                else -> throw IllegalArgumentException("Task ID must be a number")
            }
            
            val index = tasks.indexOfFirst { 
                when (val existingId = it.get("id")) {
                    is Int -> existingId.toLong() == taskId
                    is Long -> existingId == taskId
                    is Number -> existingId.toLong() == taskId
                    else -> false
                }
            }
            
            if (index >= 0) {
                // Update existing task
                tasks[index] = taskJson
            } else {
                // Add new task with existing ID
                tasks.add(taskJson)
            }
        }
        
        saveTasks()
    }
    
    private fun deleteTask(taskId: Long) {
        tasks.removeAll { 
            when (val existingId = it.get("id")) {
                is Int -> existingId.toLong() == taskId
                is Long -> existingId == taskId
                is Number -> existingId.toLong() == taskId
                else -> false
            }
        }
        saveTasks()
    }
    
    // MARK: - Log management
    
    private fun loadLogs() {
        val logsJson = prefs.getString(LOGS_KEY, "[]")
        try {
            val array = JSONArray(logsJson)
            for (i in 0 until array.length()) {
                logs.add(array.getJSONObject(i))
            }
        } catch (e: Exception) {
            // If parsing fails, start with empty list
            logs.clear()
        }
        
        nextLogId.set(prefs.getLong(NEXT_LOG_ID_KEY, 1))
    }
    
    private fun saveLogs() {
        val editor = prefs.edit()
        editor.putString(LOGS_KEY, JSONArray(logs).toString())
        editor.putLong(NEXT_LOG_ID_KEY, nextLogId.get())
        editor.apply()
    }
    
    private fun logsToJson(limit: Int): String {
        val limitedLogs = logs.take(limit)
        return JSONArray(limitedLogs).toString()
    }
    
    private fun clearLogs() {
        logs.clear()
        saveLogs()
    }
}
