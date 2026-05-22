# セットアップ手順

macOS Sonoma 以降を前提。

## 1. 状態ファイルを配置する

デフォルトはローカル (`~/.pomodoro_state.txt`)。

```bash
cp pomodoro_state.txt "${HOME}/.pomodoro_state.txt"
```

確認：

```bash
cat "${HOME}/.pomodoro_state.txt"
# → work と表示されれば OK
```

初期値は `work`（次に起動するべきフェーズ）。

> **なぜローカルがデフォルトか**：当初は iCloud Drive (`~/Library/Mobile Documents/com~apple~CloudDocs/`) に置いていたが、launchd 経由で起動された process は macOS の TCC により iCloud Drive へのアクセスがブロックされ、自動スケジュール運用が壊れることが判明したため。手動 `./start.sh` だけならターミナル経由でアクセスできる。
>
> iCloud 同期したい場合は `config.sh` の `STATE_FILE` を iCloud パスに切り替える。その場合、launchd 経由起動は失敗するので自動スケジュールとは併用不可、もしくはシェル/launchd に Full Disk Access を付与する必要がある。

## 2. スクリプトに実行権限を付ける

```bash
cd /path/to/pomodoro-loop  # clone した場所
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

## Optional: 毎日決まった時刻に自動 start / stop（推奨）

「毎朝 08:30 に走り出して、20:30 に止める」みたいな運用にしたいなら、`install-schedule.sh` を 1 回叩くだけ。

### インストール

```bash
cd /path/to/pomodoro-loop  # clone した場所
./install-schedule.sh
```

中身：

- `launchd/local.pomodoro-loop.start.plist` を `~/Library/LaunchAgents/` にコピー → `launchctl load`
- `launchd/local.pomodoro-loop.stop.plist` も同様
- 既存があれば一度 unload してから再 load（冪等）

確認：

```bash
launchctl list | grep pomodoro
# local.pomodoro-loop.start  と  local.pomodoro-loop.stop が出れば OK
```

### 時刻を変えたい

**2 箇所揃えて更新する**：

1. `launchd/local.pomodoro-loop.start.plist` と `.stop.plist` の `Hour` / `Minute`

```xml
<key>StartCalendarInterval</key>
<dict>
  <key>Hour</key>
  <integer>8</integer>       <!-- ここを変える -->
  <key>Minute</key>
  <integer>30</integer>      <!-- ここを変える -->
</dict>
```

2. `config.sh` の `SCHEDULE_START_TIME` / `SCHEDULE_STOP_TIME`（HHMM 4桁文字列、plist と一致させる）

```bash
SCHEDULE_START_TIME="0830"
SCHEDULE_STOP_TIME="2030"
```

config.sh の値は、Mac 再起動時の `RunAtLoad` 起動が稼働時間帯内かどうかの判定に使われる（後述）。
plist 側だけ変えて config.sh を放置すると、想定外の時刻に start.sh が走ってしまうので注意。

編集後、もう一度 `./install-schedule.sh`（冪等なので unload → 再 load してくれる）。

### 平日のみにしたい

`StartCalendarInterval` を **Array** にして、各曜日（`Weekday`: 1=月, 2=火, ..., 5=金）を並べる：

```xml
<key>StartCalendarInterval</key>
<array>
  <dict>
    <key>Weekday</key><integer>1</integer>
    <key>Hour</key><integer>8</integer>
    <key>Minute</key><integer>30</integer>
  </dict>
  <dict>
    <key>Weekday</key><integer>2</integer>
    <key>Hour</key><integer>8</integer>
    <key>Minute</key><integer>30</integer>
  </dict>
  <!-- 3, 4, 5 も同様 -->
</array>
```

### 解除

```bash
./uninstall-schedule.sh
```

LaunchAgent を unload して plist を消す。**現在動いている pomodoro 本体は止めない**ので、必要なら別途 `./stop.sh`。

### スケジュール側で気をつけること

- **start の二重発火** → `start.sh` は「既に running ならスキップ」する設計なので無害
- **Mac が 08:30 にスリープ中だったら？** → 標準 macOS は「次に起き上がった時に launchd が遅延発火」してくれる。確実に走らせたいなら、システム設定 → バッテリー → スケジュールで Mac を 08:25 に起こす指定もできる
- **20:30 に Pomodoro を強制停止される** → 集中作業中なら困るかも。delay したい時は `./uninstall-schedule.sh` で一時解除 → 翌朝 `./install-schedule.sh` で復帰
- **Mac 再起動でループが死ぬ** → start.plist は `RunAtLoad=true` なので、ログイン直後にも 1 回 `start.sh --scheduled` が走る。稼働時間帯内（config.sh の `SCHEDULE_START_TIME`〜`SCHEDULE_STOP_TIME`）なら自動復活、範囲外なら何もせず終了する。手動 `./start.sh`（引数なし）はガード対象外なので、いつでも起動できる

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
