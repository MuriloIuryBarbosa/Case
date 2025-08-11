📊 Case de QA e Análise de Dados – GA4 & BigQuery Simulation (MySQL Local)

Este projeto simula um cenário real de qualidade de dados e análise de conversão por canal utilizando dados exportados do Google Analytics 4 (GA4) para BigQuery, mas recriados em MySQL local para evitar custos de cloud.
O case foi estruturado para demonstrar habilidades de QA de dados, ETL, validação e análise de impacto da qualidade.

1️⃣ Estrutura do Projeto

| Pasta / Arquivo      | Descrição                                     |
|----------------------|-----------------------------------------------|
| CSV/                 | Exportações CSV para uso no Power BI          |
| SQL/                 | Scripts SQL organizados por etapa             |
| Power_BI/            | Relatórios e arquivos de conexão              |
| venv/                | Ambiente virtual Python                       |
| .env                 | Variáveis de ambiente (credenciais MySQL)     |
| populate_table.py    | Script para popular dados simulados           |
| README.md            | Documentação do projeto                       |



2️⃣ Etapas do Desenvolvimento
1. Criação do Schema e Tabela de Eventos

Arquivo: Cria_Schema_e_tabela_GA4_GTM.sql
    • Cria o schema Case e a tabela GA4_GTM que receberá os eventos GA4 simulados.
    • Estrutura compatível com colunas comuns no GA4 Export.

2. População de Dados com Simulação de Problemas de Qualidade

Arquivo: populate_table.py
    • Script Python que insere 300 registros na tabela, sendo 50 com problemas de qualidade (nulos, duplicatas, datas futuras, valores inválidos etc.).
    • Utiliza variáveis de ambiente no .env para conexão MySQL.
    • Garante aleatoriedade controlada para reproduzibilidade.

Problemas simulados:
    • source_medium nulo ou inválido
    • event_id duplicado
    • Datas futuras em event_ts
    • event_name fora do domínio permitido
    • page_location malformado
    • Compras (purchase) sem transaction_id ou valores inválidos
    • items negativos ou irreais
    • session_id nulo

3. Validação de Qualidade dos Dados

Arquivo: Cria_Procedure_de_validacao_dedados.sql
    • Procedure sp_run_quality_checks que:
        • Executa regras de validação nos campos-chave.
        • Registra resultados na tabela QA_RESULTS.
    • View vw_qa_summary para resumo da qualidade dos dados.

Como executar:

CALL `Case`.`sp_run_quality_checks`();

-- Ver resultados detalhados
SELECT *
FROM `Case`.`QA_RESULTS`
WHERE run_at = (SELECT MAX(run_at) FROM `Case`.`QA_RESULTS`)
ORDER BY severity DESC, violations DESC;

-- Ver resumo
SELECT *
FROM `Case`.`vw_qa_summary`
WHERE run_at = (SELECT MAX(run_at) FROM `Case`.`QA_RESULTS`);

4. Cálculo de Conversão por Canal com e sem Qualidade

Arquivo: Cria_procedure_e_popula_calculos_conversao.sql
    • Procedure sp_populate_mart_qc_channel_summary:
        • Calcula taxa de conversão apenas com dados de qualidade assegurada.
        • Calcula taxa de conversão com todos os dados (incluindo problemas).
        • Mostra impacto (%) da falta de qualidade.
        • Registra contagem de registros usados em cada cenário.

Como executar:
CALL `Case`.`sp_populate_mart_qc_channel_summary`();

SELECT *
FROM `Case`.`mart_qc_channel_summary`
ORDER BY all_sessions DESC, source_medium;

5. Exportação para Power BI
    • Exportação do MySQL para CSV (pasta /CSV).
    • Desenvolvimento de dashboards no Power BI no Windows usando os arquivos exportados do Ubuntu.

3️⃣ Ferramentas Utilizadas
    • ChatGPT Plus – Apoio na concepção e automação
    • MySQL Workbench 8.0 – Modelagem e execução SQL
    • Python 3.13 – Bibliotecas PyMySQL e python-dotenv
    • Ubuntu – Ambiente principal de desenvolvimento
    • Windows 11 – Ambiente para criação de dashboards no Power BI

4️⃣ Objetivo do Case

Este projeto simula um fluxo real de QA de dados em ambiente analítico:
    • Geração de dados simulados com problemas.
    • Validação sistemática da qualidade.
    • Medição do impacto da qualidade no resultado analítico.
    • Integração com ferramentas de BI para análise visual.
