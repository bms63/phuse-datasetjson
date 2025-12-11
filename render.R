library(quarto)
library(glue)

# TODO : Replace with actual paper number
XXnn <- "XXnn"  

quarto_render(
    input = "paper.qmd",
    output_file = glue("PAP_{XXnn}.docx"),
    output_format = "docx"
)