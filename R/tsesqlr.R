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
    "carregado_em TIMESTAMP DEFAULT NOW(), n_linhas BIGINT,",
    "PRIMARY KEY (tabela, ano, uf))"))
  invisible(TRUE)
}

#' Siglas das 27 UFs (sem ZZ)
#' @keywords internal
.ufs_br <- c("AC", "AL", "AM", "AP", "BA", "CE", "DF", "ES", "GO",
             "MA", "MG", "MS", "MT", "PA", "PB", "PE", "PI", "PR",
             "RJ", "RN", "RO", "RR", "RS", "SC", "SE", "SP", "TO")

#' Colunas canonicas por tabela (esquema estavel entre anos/ciclos)
#' @keywords internal
.padrao_colunas <- list(
  resultados = c("ano", "periodo", "uf", "cod_municipio_tse", "municipio",
                 "turno", "cargo", "nr_votavel", "nm_votavel", "votos"),
  candidatos = c("ano", "uf", "cod_municipio_tse", "municipio", "sq_candidato",
                 "nome", "nome_urna", "nr_candidato", "partido", "cargo",
                 "situacao"),
  perfil_eleitorado = c("ano", "uf", "cod_municipio_tse", "zona", "secao",
                        "faixa_etaria", "escolaridade", "genero", "eleitores",
                        "eleitores_biometria"),
  locais_votacao = c("ano", "uf", "cod_municipio_tse", "municipio", "zona",
                     "secao", "local_votacao", "endereco", "bairro", "lat",
                     "lon", "eleitores_secao"))

#' Completa/ordena colunas do data.frame no esquema canonico
#' @keywords internal
.padronizar <- \(dados, colunas, ano) {
  dados <- as.data.frame(dados)
  if (!"ano" %in% names(dados)) dados$ano <- as.integer(ano)
  for (col in setdiff(colunas, names(dados))) dados[[col]] <- NA
  dados[, colunas, drop = FALSE]
}

#' Agrega o boletim de urna WEB por municipio/cargo/votavel
#' @keywords internal
.agregar_boletins <- \(ano, uf) {
  dados <- tsebr::tse_boletins(ano, uf)
  chaves <- intersect(c("uf", "cod_municipio_tse", "municipio", "turno",
                        "cargo", "nr_votavel", "nm_votavel", "periodo"),
                      names(dados))
  dados |>
    dplyr::select(dplyr::all_of(c(chaves, "votos"))) |>
    dplyr::mutate(votos = as.numeric(votos),
                  cargo = if ("cargo" %in% chaves) toupper(cargo)) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(chaves))) |>
    dplyr::summarise(votos = sum(votos, na.rm = TRUE), .groups = "drop") |>
    dplyr::mutate(ano = as.integer(ano))
}

#' Carrega dados eleitorais no tsedb
#'
#' Baixa dados via tsebr e grava no banco PostgreSQL. A tabela é criada
#' com as colunas canonicas do tipo (esquema estável entre anos/ciclos);
#' cargas subsequentes fazem DELETE do escopo (ano+UF) e INSERT limpo.
#'
#' Idempotente: se o escopo (tipo, ano, uf) já foi carregado (registro
#' em `cargas`), pula a menos que `refrescar = TRUE`.
#'
#' Para `resultados`: anos anteriores a 2026 agregam a votação por
#' seção a **município x turno x cargo x votável**, uma UF por vez
#' (o conjunto nacional por seção não cabe em memória — era a causa
#' de sessões do R mortas em `uf = "all"`); 2026+ usa o boletim de
#' urna WEB (bweb) do CKAN com a mesma granularidade. A tabela
#' `resultados` tem votos por município/candidato/cargo/turno.
#'
#' @param tipo Tipo de dado: `"candidatos"`, `"resultados"`,
#'   `"perfil"` ou `"locais"`.
#' @param ano Ano eleitoral (1996..2026).
#' @param uf Sigla da UF ou `"all"` para todas as 27 UFs.
#'   Para `"all"` em resultados, o download é pesado (vários GB).
#' @param con Conexao DBI; default abre via [tsesqlr_con()].
#' @param refrescar Forcar re-download mesmo se ja carregado. Se a
#'   tabela existir com layout antigo (ex.: resultados por seção),
#'   recria a tabela — recarregue as demais cargas dela depois.
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
  uf <- toupper(uf)
  invalida <- setdiff(uf, c(.ufs_br, "ALL"))
  if (length(invalida)) {
    stop("tsesqlr: UF invalida: ", paste(invalida, collapse = ", "))
  }
  ## perfil e resultados-2026+ tem arquivo por UF: carregar UF a UF
  ## mantem a memoria bornada e da idempotencia incremental
  ## (carregar DF hoje, SP depois). resultados pre-2026 com ALL vai
  ## em carga unica: tse_votacao_municipio(uf="all") ja processa
  ## UF a UF internamente e le o zip BR (presidente) uma so vez.
  ## candidatos/locais sao nacionais: carga unica
  por_uf <- (tipo == "perfil" && identical(uf, "ALL")) ||
    (tipo == "resultados" && identical(uf, "ALL") && as.integer(ano) >= 2026)
  escopos <- if (por_uf) .ufs_br else uf
  total <- 0L
  for (esc in escopos) {
    total <- total + .carregar_um(tipo, as.integer(ano), esc, con, refrescar)
  }
  message(tipo, " ", ano, " ", uf, ": ", total, " linhas carregadas")
  invisible(total)
}

#' Carga de um escopo (tipo, ano, uf) — nucleo do [tsesqlr_carregar()]
#' @keywords internal
.carregar_um <- \(tipo, ano, uf, con, refrescar) {
  tabela <- switch(tipo,
                   candidatos = "candidatos", resultados = "resultados",
                   perfil = "perfil_eleitorado", locais = "locais_votacao")
  ja <- DBI::dbGetQuery(con, paste(
    "SELECT n_linhas FROM cargas WHERE tabela = $1 AND ano = $2 AND uf = $3"),
    params = list(tipo, ano, uf))
  if (nrow(ja) && !refrescar) {
    message(tipo, " ", ano, " ", uf, ": ja carregado (",
            ja$n_linhas, " linhas)")
    return(invisible(0L))
  }
  ## tsebr espera "all" minusculo; locais e nacional: sem recorte
  ## quando ALL (o filtro por uf apos a leitura esvaziaria a carga)
  uf_dados <- if (identical(uf, "ALL")) {
    if (tipo == "locais") NULL else "all"
  } else uf
  dados <- switch(tipo,
    candidatos = tsebr::tse_candidaturas(ano, uf = uf_dados),
    resultados = if (ano >= 2026) .agregar_boletins(ano, uf_dados) else
      tsebr::tse_votacao_municipio(ano, uf = uf_dados),
    perfil = tsebr::tse_perfis_secao(ano, uf = uf_dados),
    locais = tsebr::tse_locais_votacao(ano, uf = uf_dados))
  ## padroniza nomes de colunas-chave (tsebr conforma parcialmente)
  renomear <- c(ANO_ELEICAO = "ano", SG_UE = "cod_municipio_tse",
                NM_UE = "municipio", SG_UF = "uf",
                NR_VOTAVEL = "nr_votavel", NM_VOTAVEL = "nm_votavel",
                QT_VOTOS = "votos")
  for (de in names(renomear)) {
    if (de %in% names(dados)) names(dados)[names(dados) == de] <- renomear[[de]]
  }
  dados <- .padronizar(dados, .padrao_colunas[[tabela]], ano)
  existe <- DBI::dbGetQuery(con, paste(
    "SELECT 1 FROM information_schema.tables WHERE table_name = $1"),
    params = list(tabela))
  if (nrow(existe)) {
    atuais <- DBI::dbListFields(con, tabela)
    if (!setequal(atuais, names(dados))) {
      if (!refrescar) {
        stop("tsesqlr: tabela '", tabela, "' foi carregada com outro ",
             "layout (", paste(atuais, collapse = ", "),
             "); use refrescar = TRUE para recria-la com o esquema ",
             "atual (as outras cargas desta tabela precisam ser ",
             "recarregadas em seguida)")
      }
      warning("tsesqlr: recriando a tabela '", tabela,
              "' (layout antigo); cargas anteriores dela foram perdidas")
      DBI::dbExecute(con, paste("DROP TABLE", tabela))
      DBI::dbExecute(con, "DELETE FROM cargas WHERE tabela = $1",
                     params = list(tipo))
      existe <- data.frame()
    }
  }
  if (nrow(existe)) {
    ## escopo ALL remove so o ano (as linhas carregam a UF real)
    if (identical(uf, "ALL")) {
      DBI::dbExecute(con, paste("DELETE FROM", tabela, "WHERE ano = $1"),
                     params = list(ano))
    } else {
      DBI::dbExecute(con, paste(
        "DELETE FROM", tabela, "WHERE ano = $1 AND uf = $2"),
        params = list(ano, uf))
    }
    DBI::dbWriteTable(con, tabela, as.data.frame(dados), append = TRUE)
  } else {
    DBI::dbWriteTable(con, tabela, as.data.frame(dados), append = FALSE)
  }
  ## carga ALL cobre as UFs individuais: registros per-UF do mesmo
  ## ano ficam obsoletos
  if (identical(uf, "ALL")) {
    DBI::dbExecute(con, "DELETE FROM cargas WHERE tabela = $1 AND ano = $2",
                   params = list(tipo, ano))
  }
  DBI::dbExecute(con, paste(
    "INSERT INTO cargas (tabela, ano, uf, n_linhas) VALUES ($1,$2,$3,$4)",
    "ON CONFLICT (tabela, ano, uf) DO UPDATE SET",
    "n_linhas = $4, carregado_em = NOW()"),
    params = list(tipo, ano, uf, nrow(dados)))
  message(tipo, " ", ano, " ", uf, ": ", nrow(dados), " linhas carregadas")
  nrow(dados)
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
