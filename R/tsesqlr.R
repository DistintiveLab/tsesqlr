#' tsesqlr: banco de dados eleitorais TSE pré-carregado
#'
#' @keywords internal
#' @docType package
"_PACKAGE"

#' Conexão ao banco tsedb
#'
#' @param dbname Nome do banco; default "tsedb".
#' @export
tsesqlr_con <- \(dbname = "tsedb") {
  DBI::dbConnect(
    RPostgres::Postgres(),
    user = Sys.getenv("user", "beep"),
    password = Sys.getenv("password", "aEd1#man@gR"),
    host = Sys.getenv("host", "127.0.0.1"),
    dbname = Sys.getenv("dbname", dbname))
}

#' Inicializa o schema do tsedb
#'
#' @param con Conexao; default abre via [tsesqlr_con()].
#' @export
tsesqlr_init <- \(con = NULL) {
  .nossa <- is.null(con)
  if (.nossa) con <- tsesqlr_con()
  on.exit(if (.nossa) DBI::dbDisconnect(con), add = TRUE)
  DBI::dbExecute(con, paste(
    "CREATE TABLE IF NOT EXISTS cargas (",
    "tabela TEXT NOT NULL, ano INTEGER NOT NULL, uf TEXT NOT NULL,",
    "carregado_em TIMESTAMP DEFAULT NOW(), n_linhas BIGINT,",
    "PRIMARY KEY (tabela, ano, uf))"))
  invisible(TRUE)
}

#' Carrega dados eleitorais no tsedb
#'
#' @param tipo "candidatos", "resultados", "perfil", "locais".
#' @param ano Ano eleitoral.
#' @param uf Sigla da UF ou "all".
#' @param con Conexao; default abre.
#' @param refrescar Forcar re-download mesmo se ja carregado.
#' @export
tsesqlr_carregar <- \(tipo = c("candidatos", "resultados", "perfil", "locais"),
                      ano, uf = "all", con = NULL, refrescar = FALSE) {
  tipo <- match.arg(tipo)
  .nossa <- is.null(con)
  if (.nossa) con <- tsesqlr_con()
  on.exit(if (.nossa) DBI::dbDisconnect(con), add = TRUE)
  ja <- DBI::dbGetQuery(con, paste(
    "SELECT n_linhas FROM cargas WHERE tabela = $1 AND ano = $2 AND uf = $3"),
    params = list(tipo, as.integer(ano), toupper(uf)))
  if (nrow(ja) && !refrescar) {
    message(tipo, " ", ano, " ", uf, ": ja carregado (", ja$n_linhas, " linhas")
    return(invisible(ja$n_linhas))
  }
  dados <- switch(tipo,
    candidatos = tsebr::tse_candidaturas(ano, uf = uf),
    resultados = tsebr::tse_resultados_municipio(ano, uf = uf),
    perfil = tsebr::tse_perfis_secao(ano, uf = uf),
    locais = tsebr::tse_locais_votacao(ano, uf = uf))
  tabela <- switch(tipo,
    candidatos = "candidatos", resultados = "resultados",
    perfil = "perfil_eleitorado", locais = "locais_votacao")

  ## padroniza nomes de colunas-chave (tsebr conforma parcialmente)
  renomear <- c(ANO_ELEICAO = "ano", SG_UE = "cod_municipio_tse",
                NM_UE = "municipio", SG_UF = "uf",
                NR_VOTAVEL = "nr_votavel", NM_VOTAVEL = "nm_votavel",
                QT_VOTOS = "votos")
  for (de in names(renomear)) {
    if (de %in% names(dados)) names(dados)[names(dados) == de] <- renomear[[de]]
  }
  existe <- DBI::dbGetQuery(con, paste(
    "SELECT 1 FROM information_schema.tables WHERE table_name = $1"),
    params = list(tabela))
  if (nrow(existe)) {
    DBI::dbExecute(con, paste(
      "DELETE FROM", tabela, "WHERE ano = $1 AND uf = $2"),
      params = list(as.integer(ano), toupper(uf)))
    DBI::dbWriteTable(con, tabela, as.data.frame(dados), append = TRUE)
  } else {
    DBI::dbWriteTable(con, tabela, as.data.frame(dados), append = FALSE)
  }
  DBI::dbExecute(con, paste(
    "INSERT INTO cargas (tabela, ano, uf, n_linhas) VALUES ($1,$2,$3,$4)",
    "ON CONFLICT (tabela, ano, uf) DO UPDATE SET",
    "n_linhas = $4, carregado_em = NOW()"),
    params = list(tipo, as.integer(ano), toupper(uf), nrow(dados)))
  message(tipo, " ", ano, " ", uf, ": ", nrow(dados), " linhas carregadas")
  invisible(nrow(dados))
}

#' Consulta: resultados por município
#' @param ano Ano, uf UF, cargo regex, nr_votavel numero, con conexao
#' @export
tsesqlr_resultados <- \(ano, uf, cargo = NULL, nr_votavel = NULL, con = NULL) {
  .nossa <- is.null(con)
  if (.nossa) con <- tsesqlr_con()
  on.exit(if (.nossa) DBI::dbDisconnect(con), add = TRUE)
  sql <- "SELECT * FROM resultados WHERE ano = $1 AND uf = $2"
  params <- list(as.integer(ano), toupper(uf))
  if (!is.null(cargo)) { sql <- paste(sql, "AND cargo ~* $3"); params[[3]] <- cargo }
  if (!is.null(nr_votavel)) { sql <- paste(sql, "AND nr_votavel = $4"); params[[4]] <- as.character(nr_votavel) }
  DBI::dbGetQuery(con, sql, params = params)
}

#' Consulta: candidaturas
#' @param ano Ano, uf UF, cargo regex, con conexao
#' @export
tsesqlr_candidatos <- \(ano, uf, cargo = NULL, con = NULL) {
  .nossa <- is.null(con)
  if (.nossa) con <- tsesqlr_con()
  on.exit(if (.nossa) DBI::dbDisconnect(con), add = TRUE)
  sql <- "SELECT * FROM candidatos WHERE ano = $1 AND uf = $2"
  params <- list(as.integer(ano), toupper(uf))
  if (!is.null(cargo)) { sql <- paste(sql, "AND cargo ~* $3"); params[[3]] <- cargo }
  DBI::dbGetQuery(con, sql, params = params)
}
