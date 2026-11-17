# pomodoro-loop

Mac で「家で1日中、集中が続く」ようにするための仕組み。固定の 25/5 ではなく、**時間帯に合わせてブロックの長さと休憩の中身を変え**、始める前に宣言し、終わったら「次の一手」をメモし、席にいないときは自動で止まり、1日の終わりに終業の儀式をします。

## Claude Code でかんたんセットアップ（非エンジニア向け）

以下のプロンプトを **丸ごとコピー → 貼り付け → 送信** してください。
clone から自動スケジュール登録までを Claude Code が誘導してくれます。

````
https://github.com/yocchan-git/pomodoro-loop を ~/pomodoro-loop にクローンして、
README.md と setup-guide.md を読んだ上で、初回セットアップを最後まで一緒に進めてください。

途中で以下を私に確認してください：
- 1日のリズム (config.sh の DAY_PROFILE) をデフォルトのままにするか、自分の生活に合わせて直すか
- 自動 start/stop の時刻 (デフォルトは 06:00 開始 / 20:30 に終業の儀式で終了 / 21:00 に安全網で停止)
- 平日のみ動かすか、毎日動かすか
- オフィス/WeWork で使う場合は、その Wi-Fi の DNS ドメイン (OFFICE_DNS_DOMAINS)

macOS の UI 操作が必要なステップ (システム設定での通知許可、集中モードの例外設定など) は、
「システム設定のどこをクリックすればいいか」を具体的に手順で教えてください。
私はターミナルでの操作と、macOS の設定画面のクリックができます。

セットアップが終わったら、TIME_SCALE=1 で 1 分を 1 秒に縮めたテストを一度回してカードが出ることを
確認してから、本番設定に戻してください。

最後に "./status.sh" を実行して、process が running になっていれば完了です。
「次の 06:00 から自動で始まります」と教えてください。
````

## 設計の考え方

| 柱 | 中身 | 根拠 |
|---|---|---|
| 時間帯でブロックを変える | 約90分の波（ウルトラディアン）と、昼食後の落ち込みに合わせ、午前は 50/10 の deep、昼食後は 25/5 の shallow、夕方にもう一度 deep、夜は運動（ジム）と夕食 | Kleitman のリズム研究、Ericsson の熟達研究、Newport『Deep Work』（深い作業は1日4時間ほどが上限） |
| 休憩は「回復する」中身 | 軽い運動、遠くを見る、ため息2回の呼吸（cyclic sighing）、目を閉じて何もしない時間などをローテーション。休憩中はスマホ・SNS・YouTube に触らない | Balban 2023、attention residue |
| 宣言とメモ | 始める前に「この枠でやること1つ」を書き、終わったら ○/△/× と「再開したら最初にやること」をメモ。次の枠の入力欄にそのメモが入る | Gollwitzer の実行意図、Leroy & Glomb 2018 |
| いないときは止まる | アイドル時間（操作がない時間）を見て、外出中は自動で一時停止。戻ったら「おかえりなさい」から再開 | ジムや WeWork の時間が日によって変わっても組み直さずに済む |
| 終業の儀式 | 終業時刻に、今日の振り返り1行と明日の朝いちばんにやることを書いて閉じる。書いた内容は翌朝の最初の枠に入る | Newport の shutdown ritual、Zeigarnik 効果 |

## 1日のリズム（デフォルト）

| 時間 | 帯 (kind) | ブロック | 中身 |
|---|---|---|---|
| 06:00 | rest | カード1枚 | バルコニー（東向き）で朝日を5〜10分 |
| 06:15〜11:30 | deep | 50分作業 / 10分休憩 ×3 → 長休憩30分 | いちばん冴えている時間に、自分にとっての最重要作業 |
| 11:30〜12:30 | rest | カード1枚 | 昼食 |
| 12:30〜15:00 | shallow | 25/5 ×4 → 長休憩20分（NSDR か20分以内の仮眠） | 食後に落ち込む時間帯。細かいタスク・事務 |
| 15:00〜18:00 | deep | 50/10 ×3 → 長休憩20分 | 1日の2つ目の山 |
| 18:00〜20:30 | rest | なし | 運動（ジム）＋夕食 |
| 20:30 | shutdown | — | 終業の儀式 → ループ終了 |

その日の deep が `DEEP_CAP_MINUTES`（デフォルト 240 分）に達すると、開始カードに「浅い作業への切り替え推奨」と出ます。

## 状態機械

`work` → `break` / `long_break` → （休憩明けに操作がなければ `away`）→ `work` …、時間帯が rest なら `rest`、`SCHEDULE_STOP_TIME` で `shutdown`。

- 時間は `sleep` の長さではなく**終了時刻（epoch）**で管理し、15 秒ごとに確認する。スリープ復帰や時間帯の切り替えに強い
- **作業開始**: 入力欄つきのカード。OK を押した時点からタイマーが始まる。120 秒ごとに音を鳴らして出し直し、その間に操作がなければ away へ
- **作業終了**: 「この枠どうだった？」(○/△/×) → 「次の一手」の入力 → 休憩へ
- **作業中に `WORK_ABANDON_IDLE_SECONDS`（デフォルト 20 分）操作がない** → その枠を「中断」として away へ
- **Zoom 会議中（画面共有中を含む）**は、カード・音・ショートカット（筋トレ動画）・URL を一切出さず、操作がなくてもアイドル扱いしない（タイマーは裏で進む）。カードの表示中に会議が始まった場合も、2秒以内にカードを閉じる（System Events を終了させて閉じる。次に使うとき自動で再起動する）。終業の儀式は会議が終わるのを待ってから出す
- `caffeinate -i` でラップしてアイドルスリープを抑止

## ログ（日次レポート用）

`~/.pomodoro/logs/YYYY-MM-DD.tsv`（タブ区切り）:

```
type  start  end  kind  label  planned_min  actual_min  intent  result  next_step  location
```

- `type`: work / break / away / shutdown
- `result`: ○ / △ / × / 中断（Zoom 中は `-`）
- break の `label` は休憩メニュー名、shutdown 行は `intent` に振り返り、`next_step` に明日の最初
- レポート機能は持たない。この TSV から awk などで集計できる

## ファイル構成

```
pomodoro-loop/
├── README.md / setup-guide.md
├── config.sh                # 設定（環境変数で上書き可）
├── pomodoro-loop.sh         # 状態機械の本体
├── lib/                     # clock / log / idle / dialog / profile / break_menu
├── start.sh / stop.sh       # 開始 / 停止
├── status.sh                # 状態・帯・残り時間・今日の work 数と deep 累計・筋トレ回数
├── toggle.sh                # ON/OFF 切替（OFF した日は自動 start しない）
├── install-schedule.sh      # 毎日 06:00 start / 21:00 stop を登録
├── uninstall-schedule.sh    # スケジュール解除
└── launchd/                 # LaunchAgent plist 雛形
```

データは `~/.pomodoro/`（`DATA_DIR`）に置く: `logs/`、`state`、`next_step`、`tomorrow_first`、`last_break`。

## 日常運用

```bash
./start.sh     # 開始
./status.sh    # 状態確認
./stop.sh      # 停止
./toggle.sh    # ON/OFF 切替（動いていれば停止、止まっていれば開始）
```

`toggle.sh` で OFF にした日は `OFF_FLAG_FILE` に日付が記録され、その日の自動 start（再起動時の RunAtLoad 含む）はスキップされる。
ショートカットアプリで「シェルスクリプトを実行」に `toggle.sh` のフルパスを入れておけば、メニューバーからワンクリックで切り替えられる。

## 自動 start/stop スケジュール

```bash
./install-schedule.sh    # 06:00 start / 21:00 stop（安全網）を毎日
./uninstall-schedule.sh  # 解除
```

通常はループが `SCHEDULE_STOP_TIME`（20:30）に終業の儀式をして自分で終わる。21:00 の stop は止まらなかったときの安全網。
時刻を変えたい場合は `launchd/*.plist` の `<integer>` と `config.sh` の `SCHEDULE_START_TIME` / `SCHEDULE_STOP_TIME` を揃えてから `install-schedule.sh` を再実行（冪等）。詳細は `setup-guide.md`。

Mac 再起動でループが死んでも、start.plist は `RunAtLoad=true` なので、ログイン直後に `start.sh --scheduled` が走り、稼働時間帯内なら復活する。

## 値を変えたい

`config.sh` を編集（または環境変数で上書き）。1日のリズムは `DAY_PROFILE` の表を書き換える:

```bash
# "HHMM-HHMM|kind|work分|break分|長休憩までの回数|長休憩分|ラベル"
DAY_PROFILE=(
  "0615-1130|deep|50|10|3|30|午前の深い作業"
  "1130-1230|rest|0|0|0|0|昼食"
  "1230-1500|shallow|25|5|4|20|午後の浅い作業"
)
```

kind は deep / shallow / light / rest。どの帯にも当たらない時刻は 25/5 の「通常」帯になる。

## テスト

実時間を待たずに確かめられる。

```bash
DATA_DIR=/tmp/pl-test TIME_SCALE=1 POLL_SECONDS=1 FAKE_NOW=1300 \
POMODORO_NO_SIDE_EFFECTS=1 POMODORO_DIALOG_MOCK=/tmp/pl-test/mock \
POMODORO_FAKE_IDLE=/tmp/pl-test/idle ./pomodoro-loop.sh
```

- `TIME_SCALE=1`: 1 分を 1 秒にする
- `FAKE_NOW=HHMM`: その時刻から始まる仮想時計（実時間 1 秒 = 仮想 `60/TIME_SCALE` 秒で進む）
- `POMODORO_DIALOG_MOCK=ファイル`: 入力を伴うダイアログ（作業開始・○△×・次の一手・終業の儀式）が 1 行ずつ回答を読む。`<CANCEL>` / `<TIMEOUT>` も使える
- `POMODORO_NO_SIDE_EFFECTS=1`: 音・ショートカット・URL を実行しない
- `POMODORO_FAKE_IDLE=ファイル`: ファイルに書いた数字をアイドル秒として使う（離席の検証用）
- `POMODORO_FAKE_ZOOM=1` / `POMODORO_FAKE_LOCATION=office`: Zoom 中・オフィスの模擬
- `DAY_PROFILE_OVERRIDE`: 改行区切りで DAY_PROFILE を差し替える

## ライセンス

[MIT License](LICENSE)。自由に使用・改変・再配布できます。

> このツールはすべてローカルで完結し、外部送信や個人情報の収集を行わないため、プライバシーポリシーはありません。
