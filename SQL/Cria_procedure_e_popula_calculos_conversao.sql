DROP PROCEDURE IF EXISTS `Case`.`sp_populate_mart_qc_channel_summary`;
DELIMITER $$

CREATE PROCEDURE `Case`.`sp_populate_mart_qc_channel_summary`()
BEGIN
  -- Limpa a tabela final
  TRUNCATE TABLE `Case`.`mart_qc_channel_summary`;

  -- =======================
  -- TEMPORÁRIAS: BASE & QUALIDADE
  -- =======================
  CREATE TEMPORARY TABLE tmp_base_all AS
  SELECT
    COALESCE(source_medium, '(null)') AS source_medium_label,
    event_id, event_ts, event_name, session_id, page_location,
    transaction_id, value, currency, items
  FROM `Case`.`GA4_GTM`;

  CREATE TEMPORARY TABLE tmp_quality_events AS
  SELECT *
  FROM tmp_base_all
  WHERE session_id IS NOT NULL
    AND event_ts <= NOW() + INTERVAL 24 HOUR
    AND event_name IN ('page_view','add_to_cart','begin_checkout','purchase')
    AND source_medium_label <> '(null)'
    AND page_location IS NOT NULL
    AND (page_location LIKE 'http://%' OR page_location LIKE 'https://%')
    AND (
      event_name <> 'purchase' OR
      (transaction_id IS NOT NULL AND transaction_id <> '' AND value IS NOT NULL AND value > 0
       AND currency IN ('BRL','USD','EUR') AND items IS NOT NULL AND items > 0)
    );

  -- =======================
  -- CONTAGENS DE REGISTROS
  -- =======================
  CREATE TEMPORARY TABLE tmp_rec_quality_by_source AS
  SELECT source_medium_label, COUNT(*) AS quality_records
  FROM tmp_quality_events
  GROUP BY source_medium_label;

  CREATE TEMPORARY TABLE tmp_rec_quality_total AS
  SELECT COUNT(*) AS total_quality_records FROM tmp_quality_events;

  CREATE TEMPORARY TABLE tmp_rec_all_by_source AS
  SELECT source_medium_label, COUNT(*) AS all_records
  FROM tmp_base_all
  GROUP BY source_medium_label;

  CREATE TEMPORARY TABLE tmp_rec_all_total AS
  SELECT COUNT(*) AS total_all_records FROM tmp_base_all;

  -- =======================
  -- AGREGAÇÕES: SESSÕES/COMPRAS (QUALIDADE)
  -- =======================
  CREATE TEMPORARY TABLE tmp_sess_quality AS
  SELECT
    source_medium_label,
    session_id,
    MAX(event_name='page_view')  AS has_pv,
    MAX(event_name='purchase')   AS has_purchase
  FROM tmp_quality_events
  GROUP BY source_medium_label, session_id;

  CREATE TEMPORARY TABLE tmp_agg_quality AS
  SELECT
    source_medium_label,
    SUM(has_pv)        AS quality_sessions,
    SUM(has_purchase)  AS quality_purchases,
    IFNULL(SUM(has_purchase)/NULLIF(SUM(has_pv),0),0) AS quality_cvr
  FROM tmp_sess_quality
  GROUP BY source_medium_label;

  -- =======================
  -- AGREGAÇÕES: SESSÕES/COMPRAS (TODOS)
  -- =======================
  CREATE TEMPORARY TABLE tmp_sess_all AS
  SELECT
    source_medium_label,
    session_id,
    MAX(event_name='page_view')  AS has_pv,
    MAX(event_name='purchase')   AS has_purchase
  FROM tmp_base_all
  WHERE session_id IS NOT NULL
  GROUP BY source_medium_label, session_id;

  CREATE TEMPORARY TABLE tmp_agg_all AS
  SELECT
    source_medium_label,
    SUM(has_pv)        AS all_sessions,
    SUM(has_purchase)  AS all_purchases,
    IFNULL(SUM(has_purchase)/NULLIF(SUM(has_pv),0),0) AS all_cvr
  FROM tmp_sess_all
  GROUP BY source_medium_label;

  -- =======================
  -- CHAVES DE FONTES
  -- =======================
  CREATE TEMPORARY TABLE tmp_sm_keys AS
  SELECT source_medium_label FROM tmp_rec_quality_by_source
  UNION
  SELECT source_medium_label FROM tmp_rec_all_by_source;

  -- =======================
  -- INSERT FINAL NA TABELA
  -- =======================
  INSERT INTO `Case`.`mart_qc_channel_summary` (
    source_medium,
    quality_sessions, quality_purchases, quality_conversion_rate,
    all_sessions, all_purchases, all_conversion_rate,
    pct_quality_records, pct_all_records, pct_diff_quality_minus_all,
    quality_records_by_source, all_records_by_source, updated_at
  )
  SELECT
    k.source_medium_label AS source_medium,

    IFNULL(aq.quality_sessions, 0)         AS quality_sessions,
    IFNULL(aq.quality_purchases, 0)        AS quality_purchases,
    IFNULL(aq.quality_cvr, 0)              AS quality_conversion_rate,

    IFNULL(aa.all_sessions, 0)             AS all_sessions,
    IFNULL(aa.all_purchases, 0)            AS all_purchases,
    IFNULL(aa.all_cvr, 0)                  AS all_conversion_rate,

    ROUND(100 * IFNULL(rq.quality_records,0) / NULLIF(rqt.total_quality_records,0), 6) AS pct_quality_records,
    ROUND(100 * IFNULL(ra.all_records,0)     / NULLIF(rat.total_all_records,0), 6)     AS pct_all_records,
    ROUND(
      (100 * IFNULL(rq.quality_records,0) / NULLIF(rqt.total_quality_records,0))
      -
      (100 * IFNULL(ra.all_records,0)     / NULLIF(rat.total_all_records,0))
    , 6) AS pct_diff_quality_minus_all,

    IFNULL(rq.quality_records,0) AS quality_records_by_source,
    IFNULL(ra.all_records,0)     AS all_records_by_source,
    NOW()                        AS updated_at
  FROM tmp_sm_keys k
  LEFT JOIN tmp_agg_quality        aq  ON aq.source_medium_label = k.source_medium_label
  LEFT JOIN tmp_agg_all            aa  ON aa.source_medium_label = k.source_medium_label
  LEFT JOIN tmp_rec_quality_by_source rq ON rq.source_medium_label = k.source_medium_label
  LEFT JOIN tmp_rec_all_by_source   ra ON ra.source_medium_label = k.source_medium_label
  CROSS JOIN tmp_rec_quality_total  rqt
  CROSS JOIN tmp_rec_all_total      rat
  ORDER BY k.source_medium_label;

  -- (Opcional) limpar temporárias manualmente
  DROP TEMPORARY TABLE IF EXISTS
    tmp_base_all, tmp_quality_events,
    tmp_rec_quality_by_source, tmp_rec_quality_total,
    tmp_rec_all_by_source, tmp_rec_all_total,
    tmp_sess_quality, tmp_agg_quality,
    tmp_sess_all, tmp_agg_all,
    tmp_sm_keys;

END$$
DELIMITER ;
