# Install and load necessary packages if you haven't already
# install.packages(c("haven", "jsonlite", "arrow", "knitr", "ggplot2", "scales"))

library(haven)    # For XPT files
library(jsonlite) # For generic JSON files
library(arrow)    # For Parquet files
library(knitr)    # For Markdown table
library(ggplot2)  # For plotting
library(scales)   # For comma formatting in plot axis labels

# Define the different numbers of rows to test
# XPT Version 5 has a limitation around 99,999 rows.
# Testing with 100,000 rows will demonstrate this.
num_rows_tests <- c(5, 100, 1000, 5000, 10000, 50000, 99999)

# Initialize an empty data frame to store all results
all_file_sizes_comparison <- data.frame(
  "Number of Rows" = numeric(),
  "File Type" = character(),
  "File Name" = character(),
  "Size (bytes)" = numeric(),
  stringsAsFactors = FALSE
)

# Function to get file size safely
get_file_size <- function(filepath, file_type, n_rows) {
  if (file.exists(filepath)) {
    size_bytes <- file.info(filepath)$size
    return(data.frame(
      "Number of Rows" = n_rows,
      "File Type" = file_type,
      "File Name" = basename(filepath),
      "Size (bytes)" = size_bytes,
      stringsAsFactors = FALSE
    ))
  } else {
    message(paste("Warning: File not found for size check or creation failed for:", filepath))
    return(data.frame(
      "Number of Rows" = n_rows,
      "File Type" = file_type,
      "File Name" = basename(filepath),
      "Size (bytes)" = NA, # Assign NA if file doesn't exist
      stringsAsFactors = FALSE
    ))
  }
}

# Loop through each number of rows
for (n_rows in num_rows_tests) {
  message(paste("\n--- Generating files for", formatC(n_rows, format="d", big.mark=","), "rows ---"))
  
  # 1. Create a simple dummy dataset
  dummy_data <- data.frame(
    ID = 1:n_rows,
    Name = sample(c("Alice", "Bob", "Charlie", "David", "Eve", "Frank", "Grace", "Heidi", "Ivy", "Jack", "Karen", "Liam", "Mia", "Noah", "Olivia", "Peter", "Quinn", "Rachel", "Sam", "Tina"), n_rows, replace = TRUE),
    Age = sample(20:60, n_rows, replace = TRUE),
    City = sample(c("New York", "London", "Paris", "Berlin", "Tokyo", "Rome", "Sydney", "Cairo", "Madrid", "Beijing", "Moscow", "Rio", "Dubai", "Oslo", "Dublin", "Seoul", "Warsaw", "Vienna", "Lisbon", "Amsterdam"), n_rows, replace = TRUE),
    Value = rnorm(n_rows, mean = 100, sd = 10)
  )
  
  # Define file paths (using n_rows in filename to keep them distinct)
  xpt_file <- paste0("dummy_data_", n_rows, ".xpt")
  json_file <- paste0("dummy_data_", n_rows, ".json")
  parquet_file <- paste0("dummy_data_", n_rows, ".parquet")
  
  # 2. Create the dummy XPT file (defaulting to version 5, which limits rows)
  tryCatch({
    write_xpt(dummy_data, xpt_file) # Removed 'version = 8'
    message(paste("Dummy XPT file (version 5) created:", xpt_file))
  }, error = function(e) {
    message(paste("Error creating XPT file:", e$message))
  })
  
  # 3. Create the dummy JSON file using jsonlite package
  tryCatch({
    jsonlite::write_json(dummy_data, json_file, pretty = FALSE, auto_unbox = TRUE)
    message(paste("Dummy JSON file (jsonlite) created:", json_file))
  }, error = function(e) {
    message(paste("Error creating JSON file (jsonlite):", e$message))
  })
  
  # 4. Create the dummy Parquet file
  tryCatch({
    write_parquet(dummy_data, parquet_file)
    message(paste("Dummy Parquet file created:", parquet_file))
  }, error = function(e) {
    message(paste("Error creating Parquet file:", e$message))
  })
  
  # 5. Get file sizes for the current run and add to the overall comparison
  current_file_sizes <- rbind(
    get_file_size(xpt_file, "XPT", n_rows),
    get_file_size(json_file, "JSON (jsonlite)", n_rows),
    get_file_size(parquet_file, "Parquet", n_rows)
  )
  all_file_sizes_comparison <- rbind(all_file_sizes_comparison, current_file_sizes)
  
  # Optional: Clean up files from current iteration immediately
  # unlink(c(xpt_file, json_file, parquet_file))
}

cat("\n### Overall File Size Comparison (Markdown Table):\n")

# 6. Create a Markdown table for the overall comparison
markdown_table <- kable(all_file_sizes_comparison, format = "markdown", align = c('r', 'l', 'l', 'r'))

cat(markdown_table)
cat("\n\n")

cat("\n### File Size Comparison Plot:\n")

# 7. Create a plot of the comparison table using ggplot2
plot <- ggplot(all_file_sizes_comparison, aes(x = `Number.of.Rows`, y = `Size..bytes.` / (1024 * 1024), color = `File.Type`)) +
  geom_line(linewidth = 1) + # Use linewidth for line thickness for better visibility
  geom_point(size = 3) +     # Add points for clarity at each data point
  # Removed scale_y_log10 for linear scale
  scale_y_continuous(labels = scales::comma) + # Use continuous scale with comma labels
  scale_x_continuous(breaks = num_rows_tests, labels = scales::comma) + # Ensure all tested N rows are shown
  labs(
    title = "File Size Comparison Across Different Dataset Sizes",
    x = "Number of Rows in Dataset",
    y = "File Size (MiB)", # Updated label (removed "Log Scale")
    color = "File Type"
  ) +
  theme_minimal() + # A clean theme
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    axis.text.x = element_text(angle = 45, hjust = 1) # Angle x-axis labels if they overlap
  )

# Print the plot (this will open a plot window or display in RStudio viewer)
print(plot)

# To save the plot to a file (e.g., PNG), uncomment the following:
# ggsave("file_size_comparison_plot.png", plot, width = 10, height = 6, dpi = 300)


# 8. Clean up all created dummy files at the end
# If you want to keep the files, comment out the following lines
all_dummy_files <- unlist(lapply(num_rows_tests, function(n) {
  c(paste0("dummy_data_", n, ".xpt"),
    paste0("dummy_data_", n, ".json"),
    paste0("dummy_data_", n, ".parquet"))
}))
# unlink(all_dummy_files)
# message("All dummy files cleaned up.")