# tsesql

**Banco de dados eleitorais TSE pré-carregado (PostgreSQL)** — camada de
persistência do [tsebr](https://github.com/DistintiveLab/tsebr): baixa
uma única vez, grava em um banco dedicado (`tsedb`) e serve consultas
rápidas por SQL/DBI. O painel [beep](https://github.com/DistintiveLab/beep)
consulta este banco em vez de re-baixar da internet a cada uso.

```r
remotes::install_github("DistintiveLab/tsesql")

# inicializa o schema (idempotente)
tsesql::tsesql_init()

# carrega dados (baixa via tsebr, grava no banco)
tsesql::tsesql_carregar("candidatos", 2022, uf = "DF")
tsesql::tsesql_carregar("resultados", 2022, uf = "DF")

# consulta rápida (sem download)
tsesql::tsesql_resultados(2022, uf = "DF", cargo = "GOVERNADOR")
tsesql::tsesql_candidatos(2022, uf = "DF", cargo = "PRESIDENTE")
```

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
