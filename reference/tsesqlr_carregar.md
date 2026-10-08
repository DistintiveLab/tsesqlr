# Carrega dados eleitorais no tsedb

Baixa dados via tsebr e grava no banco PostgreSQL. A tabela é criada com
as colunas canonicas do tipo (esquema estável entre anos/ciclos); cargas
subsequentes fazem DELETE do escopo (ano+UF) e INSERT limpo.

## Usage

``` r
tsesqlr_carregar(
  tipo = c("candidatos", "resultados", "perfil", "locais"),
  ano,
  uf = "all",
  con = NULL,
  refrescar = FALSE
)
```

## Arguments

- tipo:

  Tipo de dado: `"candidatos"`, `"resultados"`, `"perfil"` ou
  `"locais"`.

- ano:

  Ano eleitoral (1996..2026).

- uf:

  Sigla da UF ou `"all"` para todas as 27 UFs. Para `"all"` em
  resultados, o download é pesado (vários GB).

- con:

  Conexao DBI; default abre via
  [`tsesqlr_con()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_con.md).

- refrescar:

  Forcar re-download mesmo se ja carregado. Se a tabela existir com
  layout antigo (ex.: resultados por seção), recria a tabela —
  recarregue as demais cargas dela depois.

## Value

Número de linhas carregadas, invisível.

## Details

Idempotente: se o escopo (tipo, ano, uf) já foi carregado (registro em
`cargas`), pula a menos que `refrescar = TRUE`.

Para `resultados`: anos anteriores a 2026 agregam a votação por seção a
**município x turno x cargo x votável**, uma UF por vez (o conjunto
nacional por seção não cabe em memória — era a causa de sessões do R
mortas em `uf = "all"`); 2026+ usa o boletim de urna WEB (bweb) do CKAN
com a mesma granularidade. A tabela `resultados` tem votos por
município/candidato/cargo/turno.

## See also

Other tsesqlr:
[`tsesqlr_candidatos()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_candidatos.md),
[`tsesqlr_con()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_con.md),
[`tsesqlr_init()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_init.md),
[`tsesqlr_resultados()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_resultados.md)

## Examples

``` r
if (FALSE) { # \dontrun{
tsesqlr_init()
tsesqlr_carregar("candidatos", 2022, uf = "DF")
tsesqlr_carregar("resultados", 2026, uf = "DF")
} # }
```
