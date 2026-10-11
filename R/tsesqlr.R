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
#' \code{user}, \code{password}, \code{host} (mesmo servidor do DW
#' beep) e \code{tsedbname} para o NOME deste banco (default
#' \code{"tsedb"}) — variável própria para não conflitar com o
#' \code{dbname} do DW na mesma sessão.
#'
#' @param dbname Nome do banco; default resolve \code{tsedbname}
#'   (fallback "tsedb").
#' @return Objeto de conexão DBI (RPostgres).
#' @examples
#' \dontrun{
#' con <- tsesqlr_con()
#' DBI::dbListTables(con)
#' DBI::dbDisconnect(con)
#' }
#' @family tsesqlr
#' @export
tsesqlr_con <- \(dbname = Sys.getenv("tsedbname", "tsedb")) {
  DBI::dbConnect(
    RPostgres::Postgres(),
    user = Sys.getenv("user", "beep"),
    password = Sys.getenv("password", "aEd1#man@gR"),
    host = Sys.getenv("host", "127.0.0.1"),
    dbname = dbname)
}

#' Inicializa o schema do tsedb
#'
#' Cria a tabela `cargas` (controle de idempotência) e os índices
#' das tabelas de dados que já existirem ([.indices_tabelas]) —
#' caminho de upgrade para bancos carregados antes de haver
#' índices. As tabelas de dados em si são criadas dinamicamente no
#' primeiro [tsesqlr_carregar()] com as colunas do data.frame do
#' tsebr. Idempotente — pode ser chamado quantas vezes necessário.
#'
#' @param con Conexao DBI; default abre via [tsesqlr_con()].
#' @return `invisible(TRUE)` se bem-sucedido.
#' @examples
#' \dontrun{
#' tsesqlr_init()
#' }
#' @family tsesqlr
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
  for (tabela in names(.indices_tabelas)) .criar_indices(con, tabela)
  invisible(TRUE)
}

#' Siglas das 27 UFs (sem ZZ)
#' @keywords internal
.ufs_br <- c("AC", "AL", "AM", "AP", "BA", "CE", "DF", "ES", "GO",
             "MA", "MG", "MS", "MT", "PA", "PB", "PE", "PI", "PR",
             "RJ", "RN", "RO", "RR", "RS", "SC", "SE", "SP", "TO")

#' Indices das tabelas de dados
#'
#' `resultados` cresce a centenas de MB por ano e toda consulta do
#' pacote filtra `ano` (+`uf`): sem indice cada uma varre a tabela
#' inteira. Medido contra o banco real (4,6M linhas, 645 MB):
#' `ano+uf` em SP cai de 623 ms para 80 ms, e em UF pequena de
#' 227 ms para 0,3 ms. Um indice de cobertura para o GROUP BY
#' custaria 242 MB e perdia do plano paralelo com o indice simples
#' de 31 MB. As demais tabelas sao pequenas demais para valer um
#' indice proprio.
#' @keywords internal
.indices_tabelas <- list(
  resultados = "CREATE INDEX IF NOT EXISTS idx_resultados_ano_uf ON resultados (ano, uf)")

#' Cria os indices de uma tabela de dados, se ela existir
#'
#' Chamado por [tsesqlr_init()] (bancos antigos, atualizacao por
#' upgrade) e por `.carregar_um()` logo apos criar a tabela. O
#' `IF NOT EXISTS` mantem tudo idempotente.
#' @keywords internal
.criar_indices <- \(con, tabela) {
  sql <- .indices_tabelas[[tabela]]
  if (is.null(sql) || !DBI::dbExistsTable(con, tabela)) return(invisible(FALSE))
  DBI::dbExecute(con, sql)
  invisible(TRUE)
}

#' Anos com votacao por secao publicada pelo TSE
#'
#' O CDN do TSE so tem `votacao_secao_<ano>_<UF>.zip` nos anos pares de
#' eleicao geral a partir de 1998. Antes disso (1994 e 1996) existe
#' apenas votacao agregada por municipio/zona
#' (`votacao_candidato_munzona_<ano>.zip`), sem detalhe por secao.
#' @keywords internal
.anos_resultados_secao <- seq(1998L, 2024L, by = 2L)

#' Valida o ano pedido para a tabela `resultados`
#'
#' Falha antes de abrir conexao e de baixar qualquer arquivo. Sem isso o
#' pedido so morre no meio da carga com um 404 cru do CDN
#' (`tse_download: falha ao baixar ...`), que nao diz que o conjunto
#' simplesmente nao existe para aquele ano.
#' @keywords internal
.verificar_ano_resultados <- \(ano) {
  if (ano >= 2026L || ano %in% .anos_resultados_secao) return(invisible(ano))
  stop("tsesqlr: 'resultados' nao existe para ", ano, ". O TSE publica ",
       "votacao por secao apenas em ano de eleicao geral: ",
       paste(.anos_resultados_secao, collapse = ", "),
       " (um arquivo votacao_secao_<ano>_<UF>.zip por UF) e de 2026 em ",
       "diante pelo boletim de urna. Para 1994 e 1996 ha so a votacao ",
       "agregada por municipio/zona (votacao_candidato_munzona), sem ",
       "detalhe por secao, que o tsesqlr ainda nao le; nesses anos da ",
       "para carregar 'candidatos', que existe desde 1994. Para o ",
       "conjunto completo de anos de cada tipo veja ",
       "tsebr::tse_anos_disponiveis().")
}

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

#' Tipos canonicos das colunas (evita NA logico virar BOOLEAN no banco)
#' @keywords internal
.tipos_colunas <- c(
  ano = "integer", periodo = "Date", uf = "character",
  cod_municipio_tse = "integer", municipio = "character",
  turno = "integer", cargo = "character", nr_votavel = "integer",
  nm_votavel = "character", votos = "numeric",
  sq_candidato = "integer", nome = "character", nome_urna = "character",
  nr_candidato = "integer", partido = "character", situacao = "character",
  zona = "integer", secao = "integer", faixa_etaria = "character",
  escolaridade = "character", genero = "character", eleitores = "integer",
  eleitores_biometria = "integer", local_votacao = "character",
  endereco = "character", bairro = "character", lat = "numeric",
  lon = "numeric", eleitores_secao = "integer")

#' Completa/ordena colunas do data.frame no esquema canonico
#'
#' As colunas ausentes sao preenchidas com `NA` do tipo canonico
#' (`.tipos_colunas`) — um `NA` logico faria o PostgreSQL criar a
#' coluna como `BOOLEAN` na primeira carga (ex.: `turno` em 2026),
#' quebrando cargas seguintes com valores de outro tipo.
#' @keywords internal
.padronizar <- \(dados, colunas, ano) {
  dados <- as.data.frame(dados)
  if (!"ano" %in% names(dados)) dados$ano <- as.integer(ano)
  for (col in setdiff(colunas, names(dados))) {
    tipo <- .tipos_colunas[[col]]
    dados[[col]] <- switch(
      if (is.null(tipo)) "character" else tipo,
      integer = NA_integer_, numeric = NA_real_,
      Date = as.Date(NA), NA_character_)
  }
  dados[, colunas, drop = FALSE]
}

#' Le dados do tsebr transformando extracao truncada de ZIP em erro
#'
#' `tsebr::tse_read()` extrai o ZIP com `try(utils::unzip(...), silent =
#' TRUE)`. Se a extracao falhar no meio (tipicamente falta de espaco em
#' `tempdir()`, que o `unzip` reporta como *write error*), a funcao segue
#' adiante e o `data.table::fread()` le o CSV cortado, ainda descartando
#' a ultima linha parcial como "single-line footer". A carga termina sem
#' erro nenhum e com menos linhas do que deveria: perda de dados
#' silenciosa. Aqui o aviso do `unzip` vira erro.
#'
#' Todo leitor do tsebr passa por `tse_read()`, entao envolver a chamada
#' de leitura uma vez cobre boletins, votacao_secao, candidaturas,
#' perfis e locais.
#'
#' O erro de download (`tse_download: falha ao baixar ...`) tambem ganha
#' contexto: o 404 do CDN do TSE quase sempre significa que o conjunto
#' nao existe para aquele ano, e nao um problema de rede.
#' @param expr Chamada de leitura do tsebr (avaliada com `expr`).
#' @param escopo Texto do escopo em carga, usado na mensagem de erro.
#' @keywords internal
.ler_tsebr <- \(expr, escopo) {
  withCallingHandlers(
    tryCatch(expr, error = function(e) {
      if (grepl("falha ao baixar", conditionMessage(e), fixed = TRUE)) {
        stop("tsesqlr: o CDN do TSE nao tem os dados de ", escopo,
             " (404). Confira se o conjunto existe para esse ano ",
             "(veja tsebr::tse_anos_disponiveis() e a secao de detalhes ",
             "de ?tsesqlr_carregar). Erro original: ",
             conditionMessage(e), call. = FALSE)
      }
      stop(e)
    }),
    warning = function(w) {
      if (grepl("extracting from zip file", conditionMessage(w),
                fixed = TRUE)) {
        stop("tsesqlr: extracao incompleta do ZIP em ", escopo,
             ": o CSV foi cortado no meio por falta de espaco para ",
             "escrever em ", tempdir(), ". O bweb de SP extrai 7,75 GiB ",
             "e essa extracao conta contra a cota de disco do usuario, ",
             "nao so contra o espaco livre do sistema: confira com ",
             "'quota -s', que pode acusar aperto mesmo com 'df' folgado. ",
             "Remova /tmp/Rtmp* de sessoes do R ja encerradas ou aponte ",
             "TMPDIR no .Renviron para outro disco e rode a carga de ",
             "novo: as UFs ja gravadas sao puladas. Se uma tentativa ",
             "anterior chegou a gravar este escopo cortado, recarregue-o ",
             "com refrescar = TRUE.")
      }
    })
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
#' `resultados` só existe onde o TSE publica votação por seção: anos
#' pares de eleição geral de 1998 a 2024 (`votacao_secao_<ano>_<UF>.zip`)
#' e 2026 em diante (boletim de urna WEB). Anos ímpares, anteriores a
#' 1998 ou fora do calendário eleitoral abortam na hora, antes de
#' qualquer download, com a lista de anos válidos ([.verificar_ano_resultados()]).
#' Em 1994 e 1996 o TSE só tem votação agregada por município/zona
#' (`votacao_candidato_munzona`), sem detalhe por seção, que o tsesqlr
#' ainda não lê; para esses anos use `tipo = "candidatos"`, disponível
#' desde 1994.
#'
#' Cada carga precisa de espaço em `tempdir()`, onde o tsebr extrai o ZIP
#' baixado antes de ler. O bweb de SP extrai 7,75 GiB, então `uf = "ALL"`
#' em 2026 exige vários GB. Isso é limitado pela cota de disco do usuário
#' (`quota -s`), não só pelo espaço livre mostrado por `df`: numa máquina
#' com cota, `/tmp` pode encher antes do resto do sistema. Aponte `TMPDIR`
#' no `.Renviron` para outro disco se `/tmp` estiver apertado, e limpe
#' `/tmp/Rtmp*` de sessões do R encerradas, que chegam facilmente a dezenas
#' de GB. Se a extração falhar no meio, a carga aborta com erro (em vez de
#' gravar um CSV cortado sem avisar); as UFs já gravadas são puladas na
#' chamada seguinte.
#'
#' @param tipo Tipo de dado: `"candidatos"`, `"resultados"`,
#'   `"perfil"` ou `"locais"`.
#' @param ano Ano eleitoral. Para `"resultados"`, apenas 1998..2024
#'   (pares) e 2026+; os demais valores abortam antes do download.
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
#' @family tsesqlr
#' @export
tsesqlr_carregar <- \(tipo = c("candidatos", "resultados", "perfil", "locais"),
                      ano, uf = "all", con = NULL, refrescar = FALSE) {
  tipo <- match.arg(tipo)
  ano <- as.integer(ano)
  if (tipo == "resultados") .verificar_ano_resultados(ano)
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

#' Verifica se a tabela do banco casa com nomes e tipos dos dados
#'
#' Normaliza nomes de tipo do PostgreSQL para comparacao
#'
#' O `information_schema.data_type` vem em minusculas e com os nomes
#' longos do catalogo (`character varying`, `double precision`),
#' enquanto [DBI::dbDataType()] (RPostgres) devolve em maiusculas e
#' com os apelidos curtos (`TEXT`, `DOUBLE PRECISION`). Os dois lados
#' passam por aqui antes de serem comparados.
#' @keywords internal
.normalizar_tipo_pg <- \(x) {
  x <- tolower(x)
  x[x %in% c("character varying", "character", "varchar")] <- "text"
  x[x %in% c("timestamp with time zone", "timestamptz")] <- "timestamptz"
  x[x %in% c("timestamp without time zone", "timestamp")] <- "timestamp"
  x[x %in% c("double precision", "float8")] <- "double precision"
  toupper(x)
}

#' Compara as colunas e os tipos de `dados` com o que existe em
#' `information_schema`. Detecta tabelas criadas com layout antigo
#' em que os nomes batem mas um tipo mudou (ex.: `turno BOOLEAN`
#' vindo de um `NA` logico) — algo que [DBI::dbWriteTable()] nao
#' acusaria antes do COPY falhar.
#'
#' Os dois lados da comparacao sao normalizados por
#' [.normalizar_tipo_pg()]: sem isso o `data_type` do PostgreSQL
#' (minusculo) nunca seria igual ao retorno de [DBI::dbDataType()]
#' (maiusculo no RPostgres) e toda tabela seria julgada incompativel.
#' @keywords internal
.layout_compativel <- \(con, tabela, dados) {
  atuais <- DBI::dbGetQuery(con, paste(
    "SELECT column_name, data_type FROM information_schema.columns",
    "WHERE table_name = $1"), params = list(tabela))
  if (!setequal(atuais$column_name, names(dados))) return(FALSE)
  esperado <- vapply(dados, function(x) DBI::dbDataType(con, x), character(1))
  isTRUE(all(.normalizar_tipo_pg(atuais$data_type) ==
               .normalizar_tipo_pg(esperado[atuais$column_name])))
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
  dados <- .ler_tsebr(
    switch(tipo,
      candidatos = tsebr::tse_candidaturas(ano, uf = uf_dados),
      resultados = if (ano >= 2026) .agregar_boletins(ano, uf_dados) else
        tsebr::tse_votacao_municipio(ano, uf = uf_dados),
      perfil = tsebr::tse_perfis_secao(ano, uf = uf_dados),
      locais = tsebr::tse_locais_votacao(ano, uf = uf_dados)),
    escopo = paste(tipo, ano, uf))
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
  if (nrow(existe) && !.layout_compativel(con, tabela, dados)) {
    if (!refrescar) {
      stop("tsesqlr: tabela '", tabela, "' foi carregada com outro ",
           "layout ou tipo de coluna (",
           paste(DBI::dbListFields(con, tabela), collapse = ", "),
           " vs ", paste(names(dados), collapse = ", "),
           "); use refrescar = TRUE para recria-la com o esquema ",
           "atual (as outras cargas desta tabela precisam ser ",
           "recarregadas em seguida)")
    }
    warning("tsesqlr: recriando a tabela '", tabela,
            "' (layout/tipo antigo); cargas anteriores dela foram perdidas")
    DBI::dbExecute(con, paste("DROP TABLE", tabela))
    DBI::dbExecute(con, "DELETE FROM cargas WHERE tabela = $1",
                   params = list(tipo))
    existe <- data.frame()
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
    .criar_indices(con, tabela)
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
#' @family tsesqlr
#' @seealso [tsesqlr_candidatos()]
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
#' @param ano Ano eleitoral ou vetor de anos.
#' @param uf Sigla da UF.
#' @param cargo Regex de cargo (case-insensitive). Default: todos.
#' @param con Conexao DBI; default abre via [tsesqlr_con()].
#' @return `data.frame` com candidaturas.
#' @examples
#' \dontrun{
#' tsesqlr_candidatos(2026, "DF", cargo = "GOVERNADOR")
#' tsesqlr_candidatos(c(2022, 2026), "SP")
#' }
#' @family tsesqlr
#' @seealso [tsesqlr_resultados()]
#' @export
tsesqlr_candidatos <- \(ano, uf, cargo = NULL, con = NULL) {
  .nossa <- is.null(con)
  if (.nossa) con <- tsesqlr_con()
  on.exit(if (.nossa) DBI::dbDisconnect(con), add = TRUE)
  puxar <- \(a) {
    sql <- "SELECT * FROM candidatos WHERE ano = $1"
    params <- list(as.integer(a))
    if (!identical(toupper(uf), "ALL")) {
      sql <- paste(sql, "AND uf = $2")
      params[[2]] <- toupper(uf)
    }
    if (!is.null(cargo)) { sql <- paste(sql, "AND cargo ~* $3"); params[[3]] <- cargo }
    DBI::dbGetQuery(con, sql, params = params)
  }
  do.call(rbind, lapply(sort(unique(as.integer(ano))), puxar))
}

#' Consulta rápida: votos por município IBGE (contrato do DW beep)
#'
#' Soma os votos da tabela `resultados` por município e devolve no
#' formato longo do DW (`local`, `periodo`, `valor`, `uf`) — mesmo
#' contrato de `tsebr::tse_resultados_municipio()`, sem baixar
#' nada: o dado já está no banco pré-carregado. Com `mapa` (saída
#' de `tsebr::tse_mapa_municipios()` ou `tse_municipios()`), `local`
#' sai como código IBGE de 7 dígitos; sem mapa, como código TSE.
#'
#' @param ano Ano eleitoral ou vetor de anos.
#' @param uf Sigla da UF.
#' @param cargo Regex de cargo (case-insensitive). Default: todos.
#' @param nr_votavel Número do candidato/partido. Default: todos.
#' @param mapa `data.frame` com cod_municipio_tse e ibge (ou
#'   geoloc_id, como em `tsebr::tse_mapa_municipios()`).
#' @param con Conexao DBI; default abre via [tsesqlr_con()].
#' @return `data.frame` long: local, periodo, valor, uf.
#' @examples
#' \dontrun{
#' tsesqlr_resultados_municipio(2022, "DF", cargo = "PRESIDENTE",
#'   nr_votavel = 13, mapa = tsebr::tse_mapa_municipios(2022, "DF"))
#' }
#' @family tsesqlr
#' @seealso [tsesqlr_resultados()] para os detalhes por cargo/turno.
#' @export
tsesqlr_resultados_municipio <- \(ano, uf, cargo = NULL, nr_votavel = NULL,
                                  mapa = NULL, con = NULL) {
  .nossa <- is.null(con)
  if (.nossa) con <- tsesqlr_con()
  on.exit(if (.nossa) DBI::dbDisconnect(con), add = TRUE)
  uf <- toupper(uf[1])
  puxar <- \(a) {
    sql <- paste("SELECT cod_municipio_tse, municipio,",
                 "SUM(votos) AS votos FROM resultados WHERE ano = $1")
    params <- list(as.integer(a))
    if (!identical(uf, "ALL")) {
      sql <- paste(sql, "AND uf = $2")
      params[[2]] <- uf
    }
    if (!is.null(cargo)) {
      sql <- paste(sql, "AND cargo ~* $3")
      params[[3]] <- cargo
    }
    if (!is.null(nr_votavel)) {
      sql <- paste(sql, "AND nr_votavel = $4")
      params[[4]] <- as.character(nr_votavel)
    }
    d <- DBI::dbGetQuery(con, paste(sql, "GROUP BY 1, 2"), params = params)
    d$ano <- as.integer(a)
    d
  }
  dados <- do.call(rbind, lapply(sort(unique(as.integer(ano))), puxar))
  if (is.null(mapa)) {
    saida <- dados |>
      dplyr::mutate(local = as.numeric(cod_municipio_tse))
  } else {
    if (!"ibge" %in% names(mapa) && "geoloc_id" %in% names(mapa)) {
      mapa$ibge <- as.numeric(mapa$geoloc_id)
    }
    if ("empate" %in% names(mapa)) {
      mapa <- mapa[is.na(mapa$empate) | !mapa$empate, , drop = FALSE]
    }
    mapa <- dplyr::mutate(mapa,
                          cod_municipio_tse = as.character(cod_municipio_tse),
                          ibge = as.numeric(ibge))
    saida <- dados |>
      dplyr::mutate(cod_municipio_tse = as.character(cod_municipio_tse)) |>
      dplyr::left_join(mapa[, c("cod_municipio_tse", "ibge")],
                       by = "cod_municipio_tse") |>
      dplyr::filter(!is.na(ibge)) |>
      dplyr::mutate(local = ibge)
  }
  saida |>
    dplyr::group_by(local, ano) |>
    dplyr::summarise(valor = sum(as.numeric(votos), na.rm = TRUE),
                     .groups = "drop") |>
    dplyr::mutate(periodo = as.Date(paste0(ano, "-12-31")), uf = uf) |>
    dplyr::select(local, periodo, valor, uf)
}

#' Escopo está carregado no banco? (decisão tsesqlr x tsebr no painel)
#'
#' Verifica, sem nunca erro, se o banco responde e se TODOS os anos
#' pedidos do tipo/UF estão em `cargas` (registro `uf = 'ALL'` cobre
#' qualquer UF). É a peça que o painel beep usa para decidir entre
#' consultar direto o banco (rápido) ou cair no download via tsebr.
#'
#' @param tipo `"resultados"`, `"candidatos"`, `"perfil"` ou
#'   `"locais"` (valor da coluna `tabela` de `cargas`).
#' @param ano Ano eleitoral ou vetor — todos precisam estar carregados.
#' @param uf Sigla da UF.
#' @param con Conexao DBI; default abre via [tsesqlr_con()].
#' @return `TRUE`/`FALSE` (qualquer falha de conexão/credencial vira
#'   `FALSE`).
#' @examples
#' \dontrun{
#' if (tsesqlr_disponivel("resultados", 2022, "DF")) { ... }
#' }
#' @family tsesqlr
#' @export
tsesqlr_disponivel <- \(tipo = c("resultados", "candidatos", "perfil", "locais"),
                        ano, uf, con = NULL) {
  tipo <- match.arg(tipo)
  tryCatch({
    .nossa <- is.null(con)
    if (.nossa) con <- tsesqlr_con()
    on.exit(if (.nossa) DBI::dbDisconnect(con), add = TRUE)
    anos_pedidos <- sort(unique(as.integer(ano)))
    ## RPostgres nao serializa vetor R como array do PG: literal
    ## "{2022,2026}" + cast explicito
    anos_txt <- paste0("{", paste(anos_pedidos, collapse = ","), "}")
    tem <- DBI::dbGetQuery(con, paste(
      "SELECT DISTINCT ano FROM cargas",
      "WHERE tabela = $1 AND ano = ANY($2::int[]) AND (uf = $3 OR uf = 'ALL')"),
      params = list(tipo, anos_txt, toupper(uf[1])))
    setequal(as.integer(tem$ano), anos_pedidos)
  }, error = \(e) FALSE)
}
