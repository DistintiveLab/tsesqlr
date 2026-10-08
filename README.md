# tsesqlr

**Banco de dados eleitorais TSE pré-carregado (PostgreSQL)** — camada de
persistência do [tsebr](https://github.com/DistintiveLab/tsebr): baixa
uma única vez, grava em um banco dedicado (`tsedb`) e serve consultas
rápidas por SQL/DBI. O painel [beep](https://github.com/DistintiveLab/beep)
consulta este banco em vez de re-baixar da internet a cada uso.

```r
remotes::install_github("DistintiveLab/tsesqlr")

# inicializa o schema (idempotente)
tsesqlr::tsesqlr_init()

# carrega dados (baixa via tsebr, grava no banco)
tsesqlr::tsesqlr_carregar("candidatos", 2022, uf = "DF")
tsesqlr::tsesqlr_carregar("resultados", 2022, uf = "DF")
tsesqlr::tsesqlr_carregar("resultados", 2022)          # nacional, UF a UF em memoria

# consulta rápida (sem download)
tsesqlr::tsesqlr_resultados(2022, uf = "DF", cargo = "GOVERNADOR")
tsesqlr::tsesqlr_candidatos(2022, uf = "DF", cargo = "PRESIDENTE")
```

## Carga com memoria bornada

`resultados` agrega a votação por seção a **município x turno x cargo x
votável** processando um arquivo por vez (a seção nacional inteira não
cabe em memória — era a causa de sessões do R mortas com `uf = "all"`).
O voto por seção continua disponível no arquivo cru via tsebr
(`tsebr::tse_boletins()`, `tsebr::tse_read()`). Para 2026+ o insumo é o
boletim de urna WEB (bweb) do CKAN, agregado à mesma granularidade.
Cargas são idempotentes por escopo (`tipo`, `ano`, `uf`); `perfil` e
`resultados` 2026+ carregam UF a UF (dá para incrementar DF hoje, SP
depois). Cada tabela tem colunas canônicas fixas — se ela existir com
layout antigo, a carga pede `refrescar = TRUE` (recria a tabela).

## Tabelas

| Tabela | Conteúdo |
|---|---|
| `candidatos` | candidaturas por ano/UF (SQ_CANDIDATO é a chave) |
| `resultados` | votos por município/candidato/cargo/turno |
| `perfil_eleitorado` | eleitores por seção com faixa etária/escolaridade/gênero |
| `locais_votacao` | seções com local, endereço, bairro, lat/lon |
| `mapa_municipios` | correspondência TSE ↔ IBGE |
| `cargas` | registro de cargas (idempotência) |

MIT © 2026 DistintiveLab.
