-- 第02章 データ型とテーブル定義

CREATE TABLE emoji_test (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(50) CHARACTER SET utf8
);

-- 端末から絵文字を直接ペーストできなかったため、UTF-8バイト列を直接指定して検証
INSERT INTO emoji_test (name) VALUES (CONVERT(UNHEX('F09F9880') USING utf8mb4));
SHOW WARNINGS;
-- Error 1366 Incorrect string value: '\xF0\x9F\x98\x80' for column 'name' at row 1
-- (non-strictモードのため INSERT 自体は成功し、値は空文字になる)

SELECT id, HEX(name), LENGTH(name), CHAR_LENGTH(name) FROM emoji_test;

-- 照合順序(collation)の確認
SHOW TABLE STATUS FROM studydb;   -- Collation: utf8mb4_0900_ai_ci

INSERT INTO emoji_test (name) VALUES ('ABC'), ('abc');
SELECT * FROM emoji_test WHERE name = 'abc';
-- 'ABC' と 'abc' の両方がヒット (ai_ci = 大文字小文字を区別しない)

DROP TABLE emoji_test;
