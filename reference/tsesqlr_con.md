# Conexão ao banco tsedb

Abre conexão ao PostgreSQL dedicado aos dados eleitorais. As credenciais
vêm das variáveis de ambiente (`.Renviron`): `user`, `password`, `host`,
`dbname`.

## Usage

``` r
tsesqlr_con(dbname = "tsedb")
```

## Arguments

- dbname:

  Nome do banco; default "tsedb" (via env var `dbname`).

## Value

Objeto de conexão DBI (RPostgres).

## See also

Other tsesqlr:
[`tsesqlr_candidatos()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_candidatos.md),
[`tsesqlr_carregar()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_carregar.md),
[`tsesqlr_init()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_init.md),
[`tsesqlr_resultados()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_resultados.md)

## Examples

``` r
if (FALSE) { # \dontrun{
con <- tsesqlr_con()
DBI::dbListTables(con)
DBI::dbDisconnect(con)
} # }
```
