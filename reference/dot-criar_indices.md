# Cria os indices de uma tabela de dados, se ela existir

Chamado por
[`tsesqlr_init()`](https://distintivelab.github.io/tsesqlr/reference/tsesqlr_init.md)
(bancos antigos, atualizacao por upgrade) e por
[`.carregar_um()`](https://distintivelab.github.io/tsesqlr/reference/dot-carregar_um.md)
logo apos criar a tabela. O `IF NOT EXISTS` mantem tudo idempotente.

## Usage

``` r
.criar_indices(con, tabela)
```
