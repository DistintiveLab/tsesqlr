# Consulta rápida: candidaturas

Busca candidaturas no banco pré-carregado. Cada linha é um candidato em
um pleito (chave: SQ_CANDIDATO).

## Usage

``` r
tsesqlr_candidatos(ano, uf, cargo = NULL, con = NULL)
```

## Arguments

- ano:

  Ano eleitoral ou vetor de anos.

- uf:

  Sigla da UF.

- cargo:

  Regex de cargo (case-insensitive). Default: todos.

- con:

  Conexao DBI; default abre via
  [`tsesqlr_con()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_con.md).

## Value

`data.frame` com candidaturas.

## See also

[`tsesqlr_resultados()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_resultados.md)

Other tsesqlr:
[`tsesqlr_carregar()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_carregar.md),
[`tsesqlr_con()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_con.md),
[`tsesqlr_detalhe_municipio()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_detalhe_municipio.md),
[`tsesqlr_disponivel()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_disponivel.md),
[`tsesqlr_init()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_init.md),
[`tsesqlr_resultados()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_resultados.md),
[`tsesqlr_resultados_municipio()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_resultados_municipio.md)

## Examples

``` r
if (FALSE) { # \dontrun{
tsesqlr_candidatos(2026, "DF", cargo = "GOVERNADOR")
tsesqlr_candidatos(c(2022, 2026), "SP")
} # }
```
