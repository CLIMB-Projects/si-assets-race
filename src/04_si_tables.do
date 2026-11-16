*=====================================================*
* Project: CLIMB - Assets and SI
* File:    04_si_tables.do
* Author:  Rajesh Satpathy-Horton
* Purpose: Generate manuscript-ready tables and figures.
* Init:    11/05/2026
* Updated: 11/05/2026
*=====================================================*
*-----------------------------------------------------*
* Init
*-----------------------------------------------------*
*--Init items for analysis -- uncomment if running alone
* Set globals and working dir
// edit $climb and $proj to run in local env; other globals can be kept the same
global climb    "C:/Users/rsatpat1/Dropbox/CLIMB Operations/Data (non-confidential)/Waves 1-7 - 08.04.2026/JHU_COVID-19 W1_W2_W3_W4_W5_W6_W7_Combined_File_20260804.dta"
global proj     "C:/Users/rsatpat1/Dropbox/CLIMB Operations/Projects/PHQ9 Suicidal Ideation"

global code "$proj/03_code"
global out  "$proj/04_output"

cd "$proj"

* Import W1-W7 data, clean data, and generate analytic vars
use "$climb", clear 
run "$code/01_cleaning_w1w7_11052026.do"
run "$code/02_si_vars.do"
run "$code/03_si_imputation.do"

* Set survey design
svyset VPSU32_T4T5 [pweight=WEIGHT_T4T5], strata(VSTRAT32_T4T5)

* Prep global macros // predictors_noimp contains vars WITH NO IMPUTATION
global predictors_noimp "ib4.AGE4_T4 ib1.GENDER_T4 ib1.race_col_T4 ib3.hh_income_tert_T4 ib3.hh_savings_tert_T4 ib1.hh_debt_tert_T4 ib1.insurance_binary_T4 ib1.home_own_T4 ib1.educ_college_T4 ib1.marital_binary_T4 ib1.religious_attendance_T4 ib1.employment_T4 ib1.social_support_T4 ib0.prev_depression_T4"

global predictors "ib4.AGE4_T4 ib1.GENDER_T4 ib1.race_col_T4 ib3.hh_income_imp_tert_T4 ib3.locf_hh_savings_tert_T4 ib1.locf_hh_debt_tert_T4 ib1.insurance_binary_T4 ib1.home_own_T4 ib1.educ_college_T4 ib1.marital_binary_T4 ib1.religious_attendance_T4 ib1.employment_T4 ib1.social_support_T4 ib0.prev_depression_T4"
fvdel, in($predictors) out(predictors_list)

global stratpred "ib4.AGE4_T4 ib1.GENDER_T4 ib3.hh_income_imp_tert_T4 ib3.locf_hh_savings_tert_T4 ib1.locf_hh_debt_tert_T4 ib1.insurance_binary_T4 ib1.home_own_T4 ib1.educ_college_T4 ib1.marital_binary_T4 ib1.religious_attendance_T4 ib1.employment_T4 ib1.social_support_T4 ib0.prev_depression_T4"
fvdel, in($stratpred) out(stratpred_list)

*==================================*
* Verify ADO statuses.
di "Verifying custom ADOs..."
* ADOs needed are:
local adolist "seqmiss fvdel mycolors unicode_chars"
foreach ado of local adolist {
    cap which `ado'
    if _rc {
        di as err "ADO not found: `ado' - request from RSH if required."
    }
    else if "`ado'"=="unicode_chars" | "`ado'"=="mycolors" {
        `ado'
    }
}
*==================================*
*-----------------------------------------------------*
* Sample identification
*-----------------------------------------------------*
*--Regenerate sample for clarity.
* Def base sample (qual + no missing exposure + >=18yo)
cap drop base_sample _insample
g base_sample = QUAL_T4==1 & QUAL_T5==1 & !missing(si_T5) & inrange(AGE4_T4,1,4)

* Identify complete case sample (byte required for markout)
g byte _insample = base_sample
markout _insample $predictors

* Evaluate sequential missingness
seqmiss $predictors_list if base_sample 
qui count if _insample
di as res "Complete case sample: n = " r(N)

*-----------------------------------------------------*
* Table 1. Overall sample characteristics
*-----------------------------------------------------*
*--Export survey-weighted sample characteristics.
* Generate table
collect clear 
dtable i.si_T5 i.si_T4 ${predictors}, ///
	svy subpop(if _insample==1) ///
	factor(, statistics(fvrawfreq fvpercent)) ///
	column(summary("N (Weighted %)")) ///
	sample(,statistics(freq)) ///
	title("Table 1. Survey-weighted sample characteristics") ///
	note(`"Note: CLIMB Waves 4-5 data, collected March-April 2026. Frequencies (N) are unweighted and percentages (%) are survey weighted. All categories recorded in 2023. Suicidal ideation defined as reporting “thoughts that you would be better off dead or of hurting yourself in some way” for “several days”, “more than half the days”, or “nearly every day” in the past 2 weeks. 2023 suicidal ideation not accounted for in complete case selection and has n=1,879 total observations."')
collect style cell header_cell_contents[factor dimension], font(, bold) // bolded fv level headers
collect preview 

*------------ Export? -----------------*
di "Export Table 1? (Y/N)", _request(RESP)
if strlower("$RESP")=="y" collect export "$out/tbl1_svywt_overall_sample.docx", replace
qui else di as err "Table not saved."

*-----------------------------------------------------*
* Table 2. Sample by W5 SI
*-----------------------------------------------------*
*--Export survey-weighted sample by exposure status.
*----------------------------------*
* Set args
*----------------------------------*
*--Define local macros to use as input directly.
local outcome  "si_T5"
local insamp   "_insample==1" 
local covars   "$predictors_list si_T4" 
local tblnum   "Table 2"
local tblnotes "Notes: CLIMB Waves 4-5 data, collected March-April 2026. Values are unweighted N (survey-weighted row %) for outcome columns and unweighted N (survey-weighted column %) for the Total column. P-values from design-based Pearson chi-square tests. Includes participants with complete cases for W5 suicidal ideation and the following Wave 4 variables: age, gender, race and ethnicity, household income, household savings, household debt, health insurance status, home ownership, education, marital status, religious service attendance, employment status, social support, and previous depression. 2023 suicidal ideation not accounted for in complete case selection and has n=1,879 total observations."
local outfile  "$out/tbl2_sample_by_outcome_svy.docx"

*----------------------------------*
* Table generation
*----------------------------------*
*--Generate table using inputs above.
* Outcome labels, pulled from the outcome itself (fail loudly if missing)
local outvallab : value label `outcome'
if "`outvallab'" == "" {
    di as error "`outcome' has no value label; column headers would show raw codes"
    exit 198
}
local outvarlab : variable label `outcome'
if "`outvarlab'" == "" local outvarlab "`outcome'"
local tbltitle "`tblnum'. Survey-weighted sample characteristics by `outvarlab'"

* Setup
collect clear

* Header n's (unweighted) and outcome levels from subpop
qui tab `outcome' if `insamp', matcell(B) matrow(BR)
local tot = string(r(N), "%9.0fc")
local outlvls ""
forval j = 1/`=rowsof(B)' {
    local b = BR[`j',1]
    local outlvls `outlvls' `b'
    local hdr_n`b' = string(B[`j',1], "%9.0fc")
}

* Loop 1: unweighted N, weighted row %, and design-based p per covariate
foreach x of local covars {
    qui svy, subpop(if `insamp'): tab `x' `outcome', ///
        percent row obs pearson collect(tbl, append) format(%5.2f)
}

* Loop 2: weighted column % for the Total column, and p-value placement
local n = 0
foreach x of local covars {
    local ++n

    qui svy, subpop(if `insamp'): proportion `x'
    qui levelsof `x' if `insamp', local(lvls)
    foreach lv of local lvls {
        collect get marg_pct = (_b[`lv'.`x']*100), ///
            tags(cmdset[`n'] `x'[`lv'] `outcome'[__margCode__]) name(tbl)
    }

    * P-value sits on the covariate's first level row
    local first : word 1 of `lvls'
    collect addtags `x'[`first'], fortags(cmdset[`n']#result[p_Pear]) name(tbl)
}

* Composite cells
collect style cell result[obs], nformat(%9.0fc)
collect style cell result[row_percent], nformat(%3.1f) sformat("(%s%%)")
collect style cell result[marg_pct], nformat(%3.1f) sformat("(%s%%)")

collect composite define obs_rowpct  = obs row_percent, replace
collect composite define obs_margpct = obs marg_pct, replace
collect label levels result obs_rowpct  "N (%)", modify
collect label levels result obs_margpct "N (%)", modify

* Column headers from the outcome's value labels
foreach b of local outlvls {
    local olab : label (`outcome') `b'
    collect label levels `outcome' `b' "`olab' (n=`hdr_n`b'')", modify
}
collect label levels `outcome' __margCode__ "Total (n=`tot')", modify

* P-value format
collect style cell result[p_Pear], nformat(%6.3f) minimum(0.001)
collect label levels result p_Pear "P-value", modify

* Layout: outcome columns use row %, Total column uses column %
collect layout (cmdset#`covars') ///
    (`outcome'[`outlvls']#result[obs_rowpct] ///
     `outcome'[__margCode__]#result[obs_margpct] ///
     result[p_Pear])
collect style cell header_cell_contents[factor], font(, bold)

* Text
collect title "`tbltitle'"
collect notes "`tblnotes'"
collect preview

*------------ Export? -----------------*
di "Export table? (Y/N)", _request(RESP)
if "$RESP"=="Y" collect export "`outfile'", replace
else di "Table not saved."

*-----------------------------------------------------*
* Table 3. Regression model
*-----------------------------------------------------*
*--Logistic regression model estimating associations with W5 SI
* Estimate full model
collect clear
collect: svy, subpop(if _insample==1): logistic si_T5 $predictors, baselevels
local res "_r_b _r_se _r_p _r_ci"
collect layout (colname extra) (result[`res'])
collect style use table-reg1-fv1
collect style row stack, nobinder indent

* Integrate sample sizes
foreach x in N_sub {
    collect addtags extra[`x'], fortags(result[`x']) 
}
collect label levels extra N_sub "# observations", modify
collect recode result N_sub=_r_b

* Style cells
collect style cell result[_r_b _r_ci _r_se], nformat(%5.2f)
collect style cell result, empty("--")
collect style cell result[_r_ci], cidelimiter(", ")
collect style cell result[_r_ci], sformat("(%s)")
collect style cell extra[N_sub], nformat(%5.0f)
collect style showbase factor
collect style cell header_cell_contents[factor dimension], font(, bold) // bolded fv level headers
collect style cell result[_r_p], nformat(%4.3f) min(0.001) // present extremely small p-values as "<0.001" 
collect stars _r_p 0.001 "***" 0.01 "** " 0.05 "* ", attach(_r_b) shownote

*----- Label referent level rows -----*
* Get list of base vars with no "b" (e.g., ib2.SEX_T7 -> 2.SEX_T7)
local basetags
foreach term of global predictors {
    if regexm("`term'", "^ib([0-9]+)\.(.+)$") {
        local basetags "`basetags' `=regexs(1)'.`=regexs(2)'"
    }
}
di "`basetags'"

* Replace OR with "Ref" and harmonize SD display for referents
collect style cell colname[`basetags']#result[_r_b], nformat(%5.2f) minimum(999999, label("Ref")) font(,italic) halign(right)
collect style cell colname[`basetags']#result[_r_se], nformat(%5.2f) minimum(999999, label("--"))
collect preview

* Add text
collect title "Table 3. Survey-weighted logistic regression estimating 2024 suicidal ideation using 2023 characteristics"
collect notes "Notes: CLIMB Waves 4-5 data, collected March-April 2023-2024. Includes N=1,896 observations with complete cases."

* Output table
collect preview

*------------ Export? -----------------*
di "Export Table 3? (Y/N)", _request(RESP)
if strlower("$RESP")=="y" collect export "$out/tbl3_main_regression_model.docx", replace
qui else di as err "Table not saved."

*-----------------------------------------------------*
* Table 4. Stratified logistic regression models
*-----------------------------------------------------*
*--Export survey-weighted stratified logistic regression results for paper
* Init stratified predictor global
global stratpred : subinstr global predictors "i.race_col_T4 " ""
fvdel, in($stratpred) out(stratpred_list)

* Collect all survey-weighted model outputs
collect clear
forval i=1/3 {
	collect: svy, subpop(if _insample==1 & race_col_T4==`i'): logistic si_T5 $stratpred, baselevels
	eststo m`i'
}

* Init layout
collect layout (colname#result[_r_b _r_ci]) (cmdset)
collect style use table-reg1-fv1
collect style row stack, nobinder indent

* Integrate sample sizes
foreach x in N_sub {
    collect addtags extra[`x'], fortags(result[`x']) 
}
collect label levels extra N_sub "# observations", modify
collect recode result N_sub=_r_b

* Style cells
collect style cell result[_r_b _r_ci], nformat(%5.2f)
collect style cell result, empty("--")
collect style cell result[_r_ci], cidelimiter(", ")
collect style cell result[_r_ci], sformat("[%s]")
collect style cell extra[N_sub], nformat(%5.0f)
collect style showbase factor
collect style cell header_cell_contents[factor dimension], font(, bold) // bolded fv level headers
collect style cell result[_r_p], nformat(%4.3f) min(0.001) // present extremely small p-values as "<0.001" 
collect stars _r_p 0.001 "***" 0.01 "** " 0.05 "* ", attach(_r_b) shownote
collect style header result, level(hide)

* Get list of base vars with no "b" (e.g., ib2.SEX_T7 -> 2.SEX_T7)
local basetags
foreach term of global stratpred {
    if regexm("`term'", "^ib([0-9]+)\.(.+)$") {
        local basetags "`basetags' `=regexs(1)'.`=regexs(2)'"
    }
}
di "`basetags'"

* Replace OR with "Ref" and harmonize SD display for referents
collect style cell colname[`basetags']#result[_r_b], nformat(%5.2f) minimum(999999, label("Ref")) font(,italic) halign(right)
collect preview
collect title "Table 4. Stratified survey-weighted logistic regression estimating odds ratios of 2024 suicidal ideation using 2023 characteristics"

* Get counts
forval i=1/4 {
    qui count if race_col_T4==`i'
    local c`i' = string(`r(N)', "%5.0fc")
    di "`c`i''"
}
collect notes "Notes: From left to right, Table 4 displays the the odds ratios (95% CI) estimated for the White, non-Hispanic subgroup (n=`c1'), Black, non-Hispanic subgroup (N=`c2'), and the Hispanic subgroup (N=`c3'). The Other, non-Hispanic group is not shown here due to small sample size and wide intervals. Ssee Supplemental Table 4 for a model containing all stratified models."

* Set model names
collect label levels cmdset 1 "Model (1) White, non-Hispanic" 2 "Model (2) Black, non-Hispanic" 3 "Model (3) Hispanic", modify
collect preview

*------------ Export? -----------------*
di "Export Table 4? (Y/N)", _request(RESP)
if strlower("$RESP")=="y" collect export "$out/tbl4_stratified_models.docx", replace
qui else di as err "Table not saved."
