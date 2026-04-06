# agile-board スライド同期

agile-board の最新ドキュメント・コードを読み込み、このリポジトリの `1_overview.md` と `2_usage.md` を最新状態に更新します。

## 手順

### 1. ソースを読み込む

以下のファイルを全て読み込んでください：

**設計ドキュメント**
- `/Users/yuya/dev/agile-board/docs/design/architecture.md`
- `/Users/yuya/dev/agile-board/docs/design/data-model.md`
- `/Users/yuya/dev/agile-board/docs/design/sync-flow.md`

**使い方ドキュメント**
- `/Users/yuya/dev/agile-board/docs/usage/dashboard.md`
- `/Users/yuya/dev/agile-board/docs/usage/sprints.md`
- `/Users/yuya/dev/agile-board/docs/usage/milestones.md`
- `/Users/yuya/dev/agile-board/docs/usage/epics.md`
- `/Users/yuya/dev/agile-board/docs/usage/retrospectives.md`
- `/Users/yuya/dev/agile-board/docs/usage/work-logs.md`
- `/Users/yuya/dev/agile-board/docs/usage/attendance.md`
- `/Users/yuya/dev/agile-board/docs/usage/settings.md`

**セットアップドキュメント**
- `/Users/yuya/dev/agile-board/docs/setup/getting-started.md` （存在する場合）
- `/Users/yuya/dev/agile-board/docs/setup/github-setup.md` （存在する場合）

**コード（ドキュメントに記載がない情報の補完用）**
- `/Users/yuya/dev/agile-board/docs/README.md`

### 2. 現状のスライドを読み込む

- `/Users/yuya/dev/agile-board-docs/1_overview.md`
- `/Users/yuya/dev/agile-board-docs/2_usage.md`

### 3. 差分を分析する

ソースと現在のスライドを比較し、以下の点を確認してください：

- 技術スタックのバージョン変更
- 削除・変更された機能
- 新規追加された機能（work-logs、attendance など）
- データモデルの変更（カラム追加・削除・意味の変化）
- 同期フローの変更
- 設定項目の追加・変更

### 4. スライドを更新する

以下のルールに従って `1_overview.md` と `2_usage.md` を書き換えてください。

**Marp frontmatter は変更しない：**
```yaml
---
marp: true
theme: default
paginate: true
---
```

**スライド構成の方針：**

`1_overview.md`（基本概念・設計向け）に含める内容：
- このアプリでできること（機能一覧）
- 技術スタック
- 認証フロー
- データモデル概要（ER図）
- Issue の階層構造
- スプリント同期モードの説明
- GitHub 同期フロー
- 同期で保護される値
- ベロシティ計算ロジック
- マルチリポジトリ対応
- ページネーション対応
- 着手日目安の計算
- Epic started_at の自動設定
- まとめ

`2_usage.md`（操作ガイド向け）に含める内容：
- ローカル環境構築
- GitHub OAuth 設定
- リポジトリの追加
- Iteration モードの有効化
- メンバー登録
- GitHub 同期の実行
- よくある同期エラー
- ダッシュボード
- スプリント管理（一覧・詳細・バーンダウン・担当者）
- エピック管理（一覧・作成・紐付け・CSV エクスポート）
- マイルストーン
- レトロスペクティブ
- 実績入力（ワークログ）※ 新機能
- 勤怠管理 ※ 新機能
- 設定（一般・リポジトリ・メンバー・ラベル・実績種別・祝日）
- まとめ

**スライドの品質基準：**
- 1スライドあたりの情報量は読みやすい量に抑える
- 表・コードブロック・箇条書きを適切に使い分ける
- 各セクションの区切りは `---` で明示する
- 削除された機能（例：Milestone モード同期）はスライドからも削除する
- 新機能は漏れなく追加する
- バージョン番号・URL・カラム名等は必ずソースの情報で上書きする

### 5. 更新完了後に報告する

更新したスライドの変更点を箇条書きで簡潔に報告してください：
- 追加したスライド・セクション
- 削除したスライド・セクション
- 修正した内容（バージョン、仕様変更など）
