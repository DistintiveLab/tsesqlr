# Compara as colunas e os tipos de `dados` com o que existe em `information_schema`. Detecta tabelas criadas com layout antigo em que os nomes batem mas um tipo mudou (ex.: `turno BOOLEAN` vindo de um `NA` logico) — algo que [`DBI::dbWriteTable()`](https://dbi.r-dbi.org/reference/dbWriteTable.html) nao acusaria antes do COPY falhar.

Os dois lados da comparacao sao normalizados por
[`.normalizar_tipo_pg()`](https://distintivelab.github.io/tsesqlr/reference/dot-normalizar_tipo_pg.md):
sem isso o `data_type` do PostgreSQL (minusculo) nunca seria igual ao
retorno de
[`DBI::dbDataType()`](https://dbi.r-dbi.org/reference/dbDataType.html)
(maiusculo no RPostgres) e toda tabela seria julgada incompativel.

## Usage

``` r
.layout_compativel(con, tabela, dados)
```
