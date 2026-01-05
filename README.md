# SMS Forwarder (Flutter + Native Android)

这是一个**可运行的 Flutter 工程**：Flutter 负责 UI（任务配置/日志查看），Android 原生负责：
- 监听短信广播 `SMS_RECEIVED`
- 按「任务规则」匹配（支持多个任务，每个任务 1 条规则）
- 命中后用 WorkManager 后台转发到接口（mock 也行）
- 记录日志（Room）

> ⚠️ 重要：如果你计划上架 Google Play，`RECEIVE_SMS` 属于敏感权限，需要严格合规与审核说明。企业内部分发/自用相对简单。

---

## 1. 功能
- **任务管理**：添加/编辑/删除/启用/停用
- **规则类型**（每个任务一条）：
  - 发件人包含 (SENDER_CONTAINS)
  - 正文包含 (BODY_CONTAINS)
  - 正文正则 (BODY_REGEX)
- **转发动作**：POST JSON 到 endpointUrl
- **日志**：命中与转发结果（SUCCESS/FAILED/PENDING）

---

## 2. 运行步骤
1) 安装 Flutter SDK（3.3+），并确保 `flutter doctor` 正常  
2) 在本项目根目录执行：
```bash
flutter pub get
flutter run
```

3) 首次启动 App 会提示请求短信权限，请允许。

---

## 3. 测试方法
- 新建任务：规则 BODY_CONTAINS = "验证码"
- endpointUrl 可以先填：`https://httpbin.org/post`（回显 JSON，便于调试）
- 用另一台手机给测试机发短信（含“验证码”），查看日志。

---

## 4. Android 关键点
- `android/app/src/main/AndroidManifest.xml` 注册短信 Receiver
- Receiver 收到短信后读取 SharedPreferences 中 Flutter 配置的 tasks
- 命中后写入 Room 日志，并 enqueue WorkManager `ForwardWorker`

---

## 5. 目录结构（关键）
- `lib/` Flutter UI + MethodChannel bridge
- `android/app/src/main/kotlin/.../` 原生 Receiver、Worker、Room、Bridge

---

## 6. 接口 Payload（示例）
Worker POST 的 JSON 结构大致如下：
```json
{
  "taskId": 1700000000000,
  "taskName": "OTP Forward",
  "receivedAt": 1736073600000,
  "sender": "+8613800138000",
  "body": "【XX银行】验证码 123456，5分钟内有效",
  "rule": {"type":"BODY_CONTAINS","value":"验证码"},
  "device": {"model":"Pixel","sdkInt":34}
}
```

---

如需我帮你把「多条件规则（AND/OR）」或「模板化 headers/body」做进 UI，也可以直接在这个工程上继续迭代。


## v2 新增
- 多条件规则（AND/OR）
- 自定义 headers JSON
- body 模板（支持占位符）
