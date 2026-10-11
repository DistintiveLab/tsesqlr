# Indices das tabelas de dados

`resultados` cresce a centenas de MB por ano e toda consulta do pacote
filtra `ano` (+`uf`): sem indice cada uma varre a tabela inteira. Medido
contra o banco real (4,6M linhas, 645 MB): `ano+uf` em SP cai de 623 ms
para 80 ms, e em UF pequena de 227 ms para 0,3 ms. Um indice de
cobertura para o GROUP BY custaria 242 MB e perdia do plano paralelo com
o indice simples de 31 MB. As demais tabelas sao pequenas demais para
valer um indice proprio.

## Usage

``` r
.indices_tabelas
```

## Format

An object of class `list` of length 1.
