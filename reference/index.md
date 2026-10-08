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
- [`tsesqlr_candidatos()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_candidatos.md)
  : Consulta rápida: candidaturas

## Detalhes internos

Helpers e esquema canônico usados pela carga, documentados com
`@keywords internal`. O `internal = TRUE` é necessário porque os
seletores do pkgdown ignoram tópicos internos por padrão.

- [`.agregar_boletins()`](https://distintivelab.github.io/tsesqlr/reference/dot-agregar_boletins.md)
  : Agrega o boletim de urna WEB por municipio/cargo/votavel

- [`.carregar_um()`](https://distintivelab.github.io/tsesqlr/reference/dot-carregar_um.md)
  :

  Carga de um escopo (tipo, ano, uf) — nucleo do
  [`tsesqlr_carregar()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_carregar.md)

- [`.layout_compativel()`](https://distintivelab.github.io/tsesqlr/reference/dot-layout_compativel.md)
  :

  Compara as colunas e os tipos de `dados` com o que existe em
  `information_schema`. Detecta tabelas criadas com layout antigo em que
  os nomes batem mas um tipo mudou (ex.: `turno BOOLEAN` vindo de um
  `NA` logico) — algo que
  [`DBI::dbWriteTable()`](https://dbi.r-dbi.org/reference/dbWriteTable.html)
  nao acusaria antes do COPY falhar.

- [`.normalizar_tipo_pg()`](https://distintivelab.github.io/tsesqlr/reference/dot-normalizar_tipo_pg.md)
  : Verifica se a tabela do banco casa com nomes e tipos dos dados

- [`.padrao_colunas`](https://distintivelab.github.io/tsesqlr/reference/dot-padrao_colunas.md)
  : Colunas canonicas por tabela (esquema estavel entre anos/ciclos)

- [`.padronizar()`](https://distintivelab.github.io/tsesqlr/reference/dot-padronizar.md)
  : Completa/ordena colunas do data.frame no esquema canonico

- [`.tipos_colunas`](https://distintivelab.github.io/tsesqlr/reference/dot-tipos_colunas.md)
  : Tipos canonicos das colunas (evita NA logico virar BOOLEAN no banco)

- [`.ufs_br`](https://distintivelab.github.io/tsesqlr/reference/dot-ufs_br.md)
  : Siglas das 27 UFs (sem ZZ)

## Pacote

- [`tsesqlr`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr-package.md)
  [`tsesqlr-package`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr-package.md)
  : tsesqlr: banco de dados eleitorais TSE pré-carregado (PostgreSQL)
