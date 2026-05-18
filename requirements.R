packages <- c(
  "shiny",
  "readxl",
  "dplyr",
  "ggplot2",
  "DT",
  "tidyr",
  "scales",
  "shinythemes"
)

missing_packages <- setdiff(packages, rownames(installed.packages()))

if (length(missing_packages) > 0) {
  install.packages(missing_packages)
}

invisible(lapply(packages, library, character.only = TRUE))

