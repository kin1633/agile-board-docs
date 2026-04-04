# agile-board スライド資料

agile-board アプリケーションの設計概念・使い方をエンジニア向けにまとめた Marp スライド集です。

## ファイル構成

| ファイル | 内容 |
|---|---|
| `1_overview.md` | 基本概念（データモデル・同期フロー・ベロシティ計算など） |
| `2_usage.md` | 詳細な使い方（セットアップから各画面の操作手順まで） |

## ビルド方法

### HTML 出力

```bash
npx @marp-team/marp-cli 1_overview.md --html -o dist/1_overview.html
npx @marp-team/marp-cli 2_usage.md --html -o dist/2_usage.html
```

### PPTX 出力

```bash
npx @marp-team/marp-cli 1_overview.md --pptx -o dist/1_overview.pptx
npx @marp-team/marp-cli 2_usage.md --pptx -o dist/2_usage.pptx
```

### ライブプレビュー（VS Code Marp 拡張推奨）

VS Code に [Marp for VS Code](https://marketplace.visualstudio.com/items?itemName=marp-team.marp-vscode) をインストールして `.md` ファイルを開くとプレビューできます。

CLI でのウォッチモード:

```bash
npx @marp-team/marp-cli --watch 1_overview.md --html
```

## 対象読者

エンジニア（開発者・運用担当者）

## Gamma API生成

Marp MD ファイルを [Gamma](https://gamma.app/) API でスライドに変換します。

### 前提条件

- Gamma の **Pro プラン以上**のアカウントが必要です
- APIキーの取得: [https://gamma.app/developers](https://gamma.app/developers)

### 環境変数の設定

```bash
cp .env.example .env
# .env を開いて GAMMA_API_KEY= の後ろに取得したAPIキーを記入
```

任意: テーマを指定する場合は `GAMMA_THEME_ID=<テーマID>` も追記してください。

### 実行コマンド

```bash
# 全MDファイルを一括変換
make gamma

# 指定ファイルのみ変換
make gamma FILE=1_overview.md
make gamma FILE=2_usage.md
```

### 出力

- 変換完了後、ターミナルに **Gamma URL** と **PPTXダウンロードURL** が表示されます
- 生成されたURLは `dist/gamma_urls.txt` に日時付きで追記保存されます
