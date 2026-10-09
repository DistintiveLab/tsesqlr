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

test_that("normalizar_tipo_pg unifica minusculas, maiusculas e apelidos", {
  norm <- tsesqlr:::.normalizar_tipo_pg
  expect_identical(norm(c("integer", "date", "text", "double precision")),
                   c("INTEGER", "DATE", "TEXT", "DOUBLE PRECISION"))
  expect_identical(norm(c("character varying", "character", "varchar")),
                   rep("TEXT", 3))
  expect_identical(norm(c("TIMESTAMPTZ", "timestamp with time zone")),
                   rep("TIMESTAMPTZ", 2))
})

test_that("data_type do Postgres e dbDataType do RPostgres passam a bater", {
  # O information_schema devolve minusculas, o dbDataType do RPostgres
  # maiusculas: sem normalizar os dois lados a comparacao dava FALSE em
  # todas as colunas e a tabela era recriada a cada carga.
  norm <- tsesqlr:::.normalizar_tipo_pg
  pg <- c("integer", "date", "text", "integer", "text", "integer",
          "text", "integer", "text", "double precision")
  dbi <- c("INTEGER", "DATE", "TEXT", "INTEGER", "TEXT", "INTEGER",
           "TEXT", "INTEGER", "TEXT", "DOUBLE PRECISION")
  expect_true(isTRUE(all(norm(pg) == norm(dbi))))
})

test_that("normalizar_tipo_pg nao confunde tipos diferentes", {
  norm <- tsesqlr:::.normalizar_tipo_pg
  expect_false(norm("integer") == norm("boolean"))
  expect_false(norm("text") == norm("integer"))
})

test_that("extracao truncada de ZIP vira erro em vez de carga parcial", {
  # Util::unzip avisa "write error" quando nao consegue escrever o CSV
  # extraido (falta de espaco em tempdir(), na pratica a cota de disco
  # do usuario). O tse_read engole o problema com try(silent = TRUE), o
  # fread le o arquivo cortado e a carga termina sem erro com menos
  # linhas: dado perdido em silencio.
  expect_error(
    tsesqlr:::.ler_tsebr(warning("write error in extracting from zip file"),
                         "resultados 2026 SP"),
    "extracao incompleta do ZIP em resultados 2026 SP")
})

test_that("ler_tsebr deixa passar avisos que nao sao do ZIP", {
  # Um "single-line footer" benigno do fread nao pode derrubar a carga.
  expect_warning(
    tsesqlr:::.ler_tsebr(warning("Discarded single-line footer"), "x"),
    "Discarded single-line footer")
  expect_identical(tsesqlr:::.ler_tsebr(42L, "x"), 42L)
})
