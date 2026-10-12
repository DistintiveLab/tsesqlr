# Consulta rápida: detalhe por município (abstenções, aptos, ...)

Busca as métricas do detalhe (aptos, comparecimento, abstencoes,
votos_nulos, votos_brancos) na tabela `detalhe` pré-carregada e devolve
no formato longo do DW (`local`, `periodo`, `valor`, `uf`, `metrica`,
`turno`) — instantâneo depois de
[`tsesqlr_carregar()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_carregar.md).
Cada turno é um ponto próprio: `periodo` cai no domingo da eleição
daquele turno (2022: 02/10 e 30/10; 2026: 04/10). Com `mapa` (saída de
[`tsebr::tse_mapa_municipios()`](https://rdrr.io/pkg/tsebr/man/tse_mapa_municipios.html)),
`local` sai como código IBGE de 7 dígitos; sem mapa, como código TSE.

## Usage

``` r
tsesqlr_detalhe_municipio(ano, uf, metrica, mapa = NULL, con = NULL)
```

## Arguments

- ano:

  Ano eleitoral ou vetor de anos.

- uf:

  Sigla da UF.

- metrica:

  Uma das métricas do detalhe.

- mapa:

  `data.frame` com cod_municipio_tse e ibge (ou geoloc_id, como em
  [`tsebr::tse_mapa_municipios()`](https://rdrr.io/pkg/tsebr/man/tse_mapa_municipios.html)).

- con:

  Conexao DBI; default abre via
  [`tsesqlr_con()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_con.md).

## Value

`data.frame` long: local, periodo, valor, uf, metrica, turno.

## See also

[`tsesqlr_resultados_municipio()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_resultados_municipio.md)

Other tsesqlr:
[`tsesqlr_candidatos()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_candidatos.md),
[`tsesqlr_carregar()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_carregar.md),
[`tsesqlr_con()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_con.md),
[`tsesqlr_disponivel()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_disponivel.md),
[`tsesqlr_init()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_init.md),
[`tsesqlr_resultados()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_resultados.md),
[`tsesqlr_resultados_municipio()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_resultados_municipio.md)

## Examples

``` r
if (FALSE) { # \dontrun{
tsesqlr_detalhe_municipio(2022, "DF", "abstencoes",
  mapa = tsebr::tse_mapa_municipios(2022, "DF"))
} # }
```
