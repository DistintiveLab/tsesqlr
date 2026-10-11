# Inicializa o schema do tsedb

Cria a tabela `cargas` (controle de idempotência) e os índices das
tabelas de dados que já existirem
([.indices_tabelas](https://distintivelab.github.io/tsesqlr/reference/dot-indices_tabelas.md))
— caminho de upgrade para bancos carregados antes de haver índices. As
tabelas de dados em si são criadas dinamicamente no primeiro
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
[`tsesqlr_detalhe_municipio()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_detalhe_municipio.md),
[`tsesqlr_disponivel()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_disponivel.md),
[`tsesqlr_resultados()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_resultados.md),
[`tsesqlr_resultados_municipio()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_resultados_municipio.md)

## Examples

``` r
if (FALSE) { # \dontrun{
tsesqlr_init()
} # }
```
