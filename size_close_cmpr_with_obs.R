library(ggplot2)
library(dplyr)   # For mutate, arrange, group_by, summarise, slice
library(tidyr)    # For pivot_longer
library(purrr)   # For purrr::map_dfr and purrr::walk
library(tibble)  # For tibble()
library(haven)   # Required to read .xpt files

# --- Existing XPT and JSON file processing (with added observation count) ---

# Get all XPT files from directory
# Ensure you have a directory named 'xpts/' with .xpt files for this to work
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

# Record file sizes and number of observations
file_sizes <- file.info(xpt_files)$size
names(file_sizes) <- tools::file_path_sans_ext(basename(xpt_files))

num_observations_vec <- integer(length(xpt_files))
names(num_observations_vec) <- tools::file_path_sans_ext(basename(xpt_files))

# xpt metadata function (unchanged)
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

# Loop through each XPT file to read data, extract metadata and observation count,
# and (optionally) convert to datasetjson.
# Uncomment the 'haven::read_xpt' and 'datasetjson' parts if you need to perform the conversion.
if (length(xpt_files) > 0) {
  purrr::walk(xpt_files, function(file) {
    dataset_name <- tools::file_path_sans_ext(basename(file))
    
    # Skip ts dataset
    if (dataset_name == "ts") return()
    
    data <- haven::read_xpt(file) # Read XPT file to get data
    num_observations_vec[[dataset_name]] <<- nrow(data) # Store observation count
    
    # Optional: Convert to datasetjson (uncomment if you need this step)
    # meta <- purrr::map_dfr(names(data), extract_xpt_meta, .data = data)
    # ds_json <- datasetjson::dataset_json(
    #   data,
    #   item_oid = dataset_name,
    #   name = dataset_name,
    #   dataset_label = dataset_name,
    #   columns = meta
    # )
    #
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

# Find common dataset names
common_names <- intersect(names(file_sizes), names(json_sizes))

# Create a wide format tibble with xpt_size, json_size, and num_observations
size_comparison_wide <- tibble::tibble(
  dataset = common_names,
  xpt_size_bytes = file_sizes[common_names],
  json_size_bytes = json_sizes[common_names],
  num_observations = num_observations_vec[common_names] # Add observation count here
)

# --- Find datasets with close sizes and plot ---

# Define the closeness threshold in KB
closeness_threshold_kb <- 100
closeness_threshold_bytes <- closeness_threshold_kb * 1024

# Calculate the absolute difference and filter for close datasets
close_datasets_wide <- size_comparison_wide %>%
  dplyr::mutate(
    absolute_difference_bytes = abs(xpt_size_bytes - json_size_bytes),
    total_size_bytes = xpt_size_bytes + json_size_bytes # Calculate total size for sorting
  ) %>%
  dplyr::filter(absolute_difference_bytes <= closeness_threshold_bytes)

# Check if any close datasets were found
if (nrow(close_datasets_wide) == 0) {
  message(sprintf("No datasets found where XPT and JSON file sizes are within %.1f KB of each other. No plot will be generated.", closeness_threshold_kb))
} else {
  # Reshape the data to a "long" format for plotting
  close_datasets_long <- close_datasets_wide %>%
    tidyr::pivot_longer(
      cols = c(xpt_size_bytes, json_size_bytes),
      names_to = "file_type_raw",
      values_to = "size_bytes"
    ) %>%
    dplyr::mutate(
      file_type = dplyr::case_when(
        file_type_raw == "xpt_size_bytes" ~ "XPT",
        file_type_raw == "json_size_bytes" ~ "JSON",
        TRUE ~ file_type_raw # Should not happen
      ),
      size_kb = size_bytes / 1024 # Convert bytes to KB for display
    )
  
  # Define the order for plotting based on the total sizes of the close datasets
  # (highest to lowest)
  ordered_datasets <- close_datasets_wide %>%
    dplyr::arrange(desc(total_size_bytes)) %>%
    pull(dataset)
  
  # Create a new combined label for the Y-axis (dataset name + observations)
  # Ensure the factor levels are set correctly for ordering on the plot
  close_datasets_long <- close_datasets_long %>%
    dplyr::mutate(
      plot_label = factor(paste0(dataset, " (Obs: ", format(num_observations, big.mark = ","), ")"),
                          levels = unique(paste0(ordered_datasets, " (Obs: ", format(close_datasets_wide$num_observations[match(ordered_datasets, close_datasets_wide$dataset)], big.mark = ","), ")")))
    )
  
  # Create the plot
  p_close_obs <- ggplot(close_datasets_long, aes(x = plot_label, y = size_kb, fill = file_type)) +
    geom_col(position = "dodge") + # Use 'dodge' to place bars side-by-side
    geom_text(aes(label = sprintf("%s: %.1f KB", file_type, size_kb)), # Label each bar with its type and size
              position = position_dodge(width = 0.9), # Adjust text position to match dodged bars
              hjust = -0.1, # Adjust hjust for better label placement after coord_flip
              size = 2.5,
              color = "black") + # Changed color to black for better contrast
    coord_flip() + # Flip coordinates to have datasets on y-axis for readability
    labs(x = "Dataset (Observations)", y = "File Size (KB)",
         title = sprintf("Datasets with XPT and JSON File Sizes within %.0f KB", closeness_threshold_kb),
         fill = "File Type") +
    theme_minimal() +
    scale_fill_manual(values = c("XPT" = "#00BFC4", "JSON" = "#F8766D")) + # Manually set distinct colors
    scale_y_continuous(expand = expansion(mult = c(0.01, 0.2))) # Expand y-axis to make space for labels
  
  # Save the plot
  ggsave("size_comparison_close_datasets_with_obs_plot.png", p_close_obs, width = 12, height = max(6, length(ordered_datasets) * 0.7), dpi = 300)
  message(sprintf("Plot 'size_comparison_close_datasets_with_obs_plot.png' generated showing %d datasets within %.0f KB closeness.", nrow(close_datasets_wide), closeness_threshold_kb))
}
