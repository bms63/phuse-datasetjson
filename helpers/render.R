library(quarto)
library(glue)

XXnn <- "SA02"  

quarto_render(
    input = "paper.qmd",
    output_file = glue("PAP_{XXnn}.docx"),
    output_format = "docx"
)
