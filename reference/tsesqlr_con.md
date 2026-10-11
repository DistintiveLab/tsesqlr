# Conexão ao banco tsedb

Abre conexão ao PostgreSQL dedicado aos dados eleitorais. As credenciais
vêm das variáveis de ambiente (`.Renviron`): `user`, `password`, `host`
(mesmo servidor do DW beep) e `tsedbname` para o NOME deste banco
(default `"tsedb"`) — variável própria para não conflitar com o `dbname`
do DW na mesma sessão.

## Usage

``` r
tsesqlr_con(dbname = Sys.getenv("tsedbname", "tsedb"))
```

## Arguments

- dbname:

  Nome do banco; default resolve `tsedbname` (fallback "tsedb").

## Value

Objeto de conexão DBI (RPostgres).

## See also

Other tsesqlr:
[`tsesqlr_candidatos()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_candidatos.md),
[`tsesqlr_carregar()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_carregar.md),
[`tsesqlr_disponivel()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_disponivel.md),
[`tsesqlr_init()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_init.md),
[`tsesqlr_resultados()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_resultados.md),
[`tsesqlr_resultados_municipio()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_resultados_municipio.md)

## Examples

``` r
if (FALSE) { # \dontrun{
con <- tsesqlr_con()
DBI::dbListTables(con)
DBI::dbDisconnect(con)
} # }
```
