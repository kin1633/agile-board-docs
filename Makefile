# agile-board-docs ビルドコマンド集
# 使い方: make <ターゲット> [FILE=<ファイル名>]

FILE ?=

.PHONY: gamma

## gamma: Gamma APIでMDファイルをスライド変換する
##   make gamma              - 全MDファイルを一括変換
##   make gamma FILE=1_overview.md - 指定ファイルのみ変換
gamma:
ifeq ($(FILE),)
	@bash scripts/gamma_generate_all.sh
else
	@bash scripts/gamma_generate.sh $(FILE)
endif
