# who is on?

プログラミングの勉強をもう一年したい学生のためのプロジェクト。
研究室出場記録を取る Racket プログラム。
もうちょっと具体的には、
WiFi機器（ケータイ電話を想定している）を持った誰がいつローカルネットに接続したかを記録する。

* who-is-on-update.rkt は、ARP テーブルに見つかる MAC アドレスをデータベースに記録する。

* who-is-on-app.rkt は指定したユーザの MAC アドレスが記録れた日時を求めに応じて表示する。

## thanks

dmac/spin https://github.com/dmac/spin

of cource Racket, Linux, ubuntu, GNU projects.

## MAC アドレスの取得

ICMP ブロードキャストに反応しないホストもあるため、
サブネットの有効なアドレス一つ一つにタイムアウト付き ping を打つ。

ping を直列に実行してはタイムアウト時間 x サブネットの数だけ時間がかかってしまう。

ping を並列に実行する関数は Racket でどう定義できるか？

## 定期実行

プログラム自体でゆっくりループするか、cron で。

cron は linux/unix の基本的機能の一つ。

## 取得した Mac アドレスの記録

SQLite3 にタイムスタンプと共に記録する。

* Racket でデータベースを扱う具体的な方法

* SQL できますか？

## 出場記録の表示

Racket の web フレームワーク dmac/spin で web アプリを作成する。

このアプリではデータベースの書き換えを行わない。
エンドポイントは全て GET メソッドとなる。

* /users

  ユーザ一覧の表示とユーザ名から記録へのリンク。

* /user/name/yyyy-mm-dd

  ユーザ name の yyyy-mm-dd の記録。

* /user/name

  ユーザ name の記録を表示。

## Web アプリのデプロイ

流行りは nginx のリバースプロキシだろう。
それってどうやるの？

勉強できたか？

---
hiroshi.kimura.0331@gmail.com
