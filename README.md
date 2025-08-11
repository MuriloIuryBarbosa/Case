<!DOCTYPE html>
<html lang="pt-br">
<head>
<meta charset="utf-8">
<title>Case de QA e Análise de Dados – GA4 & BigQuery Simulation (MySQL Local)</title>
</head>
<body>

<h1>📊 Case de QA e Análise de Dados – GA4 &amp; BigQuery Simulation (MySQL Local)</h1>
<p>Este projeto simula um cenário real de <strong>qualidade de dados</strong> e <strong>análise de conversão por canal</strong> utilizando dados exportados do Google Analytics 4 (GA4) para BigQuery, mas recriados em <strong>MySQL local</strong> para evitar custos de cloud. O case demonstra habilidades de <em>Data QA</em>, <em>ETL</em>, validação e análise do impacto da qualidade.</p>

<p><span class="badge">MySQL</span><span class="badge">Python 3.13</span><span class="badge">PyMySQL</span><span class="badge">python-dotenv</span><span class="badge">Power BI</span><span class="badge">Ubuntu</span><span class="badge">Windows 11</span></p>

<h2>1️⃣ Estrutura do Projeto</h2>
<div class="tree">
<pre>CASE/
│── CSV/                 # Exportações CSV para uso no Power BI
│── SQL/                 # Scripts SQL organizados por etapa
│── Power_BI/            # Relatórios e arquivos de conexão
│── venv/                # Ambiente virtual Python
│── .env                 # Variáveis de ambiente (credenciais MySQL)
│── populate_table.py    # Script para popular dados simulados
│── README.md            # Documentação do projeto
</pre>
</div>

<h2>2️⃣ Etapas do Desenvolvimento</h2>

<h3>1. Criação do Schema e Tabela de Eventos</h3>
<p><strong>Arquivo:</strong> <code class="inline">SQL/Cria_Schema_e_tabela_GA4_GTM.sql</code><br>
Cria o schema <code class="inline">Case</code> e a tabela <code class="inline">GA4_GTM</code> compatível com campos comuns do GA4 Export.</p>

<h3>2. População de Dados com Simulação de Problemas de Qualidade</h3>
<p><strong>Arquivo:</strong> <code class="inline">populate_table.py</code></p>
<ul>
  <li>Insere <strong>300</strong> registros, sendo <strong>50</strong> com problemas de qualidade.</li>
  <li>Usa variáveis de ambiente via <code class="inline">.env</code>.</li>
  <li>Aleatoriedade controlada para reproduzibilidade.</li>
</ul>
<p><strong>Problemas simulados:</strong> <em>source_medium</em> nulo/ inválido; <em>event_id</em> duplicado; datas futuras em <em>event_ts</em>; <em>event_name</em> fora do domínio; <em>page_location</em> malformado; <em>purchase</em> sem <em>transaction_id</em> / <em>value</em> inválido / moeda inválida; <em>items</em> negativos/irreais; <em>session_id</em> nulo.</p>

<h3>3. Validação de Qualidade dos Dados</h3>
<p><strong>Arquivo:</strong> <code class="inline">SQL/Cria_Procedure_de_validacao_dedados.sql</code></p>
<ul>
  <li>Procedure <code class="inline">sp_run_quality_checks</code> executa regras de validação e grava em <code class="inline">QA_RESULTS</code>.</li>
  <li>View <code class="inline">vw_qa_summary</code> resume violações por severidade/status.</li>
</ul>

<details>
  <summary><strong>Como executar</strong></summary>
  <pre>CALL `Case`.`sp_run_quality_checks`();

-- Resultados detalhados
SELECT *
FROM `Case`.`QA_RESULTS`
WHERE run_at = (SELECT MAX(run_at) FROM `Case`.`QA_RESULTS`)
ORDER BY severity DESC, violations DESC;

-- Resumo
SELECT *
FROM `Case`.`vw_qa_summary`
WHERE run_at = (SELECT MAX(run_at) FROM `Case`.`QA_RESULTS`);</pre>
</details>

<h3>4. Conversão por Canal – Dados com e sem Qualidade</h3>
<p><strong>Arquivo:</strong> <code class="inline">SQL/Cria_procedure_e_popula_calculos_conversao.sql</code></p>
<ul>
  <li>Procedure <code class="inline">sp_populate_mart_qc_channel_summary</code> calcula <strong>taxa de conversão</strong> por canal em dois cenários:
    <ul>
      <li><strong>Qualidade assegurada</strong> (dados válidos)</li>
      <li><strong>Todos os dados</strong> (inclui registros problemáticos)</li>
    </ul>
  </li>
  <li>Mostra o <strong>delta</strong> entre cenários e a quantidade de registros usados em cada cálculo.</li>
</ul>

<details>
  <summary><strong>Como executar</strong></summary>
  <pre>CALL `Case`.`sp_populate_mart_qc_channel_summary`();

SELECT *
FROM `Case`.`mart_qc_channel_summary`
ORDER BY all_sessions DESC, source_medium;</pre>
</details>

<h3>5. Exportação para Power BI</h3>
<p>Exportação do MySQL para CSV (pasta <code class="inline">CSV/</code>) e desenvolvimento do dashboard no Power BI (Windows). O cenário comum seria conexão direta ao BigQuery/GCP; aqui a exportação via CSV foi usada por praticidade.</p>

<h2>3️⃣ Ferramentas Utilizadas</h2>
<p>ChatGPT Plus • MySQL Workbench 8.0 • Python 3.13 (PyMySQL, python-dotenv) • Ubuntu (dev) • Windows 11 (Power BI)</p>

<hr>

<h2>📈 Desenvolvimento do BI no Power BI</h2>

<h3>1. Conexão e Tratamento de Dados</h3>
<ul>
  <li>Conexão via <strong>CSV</strong> simulando fonte direta.</li>
  <li>Conversão de tipos por tabela (Power Query).</li>
  <li>Criação da <strong>dCalendario</strong> para análises temporais.</li>
  <li>Tabela <strong>“Medidas”</strong> para centralizar DAX.</li>
</ul>

<h3>2. Modelagem e Relacionamentos</h3>
<ul>
  <li>Relacionamentos entre fatos e <strong>dCalendario</strong>.</li>
  <li>Vínculo entre <strong>GA4_GTM</strong> (eventos) e <strong>QA_RESULTS</strong> (auditoria) para análises de impacto.</li>
</ul>

<h3>3. Medidas DAX Implementadas</h3>
<div class="grid">
  <div class="card">
    <div class="kpi">Registros</div>
    <pre><code>Qtd. Registros = DISTINCTCOUNT(GA4_GTM[id])</code></pre>
  </div>
  <div class="card">
    <div class="kpi">Registros sem qualidade</div>
    <pre><code>Qtd. Registros bad = DISTINCTCOUNT(QA_RESULTS[id])</code></pre>
  </div>
  <div class="card">
    <div class="kpi">% sem qualidade</div>
    <pre><code>% s/ Qualidade = DIVIDE([Qtd. Registros bad], [Qtd. Registros])</code></pre>
  </div>
</div>

<h3>4. Visualizações Criadas</h3>
<ul>
  <li><strong>Visão Geral:</strong> KPIs de volume total, volume com problema e % sem qualidade.</li>
  <li><strong>Análise Temporal:</strong> evolução da qualidade ao longo do tempo.</li>
  <li><strong>Impacto por Fonte/Canal:</strong> volume e % de problemas por <code class="inline">source_medium</code>.</li>
  <li><strong>Impacto Financeiro:</strong> (quando aplicável) estimativa do valor afetado por registros com problema.</li>
</ul>

<hr>

<p class="muted">Qualquer dúvida ou sugestão, abra uma issue no repositório. 🚀</p>

</body>
</html>
