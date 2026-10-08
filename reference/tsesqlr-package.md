# tsesqlr: banco de dados eleitorais TSE pré-carregado (PostgreSQL)

Camada de persistência para o pacote
[tsebr](https://github.com/DistintiveLab/tsebr): baixa dados eleitorais
uma única vez, grava em um banco PostgreSQL dedicado (`tsedb`) e serve
consultas rápidas por SQL/DBI. O painel
[beep](https://github.com/DistintiveLab/beep) consulta este banco em vez
de re-baixar da internet a cada uso — padrão inspirado no
[raisqlr](https://github.com/rodrigoesborges/raisqlr).

## Fluxo de uso


    tsesqlr_init()
    tsesqlr_carregar("candidatos", 2022, uf = "DF")
    tsesqlr_carregar("resultados", 2026, uf = "DF")
    tsesqlr_resultados(2026, "DF", cargo = "GOVERNADOR")

## Tabelas

- `candidatos` — candidaturas por ano/UF

- `resultados` — votos por município/candidato/cargo/turno

- `perfil_eleitorado` — eleitores por seção (faixa etária, escolaridade,
  gênero)

- `locais_votacao` — seções com local, endereço, bairro, lat/lon

- `mapa_municipios` — correspondência TSE ↔ IBGE

- `cargas` — registro de cargas (idempotência)

## Credenciais

As variáveis de ambiente (`.Renviron`) `user`, `password`, `host` e
`dbname` controlam a conexão — mesmas variáveis usadas pelo beep e pelo
prepare_db.

## See also

Useful links:

- <https://github.com/DistintiveLab/tsesqlr>

- <https://distintivelab.github.io/tsesqlr>

- Report bugs at <https://github.com/DistintiveLab/tsesqlr/issues>

## Author

**Maintainer**: DistintiveLab <contato@distintive.com.br>
