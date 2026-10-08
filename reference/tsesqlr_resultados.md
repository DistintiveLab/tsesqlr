# Consulta rápida: resultados por município

Busca votos por candidato/cargo/turno no banco pré-carregado.
Instantâneo após a primeira carga via
[`tsesqlr_carregar()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_carregar.md).

## Usage

``` r
tsesqlr_resultados(ano, uf, cargo = NULL, nr_votavel = NULL, con = NULL)
```

## Arguments

- ano:

  Ano eleitoral.

- uf:

  Sigla da UF.

- cargo:

  Regex de cargo (ex.: "GOVERNADOR", "PRESIDENTE", case-insensitive).
  Default: todos.

- nr_votavel:

  Número do candidato/partido (ex.: 13). Default: todos.

- con:

  Conexao DBI; default abre via
  [`tsesqlr_con()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_con.md).

## Value

`data.frame` com votos por município/candidato.

## See also

[`tsesqlr_candidatos()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_candidatos.md)

Other tsesqlr:
[`tsesqlr_candidatos()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_candidatos.md),
[`tsesqlr_carregar()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_carregar.md),
[`tsesqlr_con()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_con.md),
[`tsesqlr_init()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_init.md)

## Examples

``` r
if (FALSE) { # \dontrun{
tsesqlr_resultados(2026, "DF", cargo = "GOVERNADOR")
tsesqlr_resultados(2022, "SP", nr_votavel = 13)
} # }
```
