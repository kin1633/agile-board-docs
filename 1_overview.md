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
| **ダッシュボード** | ベロシティ・バーンダウン・KPT サマリーを一覧表示 |
| **スプリント管理** | GitHub マイルストーン/Iteration からスプリントを自動作成 |
| **エピック（案件）管理** | Issue を案件単位でまとめ、工数・進捗を集計 |
| **マイルストーン** | 中長期ゴールを月次単位で管理 |
| **レトロスペクティブ** | スプリントごとの KPT（Keep/Problem/Try）を記録 |
| **GitHub 同期** | Issue・ラベル・スプリントを GitHub から自動同期 |

---

## 技術スタック

```
Backend:   PHP 8.4 / Laravel 13
Frontend:  React 19 / Inertia.js v2 / Tailwind CSS v4
DB:        SQLite（開発）/ MySQL・PostgreSQL（本番対応）
認証:       GitHub OAuth（Socialite）
ルーティング: Laravel Wayfinder（型安全な TypeScript ルート生成）
```

---

## 認証フロー

```
1. ユーザーが「GitHub でログイン」をクリック
2. GitHub OAuth → アクセストークン取得
3. users テーブルに github_id / github_token を保存
4. 以降の GitHub API 呼び出しはこの github_token を使用
```

> **重要**: `github_token` は GitHub 同期にも使われるため、
> Projects スコープが必要な場合はトークン再取得が必要

---

## データモデル概要（ER 図）

```
repositories
  └─ sprints（github_iteration_id または milestone_id）
       └─ issues（github_issue_number）
            └─ issues（parent_issue_id: Sub-issues/Tasks）

repositories
  └─ milestones（github_milestone_id または github_iteration_id）

epics
  └─ issues（epic_id: Story Issues）

labels ←→ issues（issue_labels pivot）
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
| **Epic** | 案件・大機能単位 | status, due_date, started_at |
| **Story** | スプリントに紐付く Issue | story_points, exclude_velocity |
| **Task** | Sub-issue（工数管理） | estimated_hours, actual_hours |

---

## スプリントの2モード

| | Milestone モード | Iteration モード |
|---|---|---|
| **条件** | `github_project_number` 未設定 | `github_project_number` 設定済み |
| **同期元** | GitHub REST Milestones API | GitHub Projects v2 GraphQL API |
| **スプリント識別** | `milestone_id` | `github_iteration_id` |
| **Milestone** | GitHub マイルストーン | `Monthly` Iteration フィールド |
| **後方互換** | ✅ デフォルト | — |

---

## Iteration モード詳細

GitHub Projects v2 に以下の Iteration フィールドを作成:

| フィールド名 | 用途 | 設定での変更 |
|---|---|---|
| `Sprint` | スプリント（週次） | `sprint_iteration_field` |
| `Monthly` | マイルストーン（月次） | `monthly_iteration_field` |

> フィールド名は `settings` テーブルで変更可能

---

## GitHub 同期フロー

```
POST /sync → GitHubSyncService::syncAll(githubToken)
  └─ アクティブなリポジトリ全件
      ├─ [Milestone モード] syncMilestones()
      │   └─ REST API: /repos/{owner}/{repo}/milestones
      │       └─ syncIssuesForMilestone()
      │
      ├─ [Iteration モード] syncProjectIterations()
      │   └─ GraphQL: projectV2.fields / projectV2.items
      │       ├─ [Sprint フィールド] → sprints upsert
      │       │   └─ syncIssuesForIteration()
      │       │       └─ syncSubIssues()（Sub-issues Preview API）
      │       └─ [Monthly フィールド] → milestones upsert
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
| issues | `story_points` | GitHub に存在しない |
| issues | `exclude_velocity` | アプリ独自設定 |
| issues | `estimated_hours` | ユーザー入力 |
| issues | `actual_hours` | ユーザー入力 |
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

**REST API**（Milestone・Issue・Label）
→ `Link` ヘッダーを解析して全ページ自動取得（100件/ページ）

**GraphQL API**（Project Items）
→ カーソルベースページネーション（`after: $cursor`）で100件ずつ全件取得

---

## 着手日目安の計算

```
estimated_start_date = due_date − ceil(予定工数 / チーム日次工数) 営業日
```

| 条件 | 結果 |
|---|---|
| `due_date` 未設定 | `null`（非表示） |
| 予定工数が 0 | `null`（非表示） |
| チームメンバー未登録（daily_hours 合計 = 0） | `null`（非表示） |

> チーム日次工数 = メンバー全員の `daily_hours` 合計
> DB には保存されない（毎回計算される表示専用の値）

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

## まとめ

- **GitHub OAuth** でログインし、github_token で API 同期
- **2モード**（Milestone / Iteration）で柔軟なスプリント管理
- **3階層**（Epic → Story → Task）でポイント＋工数を分離管理
- **保護フィールド**により手動設定値が同期で失われない
- **ベロシティ**はラベル・フラグで細かく除外制御可能
