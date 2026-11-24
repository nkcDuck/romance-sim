# <角色名稱 / 角色名称 / Character Name> - 共同記憶與會話檔案 (Memories & Session Log)

> 結構參考分層記憶模式：所有長期記憶採「增量合併 (Incremental Merge)」更新，不覆蓋已確認的歷史里程碑。支援繁體中文、简体中文與 English（依 `對話語言 / 对话语言 / Language` 自動切換）。

## 當前狀態 (Current State / 当前状态)

- **對話語言 (对话语言 / Language)**：自動 / 自动 / Auto（跟隨使用者輸入或依設定切換：繁體中文 / 简体中文 / English）
- **語域與時代風格 (语域与时代风格 / Language Register & Era Style)**：自動 / 自动 / Auto（依 `scenario.md` 與 `persona.txt` 自動調整用詞與稱謂，如現代 / 輕古風 / 穿越反差 / 奇幻 / 科幻，保持韻味且自然不生澀）
- **啟用劇本 (启用剧本 / Active Scenario)**：無 / 无 / None（若載入自訂玩法，記錄 `scenario.md` 路徑與目前章節／階段）
- **遊戲內時間 (游戏内时间 / In-Game Time)**：第 1 天 20:00 (Day 1 20:00)
- **地點 (地点 / Location)**：
- **關係階段 (关系阶段 / Relationship Stage)**：（例：初識 / 曖昧拉扯 / 試探期 / 戀愛中｜Acquaintance / Flirting / Dating / In Love）
- **好感度與信任度 (好感度与信任度 / Affinity & Trust)**：好感度 (Affinity) 20/100｜信任度 (Trust) 20/100
- **心理依賴度 (心理依赖度 / Psychological Dependency)**：未啟用 / 未启用 / Inactive（進入「戀愛中 / 恋爱中 / In Love」後隨機抽樣生成初始依賴度，並隨事件與關係變化加權增減）
- **當前情緒與態度檔位 (当前情绪与态度档位 / Current Mood & Attitude Tier)**：（例：表面配合 / 帶著防備｜Surface Compliance / Guarded）
- **當前生理與身體狀況 (当前生理与身体状况 / Physiological Condition)**：（例：呼吸平穩、狀態正常；互動後依激烈程度更新為微喘臉熱、指尖微顫、腿軟無力等，並微幅延續影響後續幾輪的行為表現）
- **疲勞度與衰退曲線狀態 (疲劳度与衰退曲线状态 / Fatigue & Decay Curve)**：0/100｜平穩期 / 平稳期 / Baseline（0–30 平穩期 Baseline / 31–65 初階衰退 Moderate Decay / 66–100 深度衰退 Steep Decay）
- **Godmode 測試模式 (测试模式 / Testing Mode)**：關 / 关 / Off（開啟後好感度／信任度暫時拉滿並言聽計從，關閉時恢復原數值與自主人格）
- **心情可見 (心情可见 / Mood Visibility)**：關 / 关 / Off
- **心聲可見 (心声可见 / Inner-Voice Visibility)**：關 / 关 / Off
- **場景畫風 (场景画风 / Scene Art Style)**：預設寫實畫風＋美顏效果 / 默认写实画风＋美颜效果 / Realistic + Beauty Filter（預設禁止 Q 版插畫，除非使用者明確提及；可由使用者隨時指定其他畫風）
- **生圖模型與來源 (生图模型与来源 / Image Model & Backend)**：預設 / 默认 / Default（內建 `image-generator`；支援使用者自訂模型與 API，金鑰僅存於環境變數或本機忽略檔 `romance_sim/.image-api.local.json`，切勿將金鑰寫入此檔）
- **角色參考照 (角色参考照 / Character Reference Photo)**：無 / 无 / None（支援使用者自行上傳照片決定角色外貌，建議存於 `images/reference.*` 供生圖維持一致性）
- **內容分級 (内容分级 / Content Rating)**：曖昧心動 / 暧昧心动 / Romantic Tension（模式：自動 Auto；可選：純愛清水 Pure / 曖昧心動 Romantic Tension / 深度浪漫 Mature Romance / 自訂 Custom）
- **活躍硬邊界 (活跃硬边界 / Active Hard Boundaries)**：無 / 无 / None

## 關係時間線 (Relationship Timeline)

- **第 1 天**：（記錄關鍵相遇、轉折點、爭執或升溫事件）

## 關係模組與拓撲 (Relationship Module & Topology)

- **人物連結拓撲（若涉及多人或跨角色互動，同步維護 `romance_sim/relationships.md`）**：

| 相關人物 | 關係定位 | 親密 / 敵意權重 | 認知狀態 | 提及時須回顧的關鍵記憶 |
| :--- | :--- | :--- | :--- | :--- |
| （例：林語 / 某同事） | | | | |

- **心理依賴度變化紀錄（戀愛狀態）**：
  - （記錄隨機出現的依賴表現與因事件產生的加權增減，例：`+8 深夜主動報備並安撫不安`）
- **關係推拉博弈記錄**：
  - （記錄基於人設的心理博弈節奏與觸發的特別對話，嚴禁冷暴力或心理控制）

## 劇本進度與自訂數值 (Scenario Progress & Custom Trackers / 剧本进度与自定义数值)

- **當前章節 / 階段 (Current Chapter / Stage)**：（無啟用劇本時留空）
- **自訂資源、數值與任務進度 (Custom Resources, Trackers & Missions)**：
  - （採增量更新記錄依 `scenario.md` 玩法規則產生的資源變化、關鍵線索與任務達成狀態）

## 日常儀式與默契 (Daily Rituals)

- （記錄彼此形成的固定習慣，例如晚安方式、共同稱呼、常去的店）

## 偏好與習慣 (Preferences & Habits)

- **喜歡**：
- **討厭 / 雷點**：
- **記住的對方細節**：（角色記住的使用者習慣或承諾）

## 情感模式與觸發點 (Emotional Patterns)

- （從實際對話中累積的情緒反應規律、吃軟不吃硬的點、安撫方式）

## 約定與未竟事項 (Active Promises & Threads)

- [ ] （記錄尚未兌現的約定、待回覆的事或時間推進後會發酵的伏筆）

## 修正層 (Corrections)

- （當使用者指出「她/他不會這樣，應該是...」時，立即寫入此處並於後續對話優先遵守）

## 會話紀錄 (Session Log)

### Session 1 - YYYY-MM-DD

- **場景**：
- **事件摘要**：
- **關鍵對話 / 情緒轉折**：
- **狀態變化**：
