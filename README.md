# BANA482 | Interactive Business Analytics Dashboard

I built this case study as an R Shiny dashboard for a retail customer-experience dataset. The dashboard lets a manager upload an Excel workbook, review data quality, explore descriptive summaries, and compare business metrics across categories without writing code.

## What I Am Sharing

- `src/app.R` - the Shiny app source code.
- `data/retail_customer_experience.xlsx` - the Excel workbook used for the dashboard case.
- `deliverables/case7-report.pdf` - the final written report.
- `deliverables/case7-presentation.pdf` - the final presentation deck.
- `editable/` - editable source files for the report and presentation.
- `assets/screenshots/` - screenshots of the dashboard tabs and outputs.
- `references/` - assignment handouts and case instructions.

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
3. Install the required packages:

```r
source("requirements.R")
```

4. Run the dashboard file:

```r
shiny::runApp("src")
```

The app uses `shiny`, `readxl`, `dplyr`, `ggplot2`, `DT`, `tidyr`, `scales`, and `shinythemes`.

## Notes

I used ChatGPT as a coding and layout assistant, then checked the dashboard outputs against the raw workbook and manual calculations before submitting. Course-provided prompts, rubrics, and datasets remain credited to their original sources.

## License

I am releasing my code and original written work in this repository under the MIT License. Third-party course materials and datasets keep their original ownership and usage terms.
