library(ggplot2)
library(dplyr)   # For mutate, arrange, group_by, summarise, slice
library(tidyr)    # For pivot_longer

# --- Existing XPT and JSON file processing (unchanged) ---

# Get all XPT files from directory
xpt_files <- list.files(
  "xpts/",
  pattern = "\\.xpt$",
  full.names = TRUE
)

# Create output directory
output_dir <- "json"

# Ensure output directory exists
if (!dir.exists(output_dir)) {
  dir.create(output_dir)
}

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
# Note: For this example to run, you'd need actual XPT files in 'xpts/'
# and the 'haven' and 'datasetjson' packages installed.
# The following block is kept for context, assuming it works as intended.
if (length(xpt_files) > 0) {
  purrr::walk(xpt_files, function(file) {
    dataset_name <- tools::file_path_sans_ext(basename(file))
    
    # Skip ts dataset
    if (dataset_name == "ts") return()
    
    # Placeholder for actual data reading and processing.
    # If 'haven' and 'datasetjson' are not available or files are not present,
    # this section would need to be adapted or mocked for the plotting to work.
    # For demonstration purposes, we assume JSON files are generated or exist.
    
    # data <- haven::read_xpt(file)
    # meta <- purrr::map_dfr(names(data), extract_xpt_meta, .data = data)
    # ds_json <- datasetjson::dataset_json(
    #   data,
    #   item_oid = dataset_name,
    #   name = dataset_name,
    #   dataset_label = dataset_name,
    #   columns = meta
    # )
    # datasetjson::write_dataset_json(
    #   ds_json,
    #   file.path(output_dir, paste0(dataset_name, ".json"))
    # )
  })
}

# Get JSON file sizes
json_files <- list.files(output_dir, pattern = "\\.json$", full.names = TRUE)
json_sizes <- file.info(json_files)$size
names(json_sizes) <- tools::file_path_sans_ext(basename(json_files))

# Compare sizes and prepare for plotting
common_names <- intersect(names(file_sizes), names(json_sizes))

# Create a wide format tibble with xpt_size and json_size
size_comparison_wide <- tibble::tibble(
  dataset = common_names,
  xpt_size_bytes = file_sizes[common_names],
  json_size_bytes = json_sizes[common_names]
) %>%
  dplyr::mutate(total_size_bytes = xpt_size_bytes + json_size_bytes) # Calculate total size

# Get the top 12 datasets based on total size
top_12_datasets <- size_comparison_wide %>%
  dplyr::arrange(desc(total_size_bytes)) %>%
  dplyr::slice(1:12) %>%
  pull(dataset) # Extract only the dataset names

# Reshape the data to a "long" format for plotting and filter for top 12
size_comparison_long <- size_comparison_wide %>%
  tidyr::pivot_longer(
    cols = c(xpt_size_bytes, json_size_bytes),
    names_to = "file_type",
    values_to = "size_bytes"
  ) %>%
  dplyr::mutate(
    file_type = dplyr::case_when(
      file_type == "xpt_size_bytes" ~ "XPT",
      file_type == "json_size_bytes" ~ "JSON",
      TRUE ~ file_type
    ),
    size_kb = size_bytes / 1024 # Convert bytes to KB for display
  ) %>%
  dplyr::filter(dataset %in% top_12_datasets) # Filter to include only the top 12 datasets

# Define the order for plotting based on the total sizes of the top 12
# Ensure the 'dataset' factor levels are set correctly for ordering
size_comparison_long$dataset <- factor(size_comparison_long$dataset,
                                       levels = top_12_datasets[order(top_12_datasets, decreasing = TRUE)])

# Plot
p <- ggplot(size_comparison_long, aes(x = reorder(dataset, total_size_bytes, FUN = mean), y = size_kb, fill = file_type)) +
  geom_col(position = "dodge") + # Use 'dodge' to place bars side-by-side
  geom_text(aes(label = sprintf("%s: %.1f KB", file_type, size_kb)), # Label each bar with its type and size
            position = position_dodge(width = 0.9), # Adjust text position to match dodged bars
            hjust = -0.1, # Adjust hjust for better label placement after coord_flip
            size = 2.5,
            color = "black") + # Changed color to black for better contrast
  coord_flip() + # Flip coordinates to have datasets on y-axis for readability
  labs(x = "Dataset", y = "File Size (KB)",
       title = "Top 12 Datasets: XPT vs. JSON File Sizes Comparison",
       fill = "File Type") +
  theme_minimal() +
  scale_fill_manual(values = c("XPT" = "#00BFC4", "JSON" = "#F8766D")) + # Manually set distinct colors
  scale_y_continuous(expand = expansion(mult = c(0.01, 0.2))) # Expand y-axis to make space for labels

ggsave("size_comparison_colored_top12_sorted.png", p, width = 12, height = 8, dpi = 300)
