CALL `Case`.`sp_run_quality_checks`();
SELECT * FROM `Case`.`QA_RESULTS` WHERE run_at = (SELECT MAX(run_at) FROM `Case`.`QA_RESULTS`) ORDER BY severity DESC, violations DESC;
SELECT * FROM `Case`.`vw_qa_summary` WHERE run_at = (SELECT MAX(run_at) FROM `Case`.`QA_RESULTS`);