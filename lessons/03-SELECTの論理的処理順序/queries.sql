CREATE TABLE employees (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50),
    dept_id INT,
    salary INT,
    status VARCHAR(20)
);

INSERT INTO employees (name, dept_id, salary, status) VALUES
('Alice', 1, 500000, 'active'),
('Bob',   1, 420000, 'active'),
('Carol', 1, 600000, 'retired'),
('Dave',  2, 380000, 'active'),
('Eve',   2, 410000, 'active'),
('Frank', 2, 390000, 'active'),
('Grace', 3, 700000, 'active'),
('Heidi', 3, 650000, 'active');

-- WHERE で SELECT 句の別名 cnt は参照できずエラー
SELECT dept_id, COUNT(*) AS cnt
FROM employees
WHERE cnt > 5
GROUP BY dept_id;

-- ORDER BY では別名を参照できる
SELECT dept_id, COUNT(*) AS cnt
FROM employees
GROUP BY dept_id
ORDER BY cnt DESC;

-- HAVING でも別名を参照できる（MySQL の拡張）
SELECT dept_id, COUNT(*) AS cnt
FROM employees
GROUP BY dept_id
HAVING cnt > 2;
