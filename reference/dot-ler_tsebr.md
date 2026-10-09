# Le dados do tsebr transformando extracao truncada de ZIP em erro

[`tsebr::tse_read()`](https://rdrr.io/pkg/tsebr/man/tse_read.html)
extrai o ZIP com `try(utils::unzip(...), silent = TRUE)`. Se a extracao
falhar no meio (tipicamente falta de espaco em
[`tempdir()`](https://rdrr.io/r/base/tempfile.html), que o `unzip`
reporta como *write error*), a funcao segue adiante e o
[`data.table::fread()`](https://rdrr.io/pkg/data.table/man/fread.html)
le o CSV cortado, ainda descartando a ultima linha parcial como
"single-line footer". A carga termina sem erro nenhum e com menos linhas
do que deveria: perda de dados silenciosa. Aqui o aviso do `unzip` vira
erro.

## Usage

``` r
.ler_tsebr(expr, escopo)
```

## Arguments

- expr:

  Chamada de leitura do tsebr (avaliada com `expr`).

- escopo:

  Texto do escopo em carga, usado na mensagem de erro.

## Details

Todo leitor do tsebr passa por `tse_read()`, entao envolver a chamada de
leitura uma vez cobre boletins, votacao_secao, candidaturas, perfis e
locais.
