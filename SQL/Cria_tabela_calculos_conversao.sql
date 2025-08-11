DROP TABLE IF EXISTS `Case`.`mart_qc_channel_summary`;
CREATE TABLE `Case`.`mart_qc_channel_summary` (
  `source_medium`                 VARCHAR(128) NOT NULL,
  `quality_sessions`              INT NOT NULL,
  `quality_purchases`             INT NOT NULL,
  `quality_conversion_rate`       DECIMAL(18,6) NOT NULL,
  `all_sessions`                  INT NOT NULL,
  `all_purchases`                 INT NOT NULL,
  `all_conversion_rate`           DECIMAL(18,6) NOT NULL,
  `pct_quality_records`           DECIMAL(18,6) NOT NULL,
  `pct_all_records`               DECIMAL(18,6) NOT NULL,
  `pct_diff_quality_minus_all`    DECIMAL(18,6) NOT NULL,
  `quality_records_by_source`     INT NOT NULL,
  `all_records_by_source`         INT NOT NULL,
  `updated_at`                    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`source_medium`),
  INDEX `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
