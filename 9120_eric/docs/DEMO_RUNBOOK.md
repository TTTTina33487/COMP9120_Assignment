# 演示與影片流程

專題：Remote Education Resource Support System（COMP9120）

## 展示前

1. 執行 `bash scripts/start.sh`，確認 PostgreSQL 和 `/health` 成功。
2. 開啟 Poster PDF、Showcase.mp4，以及本文件。準備影片作為網路／現場操作的備援。
3. 預先確認原始種子資料仍在有效期內。不要重設組員共享的資料庫。
4. 本機示範帳號選 Ava Mitchell，協調員選 Amelia Carter，兩人同屬 Mallee Remote College。
5. 學生同一天不能對同一資源重複申請；正式展示前不要先用相同組合提交。
   可選另一位同校學生與開放資源；或使用瀏覽器自動化的隔離資料庫錄製。

## 三分鐘以內的現場演示

| 時間 | 操作 | 講解重點 |
| --- | --- | --- |
| 0:00–0:15 | Poster／登入頁 | 偏遠教育資源的需求、資格與分配需要可追蹤的關聯資料 |
| 0:15–0:35 | 選 Ava，查看 Overview 與 Explore resources | 原始種子資料；顯示資格、效期與即時剩餘量 |
| 0:35–1:00 | 在 New application 申請 Study Library、數量 2、學習目標、優先程度 high | 實際呼叫 B 的 submit_application；送出不預留庫存 |
| 1:00–1:35 | 切換 Amelia，查看 Review & allocate，按 Approve & allocate 分配 2 | 同校限制；資格、效期、需求量、容量都在交易內檢查 |
| 1:35–1:55 | 查看分配數量及使用紀錄頁 | 核准與分配原子提交；新增 completed 使用紀錄 |
| 1:55–2:25 | Reports、下載 school applications 及 Resource CSV | 本校明細、跨地區彙總，統計來自 B 的查詢 |
| 2:25–2:50 | 測試證據、Poster 總結 | 真正 PostgreSQL 整合、回滾及並行測試；課堂原型的邊界 |

## 可直接使用的英文解說稿

“Our Remote Education Resource Support System connects students in remote
regions with educational resources and school coordinators. The prototype uses
the team's PostgreSQL schema and synthetic seed data.

As Ava, I can see my requests and discover resources. The eligibility filter
uses the backend's verified eligibility, expiry and remaining-capacity query.
I request two units of the study library and describe my learning goal. This
creates a pending application; it does not reserve stock.

I now switch to Amelia, Ava's school coordinator. Coordinators can only inspect
and process applications from their own school. Approval calls the team's
approve-and-allocate function. It locks the application and resource, checks
school access, eligibility, expiry and capacity, and commits the decision and
allocation together. If any rule fails, every change is rolled back.

The allocation can now receive a numbered usage record, making the learning
activity traceable. The reports combine school-level application history with
platform-wide resource summaries and downloadable CSV files.

Integration tests exercise real PostgreSQL transactions, including concurrent
approvals competing for the last unit. A browser test verifies the complete
student-to-report workflow. This is a local teaching prototype with synthetic
data and explicit demo role switching. Production identity integration and
additional post-approval workflows remain future work.”

## 影片剪輯

`scripts/browser_check.py` 在獨立資料庫操作完整流程，錄製真實瀏覽器影片與截圖。
`scripts/build_deliverables.py` 依錄製的場景時間碼加入英文標題／說明、統一片頭與片尾，
輸出 H.264 MP4 和可編輯 SRT。沒有使用假操作或宣稱真人配音。
影片少於三分鐘，無真人旁白；可依上述稿件錄製組員配音。

重製順序：

```bash
source scripts/env.sh
.venv/bin/python -m pytest --junitxml=artifacts/test-results.xml -q
.venv/bin/python scripts/browser_check.py
.venv/bin/python scripts/build_deliverables.py
```

## 交付負責人安排

- UI／整合負責人：驗證演示環境、操作頁面、剪輯影片、排版 Poster、確認成果清單。
- B／Python 負責人：核對函數語意、核准分配交易、回滾與已知後續工作。
- 資料庫負責人：核對 ER／關聯模型、原始 SQL、限制條件與種子資料。
- 全組：補上真實組員姓名與學號、確認課程提交格式、試播影片並確認分工敘述。

## 問答備忘

- 為什麼不在 UI 自行扣庫存？由 B 的交易持有資料列鎖並驗證，避免並行超額。
- 什麼時候扣數量？核准分配時，申請送出不扣。
- 是否支援部分分配？首次可部分分配；現有 B 不能再次核准追加，UI 不提供假功能。
- returned 會補庫存嗎？使用紀錄不會；需另外設計 allocation lifecycle 交易。
- 正式登入在哪裡？此為明確標示的展示角色選擇，上線前需校方身分驗證。
