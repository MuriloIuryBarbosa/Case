-- =====================================================================
-- SCHEMA, TABELA DE RESULTADOS, PROCEDURE DE CHECKS E VIEW DE RESUMO
-- Ambiente: MySQL 8.x
-- Schema de trabalho: `Case`
-- Tabela fonte: `Case`.`GA4_GTM`
-- =====================================================================

-- (1) Tabela de resultados dos checks
CREATE TABLE IF NOT EXISTS `Case`.`QA_RESULTS` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `run_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `check_name` VARCHAR(100) NOT NULL,
  `description` VARCHAR(500) NOT NULL,
  `severity` ENUM('LOW','MEDIUM','HIGH') NOT NULL,
  `threshold_violations` INT NOT NULL DEFAULT 0,   -- máximo tolerado de violações
  `violations` INT NOT NULL DEFAULT 0,             -- violações encontradas
  `status` ENUM('PASS','FAIL') NOT NULL,
  `sample_json` JSON NULL,                         -- amostra de linhas (até 5)
  PRIMARY KEY (`id`),
  INDEX `idx_run_at` (`run_at`),
  INDEX `idx_check_name` (`check_name`)
) ENGINE=InnoDB
DEFAULT CHARSET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;

-- (2) Procedure que roda todos os checks e registra na QA_RESULTS
DROP PROCEDURE IF EXISTS `Case`.`sp_run_quality_checks`;
DELIMITER $$
CREATE PROCEDURE `Case`.`sp_run_quality_checks`()
BEGIN
  DECLARE v_now TIMESTAMP DEFAULT NOW();

  -- Opcional: limpar execuções antigas do dia
  -- DELETE FROM `Case`.`QA_RESULTS` WHERE DATE(run_at) = CURDATE();

  -- =========================
  -- Helper: constantes
  -- =========================
  -- Domínio de eventos válidos
  SET @event_ok_list := "'page_view','add_to_cart','begin_checkout','purchase'";
  -- Domínio de moedas válidas
  SET @currency_ok_list := "'BRL','USD','EUR'";

  -- =========================
  -- 1) source_medium nulo
  -- =========================
  INSERT INTO `Case`.`QA_RESULTS` (run_at, check_name, description, severity, threshold_violations, violations, status, sample_json)
  SELECT
    v_now,
    'NULL_source_medium',
    'Eventos com source_medium nulo',
    'MEDIUM',
    0,
    COUNT(*) AS violations,
    IF(COUNT(*) <= 0, 'PASS', 'FAIL') AS status,
    (
      SELECT JSON_ARRAYAGG(JSON_OBJECT('id', id, 'event_id', event_id, 'event_name', event_name) )
      FROM (
        SELECT id, event_id, event_name
        FROM `Case`.`GA4_GTM`
        WHERE source_medium IS NULL
        ORDER BY id DESC
        LIMIT 5
      ) s
    ) AS sample_json
  FROM `Case`.`GA4_GTM`
  WHERE source_medium IS NULL;

  -- =========================
  -- 2) event_ts no futuro (> 24h)
  -- =========================
  INSERT INTO `Case`.`QA_RESULTS` (run_at, check_name, description, severity, threshold_violations, violations, status, sample_json)
  SELECT
    v_now,
    'FUTURE_events',
    'event_ts > NOW() + 24h',
    'HIGH',
    0,
    COUNT(*) AS violations,
    IF(COUNT(*) <= 0, 'PASS', 'FAIL') AS status,
    (
      SELECT JSON_ARRAYAGG(JSON_OBJECT('id', id, 'event_id', event_id, 'event_ts', event_ts) )
      FROM (
        SELECT id, event_id, event_ts
        FROM `Case`.`GA4_GTM`
        WHERE event_ts > NOW() + INTERVAL 24 HOUR
        ORDER BY event_ts DESC
        LIMIT 5
      ) s
    )
  FROM `Case`.`GA4_GTM`
  WHERE event_ts > NOW() + INTERVAL 24 HOUR;

  -- =========================
  -- 3) event_name fora do domínio
  -- =========================
  SET @sql_invalid_event = CONCAT("
    INSERT INTO `Case`.`QA_RESULTS` (run_at, check_name, description, severity, threshold_violations, violations, status, sample_json)
    SELECT
      NOW(),
      'INVALID_event_name',
      'event_name fora do domínio permitido',
      'MEDIUM',
      0,
      COUNT(*) AS violations,
      IF(COUNT(*) <= 0, 'PASS', 'FAIL') AS status,
      (
        SELECT JSON_ARRAYAGG(JSON_OBJECT('id', id, 'event_name', event_name) )
        FROM (
          SELECT id, event_name
          FROM `Case`.`GA4_GTM`
          WHERE event_name NOT IN (", @event_ok_list, ")
          ORDER BY id DESC
          LIMIT 5
        ) s
      )
    FROM `Case`.`GA4_GTM`
    WHERE event_name NOT IN (", @event_ok_list, ");
  ");
  PREPARE stmt FROM @sql_invalid_event;
  EXECUTE stmt;
  DEALLOCATE PREPARE stmt;

  -- =========================
  -- 4) event_id duplicado (conta excedentes)
  -- =========================
  INSERT INTO `Case`.`QA_RESULTS` (run_at, check_name, description, severity, threshold_violations, violations, status, sample_json)
  SELECT
    v_now,
    'DUP_event_id',
    'Registros excedentes por event_id duplicado (soma de cnt-1)',
    'HIGH',
    0,
    IFNULL(SUM(cnt - 1), 0) AS violations,
    IF(IFNULL(SUM(cnt - 1), 0) <= 0, 'PASS', 'FAIL') AS status,
    (
      SELECT JSON_ARRAYAGG(JSON_OBJECT('event_id', event_id, 'count', cnt))
      FROM (
        SELECT event_id, COUNT(*) AS cnt
        FROM `Case`.`GA4_GTM`
        WHERE event_id IS NOT NULL
        GROUP BY event_id
        HAVING COUNT(*) > 1
        ORDER BY cnt DESC
        LIMIT 5
      ) s
    ) AS sample_json
  FROM (
    SELECT event_id, COUNT(*) AS cnt
    FROM `Case`.`GA4_GTM`
    WHERE event_id IS NOT NULL
    GROUP BY event_id
    HAVING COUNT(*) > 1
  ) d;

  -- =========================
  -- 5) purchase sem transaction_id
  -- =========================
  INSERT INTO `Case`.`QA_RESULTS` (run_at, check_name, description, severity, threshold_violations, violations, status, sample_json)
  SELECT
    v_now,
    'PURCHASE_missing_txid',
    'Eventos purchase sem transaction_id',
    'HIGH',
    0,
    COUNT(*) AS violations,
    IF(COUNT(*) <= 0, 'PASS', 'FAIL') AS status,
    (
      SELECT JSON_ARRAYAGG(JSON_OBJECT('id', id, 'event_id', event_id))
      FROM (
        SELECT id, event_id
        FROM `Case`.`GA4_GTM`
        WHERE event_name='purchase' AND (transaction_id IS NULL OR transaction_id = '')
        ORDER BY id DESC
        LIMIT 5
      ) s
    )
  FROM `Case`.`GA4_GTM`
  WHERE event_name='purchase' AND (transaction_id IS NULL OR transaction_id = '');

  -- =========================
  -- 6) purchase com value inválido (NULL/<=0/absurdo)
  -- =========================
  INSERT INTO `Case`.`QA_RESULTS` (run_at, check_name, description, severity, threshold_violations, violations, status, sample_json)
  SELECT
    v_now,
    'PURCHASE_bad_value',
    'purchase com value NULL/<=0 ou muito alto',
    'HIGH',
    0,
    COUNT(*) AS violations,
    IF(COUNT(*) <= 0, 'PASS', 'FAIL') AS status,
    (
      SELECT JSON_ARRAYAGG(JSON_OBJECT('id', id, 'value', value))
      FROM (
        SELECT id, value
        FROM `Case`.`GA4_GTM`
        WHERE event_name='purchase' AND (value IS NULL OR value <= 0 OR value > 1000000)
        ORDER BY id DESC
        LIMIT 5
      ) s
    )
  FROM `Case`.`GA4_GTM`
  WHERE event_name='purchase' AND (value IS NULL OR value <= 0 OR value > 1000000);

  -- =========================
  -- 7) currency inválida
  -- =========================
  SET @sql_bad_currency = CONCAT("
    INSERT INTO `Case`.`QA_RESULTS` (run_at, check_name, description, severity, threshold_violations, violations, status, sample_json)
    SELECT
      NOW(),
      'INVALID_currency',
      'currency não está na whitelist',
      'MEDIUM',
      0,
      COUNT(*) AS violations,
      IF(COUNT(*) <= 0, 'PASS', 'FAIL') AS status,
      (
        SELECT JSON_ARRAYAGG(JSON_OBJECT('id', id, 'currency', currency))
        FROM (
          SELECT id, currency
          FROM `Case`.`GA4_GTM`
          WHERE currency IS NULL OR currency NOT IN (", @currency_ok_list, ")
          ORDER BY id DESC
          LIMIT 5
        ) s
      )
    FROM `Case`.`GA4_GTM`
    WHERE currency IS NULL OR currency NOT IN (", @currency_ok_list, ");
  ");
  PREPARE stmt FROM @sql_bad_currency;
  EXECUTE stmt;
  DEALLOCATE PREPARE stmt;

  -- =========================
  -- 8) items inválido em purchase (NULL/<=0/>1000)
  -- =========================
  INSERT INTO `Case`.`QA_RESULTS` (run_at, check_name, description, severity, threshold_violations, violations, status, sample_json)
  SELECT
    v_now,
    'PURCHASE_bad_items',
    'purchase com items NULL/<=0/>1000',
    'MEDIUM',
    0,
    COUNT(*) AS violations,
    IF(COUNT(*) <= 0, 'PASS', 'FAIL') AS status,
    (
      SELECT JSON_ARRAYAGG(JSON_OBJECT('id', id, 'items', items))
      FROM (
        SELECT id, items
        FROM `Case`.`GA4_GTM`
        WHERE event_name='purchase' AND (items IS NULL OR items <= 0 OR items > 1000)
        ORDER BY id DESC
        LIMIT 5
      ) s
    )
  FROM `Case`.`GA4_GTM`
  WHERE event_name='purchase' AND (items IS NULL OR items <= 0 OR items > 1000);

  -- =========================
  -- 9) page_location nulo
  -- =========================
  INSERT INTO `Case`.`QA_RESULTS` (run_at, check_name, description, severity, threshold_violations, violations, status, sample_json)
  SELECT
    v_now,
    'NULL_page_location',
    'page_location nulo',
    'LOW',
    0,
    COUNT(*) AS violations,
    IF(COUNT(*) <= 0, 'PASS', 'FAIL') AS status,
    (
      SELECT JSON_ARRAYAGG(JSON_OBJECT('id', id))
      FROM (
        SELECT id
        FROM `Case`.`GA4_GTM`
        WHERE page_location IS NULL
        ORDER BY id DESC
        LIMIT 5
      ) s
    )
  FROM `Case`.`GA4_GTM`
  WHERE page_location IS NULL;

  -- =========================
  -- 10) page_location malformado (sem http/https)
  -- =========================
  INSERT INTO `Case`.`QA_RESULTS` (run_at, check_name, description, severity, threshold_violations, violations, status, sample_json)
  SELECT
    v_now,
    'MALFORMED_page_location',
    'page_location não inicia com http:// ou https://',
    'MEDIUM',
    0,
    COUNT(*) AS violations,
    IF(COUNT(*) <= 0, 'PASS', 'FAIL') AS status,
    (
      SELECT JSON_ARRAYAGG(JSON_OBJECT('id', id, 'page_location', page_location))
      FROM (
        SELECT id, page_location
        FROM `Case`.`GA4_GTM`
        WHERE page_location IS NOT NULL
          AND page_location NOT LIKE 'http://%%'
          AND page_location NOT LIKE 'https://%%'
        ORDER BY id DESC
        LIMIT 5
      ) s
    )
  FROM `Case`.`GA4_GTM`
  WHERE page_location IS NOT NULL
    AND page_location NOT LIKE 'http://%'
    AND page_location NOT LIKE 'https://%';

  -- =========================
  -- 11) session_id nulo
  -- =========================
  INSERT INTO `Case`.`QA_RESULTS` (run_at, check_name, description, severity, threshold_violations, violations, status, sample_json)
  SELECT
    v_now,
    'NULL_session_id',
    'session_id nulo',
    'LOW',
    0,
    COUNT(*) AS violations,
    IF(COUNT(*) <= 0, 'PASS', 'FAIL') AS status,
    (
      SELECT JSON_ARRAYAGG(JSON_OBJECT('id', id, 'event_name', event_name))
      FROM (
        SELECT id, event_name
        FROM `Case`.`GA4_GTM`
        WHERE session_id IS NULL
        ORDER BY id DESC
        LIMIT 5
      ) s
    )
  FROM `Case`.`GA4_GTM`
  WHERE session_id IS NULL;

END$$
DELIMITER ;

-- (3) View de resumo (por severidade e status)
CREATE OR REPLACE VIEW `Case`.`vw_qa_summary` AS
SELECT
  run_at,
  severity,
  status,
  COUNT(*) AS checks,
  SUM(violations) AS total_violations
FROM `Case`.`QA_RESULTS`
GROUP BY run_at, severity, status;

-- =========================
-- COMO RODAR
-- =========================
-- 1) Execute a procedure:
-- CALL `Case`.`sp_run_quality_checks`();

-- 2) Veja os resultados detalhados:
-- SELECT * FROM `Case`.`QA_RESULTS` WHERE run_at = (SELECT MAX(run_at) FROM `Case`.`QA_RESULTS`) ORDER BY severity DESC, violations DESC;

-- 3) Resumo:
-- SELECT * FROM `Case`.`vw_qa_summary` WHERE run_at = (SELECT MAX(run_at) FROM `Case`.`QA_RESULTS`);
