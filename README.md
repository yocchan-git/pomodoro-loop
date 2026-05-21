# pomodoro-loop

Mac で 25分作業 → 5分休憩 → ... を自動ループする仕組み。

## Claude Code でかんたんセットアップ（非エンジニア向け）

以下のプロンプトを **丸ごとコピー → 貼り付け → 送信** してください。
clone から自動スケジュール登録までを Claude Code が誘導してくれます。

````
https://github.com/yocchan-git/pomodoro-loop を ~/pomodoro-loop にクローンして、
README.md と setup-guide.md を読んだ上で、初回セットアップを最後まで一緒に進めてください。

途中で以下を私に確認してください：
- 状態ファイルを iCloud Drive に置くか、Mac 内のローカル (~/.pomodoro_state.txt) に置くか
- 自動 start/stop の時刻 (デフォルトは 08:30 開始 / 20:30 停止)
- 平日のみ動かすか、毎日動かすか

macOS の UI 操作が必要なステップ (システム設定での通知許可、集中モードの例外設定など) は、
「システム設定のどこをクリックすればいいか」を具体的に手順で教えてください。
私はターミナルでの操作と、macOS の設定画面のクリックができます。

セットアップが終わったら、短時間 (1分/1分) のテストを一度回して通知が来ることを
確認してから、本番設定 (25/5) に戻してください。

最後に "./status.sh" を実行して、process が表示され state が "work" になっていれば完了です。
「明日 08:30 から自動で始まります」と教えてください。
````

> このプロンプト 1 回で、ターミナルで `git clone` → スクリプト実行権限付与 → 通知許可ガイド → 動作テスト → 自動スケジュール登録 まで完了します。手順を覚える必要はありません。

## 仕組み（採用方式）

当初は「macOS Shortcuts の『タイマー終了』オートメーション + 状態ファイル」を想定したが、
**macOS Shortcuts には『タイマー終了』トリガーが存在しない**（iOS にもない）ことが調査で判明。

そのため、以下の構成で実装する：

- **永続シェルプロセス** が `sleep` で 25分 / 5分を回す
- 各フェーズ終了時に **`osascript` で通知**（サウンド付き）
- 現在フェーズ（`work` / `break`）を **iCloud Drive 上の状態ファイル**に書き出す
  - プロセスが死んだ場合の再開ヒント + 他デバイスからの観測用
- `caffeinate -i` でラップして **アイドルスリープ抑止**
- 起動 / 停止 / 状態確認は `start.sh` / `stop.sh` / `status.sh`

ショートカットアプリは使わない。Mac 標準 + bash のみ。

## ファイル構成

```
pomodoro-loop/
├── README.md                # この文書
├── setup-guide.md           # 初回セットアップ手順
├── config.sh                # 値の調整（時間・サウンド・パス）
├── pomodoro-loop.sh         # メインループ本体
├── start.sh                 # ループ開始
├── stop.sh                  # ループ停止
├── status.sh                # 現在状態の確認
├── install-schedule.sh      # 毎日 08:30/20:30 の自動 start/stop を登録
├── uninstall-schedule.sh    # スケジュール解除
├── launchd/                 # LaunchAgent plist 雛形（時刻はここで調整）
└── pomodoro_state.txt       # 状態ファイルの雛形（初期値 "work"）
```

state ファイルの実体は `~/Library/Mobile Documents/com~apple~CloudDocs/pomodoro_state.txt`（iCloud Drive）に置く。

## 日常運用

```bash
# 作業開始（ループ in）
./start.sh

# 状態確認
./status.sh

# ループ停止
./stop.sh
```

初回起動時に状態ファイルが無ければ `work` で初期化される。

## 自動 start/stop スケジュール（推奨）

毎日決まった時刻に勝手に start / stop させる場合：

```bash
./install-schedule.sh    # 08:30 start / 20:30 stop を毎日
./uninstall-schedule.sh  # 解除
```

時刻を変えたい場合は `launchd/*.plist` の `<integer>` を編集してから `install-schedule.sh` を再実行（冪等）。
平日のみにしたい場合は plist の `StartCalendarInterval` を Array にして `Weekday` を 1..5 で並べる。詳細は `setup-guide.md` 参照。

## 値を変えたい

`config.sh` を編集。例：30分 / 10分に変えたいなら：

```bash
WORK_MINUTES=30
BREAK_MINUTES=10
```

通知サウンドは macOS 標準（`/System/Library/Sounds/*.aiff`）から選ぶ。

## セットアップ手順

`setup-guide.md` を参照。
