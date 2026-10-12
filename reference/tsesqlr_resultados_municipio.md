# Consulta rápida: votos por município IBGE (contrato do DW beep)

Soma os votos da tabela `resultados` por município e devolve no formato
longo do DW (`local`, `periodo`, `valor`, `uf`) — mesmo contrato de
[`tsebr::tse_resultados_municipio()`](https://rdrr.io/pkg/tsebr/man/tse_resultados_municipio.html),
sem baixar nada: o dado já está no banco pré-carregado. Cada turno é um
`periodo` próprio: 1º turno no primeiro domingo de outubro e 2º no
último (2022: 02/10 e 30/10), em vez do ano-fim que somava os dois
turnos no mesmo ponto. Com `mapa` (saída de
[`tsebr::tse_mapa_municipios()`](https://rdrr.io/pkg/tsebr/man/tse_mapa_municipios.html)
ou `tse_municipios()`), `local` sai como código IBGE de 7 dígitos; sem
mapa, como código TSE.

## Usage

``` r
tsesqlr_resultados_municipio(
  ano,
  uf,
  cargo = NULL,
  nr_votavel = NULL,
  mapa = NULL,
  con = NULL
)
```

## Arguments

- ano:

  Ano eleitoral ou vetor de anos.

- uf:

  Sigla da UF.

- cargo:

  Regex de cargo (case-insensitive). Default: todos.

- nr_votavel:

  Número do candidato/partido. Default: todos.

- mapa:

  `data.frame` com cod_municipio_tse e ibge (ou geoloc_id, como em
  [`tsebr::tse_mapa_municipios()`](https://rdrr.io/pkg/tsebr/man/tse_mapa_municipios.html)).

- con:

  Conexao DBI; default abre via
  [`tsesqlr_con()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_con.md).

## Value

`data.frame` long: local, periodo, valor, uf.

## See also

[`tsesqlr_resultados()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_resultados.md)
para os detalhes por cargo/turno.

Other tsesqlr:
[`tsesqlr_candidatos()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_candidatos.md),
[`tsesqlr_carregar()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_carregar.md),
[`tsesqlr_con()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_con.md),
[`tsesqlr_detalhe_municipio()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_detalhe_municipio.md),
[`tsesqlr_disponivel()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_disponivel.md),
[`tsesqlr_init()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_init.md),
[`tsesqlr_resultados()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_resultados.md)

## Examples

``` r
if (FALSE) { # \dontrun{
tsesqlr_resultados_municipio(2022, "DF", cargo = "PRESIDENTE",
  nr_votavel = 13, mapa = tsebr::tse_mapa_municipios(2022, "DF"))
} # }
```
