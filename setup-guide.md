# セットアップ手順

macOS Sonoma 以降を前提。

## 1. データ置き場

データは `~/.pomodoro/`（`config.sh` の `DATA_DIR`）に自動で作られる（`./start.sh` が `logs/` を用意する）。手動の準備は不要。

> **なぜローカルか**：iCloud Drive に置くと、launchd 経由で起動された process は macOS の TCC によりアクセスをブロックされ、自動スケジュール運用が壊れるため。

## 2. スクリプトに実行権限を付ける

```bash
cd /path/to/pomodoro-loop  # clone した場所
chmod +x *.sh
```

## 3. 通知を許可する

初回 `./start.sh` の直後、Mac の通知センターから
**「スクリプトエディタ」**（osascript の発火元）の通知許可を ON にする。

- システム設定 → 通知 → 「スクリプトエディタ」を探す → 通知を許可
- 「通知センターに表示」「サウンドを再生」を ON 推奨

許可しないと通知が見えない（音は鳴る場合あり）。

## 4. 動作確認

実時間を待たずに、1 分を 1 秒に縮めて試せる（本番設定は変えない）。

```bash
TIME_SCALE=1 POLL_SECONDS=1 FAKE_NOW=0700 ./pomodoro-loop.sh
```

作業開始カードに「やること」を入れて OK → 50 秒後に ○/△/× と次の一手 → 休憩カード、と進む。Ctrl-C で止める。
確認できたら、通常の `./start.sh` で本番を始める。

## 5. 日常運用

```bash
./start.sh   # 開始
./status.sh  # 状態・帯・残り時間・今日の集計
./stop.sh    # 停止
```

ターミナルを閉じてもプロセスは生き続ける（`nohup` 起動）。

---

## Optional: 毎日決まった時刻に自動 start / stop（推奨）

「毎日 06:00 に走り出して、20:30 に終業の儀式で終わる」運用にしたいなら、`install-schedule.sh` を 1 回叩くだけ。

### インストール

```bash
cd /path/to/pomodoro-loop  # clone した場所
./install-schedule.sh
```

中身：

- `launchd/local.pomodoro-loop.start.plist` を `~/Library/LaunchAgents/` にコピー → `launchctl load`
- `launchd/local.pomodoro-loop.stop.plist` も同様（21:00 の安全網。通常はループが 20:30 に自分で終わる）
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
  <integer>6</integer>       <!-- ここを変える -->
  <key>Minute</key>
  <integer>0</integer>       <!-- ここを変える -->
</dict>
```

2. `config.sh` の `SCHEDULE_START_TIME` / `SCHEDULE_STOP_TIME`（HHMM 4桁文字列、plist と一致させる）

```bash
SCHEDULE_START_TIME="0600"
SCHEDULE_STOP_TIME="2030"   # この時刻に終業の儀式 → ループ終了。stop.plist はこの少し後に
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
- **Mac が 06:00 にスリープ中だったら？** → 標準 macOS は「次に起き上がった時に launchd が遅延発火」してくれる。確実に走らせたいなら、システム設定 → バッテリー → スケジュールで Mac を 05:55 に起こす指定もできる
- **20:30 に終業の儀式で終わる / 21:00 に安全網で停止** → 続けたい時は `./toggle.sh` で再開（時間帯外でも手動起動できる）。その日は止めたい時も `./toggle.sh` で OFF
- **Mac 再起動でループが死ぬ** → start.plist は `RunAtLoad=true` なので、ログイン直後にも 1 回 `start.sh --scheduled` が走る。稼働時間帯内（config.sh の `SCHEDULE_START_TIME`〜`SCHEDULE_STOP_TIME`）なら自動復活、範囲外なら何もせず終了する。手動 `./start.sh`（引数なし）はガード対象外なので、いつでも起動できる

---

## トラブルシューティング

### 通知が来ない

- システム設定 → 通知 で「スクリプトエディタ」が許可されてるか確認
- 集中モード / おやすみモード が ON だと通知は出ない（サウンドは鳴る場合あり）
- `./status.sh` でプロセスが running になっているか確認
- `tail -f /tmp/pomodoro-loop.log` でログを見る。遷移ログが出てれば OK

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

### 状態がおかしくなった

- `./stop.sh` してから `rm ~/.pomodoro/state` で状態を消し、`./start.sh` でやり直す（ログ `~/.pomodoro/logs/` は消えない）

### 外出中になったまま戻らない / 勝手に外出中になる

- アイドル時間（最後の操作からの秒数）で判定している。`AWAY_IDLE_SECONDS`（休憩明け、デフォルト 300 秒）と `WORK_ABANDON_IDLE_SECONDS`（作業中、デフォルト 1200 秒）を `config.sh` で調整する
- Zoom 会議中は操作がなくてもアイドル扱いしない

### フォーカスが「会議モード」等で通知をブロックしている

- 集中モードの「許可された通知」にスクリプトエディタを追加する
- もしくは Pomodoro 中は集中モードを OFF にする

---

## Optional: 集中モード・オフィス判定・NSDR

`config.sh` で次を設定すると連携できる（すべて空なら何もしない）。

- **集中モードの ON/OFF**: ショートカットアプリで「集中モードをオンにする」「オフにする」を作り、`WORK_START_SHORTCUT="作業開始"` / `BREAK_START_SHORTCUT="休憩開始"` にその名前を入れる。作業開始カードの OK で ON、休憩開始で OFF になる
- **オフィス / WeWork の自動判定**: `OFFICE_DNS_DOMAINS="example.com"`（空白区切り）。`scutil --dns` の `search domain[0]` と一致したら office モードになり、筋トレ動画とバルコニー系のメニューを外す。ドメインは `scutil --dns | grep 'search domain\[0\]'` で確認できる。公開したくない値は、同じフォルダの `config.local.sh`（.gitignore 済み）に書けば config.sh の後に読み込まれる
- **NSDR 音声**: `NSDR_URL="https://..."`。午後の浅い帯の長休憩で開く。空なら文章で案内するだけ
- **筋トレ動画**: `TRAINING_SHORTCUT`（ショートカット名）、`TRAINING_MAX_PER_DAY`（1日の上限）、`TRAINING_WINDOW`（出す時間帯）。短い休憩にだけ、条件を満たすときだけ出る
