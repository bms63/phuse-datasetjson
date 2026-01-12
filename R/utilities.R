read_qmd <- function(file_path){
  stopifnot(
    "File is not .qmd" = grepl("\\.qmd$", file_path)
  )
  readLines(file_path)
}
