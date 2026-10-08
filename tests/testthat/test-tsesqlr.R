# Testes offline: helpers puros da carga (sem banco e sem download).

test_that("ufs_br cobre as 27 UFs sem ZZ", {
  expect_length(tsesqlr:::.ufs_br, 27L)
  expect_false("ZZ" %in% tsesqlr:::.ufs_br)
  expect_true("DF" %in% tsesqlr:::.ufs_br)
})

test_that("padronizar completa colunas ausentes com NA e ordena", {
  d <- data.frame(uf = "DF", votos = 10L, extra = "x")
  pad <- tsesqlr:::.padronizar(d, tsesqlr:::.padrao_colunas$resultados, 2022)
  expect_named(pad, tsesqlr:::.padrao_colunas$resultados)
  expect_identical(pad$ano, 2022L)
  expect_identical(pad$votos, 10L)
  expect_true(all(is.na(pad$cargo)))
})

test_that("ano existente nao e sobrescrito pelo argumento", {
  d <- data.frame(ano = 2018L, votos = 1L)
  pad <- tsesqlr:::.padronizar(d, tsesqlr:::.padrao_colunas$resultados, 2022)
  expect_identical(unique(pad$ano), 2018L)
})

test_that("todas as tabelas tem esquema canonico definido", {
  expect_setequal(
    names(tsesqlr:::.padrao_colunas),
    c("resultados", "candidatos", "perfil_eleitorado", "locais_votacao"))
  for (cols in tsesqlr:::.padrao_colunas) {
    expect_true(all(c("ano", "uf") %in% cols))
    expect_false(any(duplicated(cols)))
  }
})

test_that("coluna ausente recebe NA do tipo canonico, nao logico", {
  # NA logico faz o Postgres criar a coluna como BOOLEAN (turno em 2026),
  # quebrando cargas seguintes com turno 1/2.
  d <- data.frame(uf = "DF", votos = 10L)
  pad <- tsesqlr:::.padronizar(d, tsesqlr:::.padrao_colunas$resultados, 2022)
  expect_type(pad$turno, "integer")
  expect_true(inherits(pad$periodo, "Date"))
  expect_type(pad$cargo, "character")
  expect_false(is.logical(pad$turno))
})

test_that("tipos canonicos cobrem todas as colunas do esquema", {
  todas <- unique(unlist(tsesqlr:::.padrao_colunas))
  expect_setequal(names(tsesqlr:::.tipos_colunas), todas)
  expect_true(all(tsesqlr:::.tipos_colunas %in%
                    c("integer", "numeric", "character", "Date")))
})
