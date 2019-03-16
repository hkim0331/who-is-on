# who is on?

プログラミングの勉強をもう一年したい学生のためのお手本プロジェクト。

研究室出場記録を取る Racket プログラム。
もうちょっと具体的には、
WiFi機器（ケータイ電話を想定している）を持った誰がいつローカルネットに接続したかを記録する。

* who-is-on-update.rkt は、ARP テーブルに見つかる MAC アドレスをデータベースに記録する。

* update.sh は who-is-on-update.rkt を定期的に呼びだす。

* who-is-on-app.rkt は指定したユーザの MAC アドレスが記録れた日時を求めに応じて表示する。

### requirement

開発は macos, linuxmint 19.

* racket

```sh
# apt install racket
```

* dmac/spin pkg

```sh
$ raco pkg install https://github.com/dmac/spin.git
```

### FIXME/TODO

* macos の at コマンド

  at: pluralization is wrong
  at: cannot open lockfile /usr/lib/cron/jobs/.lockfile: Operation not permitted

* query-exec の回数を減らす。
  -> 1時間に一度実行するくらいの頻度で呼ぶ関数。血眼にならないでよい。

* nginx リバースプロキシーの設定方法
  名前ベースの仮想ホストは C104 での運用には適当ではない。
  パスベースでlocalhost:8000 へ振るんだが、

    * localhost の名前が使えないホストがある。

    * プロキシがつながらなくなる。sites-enable からのリンクでやった場合。

### FIXED

* app installer、url の書き換え、DB を上書きyes・noオプション
  => make install で。

* query-exec の回数を減らす。
  -> 1時間に一度実行するくらいの頻度で呼ぶ関数。血眼にならないでよい。

* app installer、url の書き換え、DB を上書きyes・noオプション

* install の sed ができない。
  => エスケープじゃなく、セパレータを換える作戦で。

* 2019-03-14 10 分おきに cron から起こすとして、確率 1/3 で実行するのは？
  => アラウンド 60 分後に実行するにしよう。0.5.4.

* 2019-03-14 macos の /usr/sbin/arp では 00 を 0 に短縮して表示する。
  string= で比較できない。mac= を定義するとしても、SQLite3 に組み込むのは面倒だ。
  0.5.3.3.

### MAC アドレスの取得

ICMP ブロードキャストに反応しないホストもあるため、
サブネットの有効なアドレス 10.0.33.1..254 の一つ一つにタイムアウト付き ping を打つ。

ping を直列に実行しては
（タイムアウト時間） x （サブネットの数）
だけ時間がかかってしまう。

ping を並列に実行する関数を Racket でどう定義するかが問題。

### 定期実行

プログラム自体でゆっくりループするか、cron で、
と思ったが、at コマンド で自分自身を 55〜65 分後に呼び出す方法に変更。0.5.4

cron, at は linux/unix の基本的機能の一つ。

### 取得した Mac アドレスの記録

SQLite3 にタイムスタンプと共に記録する。

* SQL できるようになれ。

* Racket でデータベースを扱う具体的な方法を身につけろ。

### 出場記録の表示

Racket の web フレームワーク dmac/spin で web アプリを作成する。

* get /users

  ユーザ一覧の表示とユーザ名から記録へのリンク。

* get /user/name/yyyy-mm-dd

  ユーザ name の yyyy-mm-dd の記録。

* get /user/name

  ユーザ name の記録を表示。

* get /users/new, post /users/create

  ユーザを追加する。

ユーザの削除は 0.5.3 では定義していない。

### Web アプリのデプロイ

流行りは nginx のリバースプロキシだろう。
それってどうやるか、わかるかい？

_勉強できたか？_

---
hiroshi.kimura.0331@gmail.com
