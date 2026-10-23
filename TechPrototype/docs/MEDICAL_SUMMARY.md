# App 内结构化就医摘要

## 功能定位

“就医摘要”把安康助手中已有的客观数据整理为一个适合在就诊现场直接向医生展示的只读页面。

- 不要求用户填写主诉或症状自述，用户可在就诊时当面说明。
- 不调用 Agent 生成诊断，不预测疾病，也不替代医生判断。
- 不新增摘要数据库表；每次打开或切换时间范围时，按最新数据实时生成。
- 暂不导出 PDF、FHIR 或分享链接，避免扩大首版功能和隐私暴露面。

## App 入口与交互

入口：`我的 -> 就医摘要`

页面支持最近 7 天、14 天和 30 天三个范围，默认 14 天。页面包含：

1. 患者基本信息：姓名、年龄、性别、身高、体重、BMI。
2. 健康档案：慢性疾病、过敏信息、既往史、关联设备。
3. 健康指标：各指标最近值、平均值、最小值、最大值、记录数和异常次数。
4. 风险提示：所选时间范围内最近的较高风险/高风险事件及其客观触发原因。
5. 用药提醒：当前启用的用药提醒及当前周期完成状态。
6. 数据来源：智能手环、手工录入或其他设备的记录数量。
7. 生成时间和医疗免责声明。

健康记录的 `remark`/`note` 字段不会进入接口返回值，防止把用户自由文本误当作临床事实展示。

## 后端接口

```http
GET /api/medical-summary?days=14
Authorization: Bearer <token>
```

`days` 允许 7～90，App 当前提供 7、14、30 三个选项。接口始终按登录用户隔离数据。

主要实现：

- `medicalsummary/controller/MedicalSummaryController.java`
- `medicalsummary/service/MedicalSummaryService.java`
- `medicalsummary/vo/MedicalSummaryVO.java`

数据读取来源：

- `user`、`health_profile`
- `health_record`
- `health_event`
- `reminder`（仅 `type=medicine` 且已启用）

## 统计口径

- 时间边界：从开始日期 `00:00`（含）到结束日期下一天 `00:00`（不含）。
- 血压：收缩压和舒张压分别聚合，展示为 `收缩压/舒张压`。
- 其他数值指标：展示最近值、算术平均值、最小值和最大值。
- 异常次数：健康记录的 `status` 不为 `normal` 时计为异常。
- 风险事件：仅展示 `elevated` 和 `high`，最多 5 条。
- 用药状态：只表达一次性/每日/每周提醒的“当前周期是否完成”，不声称是长期服药依从率。

## Flutter 实现

- 模型：`lib/models/medical_summary_model.dart`
- 请求服务：`lib/services/medical_summary_service.dart`
- 页面：`lib/pages/medical_summary/medical_summary_page.dart`
- 路由：`/medical-summary`

页面使用 `SelectionArea` 包裹摘要正文，医生或用户可长按选择文字；数据本身保持只读。

## 安全边界

页面固定显示：

> 本页由用户日常记录自动整理，仅用于就医沟通，不代表医生诊断；设备及手工录入数据可能存在误差。

当前首版不会展示手机号、邮箱和健康记录备注，不会自动向医院或第三方发送数据。
