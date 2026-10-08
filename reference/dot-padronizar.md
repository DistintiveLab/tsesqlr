# Completa/ordena colunas do data.frame no esquema canonico

As colunas ausentes sao preenchidas com `NA` do tipo canonico
(`.tipos_colunas`) — um `NA` logico faria o PostgreSQL criar a coluna
como `BOOLEAN` na primeira carga (ex.: `turno` em 2026), quebrando
cargas seguintes com valores de outro tipo.

## Usage

``` r
.padronizar(dados, colunas, ano)
```
