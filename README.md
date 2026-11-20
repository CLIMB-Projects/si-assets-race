# Assets, Race and Ethnicity, and Suicidal Ideation (CLIMB)

This repo has the Stata code behind our analysis of whether household financial, social, and physical assets in 2023 are associated with suicidal ideation one year later, and whether those associations differ by race and ethnicity.

> **Citation:** [Manuscript title, authors, journal, year (add once accepted)]

## Data

The analysis uses Waves 4 (2023) and 5 (2024) of the CLIMB study (Cumulative Life Stressors Impact on Mental Health and Well-being), a longitudinal survey of U.S. adults fielded through NORC's AmeriSpeak panel. The data aren't included in this repo. Data are available for research purposes with reasonable request sent to Dr. Ettman (cettman1@jhu.edu).

## Files

All code lives in `src/`.

| File | What it does |
|---|---|
| `01_cleaning_w1w7_11052026.do` | General-purpose CLIMB cleaning template (Waves 1 to 7). Sets 77/98/99 to missing and builds the harmonized demographic, mental health, and asset variables used across CLIMB projects. Only a subset of these are used for this paper. |
| `02_si_vars.do` | Paper-specific variables: the binary suicidal ideation outcome, PHQ-8 score, and Wave 4 income, savings, and debt tertiles. Also sets the variable and value labels that show up in the tables. |
| `03_si_imputation.do` | Defines the analytic sample and fills in missing Wave 4 asset values (details below). |
| `04_si_tables.do` | Main manuscript Tables 1 to 4. |
| `05_si_supplement.do` | Supplemental Tables S1 to S9 and Supplemental Figures S1 to S3. |

## Dependencies

From SSC: `estout` (for `eststo`) and `coefplot`.

```stata
ssc install estout
ssc install coefplot
```

Some portions of the code require custom ADO files that are available by request. These are: `seqmiss` (sequential missingness report), `fvdel` (strips factor-variable prefixes from a varlist), `adjrr_subpop` (adjusted risk ratios after `svy` subpopulation models, adapted from the [`adjrr` package](https://journals.sagepub.com/doi/10.1177/1536867X1301300304)), `mycolors` and `unicode_chars` (graph colors and label characters), and a Mermaid chart template for the sample flowchart. 

## Analytic approach

**Outcome.** Suicidal ideation is PHQ-9 item 9 ("thoughts that you would be better off dead or of hurting yourself in some way"). Anyone reporting several days, more than half the days, or nearly every day in the past two weeks is coded 1, and "not at all" is coded 0. The main outcome is Wave 5 (2024) ideation.

**Predictors.** All measured at Wave 4 (2023): age, gender, race and ethnicity, household income, savings, and debt (tertiles within the analytic sample), health insurance, home ownership, college education, marital status, religious service attendance, employment, perceived social support, and prior depression diagnosis.

**Sample.** Respondents who qualified at both Waves 4 and 5, were 18 or older, had a non-missing Wave 5 ideation response, and had no missing data for any modeled predictor after imputation.

**Missing asset data.** Three asset variables had enough missingness that we recovered values from other sources before taking complete cases:

- Household income: missing CLIMB income was filled with the Wave 4 NORC panel profile income and mapped onto CLIMB's income categories (recovers 57 values).
- Household savings and debt: last observation carried forward, checking Wave 3, then 2, then 1 (recovers 27 and 18 values, respectively).

`05_si_supplement.do` includes a comparison of included and excluded respondents (Table S1).

**Models.** All outputs are survey-weighted using the Wave 4 and 5 longitudinal weights and design variables:

```stata
svyset VPSU32_T4T5 [pweight=WEIGHT_T4T5], strata(VSTRAT32_T4T5)
```

Estimates use `subpop()` rather than dropping observations, so variance estimation reflects the full design while subsetting to the complete case sample.

## Output map

| Output | File | Content |
|---|---|---|
| Table 1 | 04 | Survey-weighted sample characteristics |
| Table 2 | 04 | Sample characteristics by 2024 suicidal ideation |
| Table 3 | 04 | Main logistic regression model |
| Table 4 | 04 | Models stratified by race and ethnicity (White, Black, Hispanic) |
| Figure S1 | 05 | Sample inclusion flowchart (Mermaid `.mmd`) |
| Table S1 | 05 | Included vs. excluded respondents |
| Table S2 | 05 | Analytic sample demographics vs. Current Population Survey benchmarks |
| Table S3 | 05 | Unadjusted odds ratios |
| Table S4 | 05 | Variance inflation factors for the main model |
| Table S5 | 05 | Adjusted risk ratios for the main model |
| Table S6 | 05 | Sample cell sizes by race and ethnicity group for stratified models |
| Table S7 | 05 | Stratified models, all race and ethnicity groups |
| Table S8 | 05 | Adjusted risk ratios for the stratified models |
| Table S9 | 05 | Joint tests of effect modification by race and ethnicity |
| Table S10 | 05 | Base model vs. base + one asset vs. full model |
| Figure S2 | 05 | Coefficient plot, main model |
| Figure S3 | 05 | Coefficient plot, stratified models |

## Contact

Questions about code can be sent to Dr. Catherine Ettman (cettman1@jhu.edu) or Raj Satpathy-Horton (rsatpat1@jh.edu).
