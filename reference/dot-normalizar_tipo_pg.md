# Verifica se a tabela do banco casa com nomes e tipos dos dados

Normaliza nomes de tipo do PostgreSQL para comparacao

## Usage

``` r
.normalizar_tipo_pg(x)
```

## Details

O `information_schema.data_type` vem em minusculas e com os nomes longos
do catalogo (`character varying`, `double precision`), enquanto
[`DBI::dbDataType()`](https://dbi.r-dbi.org/reference/dbDataType.html)
(RPostgres) devolve em maiusculas e com os apelidos curtos (`TEXT`,
`DOUBLE PRECISION`). Os dois lados passam por aqui antes de serem
comparados.
