CREATE DATABASE IF NOT EXISTS test;
DROP TABLE IF EXISTS test.companies;
CREATE TABLE test.companies (
    id INT AUTO_INCREMENT PRIMARY KEY,
    doc JSON,
    valuation INT GENERATED ALWAYS AS (doc->"$.valuation"),
    INDEX valuation_idx (valuation)
)  ENGINE=InnoDB;
