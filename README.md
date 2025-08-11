############# PASSOS PARA RESOLUÇÃO DO CASE #############
• Primeiro passo: criação do Schema “Case” e tabela “GA4_GTM”
    ◦ Comandos SQL: Cria_Schema_e_tabela_GA4_GTM.sql	

• Segundo passo: criação de um script em python para popular a tabela com registros e simular registros com problemas de qualidade aplicando com aleatoriedade de inconsistencias nessas inserções. O Script utiliza variáveis de ambiente para simular um cenário real de desenvolvimento buscando manter a segurança e possibilidade de utilizar Git para versionamento e trabalho em equipe. 
O Script popula a tabela com 300 registros e aleatoriamente cria 50 registros com problemas de qualidade de dados randomicamente (pode ser duplicatas ou campos vazios por exemplo).

DETALHES DO SCRIPT: O que esse script injeta de “problemas”:
    • source_medium NULL ou valores inválidos
    • event_id duplicado (10 IDs repetidos)
    • event_ts com datas futuras
    • event_name não pertencente ao domínio (ex.: random_event)
    • page_location malformado ou NULL
    • purchase sem transaction_id, value negativo ou moeda inválida
    • items negativo ou irreal para purchase
    • session_id NULL em alguns casos

• Quarto passo: Criação de comando SQL para validação de campos chaves na tabela e quantificação de quantidade de problemas de qualidade dos dados. O comando garante que a procedure existe e se não existe ele o cria, após essa etapa gera uma view com os checks de dados. Abaixo o comando criado:
    ◦ Comandos SQL: Cria_Procedure_de_validacao_dedados.sql
    ◦ COMO RODAR
    1) Execute a procedure: 
        CALL `Case`.`sp_run_quality_checks`();
	2) Veja os resultados detalhados: 
        SELECT * FROM `Case`.`QA_RESULTS`			
        WHERE run_at = (SELECT MAX(run_at) 
        FROM `Case`.`QA_RESULTS`) 
        ORDER BY severity DESC, violations DESC;

	3) Veja o resultado resumido: 
        SELECT * FROM `Case`.`vw_qa_summary` 
        WHERE run_at = (SELECT MAX(run_at) 
        FROM `Case`.`QA_RESULTS`);

• Quinto passo: Criação de um comando SQL que popula uma nova tabela aonde é calculado:
    ◦ taxa de conversão por canal com os dados que tem qualidade de dados asseguradas 
    ◦ quantidade de registros que compuseram o calculo com qualidade de dados aseguradas
    ◦ taxa de conversão por canal com os dados que não tem qualidade de dados assegurados
    ◦ quantidade de registros que compuseram o calculo sem qualidade de dados aseguradas
    ◦ delta entre os dois cenários para analisar o impacto que a falta de qualidade de dados gera na análise final
    ◦ comando SQL: Cria_procedure_e_popula_calculos_conversao.sql 

    ◦ COMO RODAR
    1) Executar a procedure para popular a tabela:
        CALL `Case`.`sp_populate_mart_qc_channel_summary`();
    2) Consultar os resultados atualizados:
        SELECT *
        FROM `Case`.`mart_qc_channel_summary`
        ORDER BY all_sessions DESC, source_medium;

• Sexto passo: recentemente migrei o sistema operacional que utilizo para treinar habilidades em ambiente de desenvolvimento em ambientes linux (no caso estou trabalhando com Ubuntu), portanto fiz a exportação dos dados do MySQL em formato CSV para seguir o desenvolvimento dos dashboards no Power BI em máquina com sistema operacional Windows

FERRAMENTAS UTILIZADAS:
    • ChatGPT Plus
    • Mysql Worbench 8.0
    • Python 13 (Bibliotecas: PyMySQL e dotenv)
    • Ubuntu 
    • Windows 11

