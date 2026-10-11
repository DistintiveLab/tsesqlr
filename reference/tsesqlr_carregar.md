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

  Ano eleitoral. Para `"resultados"`, apenas 1998..2024 (pares) e 2026+;
  os demais valores abortam antes do download.

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

`resultados` só existe onde o TSE publica votação por seção: anos pares
de eleição geral de 1998 a 2024 (`votacao_secao_<ano>_<UF>.zip`) e 2026
em diante (boletim de urna WEB). Anos ímpares, anteriores a 1998 ou fora
do calendário eleitoral abortam na hora, antes de qualquer download, com
a lista de anos válidos
([`.verificar_ano_resultados()`](https://distintivelab.github.io/tsesqlr/reference/dot-verificar_ano_resultados.md)).
Em 1994 e 1996 o TSE só tem votação agregada por município/zona
(`votacao_candidato_munzona`), sem detalhe por seção, que o tsesqlr
ainda não lê; para esses anos use `tipo = "candidatos"`, disponível
desde 1994.

Cada carga precisa de espaço em
[`tempdir()`](https://rdrr.io/r/base/tempfile.html), onde o tsebr extrai
o ZIP baixado antes de ler. O bweb de SP extrai 7,75 GiB, então
`uf = "ALL"` em 2026 exige vários GB. Isso é limitado pela cota de disco
do usuário (`quota -s`), não só pelo espaço livre mostrado por `df`:
numa máquina com cota, `/tmp` pode encher antes do resto do sistema.
Aponte `TMPDIR` no `.Renviron` para outro disco se `/tmp` estiver
apertado, e limpe `/tmp/Rtmp*` de sessões do R encerradas, que chegam
facilmente a dezenas de GB. Se a extração falhar no meio, a carga aborta
com erro (em vez de gravar um CSV cortado sem avisar); as UFs já
gravadas são puladas na chamada seguinte.

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
