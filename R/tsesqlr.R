#' tsesqlr: banco de dados eleitorais TSE pré-carregado (PostgreSQL)
#'
#' Camada de persistência para o pacote
#' \href{https://github.com/DistintiveLab/tsebr}{tsebr}: baixa dados
#' eleitorais uma única vez, grava em um banco PostgreSQL dedicado
#' (`tsedb`) e serve consultas rápidas por SQL/DBI. O painel
#' \href{https://github.com/DistintiveLab/beep}{beep} consulta este
#' banco em vez de re-baixar da internet a cada uso — padrão
#' inspirado no
#' \href{https://github.com/rodrigoesborges/raisqlr}{raisqlr}.
#'
#' @section Fluxo de uso:
#' \preformatted{
#' tsesqlr_init()
#' tsesqlr_carregar("candidatos", 2022, uf = "DF")
#' tsesqlr_carregar("resultados", 2026, uf = "DF")
#' tsesqlr_resultados(2026, "DF", cargo = "GOVERNADOR")
#' }
#'
#' @section Tabelas:
#' \itemize{
#'   \item \code{candidatos} — candidaturas por ano/UF
#'   \item \code{resultados} — votos por município/candidato/cargo/turno
#'   \item \code{perfil_eleitorado} — eleitores por seção (faixa etária, escolaridade, gênero)
#'   \item \code{locais_votacao} — seções com local, endereço, bairro, lat/lon
#'   \item \code{mapa_municipios} — correspondência TSE ↔ IBGE
#'   \item \code{cargas} — registro de cargas (idempotência)
#' }
#'
#' @section Credenciais:
#' As variáveis de ambiente (`.Renviron`) \code{user}, \code{password},
#' \code{host} e \code{dbname} controlam a conexão — mesmas variáveis
#' usadas pelo beep e pelo prepare_db.
#'
#' @keywords internal
#' @docType package
"_PACKAGE"

#' Conexão ao banco tsedb
#'
#' Abre conexão ao PostgreSQL dedicado aos dados eleitorais. As
#' credenciais vêm das variáveis de ambiente (`.Renviron`):
#' \code{user}, \code{password}, \code{host}, \code{dbname}.
#'
#' @param dbname Nome do banco; default "tsedb" (via env var \code{dbname}).
#' @return Objeto de conexão DBI (RPostgres).
#' @examples
#' \dontrun{
#' con <- tsesqlr_con()
#' DBI::dbListTables(con)
#' DBI::dbDisconnect(con)
#' }
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
#' Cria a tabela `cargas` (controle de idempotência). As tabelas de
#' dados são criadas dinamicamente no primeiro [tsesqlr_carregar()]
#' com as colunas do data.frame do tsebr. Idempotente — pode ser
#' chamado quantas vezes necessário.
#'
#' @param con Conexao DBI; default abre via [tsesqlr_con()].
#' @return `invisible(TRUE)` se bem-sucedido.
#' @examples
#' \dontrun{
#' tsesqlr_init()
#' }
#' @export
tsesqlr_init <- \(con = NULL) {
  .nossa <- is.null(con)
  if (.nossa) con <- tsesqlr_con()
  on.exit(if (.nossa) DBI::dbDisconnect(con), add = TRUE)
  DBI::dbExecute(con, paste(
    "CREATE TABLE IF NOT EXISTS cargas (",
    "tabela TEXT NOT NULL, ano INTEGER NOT NULL, uf TEXT NOT NULL,",
    "carregado_en TIMESTAMP DEFAULT NOW(), n_linhas BIGINT,",
    "PRIMARY KEY (tabela, ano, uf))"))
  invisible(TRUE)
}

#' Carrega dados eleitorais no tsedb
#'
#' Baixa dados via tsebr e grava no banco PostgreSQL. A tabela é criada
#' dinamicamente com as colunas do data.frame na primeira carga; cargas
#' subsequentes fazem DELETE do escopo (ano+UF) e INSERT limpo.
#'
#' Idempotente: se o escopo (tipo, ano, uf) já foi carregado (registro
#' em `cargas`), pula a menos que `refrescar = TRUE`.
#'
#' Para 2026 em diante, resultados usam o boletim de urna WEB (bweb)
#' do CKAN — o dataset `resultados-2026` ainda não publicou os CSVs
#' tradicionais de votacao_secao. Para anos anteriores, usa os zips
#' padrão do CDN.
#'
#' @param tipo Tipo de dado: `"candidatos"`, `"resultados"`,
#'   `"perfil"` ou `"locais"`.
#' @param ano Ano eleitoral (1996..2026).
#' @param uf Sigla da UF ou `"all"` para todas as 27 UFs.
#'   Para `"all"` em resultados, o download é pesado (vários GB).
#' @param con Conexao DBI; default abre via [tsesqlr_con()].
#' @param refrescar Forcar re-download mesmo se ja carregado.
#'   Default FALSE.
#' @return Número de linhas carregadas, invisível.
#' @examples
#' \dontrun{
#' tsesqlr_init()
#' tsesqlr_carregar("candidatos", 2022, uf = "DF")
#' tsesqlr_carregar("resultados", 2026, uf = "DF")
#' }
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
    resultados = if (ano >= 2026) tsebr::tse_boletins(ano, uf = uf) else
      tsebr::tse_resultados_municipio(ano, uf = uf),
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
    "n_linhas = $4, carregado_en = NOW()"),
    params = list(tipo, as.integer(ano), toupper(uf), nrow(dados)))
  message(tipo, " ", ano, " ", uf, ": ", nrow(dados), " linhas carregadas")
  invisible(nrow(dados))
}

#' Consulta rápida: resultados por município
#'
#' Busca votos por candidato/cargo/turno no banco pré-carregado.
#' Instantâneo após a primeira carga via [tsesqlr_carregar()].
#'
#' @param ano Ano eleitoral.
#' @param uf Sigla da UF.
#' @param cargo Regex de cargo (ex.: "GOVERNADOR", "PRESIDENTE",
#'   case-insensitive). Default: todos.
#' @param nr_votavel Número do candidato/partido (ex.: 13). Default: todos.
#' @param con Conexao DBI; default abre via [tsesqlr_con()].
#' @return `data.frame` com votos por município/candidato.
#' @examples
#' \dontrun{
#' tsesqlr_resultados(2026, "DF", cargo = "GOVERNADOR")
#' tsesqlr_resultados(2022, "SP", nr_votavel = 13)
#' }
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

#' Consulta rápida: candidaturas
#'
#' Busca candidaturas no banco pré-carregado. Cada linha é um
#' candidato em um pleito (chave: SQ_CANDIDATO).
#'
#' @param ano Ano eleitoral.
#' @param uf Sigla da UF.
#' @param cargo Regex de cargo (case-insensitive). Default: todos.
#' @param con Conexao DBI; default abre via [tsesqlr_con()].
#' @return `data.frame` com candidaturas.
#' @examples
#' \dontrun{
#' tsesqlr_candidatos(2026, "DF", cargo = "GOVERNADOR")
#' tsesqlr_candidatos(2022, "SP")
#' }
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
