# Confere que os dados lidos pertencem ao escopo de UF pedido

Rede de segurança contra leitura de arquivo errado: se o downloader
escolher o recurso de outra UF (foi o caso do bweb 2026, em que o
casamento por nome casou "PR" em "Primeiro turno" e gravou dados de AC
nos escopos PR/RN/RO), a carga aborta antes de apagar ou gravar qualquer
linha do banco.

## Usage

``` r
.verificar_uf_dados(dados, uf)
```
