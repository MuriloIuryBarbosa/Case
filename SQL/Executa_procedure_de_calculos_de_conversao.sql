-- ======================
-- PASSO A PASSO (rodar)
-- ======================
-- 1) Executar a procedure para popular a tabela:
CALL `Case`.`sp_populate_mart_qc_channel_summary`();

-- 2) Consultar os resultados atualizados:
SELECT *
FROM `Case`.`mart_qc_channel_summary`
ORDER BY all_sessions DESC, source_medium;