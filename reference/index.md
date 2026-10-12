# Package index

## Conexão e schema

Abre a conexão ao banco dedicado (`tsedb`) e prepara o schema.

- [`tsesqlr_con()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_con.md)
  : Conexão ao banco tsedb
- [`tsesqlr_init()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_init.md)
  : Inicializa o schema do tsedb

## Carga de dados

Baixa os dados via tsebr e grava no banco de forma idempotente por
escopo (`tipo`, `ano`, `uf`).

- [`tsesqlr_carregar()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_carregar.md)
  : Carrega dados eleitorais no tsedb

## Consultas

Consultas rápidas no banco pré-carregado, sem download.

- [`tsesqlr_resultados()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_resultados.md)
  : Consulta rápida: resultados por município
- [`tsesqlr_resultados_municipio()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_resultados_municipio.md)
  : Consulta rápida: votos por município IBGE (contrato do DW beep)
- [`tsesqlr_candidatos()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_candidatos.md)
  : Consulta rápida: candidaturas
- [`tsesqlr_disponivel()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_disponivel.md)
  : Escopo está carregado no banco? (decisão tsesqlr x tsebr no painel)
- [`tsesqlr_detalhe_municipio()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_detalhe_municipio.md)
  : Consulta rápida: detalhe por município (abstenções, aptos, ...)

## Detalhes internos

Helpers e esquema canônico usados pela carga, documentados com
`@keywords internal`. O `internal = TRUE` é necessário porque os
seletores do pkgdown ignoram tópicos internos por padrão.

- [`.agregar_boletins()`](https://distintivelab.github.io/tsesqlr/reference/dot-agregar_boletins.md)
  : Agrega o boletim de urna WEB por municipio/cargo/votavel

- [`.anos_resultados_secao`](https://distintivelab.github.io/tsesqlr/reference/dot-anos_resultados_secao.md)
  : Anos com votacao por secao publicada pelo TSE

- [`.carregar_um()`](https://distintivelab.github.io/tsesqlr/reference/dot-carregar_um.md)
  :

  Carga de um escopo (tipo, ano, uf) — nucleo do
  [`tsesqlr_carregar()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_carregar.md)

- [`.criar_indices()`](https://distintivelab.github.io/tsesqlr/reference/dot-criar_indices.md)
  : Cria os indices de uma tabela de dados, se ela existir

- [`.indices_tabelas`](https://distintivelab.github.io/tsesqlr/reference/dot-indices_tabelas.md)
  : Indices das tabelas de dados

- [`.layout_compativel()`](https://distintivelab.github.io/tsesqlr/reference/dot-layout_compativel.md)
  :

  Compara as colunas e os tipos de `dados` com o que existe em
  `information_schema`. Detecta tabelas criadas com layout antigo em que
  os nomes batem mas um tipo mudou (ex.: `turno BOOLEAN` vindo de um
  `NA` logico) — algo que
  [`DBI::dbWriteTable()`](https://dbi.r-dbi.org/reference/dbWriteTable.html)
  nao acusaria antes do COPY falhar.

- [`.ler_tsebr()`](https://distintivelab.github.io/tsesqlr/reference/dot-ler_tsebr.md)
  : Le dados do tsebr transformando extracao truncada de ZIP em erro

- [`.normalizar_tipo_pg()`](https://distintivelab.github.io/tsesqlr/reference/dot-normalizar_tipo_pg.md)
  : Verifica se a tabela do banco casa com nomes e tipos dos dados

- [`.padrao_colunas`](https://distintivelab.github.io/tsesqlr/reference/dot-padrao_colunas.md)
  : Colunas canonicas por tabela (esquema estavel entre anos/ciclos)

- [`.padronizar()`](https://distintivelab.github.io/tsesqlr/reference/dot-padronizar.md)
  : Completa/ordena colunas do data.frame no esquema canonico

- [`.periodo_eleicao()`](https://distintivelab.github.io/tsesqlr/reference/dot-periodo_eleicao.md)
  : Data de cada turno da eleição geral (domingos de outubro)

- [`.tipos_colunas`](https://distintivelab.github.io/tsesqlr/reference/dot-tipos_colunas.md)
  : Tipos canonicos das colunas (evita NA logico virar BOOLEAN no banco)

- [`.ufs_br`](https://distintivelab.github.io/tsesqlr/reference/dot-ufs_br.md)
  : Siglas das 27 UFs (sem ZZ)

- [`.verificar_ano_resultados()`](https://distintivelab.github.io/tsesqlr/reference/dot-verificar_ano_resultados.md)
  :

  Valida o ano pedido para a tabela `resultados`

- [`.verificar_uf_dados()`](https://distintivelab.github.io/tsesqlr/reference/dot-verificar_uf_dados.md)
  : Confere que os dados lidos pertencem ao escopo de UF pedido

## Pacote

- [`tsesqlr`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr-package.md)
  [`tsesqlr-package`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr-package.md)
  : tsesqlr: banco de dados eleitorais TSE pré-carregado (PostgreSQL)
