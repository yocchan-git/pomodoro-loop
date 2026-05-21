# セットアップ手順

macOS Sonoma 以降を前提。

## 1. 状態ファイルを iCloud Drive に置く

```bash
mkdir -p "${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
cp pomodoro_state.txt "${HOME}/Library/Mobile Documents/com~apple~CloudDocs/pomodoro_state.txt"
```

**注意**：`Mobile Documents` は **半角スペースを含む**（`MobileDocuments` ではない）。
これは Apple が iCloud 系の保存場所として使う固定パス。コピペ時にスペースが消えていないか確認すること。
シェルでは必ず `"..."` で囲む（クォート無しだと `Mobile` と `Documents` が別引数として扱われて失敗する）。

確認：

```bash
cat "${HOME}/Library/Mobile Documents/com~apple~CloudDocs/pomodoro_state.txt"
# → work と表示されれば OK
```

初期値は `work`（次に起動するべきフェーズ）。

> 状態ファイルを iCloud に置かない場合は `config.sh` の `STATE_FILE` を書き換える（例：`${HOME}/.pomodoro_state.txt`）。
> iCloud 同期の race を避けたいなら local に置いた方が確実。

## 2. スクリプトに実行権限を付ける

```bash
cd ~/workspace/YoshiharuTakenaka/pomodoro-loop
chmod +x pomodoro-loop.sh start.sh stop.sh status.sh
```

## 3. 通知を許可する

初回 `./start.sh` の直後、Mac の通知センターから
**「スクリプトエディタ」**（osascript の発火元）の通知許可を ON にする。

- システム設定 → 通知 → 「スクリプトエディタ」を探す → 通知を許可
- 「通知センターに表示」「サウンドを再生」を ON 推奨

許可しないと通知が見えない（音は鳴る場合あり）。

## 4. 動作確認

短時間で挙動を確認したいなら、`config.sh` を一時的に：

```bash
WORK_MINUTES=1
BREAK_MINUTES=1
```

に変えて：

```bash
./start.sh
./status.sh
# 1分待つ → 通知が来るか確認
./stop.sh
```

確認できたら値を元に戻す。

## 5. 日常運用

```bash
./start.sh   # 作業開始
./status.sh  # 現在の状態確認
./stop.sh    # 停止
```

ターミナルを閉じてもプロセスは生き続ける（`nohup` 起動）。

---

## Optional: ログイン時に自動開始したい場合

LaunchAgent として登録すれば、Mac ログイン時に自動でループが始まる。
**ただし「明示的に始めたい」派は不要**。以下は希望者のみ。

### LaunchAgent の plist を作る

`~/Library/LaunchAgents/com.yoshiharu.pomodoro-loop.plist`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.yoshiharu.pomodoro-loop</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Users/yoshiharu/workspace/YoshiharuTakenaka/pomodoro-loop/start.sh</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/pomodoro-loop.launchd.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/pomodoro-loop.launchd.err</string>
</dict>
</plist>
```

### ロード

```bash
launchctl load ~/Library/LaunchAgents/com.yoshiharu.pomodoro-loop.plist
```

### 解除

```bash
launchctl unload ~/Library/LaunchAgents/com.yoshiharu.pomodoro-loop.plist
rm ~/Library/LaunchAgents/com.yoshiharu.pomodoro-loop.plist
```

---

## トラブルシューティング

### 通知が来ない

- システム設定 → 通知 で「スクリプトエディタ」が許可されてるか確認
- 集中モード / おやすみモード が ON だと通知は出ない（サウンドは鳴る場合あり）
- `./status.sh` でプロセスが running になっているか確認
- `tail -f /tmp/pomodoro-loop.log` でログを見る。フェーズ遷移ログが出てれば OK

### 長時間放置中にループが止まる

- アイドルスリープが原因の可能性。`caffeinate -i` でラップしているが、ディスプレイスリープと併用される設定だと不安定になることがある
- Mac のシステム設定 → バッテリー（電源アダプタ）で「ディスプレイがオフのときコンピュータを自動でスリープさせない」を ON にすると確実
- それでも止まる場合は `tail /tmp/pomodoro-loop.log` で最終遷移時刻を確認

### Mac 起動 / スリープ復帰直後に通知が遅れる

- 通知センター自体が起動中なので最初の数秒は遅延が出る。仕様
- ログには正しい時刻で記録されている

### プロセスが二重起動した気がする

- `ps aux | grep pomodoro-loop` で確認
- 余計なのを `kill <pid>` で落とす
- `./stop.sh` → `./start.sh` でやり直す

### 状態ファイルがおかしくなった

- iCloud 同期の race などで内容が壊れたら、`./stop.sh` してから：
  ```bash
  echo "work" > "${HOME}/Library/Mobile Documents/com~apple~CloudDocs/pomodoro_state.txt"
  ./start.sh
  ```
- `work` か `break` のどちらかにすればよい

### フォーカスが「会議モード」等で通知をブロックしている

- 集中モードの「許可された通知」にスクリプトエディタを追加する
- もしくは Pomodoro 中は集中モードを OFF にする
