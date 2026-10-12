# Data de cada turno da eleição geral (domingos de outubro)

1º turno: primeiro domingo de outubro; 2º turno: último domingo de
outubro (regra da Constituição). É o `periodo` gravado na tabela
`resultados` e devolvido no contrato do DW: cada turno é um ponto de
dados próprio (2022: 02/10 e 30/10; 2026: 04/10), em vez do ano-fim
(31/12), que juntava os dois turnos na mesma data.

## Usage

``` r
.periodo_eleicao(ano, turno)
```
