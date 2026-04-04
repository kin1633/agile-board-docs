---
marp: true
theme: default
paginate: true
---

# agile-board 使い方ガイド

セットアップから各画面の操作手順まで — エンジニア向け

---

## 目次

1. ローカル環境構築
2. GitHub OAuth 設定
3. リポジトリ・メンバー設定
4. GitHub 同期
5. ダッシュボード
6. スプリント管理
7. エピック（案件）管理
8. マイルストーン
9. レトロスペクティブ
10. 設定

---

# セットアップ

---

## ローカル環境構築（1/2）

```bash
# 1. クローン
git clone https://github.com/your-org/agile-board.git
cd agile-board

# 2. 依存関係インストール
composer install
npm install

# 3. 環境変数設定
cp .env.example .env
php artisan key:generate
```

**必要なもの**: PHP 8.4+, Composer, Node.js 22+, npm

---

## ローカル環境構築（2/2）

```bash
# 4. DB マイグレーション
php artisan migrate

# 5. フロントエンドビルド
npm run build

# 6. 開発サーバー起動
composer run dev
```

ブラウザで `http://localhost:8000` を開き、
「GitHub でログイン」が表示されれば成功

---

## GitHub OAuth 設定

`.env` に以下を設定:

```env
APP_URL=http://localhost:8000

GITHUB_CLIENT_ID=your_client_id
GITHUB_CLIENT_SECRET=your_client_secret
GITHUB_REDIRECT_URI=http://localhost:8000/auth/github/callback
```

GitHub OAuth App の作成:
1. GitHub → Settings → Developer settings → OAuth Apps
2. Authorization callback URL = `{APP_URL}/auth/github/callback`
3. Client ID / Secret を `.env` にコピー

---

## リポジトリの追加

**URL**: `/settings/repositories`

1. 「+ リポジトリを追加」をクリック
2. **オーナー名**（例: `octocat`）と**リポジトリ名**を入力
3. 追加後、「有効にする」で `active = true` に切り替え

| 設定 | 説明 |
|---|---|
| **有効** | GitHub 同期の対象になる |
| **無効** | 同期をスキップ |
| **Project #** | GitHub Projects v2 のプロジェクト番号（Iteration モード用） |

---

## Iteration モードの有効化

GitHub Projects v2 で管理する場合:

1. `/settings/repositories` でリポジトリの `Project #` を入力
   - GitHub Projects URL の末尾の数字（例: `.../projects/5` → `5`）
2. **一度ログアウト → 再ログイン**して `project` スコープを取得
3. GitHub Projects に以下の Iteration フィールドを作成:
   - `Sprint`（週次スプリント管理）
   - `Monthly`（月次マイルストーン管理）

---

## メンバー登録

**URL**: `/settings/members`

- メンバーは **GitHub OAuth でログインした時点で自動登録**
- 手動追加・削除は不可

各メンバーの編集で設定できる項目:

| 項目 | 説明 | デフォルト |
|---|---|---|
| 表示名 | アプリ内表示名 | GitHub ログイン名 |
| 1日の稼働時間 | 工数グラフ・着手日目安の計算に使用 | 6時間/日 |

---

# GitHub 同期

---

## GitHub 同期の実行

ナビバー右上の「**GitHub 同期**」ボタンをクリック

同期内容:
- スプリント（マイルストーン or Iteration）
- Issue（Story + Task/Sub-issues）
- ラベル
- Epic の着手日自動設定

> 定期自動同期は未実装。必要に応じて手動実行

---

## よくある同期エラー

| 症状 | 原因 | 対処 |
|---|---|---|
| Projects 権限エラー | `project` スコープがない | 再ログインしてスコープ取得 |
| プライベートリポジトリが同期されない | `repo` スコープ不足 | 再ログインしてスコープ確認 |
| Sub-issues が取得できない | Sub-issues Public Preview API 未対応環境 | GraphQL-Features ヘッダーが必要（実装済み） |
| 同期は成功するが Issue が増えない | リポジトリが inactive | `/settings/repositories` で有効化 |

---

# ダッシュボード

---

## ダッシュボード概要

**URL**: `/`（アクティブなスプリントを自動選択）

4つのメトリクスカード:

| カード | 内容 |
|---|---|
| **ポイントベロシティ** | 直近スプリントの完了ポイント |
| **Issue ベロシティ** | 直近スプリントの完了 Issue 数 |
| **バーンダウン進捗** | 残ポイント / 全ポイント |
| **完了率** | closed Issue 数 / 全 Issue 数 |

---

## ダッシュボード — バーンダウンチャート

- **理想線**: `start_date` から `working_days` で等分に減少
- **実績線**: Issue の `closed_at` を使って実際の消化を描画

> バーンダウンチャートを表示するには
> スプリント詳細で `start_date` と `working_days` を設定する必要があります

---

# スプリント管理

---

## スプリント一覧

**URL**: `/sprints`

各スプリントに表示される情報:

| 項目 | 説明 |
|---|---|
| タイトル | スプリント名（GitHub マイルストーン名 or Iteration 名） |
| 状態バッジ | `open`（緑）/ `closed`（グレー） |
| 期間 | `start_date` 〜 `end_date` |
| ポイントベロシティ | closed Issue の story_points 合計 |
| Issue ベロシティ | closed Issue 件数 |

---

## スプリント詳細 — Issue タブ

**URL**: `/sprints/{id}`

各 Issue 行で設定できる項目:

| 項目 | 説明 |
|---|---|
| **story_points** | ストーリーポイント（整数）。ベロシティ計算に使用 |
| **epic 紐付け** | ドロップダウンでエピックを選択（即時保存） |
| **exclude_velocity** | チェックでこの Issue をベロシティ除外 |
| **工数（Task）** | Sub-issue の estimated_hours / actual_hours を入力 |

> story_points と exclude_velocity は GitHub 同期で上書きされない

---

## スプリント詳細 — バーンダウンタブ

バーンダウンチャートを正しく表示するための設定:

1. 「スプリント設定」から以下を入力:
   - **開始日**（`start_date`）: スプリント開始日
   - **稼働日数**（`working_days`）: 週5日などの実稼働日数
2. 「保存」でチャートが更新される

> これらは GitHub 同期で上書きされないので一度設定すれば OK

---

## スプリント詳細 — 担当者タブ

担当者別の工数内訳を確認できます:

- **予定工数（estimated_hours）** 対 **実績工数（actual_hours）** の比較
- Task（Sub-issue）の `assignee_login` で集計
- メンバーの `daily_hours` を基準に人日換算も表示

---

# エピック（案件）管理

---

## エピック一覧

**URL**: `/epics`

各エピックに表示される情報:

| 項目 | 説明 |
|---|---|
| ステータスバッジ | 計画中 / 進行中 / 完了 |
| リリース予定日 + 残り日数 | 残り日数に応じて色変化 |
| 着手日目安（青） | due_date から逆算した目安（自動計算） |
| 着手日（緑） | 実際の着手日（手動 or 同期時自動設定） |
| 進捗バー | closed / 全 Issue 数 % |
| 実績 / 予定（h） | Task 工数の集計値 |
| 推定スプリント数 | 残ポイント ÷ 平均ベロシティ |

---

## エピックの作成・編集

「+ 新規エピック（案件）」ボタンから作成:

| 項目 | 必須 | 説明 |
|---|---|---|
| タイトル | ✅ | エピック名 |
| 説明 | — | 概要・目的 |
| ステータス | ✅ | 計画中 / 進行中 / 完了 |
| 優先度 | ✅ | 高 / 中 / 低 |
| リリース予定日 | — | `YYYY-MM-DD` |
| 着手日 | — | 手動設定（同期でも自動設定される） |

---

## Issue とエピックの紐付け

GitHub 同期では紐付けは**行われない**。UI から手動で設定:

1. `/sprints/{id}` の Issue タブを開く
2. 紐付けたい Issue 行のエピック列ドロップダウンをクリック
3. 一覧からエピックを選択 → 即時保存
4. 解除したい場合は「案件なし」を選択

---

## 工数 CSV エクスポート

**URL**: `GET /epics/export?from=YYYY-MM-DD&to=YYYY-MM-DD`

1. エピック一覧右上で集計期間を入力（デフォルト: 当月）
2. 「CSV エクスポート」ボタンをクリック

CSV フォーマット:
```
案件名,担当者,予定工数(h),実績工数(h),予定工数(人日),実績工数(人日)
案件A,alice,10,8,1.43,1.14
```

> 期間フィルタ: Task の `closed_at` が指定期間内のもののみ集計

---

# マイルストーン

---

## マイルストーン一覧

**URL**: `/milestones`

リポジトリごとにグループ表示:

| 項目 | 説明 |
|---|---|
| タイトル | マイルストーン名 |
| 期限 | `due_on`（Iteration モードは startDate + duration - 1日 で自動計算） |
| ステータス | open（緑）/ closed（グレー） |

ヘッダーの「Project #N」バッジは Iteration モードのリポジトリに表示。
GitHub Projects または GitHub Milestones へのリンクも表示。

---

# レトロスペクティブ

---

## KPT ボード

**URL**: `/retrospectives`

スプリント選択 → KPT を追加・管理:

| 種別 | 色 | 内容 |
|---|---|---|
| **Keep** | 緑 | うまくいっていること・継続したいこと |
| **Problem** | 赤 | 問題・課題・改善が必要なこと |
| **Try** | 青 | 次のスプリントで試すこと |

- カード単位で**インライン編集**と**削除**が可能
- 過去のスプリントもドロップダウンで選択して参照可能

---

# 設定

---

## 一般設定

**URL**: `/settings/general`

| 設定項目 | 説明 | デフォルト |
|---|---|---|
| 外観 | ライト / ダーク / システム連動 | システム |
| 1人日の基準時間 | 工数（h）→ 人日換算の基準 | 7時間 |

外観はボタン選択後即時反映。
1人日の基準時間は「保存」ボタンで確定。

---

## ラベル管理

**URL**: `/settings/labels`

GitHub 同期後にラベル一覧が表示される。
各ラベルのトグルで `exclude_velocity` を設定:

| 状態 | 説明 |
|---|---|
| **オン（管理対象）** | 通常通りベロシティに含まれる |
| **オフ（除外）** | このラベルが付いた Issue はベロシティ除外 |

活用例: `spike`, `tech-debt`, `管理` などの非開発 Issue を除外して
実際の開発速度を正確に計測

---

## その他の設定

| ページ | URL | 概要 |
|---|---|---|
| プロフィール | `/settings/profile` | 名前・メールアドレスの変更 |
| セキュリティ | `/settings/security` | パスワード変更 |

> このアプリは GitHub OAuth 認証を主とするため、
> パスワードは補助的なものです。2FA はサポートしていません。

---

## まとめ

```
セットアップ → リポジトリ追加 → GitHub 同期
  → スプリントに story_points 入力
  → Issue をエピックに紐付け
  → Task に工数入力
  → バーンダウンで進捗確認
  → レトロスペクティブで振り返り
  → CSV エクスポートでクライアント報告
```

**週次フロー**: 同期 → ポイント更新 → バーンダウン確認 → KPT 記録
