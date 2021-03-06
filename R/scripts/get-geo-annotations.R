#!/usr/bin/env Rscript

usePackage <- function(p) 
{
  if (!is.element(p, installed.packages()[,1]))
    install.packages(p, repos = "http://cran.us.r-project.org", dep = TRUE)
  require(p, character.only = TRUE)
}
usePackage("pacman")

suppressPackageStartupMessages(p_load("GEOquery"))
suppressPackageStartupMessages(p_load("SRAdb"))
suppressPackageStartupMessages(p_load("plyr"))
suppressPackageStartupMessages(p_load("optparse"))

option_list <- list(
                    make_option(c("--gse"), action="store",
                                default=NULL,
                                help="GEO Series accession number (e.g., \"GSE89777\")"))

descr <- "\
Extract GEO annotations from the GEO data set with identifier specified by 'GSE'.  If the data set has SRA entries, the ftp directory is expected to be specified in GEO annotation fields that include the pattern 'supplementary_file'.  This field will be parsed to extract the SRA identifier, which will be used to determine the URL of the FTP file.  Whether an SRA data set or not, the URL will be included in the 'url' column of the output.
"

parser <- OptionParser(usage = "%prog [options]", option_list=option_list, description=descr)

arguments <- parse_args(parser, positional_arguments = TRUE)
opt <- arguments$options

## Collect input parameters
gse.identifier <- opt$gse

if ( length(arguments$args) != 0 ) {
  print_help(parser)
  q(status=1)
}

if ( is.null(gse.identifier) ) {
  print_help(parser)
  q(status=1)
}

options('download.file.method.GEOquery' = 'libcurl')

## Get the GSE object
message(paste0("Retrieving the GSE object for identifier: ", gse.identifier, "\n"))
gse.geo <- getGEO(gse.identifier, getGPL=FALSE)

## Iterate over each of the GSMs associated with this GSE
metadata.tbl <- ldply(sampleNames(phenoData(gse.geo[[1]])), 
                      .fun = function(gsm.identifier) {

                        message(paste0("Retrieving metadata for GSM identifier: ", gsm.identifier, "\n"))
                          
                        ## Get the GSM object
                        gsm.geo <- getGEO(gsm.identifier)
        
                        ## Extract its metadata
                        md <- Meta(gsm.geo)
                        
                        ## Metadata is a list of lists.
                        ## Go through each entry and concatenate the individual lists using a ';' delimiter
                        as.data.frame(lapply(md, function(entry) paste(entry, collapse=";")))
                      })

## If these are SRA entries, the entity listed in supplementary_file will be a directory
## not a URL.  Do a little more work to find that URL.
supp.file.columns <- colnames(metadata.tbl)[grepl(colnames(metadata.tbl), pattern="supplementary_file")]
if(length(supp.file.columns) == 0) {
    stop(paste0("Could not find a column name with pattern \"supplementary_file\" in columns:\n", paste(colnames(metadata.tbl), collapse=", "), "\n"))
}

if(length(supp.file.columns) > 1) {
    warning(paste0("Got multiple columns with pattern \"supplementary_file\"\nJust using the first of the following:\n", paste(supp.file.columns, collpase=", "), "\n"))
}

metadata.tbl$url <- as.character(metadata.tbl[, supp.file.columns[1]])

if(any(metadata.tbl$type == "SRA")) {
  sra.db.dest.file <- "SRAmetadb.sqlite"
  if(!file.exists(sra.db.dest.file)) {
    sra.db.dest.file <- getSRAdbFile(destfile = paste0(sra.db.dest.file, ".gz"))
  }
  con <- dbConnect(RSQLite::SQLite(), sra.db.dest.file)
  
  for(i in 1:nrow(metadata.tbl)) {
    if(metadata.tbl$type[i] == "SRA") {
      ## Extract the SRA identifier
      ## NB: this is probably also in the relation column
      url <- metadata.tbl$url[i]
      sra.identifier <- gsub("^.*\\/([^\\/]+)$", "\\1", url)
      url <- listSRAfile(sra.identifier, con)$ftp
      metadata.tbl$url[i] <- url
    }
  }
  
  d <- dbDisconnect(con)
}

write.table(metadata.tbl, sep="\t", quote=FALSE, row.names=FALSE, col.names=TRUE)

message("Successfully completed\n")
q(status = 0)
