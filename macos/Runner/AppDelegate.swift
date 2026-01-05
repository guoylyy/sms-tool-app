import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    // 内存存储模拟
    private var tasks: [[String: Any]] = []
    private var logs: [[String: Any]] = []
    private var nextTaskId: Int64 = 1
    private var nextLogId: Int64 = 1
    
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    override func applicationDidFinishLaunching(_ notification: Notification) {
        // 注册方法通道
        let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
        let channel = FlutterMethodChannel(
            name: "sms_forwarder",
            binaryMessenger: controller.engine.binaryMessenger
        )
        
        channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            guard let self = self else {
                result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate not available", details: nil))
                return
            }
            
            switch call.method {
            case "getTasks":
                // 返回任务列表
                result(self.tasksToJson())
                
            case "saveTask":
                // 保存任务
                if let arguments = call.arguments as? [String: Any] {
                    self.saveTask(arguments)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for saveTask", details: nil))
                }
                
            case "deleteTask":
                // 删除任务
                if let arguments = call.arguments as? [String: Any],
                   let taskId = arguments["taskId"] as? Int64 {
                    self.deleteTask(taskId)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for deleteTask", details: nil))
                }
                
            case "getLogs":
                // 返回日志列表
                var limit = 200
                if let arguments = call.arguments as? [String: Any],
                   let argLimit = arguments["limit"] as? Int {
                    limit = argLimit
                }
                result(self.logsToJson(limit: limit))
                
            case "clearLogs":
                // 清空日志
                self.clearLogs()
                result(nil)
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        super.applicationDidFinishLaunching(notification)
    }
    
    // MARK: - 任务管理
    
    private func tasksToJson() -> String {
        do {
            let data = try JSONSerialization.data(withJSONObject: tasks, options: [])
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            return "[]"
        }
    }
    
    private func saveTask(_ taskData: [String: Any]) {
        var task = taskData
        
        // 如果任务没有ID，分配一个新ID
        if task["id"] == nil {
            task["id"] = nextTaskId
            nextTaskId += 1
        } else if let existingId = task["id"] as? Int64 {
            // 更新现有任务
            if let index = tasks.firstIndex(where: { ($0["id"] as? Int64) == existingId }) {
                tasks[index] = task
                return
            }
        }
        
        tasks.append(task)
    }
    
    private func deleteTask(_ taskId: Int64) {
        tasks.removeAll { ($0["id"] as? Int64) == taskId }
    }
    
    // MARK: - 日志管理
    
    private func logsToJson(limit: Int) -> String {
        let limitedLogs = Array(logs.prefix(limit))
        do {
            let data = try JSONSerialization.data(withJSONObject: limitedLogs, options: [])
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            return "[]"
        }
    }
    
    private func clearLogs() {
        logs.removeAll()
    }
}
