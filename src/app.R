# =============================================================================
# STAT 482 - Case Study 7
# Interactive Business Analytics Dashboard (R Shiny)
# Author: Mohammed
# -----------------------------------------------------------------------------
# Reads an Excel workbook, auto-detects variable types, and produces
# descriptive statistics, frequency tables, grouped summaries, and plots.
# Designed against STAT482_sample_dashboard_dataset.xlsx but works on any
# tidy worksheet (with optional title row above the header).
# =============================================================================

# ---- Package bootstrap ------------------------------------------------------
required_pkgs <- c("shiny", "readxl", "dplyr", "ggplot2", "DT",
                   "tidyr", "scales", "shinythemes")
to_install <- required_pkgs[!(required_pkgs %in% rownames(installed.packages()))]
if (length(to_install)) install.packages(to_install, repos = "https://cloud.r-project.org")

suppressPackageStartupMessages({
  library(shiny)
  library(readxl)
  library(dplyr)
  library(ggplot2)
  library(DT)
  library(tidyr)
  library(scales)
  library(shinythemes)
})

options(shiny.maxRequestSize = 50 * 1024^2)  # allow up to 50 MB uploads

# ---- Helper functions -------------------------------------------------------

# Detect the header row when the sheet has a title above the headers.
# Strategy: read the first 10 rows with no header, pick the first row whose
# cells are mostly non-missing and look like column names.
detect_header_row <- function(path, sheet) {
  preview <- tryCatch(
    suppressMessages(read_excel(path, sheet = sheet, col_names = FALSE, n_max = 10)),
    error = function(e) NULL
  )
  if (is.null(preview) || nrow(preview) == 0) return(0)

  for (i in seq_len(nrow(preview))) {
    row_vals <- as.character(unlist(preview[i, ]))
    non_na   <- sum(!is.na(row_vals) & nzchar(trimws(row_vals)))
    # Header: most cells filled AND no purely numeric tokens
    if (non_na >= max(2, ceiling(ncol(preview) * 0.6))) {
      looks_numeric <- suppressWarnings(!is.na(as.numeric(row_vals)))
      if (mean(looks_numeric, na.rm = TRUE) < 0.3) {
        return(i - 1L)  # rows to skip BEFORE the header
      }
    }
  }
  0L
}

# Classify a single column as numeric / date / categorical / text.
classify_column <- function(x) {
  if (inherits(x, c("POSIXt", "Date"))) return("date")
  if (is.numeric(x))                    return("numeric")
  if (is.logical(x))                    return("categorical")
  # Character or factor: text vs categorical based on cardinality
  vals <- as.character(x)
  vals <- vals[!is.na(vals) & nzchar(vals)]
  if (length(vals) == 0) return("text")
  uniq_ratio <- length(unique(vals)) / length(vals)
  avg_len    <- mean(nchar(vals))
  if (uniq_ratio > 0.5 && avg_len > 25) "text" else "categorical"
}

# Numeric summary table (n, missing, mean, median, sd, min, max, q1, q3).
numeric_summary <- function(df, vars) {
  if (length(vars) == 0) return(data.frame())
  rows <- lapply(vars, function(v) {
    x <- suppressWarnings(as.numeric(df[[v]]))
    data.frame(
      Variable = v,
      N        = sum(!is.na(x)),
      Missing  = sum(is.na(x)),
      Mean     = round(mean(x, na.rm = TRUE), 3),
      Median   = round(median(x, na.rm = TRUE), 3),
      SD       = round(sd(x, na.rm = TRUE), 3),
      Min      = round(suppressWarnings(min(x, na.rm = TRUE)), 3),
      Q1       = round(quantile(x, 0.25, na.rm = TRUE), 3),
      Q3       = round(quantile(x, 0.75, na.rm = TRUE), 3),
      Max      = round(suppressWarnings(max(x, na.rm = TRUE)), 3),
      stringsAsFactors = FALSE,
      row.names = NULL
    )
  })
  do.call(rbind, rows)
}

# Frequency table for a categorical variable.
frequency_table <- function(df, var) {
  x <- df[[var]]
  tab <- as.data.frame(table(Value = x, useNA = "ifany"), stringsAsFactors = FALSE)
  tab$Percent <- round(100 * tab$Freq / sum(tab$Freq), 2)
  tab <- tab[order(-tab$Freq), ]
  names(tab) <- c("Value", "Count", "Percent")
  tab
}

# Grouped summary of a numeric variable by a categorical variable.
grouped_summary <- function(df, num_var, group_var) {
  df %>%
    mutate(.group = as.character(.data[[group_var]]),
           .num   = suppressWarnings(as.numeric(.data[[num_var]]))) %>%
    group_by(.group) %>%
    summarise(
      N       = sum(!is.na(.num)),
      Missing = sum(is.na(.num)),
      Mean    = round(mean(.num, na.rm = TRUE), 3),
      Median  = round(median(.num, na.rm = TRUE), 3),
      SD      = round(sd(.num, na.rm = TRUE), 3),
      Min     = round(suppressWarnings(min(.num, na.rm = TRUE)), 3),
      Max     = round(suppressWarnings(max(.num, na.rm = TRUE)), 3),
      .groups = "drop"
    ) %>%
    rename(!!group_var := .group) %>%
    arrange(desc(Mean))
}

# ---- UI ---------------------------------------------------------------------
ui <- fluidPage(
  theme = shinytheme("flatly"),
  titlePanel("STAT 482 - Retail Customer Experience Dashboard"),

  sidebarLayout(
    sidebarPanel(
      width = 3,
      h4("1. Load Data"),
      fileInput("file", "Upload Excel workbook (.xlsx)",
                accept = c(".xlsx", ".xls")),
      uiOutput("sheet_ui"),
      checkboxInput("auto_header", "Auto-detect header row", value = TRUE),
      conditionalPanel(
        "input.auto_header == false",
        numericInput("skip_rows", "Rows to skip before header", value = 0,
                     min = 0, max = 20, step = 1)
      ),
      hr(),
      h4("2. Filter (optional)"),
      uiOutput("filter_ui"),
      hr(),
      helpText("Built for STAT 482 Case Study 7. Verify any ChatGPT-suggested",
               "statistic against the raw worksheet before reporting.")
    ),

    mainPanel(
      width = 9,
      tabsetPanel(
        id = "tabs",
        tabPanel("Overview",
          br(),
          fluidRow(
            column(3, wellPanel(h4(textOutput("kpi_rows")),    "Rows")),
            column(3, wellPanel(h4(textOutput("kpi_cols")),    "Columns")),
            column(3, wellPanel(h4(textOutput("kpi_numeric")), "Numeric vars")),
            column(3, wellPanel(h4(textOutput("kpi_cat")),     "Categorical vars"))
          ),
          h4("Detected variable types"),
          DTOutput("type_table"),
          h4("Missing values per column"),
          plotOutput("missing_plot", height = "320px")
        ),

        tabPanel("Numeric Summary",
          br(),
          helpText("Descriptive statistics for every detected numeric variable."),
          DTOutput("numeric_table")
        ),

        tabPanel("Categorical Summary",
          br(),
          uiOutput("cat_var_ui"),
          DTOutput("freq_table")
        ),

        tabPanel("Grouped Summary",
          br(),
          fluidRow(
            column(6, uiOutput("group_num_ui")),
            column(6, uiOutput("group_cat_ui"))
          ),
          DTOutput("group_table")
        ),

        tabPanel("Plot",
          br(),
          fluidRow(
            column(6, uiOutput("plot_var_ui")),
            column(6, uiOutput("plot_group_ui"))
          ),
          plotOutput("explore_plot", height = "450px")
        ),

        tabPanel("Raw Data",
          br(),
          helpText("Searchable preview of the loaded worksheet (after the",
                   "header row is detected and any filters applied)."),
          DTOutput("raw_table")
        ),

        tabPanel("About",
          br(),
          tags$div(
            tags$h3("Dashboard purpose"),
            tags$p("Built for STAT 482 Case Study 7 (Spring 2026). The app",
                   "lets a manager upload an Excel workbook with mixed",
                   "quantitative and qualitative variables and quickly",
                   "inspect descriptive summaries on demand."),
            tags$h4("Features"),
            tags$ul(
              tags$li("Excel upload with worksheet selection."),
              tags$li("Automatic header-row detection (handles title rows)."),
              tags$li("Automatic variable-type classification."),
              tags$li("Numeric summary table: n, missing, mean, median, SD, min, Q1, Q3, max."),
              tags$li("Frequency table for any categorical variable."),
              tags$li("Grouped summary of a numeric variable by a category."),
              tags$li("Histogram, boxplot, or bar chart for quick exploration."),
              tags$li("Searchable raw-data preview with column filters."),
              tags$li("Sidebar filters on suggested fields (Region, Channel, etc.).")
            ),
            tags$h4("ChatGPT use note"),
            tags$p("ChatGPT was used to brainstorm the layout and to draft",
                   "starter helper functions. Every statistic was cross-checked",
                   "against manual calculations in Excel before submission.")
          )
        )
      )
    )
  )
)

# ---- Server -----------------------------------------------------------------
server <- function(input, output, session) {

  # Reactive: list of sheets in the uploaded file
  sheet_names <- reactive({
    req(input$file)
    excel_sheets(input$file$datapath)
  })

  output$sheet_ui <- renderUI({
    req(sheet_names())
    selectInput("sheet", "Worksheet", choices = sheet_names(),
                selected = sheet_names()[1])
  })

  # Reactive: raw data with header-row handling
  raw_data <- reactive({
    req(input$file, input$sheet)
    skip <- if (isTRUE(input$auto_header)) {
      detect_header_row(input$file$datapath, input$sheet)
    } else {
      input$skip_rows %||% 0
    }
    df <- suppressMessages(
      read_excel(input$file$datapath, sheet = input$sheet, skip = skip)
    )
    # Drop fully empty columns (Excel artifacts)
    df <- df[, colSums(!is.na(df)) > 0, drop = FALSE]
    # Make column names safer
    names(df) <- make.names(names(df), unique = TRUE)
    df
  })

  # Reactive: classified columns
  classes <- reactive({
    df <- raw_data()
    sapply(df, classify_column)
  })

  numeric_vars <- reactive(names(classes())[classes() == "numeric"])
  cat_vars     <- reactive(names(classes())[classes() == "categorical"])
  date_vars    <- reactive(names(classes())[classes() == "date"])
  text_vars    <- reactive(names(classes())[classes() == "text"])

  # Sidebar filters: only show for the suggested filter columns if present
  output$filter_ui <- renderUI({
    df <- raw_data()
    suggested <- c("Region", "Channel", "Product_Category",
                   "Customer_Segment", "Loyalty_Tier")
    avail <- intersect(suggested, names(df))
    if (length(avail) == 0) return(helpText("No suggested filter columns found."))
    lapply(avail, function(v) {
      selectInput(paste0("flt_", v), v,
                  choices  = c("(All)", sort(unique(as.character(df[[v]])))),
                  selected = "(All)")
    })
  })

  # Reactive: filtered data based on sidebar selections
  filtered_data <- reactive({
    df <- raw_data()
    for (v in c("Region", "Channel", "Product_Category",
                "Customer_Segment", "Loyalty_Tier")) {
      sel <- input[[paste0("flt_", v)]]
      if (!is.null(sel) && sel != "(All)" && v %in% names(df)) {
        df <- df[as.character(df[[v]]) == sel, , drop = FALSE]
      }
    }
    df
  })

  # ---- Overview tab ---------------------------------------------------------
  output$kpi_rows    <- renderText(nrow(filtered_data()))
  output$kpi_cols    <- renderText(ncol(filtered_data()))
  output$kpi_numeric <- renderText(length(numeric_vars()))
  output$kpi_cat     <- renderText(length(cat_vars()))

  output$type_table <- renderDT({
    df <- filtered_data()
    cls <- classes()
    data.frame(
      Variable     = names(df),
      Detected_Type = unname(cls[names(df)]),
      Unique_Values = sapply(df, function(x) length(unique(x))),
      Missing       = sapply(df, function(x) sum(is.na(x))),
      stringsAsFactors = FALSE
    )
  }, options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)

  output$missing_plot <- renderPlot({
    df <- filtered_data()
    miss <- data.frame(
      Variable = names(df),
      Missing  = sapply(df, function(x) sum(is.na(x))),
      stringsAsFactors = FALSE
    )
    miss <- miss[order(-miss$Missing), ]
    ggplot(miss, aes(x = reorder(Variable, Missing), y = Missing)) +
      geom_col(fill = "#2c7fb8") +
      coord_flip() +
      labs(x = NULL, y = "Missing values") +
      theme_minimal(base_size = 12)
  })

  # ---- Numeric Summary tab --------------------------------------------------
  output$numeric_table <- renderDT({
    nv <- numeric_vars()
    if (length(nv) == 0) {
      return(datatable(data.frame(Note = "No numeric variables detected.")))
    }
    datatable(numeric_summary(filtered_data(), nv),
              options = list(pageLength = 15, scrollX = TRUE),
              rownames = FALSE)
  })

  # ---- Categorical Summary tab ----------------------------------------------
  output$cat_var_ui <- renderUI({
    cv <- cat_vars()
    if (length(cv) == 0) return(helpText("No categorical variables detected."))
    selectInput("cat_var", "Categorical variable", choices = cv,
                selected = cv[1])
  })

  output$freq_table <- renderDT({
    req(input$cat_var)
    datatable(frequency_table(filtered_data(), input$cat_var),
              options = list(pageLength = 15), rownames = FALSE)
  })

  # ---- Grouped Summary tab --------------------------------------------------
  output$group_num_ui <- renderUI({
    nv <- numeric_vars()
    selectInput("group_num", "Numeric variable", choices = nv,
                selected = if (length(nv)) nv[1] else NULL)
  })
  output$group_cat_ui <- renderUI({
    cv <- cat_vars()
    selectInput("group_cat", "Group by (categorical)", choices = cv,
                selected = if (length(cv)) cv[1] else NULL)
  })

  output$group_table <- renderDT({
    req(input$group_num, input$group_cat)
    datatable(grouped_summary(filtered_data(), input$group_num, input$group_cat),
              options = list(pageLength = 15, scrollX = TRUE),
              rownames = FALSE)
  })

  # ---- Plot tab -------------------------------------------------------------
  output$plot_var_ui <- renderUI({
    all_vars <- c(numeric_vars(), cat_vars())
    selectInput("plot_var", "Variable to plot", choices = all_vars,
                selected = if (length(all_vars)) all_vars[1] else NULL)
  })
  output$plot_group_ui <- renderUI({
    cv <- c("(none)", cat_vars())
    selectInput("plot_group", "Optional group/colour", choices = cv,
                selected = "(none)")
  })

  output$explore_plot <- renderPlot({
    req(input$plot_var)
    df <- filtered_data()
    v  <- input$plot_var
    g  <- input$plot_group
    is_num <- v %in% numeric_vars()
    p <- if (is_num) {
      base <- ggplot(df, aes(x = .data[[v]]))
      if (!is.null(g) && g != "(none)" && g %in% names(df)) {
        base + geom_histogram(aes(fill = as.character(.data[[g]])),
                              bins = 25, position = "identity",
                              alpha = 0.65, colour = "white") +
          labs(fill = g)
      } else {
        base + geom_histogram(bins = 25, fill = "#2c7fb8", colour = "white")
      }
    } else {
      counts <- df %>%
        mutate(.x = as.character(.data[[v]])) %>%
        count(.x, sort = TRUE)
      ggplot(counts, aes(x = reorder(.x, n), y = n)) +
        geom_col(fill = "#2c7fb8") +
        coord_flip() +
        labs(x = v, y = "Count")
    }
    p + labs(title = paste("Distribution of", v)) +
      theme_minimal(base_size = 13)
  })

  # ---- Raw Data tab ---------------------------------------------------------
  output$raw_table <- renderDT({
    datatable(filtered_data(),
              filter = "top",
              options = list(pageLength = 15, scrollX = TRUE),
              rownames = FALSE)
  })
}

# Convenience NULL-coalescing operator (Shiny ships its own, but be explicit)
`%||%` <- function(a, b) if (is.null(a)) b else a

# ---- Launch -----------------------------------------------------------------
shinyApp(ui = ui, server = server)
