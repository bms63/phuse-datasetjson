library(ellmer)
library(glue)
library(rstudioapi)

source(file.path(getwd(), "R", "utilities.R"))

paper_txt <- read_qmd("paper.qmd")

paper_chat <- function(paper, prompt){
  chat <- chat_openai(model = "gpt-4.1")
  resp <- chat$chat(
    glue("First, here's the my paper for Phuse that I'll ask you about: {paper}. {prompt}")
  )
  resp
}

feedback <- paper_chat(
  paper_txt, 
  "Provide feedback on the clarity of the introduction section."
)

slides <- paper_chat(
  paper_txt, 
  "Generate Quarto RevealJS slides for a 20 minute presentation at Phuse based on the paper. Include slide titles and bullet points. Ensure it is concise but engaging. Only give me the slide content in qmd format. Do not include tick marks like ```qmd or ```markdown like your normally would. You can include speaker notes using this format:
  ::: {.notes}
  Speaker notes go here.
  :::"
)

writeLines(feedback, "feedback.md")
writeLines(slides, "draft_slides.qmd")

documentOpen("feedback.md")
documentOpen("draft_slides.qmd")
