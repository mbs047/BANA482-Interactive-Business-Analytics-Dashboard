# STAT 482 Case 7 - Interactive Business Analytics Dashboard

I built this case study as an R Shiny dashboard for a retail customer-experience dataset. The dashboard lets a manager upload an Excel workbook, review data quality, explore descriptive summaries, and compare business metrics across categories without writing code.

## What I Am Sharing

- `Deliverable/Dashboard.R` - the Shiny app source code.
- `Deliverable/STAT482_case_report.pdf` - the final written report.
- `Deliverable/STAT482_presentation.pdf` - the final presentation deck.
- `Office Open XML spreadsheet.xlsx` - the Excel workbook used for the dashboard case.
- `Screenshots/` - screenshots of the dashboard tabs and outputs.
- `STAT482_case_report.docx` and `STAT482_presentation.pptx` - editable source files for the report and presentation.

## Dashboard Focus

I designed the dashboard around mixed business data: numeric variables such as order value, discount rate, wait time, satisfaction score, and NPS, plus categorical variables such as region, channel, product category, loyalty tier, and complaint theme.

The app supports:

- Excel upload and worksheet selection.
- Automatic header-row detection.
- Automatic variable-type classification.
- Numeric summary statistics.
- Categorical frequency tables.
- Grouped summaries of numeric metrics by category.
- Custom exploratory plots.
- Searchable raw-data preview.

## How I Run It

1. Open R or RStudio.
2. Set the working directory to this case folder.
3. Run the dashboard file:

```r
shiny::runApp("Deliverable/Dashboard.R")
```

The script installs any missing R packages from CRAN before launching the app. I used `shiny`, `readxl`, `dplyr`, `ggplot2`, `DT`, `tidyr`, `scales`, and `shinythemes`.

## Notes

I used ChatGPT as a coding and layout assistant, then checked the dashboard outputs against the raw workbook and manual calculations before submitting. Course-provided prompts, rubrics, and datasets remain credited to their original sources.

## License

I am releasing my code and original written work in this repository under the MIT License. Third-party course materials and datasets keep their original ownership and usage terms.
