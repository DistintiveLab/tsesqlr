# Escopo está carregado no banco? (decisão tsesqlr x tsebr no painel)

Verifica, sem nunca erro, se o banco responde e se TODOS os anos pedidos
do tipo/UF estão em `cargas` (registro `uf = 'ALL'` cobre qualquer UF).
É a peça que o painel beep usa para decidir entre consultar direto o
banco (rápido) ou cair no download via tsebr.

## Usage

``` r
tsesqlr_disponivel(
  tipo = c("resultados", "candidatos", "perfil", "locais", "detalhe"),
  ano,
  uf,
  con = NULL
)
```

## Arguments

- tipo:

  `"resultados"`, `"candidatos"`, `"perfil"` ou `"locais"` (valor da
  coluna `tabela` de `cargas`).

- ano:

  Ano eleitoral ou vetor — todos precisam estar carregados.

- uf:

  Sigla da UF.

- con:

  Conexao DBI; default abre via
  [`tsesqlr_con()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_con.md).

## Value

`TRUE`/`FALSE` (qualquer falha de conexão/credencial vira `FALSE`).

## See also

Other tsesqlr:
[`tsesqlr_candidatos()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_candidatos.md),
[`tsesqlr_carregar()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_carregar.md),
[`tsesqlr_con()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_con.md),
[`tsesqlr_detalhe_municipio()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_detalhe_municipio.md),
[`tsesqlr_init()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_init.md),
[`tsesqlr_resultados()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_resultados.md),
[`tsesqlr_resultados_municipio()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_resultados_municipio.md)

## Examples

``` r
if (FALSE) { # \dontrun{
if (tsesqlr_disponivel("resultados", 2022, "DF")) { ... }
} # }
```
