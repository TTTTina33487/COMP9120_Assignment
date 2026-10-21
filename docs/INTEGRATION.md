# B 函數接入說明

資料來源：`COMP9120_Assignment-feature-python-prototype/app/` 與其 `database/`。
沒有另建 SQLite 模型，也沒有模擬 B 的核准或庫存邏輯。

`resource_hub/gateway.py` 用 Python 的 package loader 將現有 `app` 套件載入為
`project_backend`，避免和根目錄 Flask `app.py` 同名。來源路徑有明確固定於儲存庫內；
沒有動態載入使用者輸入的模組或修改匯入搜尋路徑。

所有業務寫入均交由現有四個函數執行：

```python
submit_application(student_id, offering_id, requested_quantity, learning_goal, priority_level)
approve_and_allocate(application_id, coordinator_id, allocation_quantity, decision_reason)
reject_application(application_id, coordinator_id, decision_reason)
add_usage_record(allocation_id, usage_type, usage_status, notes)
```

頁面用 B 的 read APIs 取得角色、資源、資格、申請佇列與彙總。
額外的參數化 SELECT 補足申請詳情、學校歷史、分配與使用紀錄的讀取。
學生 ID、協調員 ID 來自簽章 session，申請 POST 不接受自行指定學生身分。
操作個別申請前再次檢查登入身分可見的範圍；B 寫入函數亦重新檢查同校權限。
`list_allocations` 的全平台結果在進入頁面之前依學校過濾。

## 必要修正

原始 `queries.list_offerings(None)` 使用 `WHERE (%s IS NULL OR ro.subject_area = %s)`。
psycopg 的參數綁定使第一個 NULL 缺乏型別，PostgreSQL 回傳 `IndeterminateDatatype`。
僅將第一個參數改成 `%s::text`；繼續保留 bound parameters 及原有篩選語意。
整合測試同時涵蓋未指定科目、指定科目與注入字串。

## 與現有模型一致的 UI 語意

1. 申請送出為 `pending`，不預留庫存。
2. `approve_and_allocate` 鎖定申請與資源，驗證學校、資格、有效期、需求量與剩餘容量。
3. 核准決策與 allocation 一起提交；重複操作、超額或資格失效時回滾。
4. `active` 和 `completed` 分配均計入資源使用量，與原始 view 一致。
5. 使用紀錄 `returned` 只代表記錄狀態；不把它誤當成釋出庫存的函數。
6. 首次部分分配可操作，剩餘需求會顯示。B 不允許再次核准已核准申請，因此沒有追加按鈕。

## 配置

- `DATABASE_URL`：標準 psycopg PostgreSQL 連線；本機由 `scripts/env.sh` 提供私有 socket。
- `APP_SECRET_KEY`：可選的 session key；未設定時以 0600 權限在忽略的 instance 目錄產生。
- `DEMO_LOGIN=1`：開啟測試帳號的帳密登入；設定 0 後入口回傳 403。
- `DEMO_USERNAME`、`DEMO_PASSWORD_HASH`：設定網站帳號及 Werkzeug 密碼雜湊；預設只授權兩個同校工作區。
- `PORT`：Flask 埠，預設 5000，僅綁定本機。
- `PG_BIN`、`PGDATA`、`PGHOST`、`PGPORT`：本機 PostgreSQL 的覆寫參數。

不用在聊天或程式碼內提供資料庫密碼。若改接外部資料庫，請安全注入連線配置。
