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

Helpers e esquema canônico usados pela carga.

- [`tsesqlr_candidatos()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_candidatos.md)
  : Consulta rápida: candidaturas
- [`tsesqlr_carregar()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_carregar.md)
  : Carrega dados eleitorais no tsedb
- [`tsesqlr_con()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_con.md)
  : Conexão ao banco tsedb
- [`tsesqlr_init()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_init.md)
  : Inicializa o schema do tsedb
- [`tsesqlr_resultados()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_resultados.md)
  : Consulta rápida: resultados por município

## Pacote

- [`tsesqlr`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr-package.md)
  [`tsesqlr-package`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr-package.md)
  : tsesqlr: banco de dados eleitorais TSE pré-carregado (PostgreSQL)
