# Valida o ano pedido para a tabela `resultados`

Falha antes de abrir conexao e de baixar qualquer arquivo. Sem isso o
pedido so morre no meio da carga com um 404 cru do CDN
(`tse_download: falha ao baixar ...`), que nao diz que o conjunto
simplesmente nao existe para aquele ano.

## Usage

``` r
.verificar_ano_resultados(ano)
```
