baseoai <- function() "https://ws.pangaea.de/oai/provider"
base <- function() 'https://doi.pangaea.de/'
sbase <- function() "https://www.pangaea.de/advanced/search.php"
esbase <- function() "https://ws.pangaea.de/es/pangaea/panmd/_search"

pgc <- function(x) Filter(Negate(is.null), x)

pluck <- function(x, name, type) {
  if (missing(type)) {
    lapply(x, "[[", name)
  } else {
    vapply(x, "[[", name, FUN.VALUE = type)
  }
}

check <- function(x) {
  if (is.character(x)) {
    if ( grepl("does not exist|unknown", x))
      stop(x, call. = FALSE)
  }
}

read_csv <- function(x) {
  nlines <- 1000
  lns <- readLines(x, n = nlines)
  ln_no <- grep("\\*/", lns)
  # read in more lines if needed
  while(length(ln_no) == 0){
    nlines <- nlines + 1000
    lns <- readLines(x, n = nlines)
    ln_no <- grep("\\*/", lns)
  }
  tmp <- utils::read.csv(x, header = FALSE, sep = "\t",
                  skip = ln_no + 1, stringsAsFactors = FALSE)
  nn <- strsplit(lns[ln_no + 1], "\t")[[1]]
  stats::setNames(tmp, nn)
}

read_meta <- function(x) {
  # return NA if not a .txt file
  if (!grepl("\\.txt", x)) return(list())

  nlines <- 1000
  lns <- readLines(x, n = nlines)
  ln_no <- grep("\\*/", lns)
  # read in more lines if needed
  while(length(ln_no) == 0){
    nlines <- nlines + 1000
    lns <- readLines(x, n = nlines)
    ln_no <- grep("\\*/", lns)
  }
  all_lns <- seq_len(ln_no)
  txt <- lns[all_lns[-c(1, length(all_lns))]]
  starts <- grep(":\\\t", txt)
  ext <- list()
  for (i in seq_along(starts)) {
    end <- starts[i + 1] - 1
    if (is.na(end)) {
      gt <- starts[i]
    } else {
      gt <- if (starts[i] == end) {
        starts[i]
      } else {
        starts[i]:end
      }
    }
    ext[[i]] <- txt[gt]
  }
  ext2 <- list()
  for (i in seq_along(ext)) {
    sp <- strsplit(ext[[i]], "\\\t")
    nm <- tolower(gsub("\\s", "_", gsub(":|\\(|\\)", "", sp[[1]][1])))
    if(nm == "parameters"){
      tmp <- unlist(c(sp[[1]][-1], sp[-1]))
      tmp <- tmp[nzchar(tmp)]
      dat <- list(tmp)
    } else if (length(sp) > 1) {
      tmp <- unlist(c(sp[[1]][-1], sp[-1]))
      tmp <- tmp[nzchar(tmp)]
      dat <- paste0(tmp, collapse = "; ")
    } else {
      dat <- sp[[1]][-1]
      if (nm == "events") {
        dat <- sapply(strsplit(dat, "\\s\\*\\s")[[1]], function(z) {
          zz <- strsplit(z, ":\\s")[[1]]
          zz <- gsub("^\\s|\\s$", "", zz)
          as.list(stats::setNames(zz[2], zz[1]))
        }, USE.NAMES = FALSE)
        dat <- list(dat)
      }
    }
    ext2[[i]] <- as.list(stats::setNames(dat, nm))
  }
  ext2 <- unlist(ext2, FALSE)
  # attempt to handle parameters
  if ("parameters" %in% names(ext2)) {
    parm <- ext2$parameters
    # parm <- strw(strsplit(parm, ";")[[1]])
    # added space before * to handle ** in units
    parm <- lapply(parm, function(w) {
      strw(strsplit(w, " \\*")[[1]])
    })
    # parse parameters
    # short name: last occurrence within brackets (allow for brackets in unit)
    shortName <- sapply(parm, function(x) sub(".*(\\(((?:[^()]++|(?1))*)\\))$", "\\2", x[1], perl = TRUE))
    Unit <- sapply(parm, function(x) regmatches(x[1], gregexpr("(?<=\\[).*?(?=\\])", x[1], perl = TRUE))[[1]])
    Unit <- sapply(Unit, function(x) ifelse(length(x) == 0, yes = NA_character_, no = x))
    # long name: if unit present, extract everything up to [; if not up to last occurrence of (
    longName <- NA
    for(i in 1:length(Unit)){
      pat <- if(is.na(Unit[i])){
        paste0('\\(', shortName[i], '\\)')
      } else {
        '\\[.*'
      }
      longName[i] <- trimws(sub(pat, "", parm[[i]][1]))
    }
    PI <- sapply(parm, function(x) x[grep('PI:', x)])
    PI <- sapply(PI, function(x) ifelse(length(x) == 0, yes = NA_character_, no = gsub('PI: ', '', x)))
    Method_Device <- sapply(parm, function(x) x[grep('METHOD/DEVICE:', x)])
    Method_Device <- sapply(Method_Device, function(x) ifelse(length(x) == 0, yes = NA_character_, no = gsub('METHOD/DEVICE: ', '', x)))
    Comment <- sapply(parm, function(x) x[grep('COMMENT:', x)])
    Comment <-   sapply(Comment, function(x) ifelse(length(x) == 0, yes = NA_character_, no = gsub('COMMENT: ', '', x)))
    
    ext2$parameters <- tibble::tibble(longName,
                              shortName,
                              Unit,
                              PI,
                              Method_Device,
                              Comment)
    
    
  }
  return(ext2)
}

strw <- function(x) gsub("^\\s|\\s$", "", x)

strextract <- function(str, pattern) regmatches(str, regexpr(pattern, str))

cl <- function(x) if (is.null(x)) NULL else paste0(x, collapse = ",")

cn <- function(x) {
  name <- substitute(x)
  if (!is.null(x)) {
    tryx <- tryCatch(as.numeric(as.character(x)), warning = function(e) e)
    if ("warning" %in% class(tryx)) {
      stop(name, " should be a numeric or integer class value", call. = FALSE)
    }
    if (!is.numeric(tryx) | is.na(tryx))
      stop(name, " should be a numeric or integer class value", call. = FALSE)
    return( format(x, digits = 22, scientific = FALSE) )
  } else {
    NULL
  }
}

as_log <- function(x) {
  if (is.null(x)) {
    x
  } else {
    if (x) 'true' else 'false'
  }
}
