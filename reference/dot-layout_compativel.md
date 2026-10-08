# Verifica se a tabela do banco casa com nomes e tipos dos dados

Compara as colunas e os tipos de `dados` com o que existe em
`information_schema`. Detecta tabelas criadas com layout antigo em que
os nomes batem mas um tipo mudou (ex.: `turno BOOLEAN` vindo de um `NA`
logico) — algo que
[`DBI::dbWriteTable()`](https://dbi.r-dbi.org/reference/dbWriteTable.html)
nao acusaria antes do COPY falhar.

## Usage

``` r
.layout_compativel(con, tabela, dados)
```
