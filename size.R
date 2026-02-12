# Get all XPT files from directory
xpt_files <- list.files(
  "xpts/",
  pattern = "\\.xpt$",
  full.names = TRUE
)

# Create output directory
output_dir <- "json"

# Record file sizes
file_sizes <- file.info(xpt_files)$size
names(file_sizes) <- tools::file_path_sans_ext(basename(xpt_files))

# xpt metadata
extract_xpt_meta <- function(n, .data) {
  attrs <- attributes(.data[[n]])

  out <- list()

  # Identify the variable type
  if (inherits(.data[[n]], "Date")) {
    out$dataType <- "date"
    out$targetDataType <- "integer"
  } else if (inherits(.data[[n]], "POSIXt")) {
    out$dataType <- "datetime"
    out$targetDataType <- "integer"
  } else if (inherits(.data[[n]], "numeric")) {
    if (any(is.double(.data[[n]]))) {
      out$dataType <- "float"
    } else {
      out$dataType <- "integer"
    }
  } else if (inherits(.data[[n]], "hms")) {
    out$dataType <- "time"
    out$targetDataType <- "integer"
  } else {
    out$dataType <- "string"
    out$length <- max(purrr::map_int(.data[[n]], function(x) {
      if (is.na(x)) return(0)
      tryCatch(nchar(x), error = function(e) 0)
    }))
  }

  out$itemOID <- n
  out$name <- n
  out$label <- attr(.data[[n]], 'label')
  out$displayFormat <- attr(.data[[n]], 'format.sas')
  tibble::as_tibble(out)
}

# Loop through each XPT file to convert to datasetjson
purrr::walk(xpt_files, function(file) {
  dataset_name <- tools::file_path_sans_ext(basename(file))
  
  # Skip ts dataset
  if (dataset_name == "ts") return()
  
  data <- haven::read_xpt(file)
  
  # Create metadata
  meta <- purrr::map_dfr(names(data), extract_xpt_meta, .data = data)
  
  # Convert to datasetjson
  ds_json <- datasetjson::dataset_json(
    data,
    item_oid = dataset_name,
    name = dataset_name,
    dataset_label = dataset_name,
    columns = meta
  )

  datasetjson::write_dataset_json(
    ds_json,
    file.path(output_dir, paste0(dataset_name, ".json"))
  )
  
})

# Get JSON file sizes
json_files <- list.files(output_dir, pattern = "\\.json$", full.names = TRUE)
json_sizes <- file.info(json_files)$size
names(json_sizes) <- tools::file_path_sans_ext(basename(json_files))

# Compare sizes
common_names <- intersect(names(file_sizes), names(json_sizes))
size_comparison <- tibble::tibble(
  dataset = common_names,
  xpt_size = file_sizes[common_names],
  json_size = json_sizes[common_names],
  proportion = json_size / xpt_size
)

# Plot
library(ggplot2)
p <- ggplot(size_comparison, aes(x = reorder(dataset, proportion), y = proportion)) +
  geom_col() +
  geom_text(aes(label = sprintf("XPT: %.1f KB\nJSON: %.1f KB", xpt_size/1024, json_size/1024)), 
            hjust = 1.1, size = 3, color = "white") +
  geom_hline(yintercept = 1, linetype = "dashed", color = "red") +
  coord_flip() +
  labs(x = "Dataset", y = "JSON Size / XPT Size", 
       title = "JSON File Size as Proportion of XPT File Size") +
  theme_minimal()

ggsave("size_comparison.png", p, width = 10, height = 8, dpi = 300)
