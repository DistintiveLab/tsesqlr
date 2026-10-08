# Inicializa o schema do tsedb

Cria a tabela `cargas` (controle de idempotência). As tabelas de dados
são criadas dinamicamente no primeiro
[`tsesqlr_carregar()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_carregar.md)
com as colunas do data.frame do tsebr. Idempotente — pode ser chamado
quantas vezes necessário.

## Usage

``` r
tsesqlr_init(con = NULL)
```

## Arguments

- con:

  Conexao DBI; default abre via
  [`tsesqlr_con()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_con.md).

## Value

`invisible(TRUE)` se bem-sucedido.

## See also

Other tsesqlr:
[`tsesqlr_candidatos()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_candidatos.md),
[`tsesqlr_carregar()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_carregar.md),
[`tsesqlr_con()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_con.md),
[`tsesqlr_resultados()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_resultados.md)

## Examples

``` r
if (FALSE) { # \dontrun{
tsesqlr_init()
} # }
```
