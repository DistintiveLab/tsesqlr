#' tsesql: banco de dados eleitorais TSE pré-carregado
#'
#' Camada de persistência para o tsebr: baixa uma vez, grava em
#' PostgreSQL (tsedb) e serve consultas rápidas. O painel beep
#' consulta este banco em vez de re-baixar da internet.
#'
#' @keywords internal
#' @docType package
"_PACKAGE"

#' Conexão ao banco tsedb
#'
#' Abre a conexão ao PostgreSQL dedicado aos dados eleitorais.
#' As credenciais vêm das variáveis de ambiente (`.Renviron`):
#' `user`, `password`, `host`, `dbname` (default: tsedb).
#'
#' @param dbname Nome do banco; default "tsedb".
#' @param con Conexao existente (para reutilizar).
#' @return Conexao DBI.
#' @export
tsesql_con <- \(dbname = "tsedb", con = NULL) {
  if (!is.null(con)) return(con)
  DBI::dbConnect(
    RPostgres::Postgres(),
    user = Sys.getenv("user", "beep"),
    password = Sys.getenv("password", "aEd1#man@gR"),
    host = Sys.getenv("host", "127.0.0.1"),
    dbname = Sys.getenv("dbname", dbname))
}

#' Inicializa o schema do tsedb
#'
#' Cria as tabelas se ainda não existirem (idempotente):
#' `candidatos`, `resultados`, `perfil_eleitorado`, `locais_votacao`,
#' `mapa_municipios`.
#'
#' @param con Conexao; default abre via [tsesql_con()].
#' @export
tsesql_init <- \(con = NULL) {
  .con_nossa <- is.null(con)
  if (.con_nossa) con <- tsesql_con()
  on.exit(if (.con_nossa) DBI::dbDisconnect(con), add = TRUE)

  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS candidatos (
      ano INTEGER NOT NULL,
      uf TEXT NOT NULL,
      cod_municipio_tse TEXT,
      municipio TEXT,
      sq_candidato TEXT,
      nr_candidato TEXT,
      nome TEXT, nome_urna TEXT,
      partido TEXT, cargo TEXT, situacao TEXT,
      PRIMARY KEY (ano, uf, sq_candidato)
    )")

  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS resultados (
      ano INTEGER NOT NULL,
      uf TEXT NOT NULL,
      cod_municipio_tse TEXT,
      nr_votavel TEXT,
      nm_votavel TEXT,
      cargo TEXT,
      turno INTEGER DEFAULT 1,
      votos BIGINT,
      PRIMARY KEY (ano, uf, cod_municipio_tse, nr_votavel, cargo, turno)
    )")

  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS perfil_eleitorado (
      ano INTEGER NOT NULL,
      uf TEXT NOT NULL,
      cod_municipio_tse TEXT,
      zona TEXT, secao TEXT,
      faixa_etaria TEXT, escolaridade TEXT, genero TEXT,
      eleitores BIGINT,
      PRIMARY KEY (ano, uf, cod_municipio_tse, zona, secao, faixa_etaria, escolaridade, genero)
    )")

  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS locais_votacao (
      ano INTEGER NOT NULL,
      uf TEXT NOT NULL,
      zona TEXT, secao TEXT,
      local TEXT, endereco TEXT, bairro TEXT,
      lat DOUBLE PRECISION, lon DOUBLE PRECISION,
      eleitores_secao BIGINT,
      PRIMARY KEY (ano, uf, zona, secao)
    )")

  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS mapa_municipios (
      cod_municipio_tse TEXT PRIMARY KEY,
      municipio TEXT, uf TEXT,
      geoloc_id BIGINT, empate BOOLEAN DEFAULT FALSE
    )")

  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS cargas (
      tabela TEXT NOT NULL,
      ano INTEGER NOT NULL,
      uf TEXT NOT NULL,
      carregado_em TIMESTAMP DEFAULT NOW(),
      n_linhas BIGINT,
      PRIMARY KEY (tabela, ano, uf)
    )")

  invisible(TRUE)
}

#' Carrega dados eleitorais no tsedb
#'
#' Baixa via tsebr e grava no banco. Idempotente: se já foi carregado
#' (registro em `cargas`), pula a menos que `refrescar = TRUE`.
#'
#' @param tipo "candidatos", "resultados", "perfil", "locais".
#' @param ano Ano eleitoral.
#' @param uf Sigla da UF ou "all".
#' @param con Conexao; default abre.
#' @param refrescar Forcar re-download mesmo se ja carregado.
#' @export
tsesql_carregar <- \(tipo = c("candidatos", "resultados", "perfil", "locais"),
                      ano, uf = "all", con = NULL, refrescar = FALSE) {
  tipo <- match.arg(tipo)
  .con_nossa <- is.null(con)
  if (.con_nossa) con <- tsesql_con()
  on.exit(if (.con_nossa) DBI::dbDisconnect(con), add = TRUE)

  ja <- DBI::dbGetQuery(con, paste(
    "SELECT n_linhas FROM cargas WHERE tabela = $1 AND ano = $2 AND uf = $3"),
    params = list(tipo, as.integer(ano), toupper(uf)))
  if (nrow(ja) && !refrescar) {
    message(tipo, " ", ano, " ", uf, ": ja carregado (", ja$n_linhas,
            " linhas) — use refrescar = TRUE para recarregar")
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

  DBI::dbWriteTable(con, tabela, as.data.frame(dados),
                   append = TRUE, overwrite = FALSE)

  DBI::dbExecute(con, paste(
    "INSERT INTO cargas (tabela, ano, uf, n_linhas) VALUES ($1,$2,$3,$4)",
    "ON CONFLICT (tabela, ano, uf) DO UPDATE SET",
    "n_linhas = $4, carregado_em = NOW()"),
    params = list(tipo, as.integer(ano), toupper(uf), nrow(dados)))

  message(tipo, " ", ano, " ", uf, ": ", nrow(dados), " linhas carregadas")
  invisible(nrow(dados))
}

#' Consulta rápida: resultados por município
#'
#' @param ano Ano eleitoral.
#' @param uf Sigla da UF.
#' @param cargo Regex de cargo (opcional).
#' @param nr_votavel Numero do candidato (opcional).
#' @param con Conexao; default abre.
#' @return `data.frame` com votos por município/candidato.
#' @export
tsesql_resultados <- \(ano, uf, cargo = NULL, nr_votavel = NULL,
                       con = NULL) {
  .con_nossa <- is.null(con)
  if (.con_nossa) con <- tsesql_con()
  on.exit(if (.con_nossa) DBI::dbDisconnect(con), add = TRUE)

  sql <- "SELECT * FROM resultados WHERE ano = $1 AND uf = $2"
  params <- list(as.integer(ano), toupper(uf))
  if (!is.null(cargo)) {
    sql <- paste(sql, "AND cargo ~* $3")
    params$cargo <- cargo
  }
  if (!is.null(nr_votavel)) {
    sql <- paste(sql, "AND nr_votavel = $4")
    params$nr_votavel <- as.character(nr_votavel)
  }
  DBI::dbGetQuery(con, sql, params = params)
}

#' Consulta rápida: candidaturas
#'
#' @param ano Ano eleitoral.
#' @param uf Sigla da UF.
#' @param cargo Regex de cargo (opcional).
#' @param con Conexao; default abre.
#' @return `data.frame` com candidaturas.
#' @export
tsesql_candidatos <- \(ano, uf, cargo = NULL, con = NULL) {
  .con_nossa <- is.null(con)
  if (.con_nossa) con <- tsesql_con()
  on.exit(if (.con_nossa) DBI::dbDisconnect(con), add = TRUE)

  sql <- "SELECT * FROM candidatos WHERE ano = $1 AND uf = $2"
  params <- list(as.integer(ano), toupper(uf))
  if (!is.null(cargo)) {
    sql <- paste(sql, "AND cargo ~* $3")
    params$cargo <- cargo
  }
  DBI::dbGetQuery(con, sql, params = params)
}
