---
marp: true
theme: default
paginate: true
---

# agile-board 基本概念

GitHub 連携アジャイルボード — エンジニア向け設計解説

---

## このアプリでできること

| 機能 | 概要 |
|---|---|
| **ダッシュボード** | バーンダウン・KPT サマリー・進行中 Issue を一覧表示 |
| **スプリント管理** | GitHub Projects Iteration からスプリントを自動同期 |
| **エピック（案件）管理** | Issue を案件単位でまとめ、工数・進捗を集計 |
| **マイルストーン** | 月次ゴールをアプリ独自管理（GitHub 非依存） |
| **レトロスペクティブ** | スプリントごとの KPT（Keep/Problem/Try）を記録・履歴表示 |
| **実績入力（ワークログ）** | 週次タイムライン形式で作業実績を入力・集計 |
| **勤怠管理** | 休暇・早退・遅刻を週単位で管理 |
| **GitHub 同期** | Issue・ラベル・スプリントを GitHub Projects から自動同期 |

---

## 技術スタック

```
Backend:   PHP 8.3+ / Laravel 13
Frontend:  React 19 / TypeScript / Inertia.js v2 / Tailwind CSS v4
DB:        SQLite（開発）/ MySQL・PostgreSQL（本番対応）
認証:       GitHub OAuth（Socialite）
ルーティング: Laravel Wayfinder（型安全な TypeScript ルート生成）
グラフ:     Recharts
テスト:     Pest v4
```

---

## 認証フロー

```
1. ユーザーが「GitHub でログイン」をクリック
2. GitHub OAuth → アクセストークン取得
3. users テーブルに github_id / github_token を upsert
4. 以降の GitHub API 呼び出しはこの github_token を使用
```

> **スコープ**: `read:user`（ユーザー情報）、`repo`（プライベートリポジトリ）
> Iteration モードを使う場合は一度再ログインして `project` スコープを取得する必要あり

---

## データモデル概要（ER 図）

```
users
  └─ members（ログイン時に自動登録）

repositories（active フラグで同期対象を制御）
  └─ sprints（github_iteration_id）
       └─ issues（github_issue_number）
            └─ issues（parent_issue_id: Sub-issues/Tasks）

milestones（year + month で一意。アプリ独自管理）
  └─ sprints（milestone_id: 手動紐付け）

epics
  └─ issues（epic_id: Story Issues）

labels ←→ issues（issue_labels pivot）

work_logs（実績入力）
attendance（勤怠記録）
```

---

## Issue の3階層

```
Epic（案件）
  └─ Story Issue（parent_issue_id IS NULL）
       └─ Task Issue（parent_issue_id IS NOT NULL）
            = GitHub Sub-issues
```

| 種類 | 用途 | 主要フィールド |
|---|---|---|
| **Epic** | 案件・大機能単位 | due_date, started_at, priority |
| **Story** | スプリントに紐付く Issue | story_points, exclude_velocity |
| **Task** | Sub-issue（工数管理） | estimated_hours（手動）, actual_hours（ワークログ集計） |

---

## スプリント同期モード

| 条件 | 動作 |
|---|---|
| `github_project_number` **設定済み** | **Iteration モード**: GitHub Projects の `Sprint` フィールドからスプリントを自動同期 |
| `github_project_number` **未設定** | 同期なし: スプリントは手動管理（tinker 等で直接登録） |

> マイルストーンはどちらのモードでも **GitHub と同期しない**。アプリ独自管理。

---

## GitHub 同期フロー

```
POST /sync → GitHubSyncService::syncAll(githubToken)
  └─ アクティブなリポジトリ全件
      ├─ [Iteration モード] syncProjectIterations()
      │   └─ GraphQL: projectV2.fields / projectV2.items
      │       ├─ [Sprint フィールド] → sprints upsert
      │       │   └─ syncIssuesForIteration()
      │       │       └─ syncSubIssues()（Sub-issues Preview API）
      │       └─ ※ Monthly フィールドによる Milestone 同期は廃止
      │
      ├─ syncLabels()
      └─ repositories.synced_at 更新
  └─ syncEpicStartDates()
```

---

## 同期で保護される値

> GitHub 側に存在しない、アプリ側で手動設定する値は**上書きしない**

| テーブル | カラム | 理由 |
|---|---|---|
| sprints | `start_date` | アプリ側で手動設定 |
| sprints | `working_days` | GitHub に存在しない |
| sprints | `milestone_id` | マイルストーン紐付けはアプリ側で手動管理 |
| issues | `story_points` | GitHub に存在しない |
| issues | `exclude_velocity` | アプリ独自設定 |
| issues | `estimated_hours` | ユーザー入力 |
| issues | `actual_hours` | ユーザー入力（ワークログから集計） |
| epics | `started_at` | 未設定の場合のみ自動設定 |

---

## ベロシティ計算ロジック

以下の条件を**全て満たす** Issue をカウント:

```
1. state = 'closed'
2. exclude_velocity = false（Issue 単位の除外フラグ）
3. ラベルに exclude_velocity = true のものが付いていない
```

| 種別 | 計算式 |
|---|---|
| **ポイントベロシティ** | 対象 Issue の `story_points` 合計 |
| **Issue ベロシティ** | 対象 Issue の件数 |

---

## マルチリポジトリ対応

Iteration モードでは1つの GitHub Project に複数リポジトリの Issue が混在可能。

```
resolveRepository(fallback, repo_owner, repo_name):
  1. repo_owner / repo_name が null → fallback を使用
  2. DB に該当リポジトリが存在しない → fallback を使用
  3. 一致するリポジトリが存在する → そのリポジトリを使用
```

> fallback = `github_project_number` が設定されたアクティブリポジトリ

---

## ページネーション対応

**GraphQL API**（Project Items）
→ カーソルベースページネーション（`after: $cursor`）で 100件ずつ全件取得

**REST API**（Issue・Label）
→ `Link` ヘッダーを解析して全ページ自動取得（100件/ページ）

---

## 着手日目安の計算

```
開発完了目標日 = due_date − リリースバッファ日数（営業日）
着手日目安    = 開発完了目標日 − ceil(予定工数 / チーム日次工数) 営業日
```

> 営業日の計算は土日に加えて**祝日管理に登録された祝日も除外**
> DB には保存されない表示専用の値（毎回計算）

| 条件 | 結果 |
|---|---|
| `due_date` 未設定 | 非表示 |
| 予定工数が 0 | 非表示 |
| チームメンバー未登録（daily_hours 合計 = 0） | 非表示 |

---

## Epic started_at の自動設定

GitHub 同期後、以下の条件を満たすエピックに**着手日を自動設定**:

```
条件:
  1. started_at が null（未設定）
  2. 配下の Story Issue（parent_issue_id IS NULL）に
     project_status = 'In Progress' のものが1件以上ある

設定値: today()（同期実行日）
```

> `started_at` が既に設定されている場合は上書きしない

---

## マイルストーン管理

マイルストーンは **GitHub と完全に独立したアプリ独自管理**。

- `/milestones` アクセス時に `MilestoneGeneratorService` が現在月 −6〜+12ヶ月（計19ヶ月）を自動補完
- 手動作成・削除不可。タイトル・ゴール・ステータス・日付の編集のみ可能
- スプリントとの紐付けはマイルストーン詳細画面から手動設定

| フィールド | 自動計算方法 |
|---|---|
| `started_at`（デフォルト） | 月の第1月曜日 |
| `due_date`（デフォルト） | 翌月の第1月曜日の前日 |

---

## まとめ

- **GitHub OAuth** でログインし、github_token で API 同期
- **Iteration モード**（`github_project_number` 設定時）でスプリント自動同期
- **3階層**（Epic → Story → Task）でポイント＋工数を分離管理
- **マイルストーン**は GitHub 非依存のアプリ独自管理に完全移行
- **ワークログ・勤怠管理**で実績をタイムライン形式で記録
- **保護フィールド**により手動設定値が同期で失われない
- **ベロシティ**はラベル・フラグで細かく除外制御可能
