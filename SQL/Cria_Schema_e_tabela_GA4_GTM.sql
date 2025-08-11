Query SQL:
CREATE SCHEMA IF NOT EXISTS `Case` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE TABLE `Case`.`GA4_GTM` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `event_id`        VARCHAR(64) NULL,              -- pode repetir (permitir duplicatas p/ teste)
  `event_ts`        DATETIME(6) NOT NULL,          -- timestamp do evento
  `event_date`      DATE NOT NULL,                 -- partição lógica (YYYY-MM-DD)
  `user_pseudo_id`  VARCHAR(64) NOT NULL,
  `session_id`      BIGINT NULL,
  `event_name`      VARCHAR(64) NOT NULL,          -- ex: page_view, add_to_cart, purchase...
  `source_medium`   VARCHAR(128) NULL,             -- ex: "google / cpc", "direct / (none)"
  `page_location`   VARCHAR(512) NULL,             -- URL (pode vir malformada intencionalmente)
  `transaction_id`  VARCHAR(64) NULL,              -- obrigatório em purchase (vamos quebrar isso em alguns casos)
  `items`           INT NULL,                      -- quantidade de itens (alguns casos inconsistentes)
  `value`           DECIMAL(10,2) NULL,            -- valor da compra (alguns casos negativos/fora da faixa)
  `currency`        VARCHAR(10) NULL,              -- ex: BRL, USD (alguns casos inválidos)
  `is_mobile`       TINYINT(1) NOT NULL DEFAULT 0, -- 0/1
  `user_agent`      VARCHAR(255) NULL,
  `ingested_at`     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
)

SELECT * FROM Case.GA4_GTM;