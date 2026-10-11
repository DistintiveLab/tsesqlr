# Anos com votacao por secao publicada pelo TSE

O CDN do TSE so tem `votacao_secao_<ano>_<UF>.zip` nos anos pares de
eleicao geral a partir de 1998. Antes disso (1994 e 1996) existe apenas
votacao agregada por municipio/zona
(`votacao_candidato_munzona_<ano>.zip`), sem detalhe por secao.

## Usage

``` r
.anos_resultados_secao
```

## Format

An object of class `integer` of length 14.
