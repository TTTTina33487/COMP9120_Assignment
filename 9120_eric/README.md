# 原型介面、後端整合與展示交付：執行說明

COMP9120 · Remote Education Resource Support System

本文件說明「UI／原型整合與展示交付」這部分如何安裝、啟動、操作、測試及產生展示材料。
介面使用 **Flask**，直接呼叫 B 提供的 Python 函數，並連接 **PostgreSQL**。
資料來自專案的 `schema.sql` 與 `seed.sql`，全部是虛構示範資料。
介面、表單、錯誤訊息、CSV 欄位與程式註解已統一為英文。

**本機安裝與英文介面操作：**[LOCAL_SETUP.md](docs/LOCAL_SETUP.md)。
**新版英文介面截圖：**[SCREENSHOTS.md](docs/SCREENSHOTS.md)（11 張桌面、3 張手機）。
本專案是一個 Flask 網站，學生、協調員、報表都是其中的頁面，B 的 Python 模組提供後端功能。

## 1. 我負責的部分

- 學生介面：資源查詢、資格篩選、提出申請及追蹤結果。
- 協調員介面：同校申請審核、核准並分配、駁回及填寫原因。
- 使用追蹤與報表：新增使用紀錄、資源使用統計及 CSV 匯出。
- 接入 B 的 Python 函數，完成 PostgreSQL 整合與瀏覽器操作測試。
- 製作單頁 Poster、展示影片、字幕及演示流程／講稿。

本部分不取代整組的正式 Project Report、教學團隊範本的貢獻表或現場展示。

## 2. 從哪裡取得程式與成果

程式與展示材料在 GitHub 的 **`codex/remote-education-delivery`** 分支：

[開啟交付分支](https://github.com/Eric-LIN18/9120/tree/codex/remote-education-delivery)

| 交付項目 | 檔案 |
| --- | --- |
| 完整交付包，含程式與下列成果 | [9120-delivery.zip](artifacts/9120-delivery.zip) |
| 一頁 A3 Poster | [Poster.pdf](artifacts/Poster.pdf) |
| 108 秒展示影片，字幕版、無真人旁白 | [Showcase.mp4](artifacts/Showcase.mp4) |
| 可編輯字幕 | [Showcase.srt](artifacts/Showcase.srt) |
| 現場演示流程及英文解說稿 | [DEMO_RUNBOOK.md](docs/DEMO_RUNBOOK.md) |
| B 函數接入說明 | [INTEGRATION.md](docs/INTEGRATION.md) |
| 已完成的測試紀錄 | [VALIDATION.md](docs/VALIDATION.md) |

下載單一 ZIP、PDF 或影片：開啟 GitHub 檔案頁後按 **Download raw／下載原始檔案**。
若要取得全部分支內容，使用 GitHub 的 **Code → Download ZIP**，並先確認目前選的是交付分支。

## 3. 已設定好的 Codex 雲端環境：快速啟動

以下指令要在已連接雲端環境的終端執行；貼在聊天中時，可請 Codex 代為執行。
`/workspace/9120` 是雲端內部路徑，不是你電腦的資料夾。

```bash
cd /workspace/9120
bash scripts/start.sh
```

腳本會啟動本機 PostgreSQL、保留既有資料，再啟動 Flask。
本環境的 PostgreSQL 使用私有 Unix socket；TCP 連線停用。

可在另一個終端檢查服務：

```bash
curl --fail --silent http://127.0.0.1:5000/health
```

正常結果包含 `"status":"ok"`、`"backend":"B Python + PostgreSQL"`，原始種子資料有 8 項資源。

**Codex 網頁任務不會因為啟動 Flask 就自動提供可點擊的網站預覽。**
若要親自操作瀏覽器介面，請使用下面的本機執行方式，或使用支援連接服務埠的開發環境。

若相同 Debian 13 雲端映像尚未安裝本部分依賴，先執行一次：

```bash
cd /workspace/9120
bash scripts/setup.sh
bash scripts/start.sh
```

`setup.sh` 安裝鎖定的 Python 套件與一般使用者可執行的 PostgreSQL 17。
它不會重設已初始化的資料庫，也不會重新灌入種子資料。
基礎映像須提供 Python、Git、Debian 套件工具；重製展示材料另需 Chromium、FFmpeg 和 Noto CJK 字型。
此安裝腳本是目前 Debian 雲端環境專用，Windows／macOS 請依下節設定。

## 4. 在自己的電腦執行介面

### 4.1 取得程式並準備工具

需要 **Python 3.10 以上**、**PostgreSQL 15 以上**；目前雲端驗證使用 Python 3.12／PostgreSQL 17。
只操作介面時，不需要安裝 Chromium、FFmpeg 或影片製作套件。

有安裝 Git 可執行：

```bash
git clone --branch codex/remote-education-delivery --single-branch https://github.com/Eric-LIN18/9120.git
cd 9120
```

也可以下載交付分支 ZIP，解壓後在含有 `app.py` 的資料夾開啟終端。
接下來的所有本機指令都在這個資料夾執行。

### 4.2 安裝 Python 依賴

Windows PowerShell：

```powershell
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

macOS／Linux：

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
```

不必啟用虛擬環境；以上指令直接指定其中的 Python。

### 4.3 建立本機 PostgreSQL 資料庫

先確認 PostgreSQL 服務正在運作。使用 pgAdmin 建立空資料庫 `remote_education_db`，
或在可使用 PostgreSQL 命令列工具的終端執行：

```bash
createdb -U postgres remote_education_db
psql -U postgres -d remote_education_db -v ON_ERROR_STOP=1 -f COMP9120_Assignment-feature-python-prototype/database/schema.sql
psql -U postgres -d remote_education_db -v ON_ERROR_STOP=1 -f COMP9120_Assignment-feature-python-prototype/database/seed.sql
```

若使用 pgAdmin，連接該資料庫，在 Query Tool 依序開啟並執行同一份 `schema.sql`、`seed.sql`。
儲存庫有兩份資料庫工作包；這個介面使用 **`COMP9120_Assignment-feature-python-prototype/database/`**。
不要把兩份工作包的 schema／seed 都灌入同一個資料庫。

以上初始化只對**新建的空資料庫執行一次**。若 B 已替你建好同一份 schema 和資料，可直接沿用。
若你的 PostgreSQL 使用不同帳號或連接埠，請相應調整指令與下一步連線設定。

### 4.4 設定連線

將根目錄的 `.env.example` 複製為本機 `.env`；若已有 `.env`，請保留並編輯既有檔案。內容格式如下：

```dotenv
DATABASE_URL=postgresql://postgres:YOUR_LOCAL_PASSWORD@127.0.0.1:5432/remote_education_db
DEMO_LOGIN=1
PORT=5000
```

將 `YOUR_LOCAL_PASSWORD` 改為你自己的本機 PostgreSQL 密碼。
若密碼含有 `@`、`:`、`/` 等 URL 特殊字元，需使用 URL 編碼。
`.env` 已被 Git 忽略；不要將真實密碼加入 README、程式或 Git 提交。
B 的連線模組會自動讀取 `.env`。

### 4.5 啟動與開啟畫面

Windows PowerShell：

```powershell
.\.venv\Scripts\python.exe app.py
```

macOS／Linux：

```bash
.venv/bin/python app.py
```

保持終端開啟，在**同一台電腦**的瀏覽器輸入 `http://127.0.0.1:5000`。
這是你本機服務的位址，不是 Codex 雲端環境的公開網址。
停止前景執行的 Flask 時，在啟動它的終端按 `Ctrl+C`。

## 5. 完整操作示範

建議使用同校角色：學生 **Ava Mitchell**、協調員 **Amelia Carter**。
登入頁是本機展示角色選擇，不需密碼，也不是正式身分驗證系統。

| 步驟 | 角色與操作 | 預期結果 |
| --- | --- | --- |
| 1 | 選 Ava Mitchell，點 Enter workspace，進入 Explore resources | 顯示資源、需求資格、期限及剩餘量 |
| 2 | 勾選「Eligible only」後搜尋 | 只列出符合該學生資格、尚未過期且仍有庫存的資源 |
| 3 | 新增申請，選 Downloadable Year 10 Study Library，數量 2，填入至少 10 字的學習目標 | 產生待審核申請；不預留庫存 |
| 4 | 登出，改選 Amelia Carter，進入「Review & allocate」 | 只看到所屬學校的申請 |
| 5 | 開啟剛送出的申請，確認分配數量及處理原因，按「Approve & allocate」 | 同一筆交易更新決策與分配，剩餘資源量下降 |
| 6 | 進入「Usage records」，選該筆分配，填入類型及狀態後保存 | 新增有序號的使用紀錄，可回申請詳情查看 |
| 7 | 進入「Reports」，下載本校申請 CSV／資源 CSV | 匯出對應明細與全平台資源彙總 |

若要展示駁回，可選另一個尚未處理的本校申請，填寫原因後按「Reject application」。
學生同一天不能對同一資源重複申請；演示前若已提交過，請改用另一個有效組合。
不需要為了重做展示而刪除現有資料庫。

## 6. 與 B 的函數對接

| 介面功能 | B 的 Python 函數 |
| --- | --- |
| 展示角色選擇 | `list_students`、`list_coordinators` |
| 資源／資格查詢 | `list_offerings`、`list_suitable_offerings` |
| 送出學生申請 | `submit_application` |
| 申請列表與審核佇列 | `list_student_applications`、`list_review_queue` |
| 核准與分配 | `approve_and_allocate` |
| 駁回申請 | `reject_application` |
| 分配及使用紀錄 | `list_allocations`、`add_usage_record` |
| 報表與地區資訊 | `dashboard_metrics`、`utilisation_report`、`list_regions` |

`resource_hub/gateway.py` 負責載入 B 的套件與頁面資料映射。
所有業務寫入均呼叫 B 的服務；資格、同校權限、數量、期限與交易回滾不由介面自行取代。
詳見 [INTEGRATION.md](docs/INTEGRATION.md)。

## 7. 執行整合測試

下面是**目前已設定好的 Codex／Linux 環境**命令：

```bash
cd /workspace/9120
source scripts/env.sh
bash scripts/database.sh
.venv/bin/python -m pip install -r requirements.lock.txt
.venv/bin/python -m pytest --junitxml=artifacts/test-results.xml -q
```

現有驗證紀錄為 **35 項通過、0 失敗、0 跳過**。
涵蓋主要頁面、完整流程、資格／效期、跨校存取、庫存不足回滾、重複核准、並行分配及 CSV。

測試會建立並清理專屬臨時 PostgreSQL 資料庫，不會重設日常操作的資料。
測試連線角色必須有建立資料庫的權限，請在開發／測試 PostgreSQL 執行。
本機測試請先完成第 4 節的資料庫與 `.env` 設定，再安裝開發依賴：

```bash
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/python -m pytest --junitxml=artifacts/test-results.xml -q
```

Windows 將以上 Python 路徑改為 `.\.venv\Scripts\python.exe`。
B 的模組在測試載入時也會讀取 `.env`；終端若已設定 `DATABASE_URL`，會優先使用該值。

## 8. 重新產生截圖、Poster 與影片

只要觀看現有成果，直接下載 `artifacts/` 的檔案即可，不必重製。
下列流程已在目前 **Debian 雲端環境**驗證；錄影腳本使用 Linux 的路徑與符號連結。

除開發套件外，需要系統的 Chromium、FFmpeg／ffprobe 及 Noto CJK 字型。
先執行上節測試，確保本次 `artifacts/test-results.xml` 全部通過，再依序執行：

```bash
cd /workspace/9120
source scripts/env.sh
.venv/bin/python scripts/browser_check.py
.venv/bin/python scripts/build_deliverables.py
```

第一個腳本會使用隔離資料庫完成真實瀏覽器操作、下載 CSV、錄影並擷取桌面／手機截圖。
第二個腳本才會利用剛產生的錄影、截圖與測試結果製作交付檔。
`browser-result.json` 與原始錄影不在 Git 內，因此從新下載的程式碼重製時不能跳過第一步。

主要輸出：

| 輸出 | 位置 |
| --- | --- |
| 頁面截圖 | `artifacts/screenshots/` |
| 原始操作錄影 | `artifacts/browser/workflow.webm`（不納入 Git） |
| 一頁 Poster PDF／預覽 | `artifacts/Poster.pdf`、`artifacts/Poster.png` |
| 剪輯影片／字幕 | `artifacts/Showcase.mp4`、`artifacts/Showcase.srt` |
| 測試與交付紀錄 | `docs/VALIDATION.md` |
| 完整交付包 | `artifacts/9120-delivery.zip` |

修改海報內容請編輯 `docs/poster.html`；修改影片片頭、片尾與字幕樣式請編輯
`scripts/build_deliverables.py`。現場說明順序及英文講稿見 [DEMO_RUNBOOK.md](docs/DEMO_RUNBOOK.md)。

## 9. 常見問題

| 情況 | 處理方式 |
| --- | --- |
| `Port 5000 is in use`／`Address already in use` | 先檢查 `/health`；可能已有同一服務執行，不必重複啟動。不要直接終止不明程序。要改用 5001，可在 `.env` 設 `PORT=5001`；雲端 `start.sh` 可用 `PORT=5001 bash scripts/start.sh` |
| 找不到 `.venv` 或 Flask／psycopg | 回到根目錄建立虛擬環境並安裝 `requirements.txt`；雲端可執行 `bash scripts/setup.sh` |
| 找不到 `psql`／`createdb` | 確認已安裝 PostgreSQL 工具並加入 PATH，或改用 pgAdmin 初始化 |
| 資料庫無法連線／密碼錯誤 | 檢查 PostgreSQL 服務、`.env` 的帳號／密碼／埠／資料庫名稱；本機不要沿用雲端 socket 路徑 |
| 找不到 `remote_education` 內的資料表 | 確認連到正確資料庫，並在新空資料庫依序執行原始 schema、seed |
| 某資源無法申請／核准 | 查看資格、驗證狀態、有效期限與剩餘量；資格及資源種子日期主要於 2027 年到期 |
| 同一申請不能再次核准 | 已處理的申請不可重複核准，避免重複分配 |
| Poster／影片重製找不到檔案 | 先完成 pytest 和 `browser_check.py`，再執行 `build_deliverables.py` |
| Chromium 路徑不同 | 在執行展示腳本前設定 `CHROMIUM_PATH`；預設 `/usr/bin/chromium` |

## 10. 本部分檔案與已知範圍

```text
app.py                         Flask 入口、頁面路由、session 與表單檢查
resource_hub/gateway.py         B 套件接入、資料映射及學校範圍查詢
templates/                     學生／協調員／報表等頁面
static/style.css               響應式介面樣式
tests/                         真正 PostgreSQL 的整合測試
scripts/                       安裝、啟動、瀏覽器驗證及交付產生工具
docs/                          整合說明、演示講稿、Poster 原稿與驗證紀錄
artifacts/                     可下載的成果、截圖及測試輸出
COMP9120_Assignment-feature-python-prototype/app/
                               B 提供的 Python 資料庫與業務函數
COMP9120_Assignment-feature-python-prototype/database/
                               本原型使用的原始 PostgreSQL SQL 與種子資料
instance/                      本機資料庫與 session key，已忽略版本控制
```

- 核准與分配為同一筆交易；失敗回滾，且有並行庫存保護。
- 支援首次部分分配；目前 B 不支援核准後追加分配。
- 使用紀錄的 `returned` 不會自動改變分配狀態或釋出庫存。
- 本機展示角色切換不等於正式登入；`DEMO_LOGIN=0` 可關閉展示入口。
- 本部分使用 OpenAI Codex 協助程式整合、文件、測試及展示材料製作；提交前仍須由組員檢查並能解釋內容。正式報告請依課程要求另附完整 AI 使用聲明。
