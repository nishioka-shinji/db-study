# 第01章 環境構築と RDBMS の全体像

- 実施日: 2026-09-05
- 所要: 1セッション

## 学んだこと
- MySQL はクライアント層 → SQL層(パース/オプティマイザ/実行器) → ストレージエンジン層 の3層構造で、
  SQL層は全エンジン共通、ストレージエンジン層だけが差し替え可能(PostgreSQL/Oracle との大きな違い)。
- `SHOW ENGINES;` で確認できる通り、InnoDB だけが `Support: DEFAULT` かつ `Transactions: YES`。
- トランザクションのロールバックは MyISAM では効かない(非トランザクションエンジンのため)。
  一方 UNIQUE 制約自体はトランザクションの有無と無関係に機能する(誤解しやすい点)。
- 本編でほぼ常に InnoDB を前提にするのは、ロールバックによる整合性保証と外部キー制約が
  実務上ほぼ必須だから。
- `SHOW ENGINES;` は `INFORMATION_SCHEMA.ENGINES` を見ており、ディスク上のデータではなく
  「サーバにロードされているストレージエンジンのプラグイン一覧」を返す。
- CSV エンジンはテーブルの実体がそのまま `.CSV` ファイル(NOT NULL 列のみ許可)。
  ただし行数などのメタデータは別ファイル `.CSM` で管理しており、MySQL を経由せず
  `.CSV` を直接書き換えても `SELECT` には反映されない。`REPAIR TABLE` で同期される。

## 手を動かしたこと
```sql
SELECT VERSION();
SHOW ENGINES;

CREATE TABLE t_innodb (id INT PRIMARY KEY) ENGINE=InnoDB;
CREATE TABLE t_myisam (id INT PRIMARY KEY) ENGINE=MyISAM;

START TRANSACTION;
INSERT INTO t_innodb VALUES (1);
ROLLBACK;
SELECT * FROM t_innodb;   -- 空 (ロールバックされた)

START TRANSACTION;
INSERT INTO t_myisam VALUES (1);
ROLLBACK;
SELECT * FROM t_myisam;   -- 1件残る (ロールバックされない)
SHOW WARNINGS;            -- Some non-transactional changed tables couldn't be rolled back

DROP TABLE t_innodb, t_myisam;

-- CSV エンジンの実験
CREATE TABLE t_csv (id INT NOT NULL, name VARCHAR(10) NOT NULL) ENGINE=CSV;
INSERT INTO t_csv VALUES (1, 'alice'), (2, 'bob');
SELECT * FROM t_csv;
-- コンテナ内で直接 .CSV に1行 追記 (3,"carol") しても SELECT には反映されない
REPAIR TABLE t_csv;   -- .CSM (メタデータ) を同期
SELECT * FROM t_csv;  -- ここで carol が見える
DROP TABLE t_csv;
```

## 図

```mermaid
flowchart TB
    client["クライアント\n(mysql cli / アプリのDBドライバ)"]
    subgraph server["MySQL Server (mysqld)"]
        conn["接続層\n認証・スレッド割当"]
        sql["SQL層\nパーサ → オプティマイザ → 実行器\n(全ストレージエンジン共通)"]
        engine["ストレージエンジン層\nInnoDB / MyISAM など\n(差し替え可能)"]
        conn --> sql --> engine
    end
    disk["ディスク上のファイル\n(データ, ログ)"]

    client -->|TCP/ソケット| conn
    engine --> disk
```

## つまずき / 誤解した点
- 「トランザクションがないと UNIQUE 制約(一意性)が保証できない」と誤解した。
  実際は UNIQUE/PRIMARY KEY はトランザクションと無関係に機能する。
  MyISAM が実務で困る本当の理由は「ロールバック不可」と「外部キー制約が使えない」の2点。
- CSV エンジンで `SELECT` の中身を「ファイルを直接見てるだけ」と早合点した。
  正しくは `.CSV`(データ)と `.CSM`(メタデータ)の2ファイル構成で、外部からの直接編集は
  メタデータとズレるため反映されない。

## 覚えておくコマンド・構文
- `SHOW ENGINES;` — 利用可能なストレージエンジンと特性(Transactions/XA/Savepoints)を確認
- `SHOW WARNINGS;` — 直前の1文の警告を確認(直後に打たないと消える)
- `CREATE TABLE ... ENGINE=xxx;` — テーブル単位でストレージエンジンを指定

## 次への宿題
- InnoDB の内部構造(ページ/バッファプール/REDO・UNDO)は第10章で深掘り。
