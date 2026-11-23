*=====================================================*
* Project: CLIMB - Assets and SI
* File:    05_si_supplement.do
* Author:  Rajesh Satpathy-Horton
* Purpose: Generate supplemental tables and figures.
* Init:    11/05/2026
* Updated: 11/20/2026
*=====================================================*
*-----------------------------------------------------*
* Init
*-----------------------------------------------------*
*--Init items for analysis
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
* Supplemental Figure 1. Sample inclusion flowchart
*-----------------------------------------------------*
*--Def nested sample restrictions and output a Mermaid flowchart.
* Def global pointer to engine
global mermaid_engine "Z:/personal_ado/mermaid_templates/sample_flow_engine.do"

*----------------------------------*
* Step flags
*----------------------------------*
*--Def 0/1 flags, each nested in the one before.
* Starting cohort: invited to W4 + W5
g invited = !missing(QUAL_T4, QUAL_T5)

* Qualified at both waves
g qualified = invited & QUAL_T4==1 & QUAL_T5==1 & inrange(AGE4_T4,1,4)

* Non-missing outcome
g has_outcome = qualified & !missing(si_T5)

* Complete case sample on model covariates
g byte mermaid_sample = has_outcome
markout mermaid_sample $predictors_list

*----------------------------------*
* Flowchart config
*----------------------------------*
*--Def flag order, box labels, and output options.
* Flag order (starting cohort -> analytic sample)
local flow_flags invited qualified has_outcome mermaid_sample

* Retained (keep) and excluded (drop) box labels by step
local keep_1 "Invited to Waves 4 and 5"

local drop_2 "Not qualified at both waves or <18yo at W4"
local keep_2 "Qualified at both waves"

local drop_3 "Missing 2024 suicidal ideation"
local keep_3 "Has outcome (2024 SI)"

local drop_4 "Missing Wave 5 covariates"
local drop_4_detail $predictors_list
local keep_4 "Included in the analysis"

* Optional strata variable and output path
local flow_strata ""
local flow_out "$out/sample_flow.mmd"

* Generate counts and flowchart
include "$mermaid_engine"

*-----------------------------------------------------*
* Supplemental Table 1. Comparison of included + excluded demos
*-----------------------------------------------------*
*--Generate a table that compares the included vs excluded samples by demos.
* Create var to ID each
g sample_status = . 
replace sample_status = 1 if _insample
replace sample_status = 0 if !_insample & (QUAL_T4==1 & QUAL_T5==1 & inrange(AGE4_T4, 1, 4))
la def samplbl 0 "Excluded qualified responses due to missingness" 1 "Included analytic sample", replace
la val sample_status samplbl
la var sample_status "Sample inclusion status"

* Create table
local demos "i.AGE4_T4 i.GENDER_T4 i.race_col_T4"
dtable `demos', by(sample_status, tests) svy ///
    sample(, statistics(freq percent)) ///
    factor(, statistics(fvrawfrequency fvpercent)) ///
    title("Supplemental Table 1. Comparison of responses by sample inclusion status")

*------------ Export? -----------------*
di "Export STable1? (Y/N)", _request(RESP)
if strlower("$RESP")=="y" collect export "$out/tblS1_comparison_by_inclusion.docx", replace
qui else di as err "Table not saved."

*-----------------------------------------------------*
* Supplemental Table 2. Comparison of national vs CLIMB weighted samples
*-----------------------------------------------------*
*--Create weighted demographic %s from analytic sample.
* Def CPS benchmarks (static weighted %; rownames = collect tags)
matrix CPS = (20.1 \ 25.8 \ 23.5 \ 30.6 \ 48.8 \ 51.2 \ 61.4 \ 12.1 \ 17.5 \ 9.1)
matrix rownames CPS = 1.AGE4_T4 2.AGE4_T4 3.AGE4_T4 4.AGE4_T4 1.GENDER_T4 2.GENDER_T4 ///
    1.race_col_T4 2.race_col_T4 3.race_col_T4 4.race_col_T4

* Run dtable for sample cols 
local demos "i.AGE4_T4 i.GENDER_T4 i.race_col_T4"
dtable `demos', svy subpop(if _insample==1) ///
    factor(, statistics(fvrawfrequency fvrawpercent fvpercent)) ///
    title("Supplemental Table 2. Comparison of Weighted and Unweighted Demographic Distribution of Analytic Sample to CPS Benchmarks")
collect addtags source[sample]

* Add CPS values to collection
local i = 0
foreach lev in `: rownames CPS' {
    collect get cps = (CPS[`++i', 1]), tags(var[`lev'] source[cps])
}

* Def composites and formats
collect composite define unwt = frequency fvrawfrequency fvrawpercent, trim replace
collect composite define wt   = frequency fvpercent, trim replace
collect style cell result[frequency fvrawfrequency], nformat(%9.0fc)
collect style cell result[fvrawpercent], nformat(%5.1f) sformat("(%s%%)")
collect style cell result[fvpercent cps], nformat(%5.1f) sformat("%s%%")

* Apply lbls and layout
collect label levels source sample "Analytic Sample" cps "Current Population Survey", modify
collect label levels result unwt "Unweighted N (%)" wt "Weighted %" cps "Weighted %", modify
collect style header source result, title(hide) level(label)
collect style column, dups(center)
collect layout (var) (source[sample]#result[unwt wt] source[cps]#result[cps])

* Preview and export
collect preview 
collect export "$out/tblS2_demo_distribution_with_cps.docx", replace

*-----------------------------------------------------*
* Supplemental Table 3. Cell sizes by race / ethnicity
*-----------------------------------------------------*
*--Generate a table with cell sizes for race-stratified models.
* Output table
dtable $stratpred, by(race_col_T4, nototal) ///
    svy subpop(if _insample==1) ///
	factor(, statistics(fvrawfreq)) ///
	column(summary("N")) ///
	sample(,statistics(freq)) ///
	title("Supplemental Table 3. Demographic and asset distributions across race and ethnicity groups") ///
	note("Note: Table displays the unweighted number of participants within each category by race and ethnicity.")

*------------ Export? -----------------*
di "Export Supplemental Table 3? (Y/N)", _request(RESP)
if strlower("$RESP")=="y" collect export "tblS3_cell_sizes_by_race.docx", replace
qui else di as err "Table not saved."

*-----------------------------------------------------*
* Supplemental Table 4. Unadjusted ORs (main model)
*-----------------------------------------------------*
*--Generate table with unadjusted ORs for main model covars.
* Iterate through each var and collect results
collect clear 
foreach var in $predictors {
	collect: svy, subpop(if _insample==1): logistic si_T5 `var', baselevels
}

collect layout (colname) (result[_r_b _r_se _r_p _r_ci])
collect style use table-reg1-fv1
collect style row stack, nobinder indent
collect style cell result[_r_b _r_ci _r_se], nformat(%5.2f)
collect style cell result, empty("--")
collect style cell result[_r_ci], cidelimiter(", ")
collect style cell result[_r_ci], sformat("(%s)")
collect style cell extra[N_sub], nformat(%5.0f)
collect style showbase factor
collect style cell header_cell_contents[factor dimension], font(, bold) // bolded fv level headers
collect style cell result[_r_p], nformat(%4.3f) min(0.001) // present extremely small p-values as "<0.001" 
collect stars _r_p 0.001 "***" 0.01 "** " 0.05 "* ", attach(_r_b) shownote
collect preview

* Add text and finalize
collect title "Supplemental Table 4. Unadjusted survey-weighted association between 2023 characteristics and 2024 suicidal ideation"
collect notes "Notes: All unadjusted models use the final analytic sample of N=1,896 participants."
collect preview

collect export "$out/tblS4_unadjusted_table.docx", replace

*-----------------------------------------------------*
* Supplemental Table 5. VIF of main model
*-----------------------------------------------------*
*--Generate VIF table for main model.
collect clear
reg si_T5 $predictors if _insample==1, base
estat vif
di "Enter mean VIF from above: ", _request(VALUE)
local meanval "$VALUE"

* Use results matrix to get names
tempname b V
matrix `b' = e(b)
matrix `V' = e(V)
local cols : colnames `b'
local vifnames
forval j = 1/`=colsof(`b')' {
    local nm : word `j' of `cols'
    if "`nm'" == "_cons" continue
    if `V'[`j',`j'] == 0 continue
    local vifnames `vifnames' `nm'
}
local nvif : word count `vifnames'

* Get vif vals from collect
collect: estat vif
local rec
forval i = 1/`nvif' {
    local nm : word `i' of `vifnames'
    collect addtags colname[`nm'], fortags(result[vif_`i'])
    local rec `rec' vif_`i'=vif
}
collect recode result `rec'

collect layout (colname) (result[vif])
collect style use table-reg1-fv1
collect style row stack, nobinder indent
collect style showbase factor
collect label levels result vif "VIF", modify
collect style cell result[vif], nformat(%5.2f)
collect title "Supplemental Table 5. Variance inflation factors (VIFs) of main model"
collect notes "Notes: VIFs estimated using unweighted regression model with identical model specification and analytic sample as main model. Mean VIF = `meanval'."
collect preview

*------------ Export? -----------------*
di "Export Supplemental Table 5 (VIFs)? (Y/N)", _request(RESP)
if strlower("$RESP")=="y" collect export "$out/tblS5_main_model_vif.docx", replace
qui else di as err "Table not saved."

*-----------------------------------------------------*
* Supplemental Table 6. Adjusted risk ratios
*-----------------------------------------------------*
*--Logistic regression model estimating associations with W5 SI
* Estimate full model - ORs estimated first to use the same table layout but cleared
collect clear
collect: svy, subpop(if _insample==1): logistic si_T5 $predictors, baselevels
eststo tbl3_logit
local df = e(df_r) // design df, so aRR inference matches svy inference

* Integrate sample sizes
collect get N_sub = (e(N_sub)), tags(cmdset[2])
foreach x in N_sub {
    collect addtags extra[`x'], fortags(result[`x'])
}
collect label levels extra N_sub "# observations", modify
collect recode result N_sub=_r_b

*----------------------------------*
* Estimate ARRs
*----------------------------------*
*--Estimate ARRs using adjrr_subpop
* Get terms from table layout
local terms : colnames e(b)

* First, store base level of each covariate
foreach t of local terms {
    _ms_parse_parts `t'
    if "`r(type)'" == "factor" & r(base) == 1 local b_`r(name)' = r(level)
}

* Second, get ARRs using adjrr_subpop
local tcrit = invttail(`df', 0.025)
foreach t of local terms {
    if "`t'" == "_cons" continue
    _ms_parse_parts `t'
    local type   "`r(type)'"
    local var    "`r(name)'"
    local lvl    "`r(level)'"
    local isbase = ("`type'" == "factor" & r(base) == 1)
    local omit   = r(omit)

    * Referent rows: placeholder so the "Ref" style picks them up
    if `isbase' {
        collect get rr = (1), tags(cmdset[2] colname[`lvl'.`var'])
        continue
    }
    if `omit' | !inlist("`type'", "factor", "variable") {
        di as txt "Skipping `t' (omitted or interaction term)"
        continue
    }

    * Contrast: factor level vs. base; 0/1 numeric 1 vs. 0; continuous mean+1 vs. mean
    if "`type'" == "factor" {
        local x0  `b_`var''
        local x1  `lvl'
        local tag `lvl'.`var'
    }
    else {
        local tag `var'
        capture assert inlist(`var', 0, 1) if _insample == 1
        if !_rc {
            local x0 0
            local x1 1
        }
        else {
            quietly svy, subpop(if _insample == 1): mean `var'
            local x0 = _b[`var']
            local x1 = `x0' + 1 // change if one unit isn't a meaningful contrast
        }
    }

    estimates restore tbl3_logit
    di as txt _n "{hline 60}" _n "`t': `var' = `x1' vs. `x0'"
    adjrr_subpop `var', x0(`x0') x1(`x1') subpop(if _insample == 1)

    * Log-scale CI and p-value with design df
    local rr    = r(ARR)
    local rr_se = r(ARR_se)
    local lnse  = `rr_se' / `rr'
    collect get rr    = (`rr')                                     ///
                rr_se = (`rr_se')                                  ///
                rr_lb = (exp(ln(`rr') - `tcrit' * `lnse'))         ///
                rr_ub = (exp(ln(`rr') + `tcrit' * `lnse'))         ///
                rr_p  = (2 * ttail(`df', abs(ln(`rr') / `lnse'))), ///
                tags(cmdset[2] colname[`tag'])
}
estimates restore tbl3_logit

* Map aRR results onto the table names to use layout 
collect recode result rr=_r_b rr_se=_r_se rr_lb=_r_lb rr_ub=_r_ub rr_p=_r_p

* Layout ARR table
local res "_r_b _r_se _r_p _r_ci"
collect layout (colname extra) (cmdset[2]#result[`res'])
collect style use table-reg1-fv1
collect style row stack, nobinder indent
collect style header cmdset, title(hide) level(hide)
collect label levels result _r_b "aRR", modify

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

* Label referents
local basetags
foreach term of global predictors {
    if regexm("`term'", "^ib([0-9]+)\.(.+)$") {
        local basetags "`basetags' `=regexs(1)'.`=regexs(2)'"
    }
}
di "`basetags'"

* Replace aRR with "Ref" and harmonize SD display for referents
collect style cell colname[`basetags']#result[_r_b], nformat(%5.2f) minimum(999999, label("Ref")) font(,italic) halign(right)
collect style cell colname[`basetags']#result[_r_se], nformat(%5.2f) minimum(999999, label("--"))
collect preview

* Add text
collect title "Supplemental Table 6. Adjusted risk ratios of 2024 suicidal ideation by 2023 characteristics"
collect notes "Notes: CLIMB Waves 4-5 data, collected March-April 2023-2024. Includes N=1,896 observations with complete cases."
collect notes "Table presents main model adjusted risk ratios (ARR) for each covariate when all other covariates held at observed values. 95% CIs and p-values are computed on the log scale using the delta method and design-based degrees of freedom. Adjusted odds ratios are presented in Table 3."

* Output table
collect preview

*------------ Export? -----------------*
di "Export Supplemental Table 6? (Y/N)", _request(RESP)
if strlower("$RESP")=="y" collect export "$out/tblS6_main_model_ARRs.docx", replace
else di as err "Table not saved."

*-----------------------------------------------------*
* Supplemental Table 7. Stratified logistic regression models
*-----------------------------------------------------*
*--Export survey-weighted stratified logistic regression results for paper (all groups)
* Collect all survey-weighted model outputs
collect clear
est clear
forval i=1/4 {
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
collect title "Supplemental Table 7. Stratified survey-weighted logistic regression estimating odds ratios of 2024 suicidal ideation using 2023 characteristics (all race and ethnicity groups)"

* Get counts
forval i=1/4 {
    qui count if race_col_T4==`i' & _insample==1
    local c`i' = string(`r(N)', "%5.0fc")
    di "`c`i''"
}
collect notes "Notes: From left to right, Supplemental Table 7 displays the odds ratios (95% CI) estimated for the White, non-Hispanic subgroup (n=`c1'), the Black, non-Hispanic subgroup (N=`c2'), the Hispanic subgroup (N=`c3'). The Other, non-Hispanic group is not shown here due to small sample size and wide intervals."

* Set model names
collect label levels cmdset ///
    1 "Model (1) White, non-Hispanic" 2 "Model (2) Black, non-Hispanic" ///
    3 "Model (3) Hispanic" 4 "Model (4) Other, non-Hispanic", modify
collect preview

*------------ Export? -----------------*
di "Export STable 7? (Y/N)", _request(RESP)
if strlower("$RESP")=="y" collect export "$out/tblS7_stratified_models_allgrps.docx", replace
qui else di as err "Table not saved."

*-----------------------------------------------------*
* Supplemental Table 8. Stratified model ARRs
*-----------------------------------------------------*
*--Generate a stratified ARR table for the supplement.
collect clear

* Begin iteration over each race and ethnicity group
forval i=1/4 {
	local sp "_insample==1 & race_col_T4==`i'"
	collect: svy, subpop(if `sp'): logistic si_T5 $stratpred, baselevels
	eststo m`i'
	local df`i' = e(df_r)
	local tcrit = invttail(`df`i'', 0.025)
	local c`i'  = string(e(N_sub), "%5.0fc") // analytic n for the notes
	local terms : colnames e(b)

	* Store base levels for each term
	foreach t of local terms {
		_ms_parse_parts `t'
		if "`r(type)'" == "factor" & r(base) == 1 local b_`r(name)' = r(level)
	}

	* Call adjrr_subpop once per term 
	foreach t of local terms {
		if "`t'" == "_cons" continue
		_ms_parse_parts `t'
		local type   "`r(type)'"
		local var    "`r(name)'"
		local lvl    "`r(level)'"
		local isbase = ("`type'" == "factor" & r(base) == 1)
		local omit   = r(omit)

		* Referent rows: placeholder so the "Ref" style picks them up
		if `isbase' {
			collect get rr = (1), tags(cmdset[`i'] estimate[rr] colname[`lvl'.`var'])
			continue
		}
		if `omit' | !inlist("`type'", "factor", "variable") {
			di as txt "Model `i': skipping `t' (omitted or interaction term)"
			continue
		}

		* Contrast: factor level vs. base; 0/1 numeric 1 vs. 0; continuous mean+1 vs. mean
		if "`type'" == "factor" {
			local x0  `b_`var''
			local x1  `lvl'
			local tag `lvl'.`var'
		}
		else {
			local tag `var'
			capture assert inlist(`var', 0, 1) if `sp'
			if !_rc {
				local x0 0
				local x1 1
			}
			else {
				quietly svy, subpop(if `sp'): mean `var'
				local x0 = _b[`var']
				local x1 = `x0' + 1 // stratum-specific mean; change if one unit isn't meaningful
			}
		}

		estimates restore m`i'
		di as txt _n "{hline 60}" _n "Model `i' | `t': `var' = `x1' vs. `x0'"
		adjrr_subpop `var', x0(`x0') x1(`x1') subpop(if `sp')

		* Log-scale CI and p-value with design df (se(ln ARR) = se(ARR)/ARR)
		local rr    = r(ARR)
		local rr_se = r(ARR_se)
		local lnse  = `rr_se' / `rr'
		collect get rr    = (`rr')                                            ///
		            rr_se = (`rr_se')                                         ///
		            rr_lb = (exp(ln(`rr') - `tcrit' * `lnse'))                ///
		            rr_ub = (exp(ln(`rr') + `tcrit' * `lnse'))                ///
		            rr_p  = (2 * ttail(`df`i'', abs(ln(`rr') / `lnse'))),     ///
		            tags(cmdset[`i'] estimate[rr] colname[`tag'])
	}
	estimates restore m`i'
}

* Map aRR results to normal names to use layouts
collect recode result rr=_r_b rr_se=_r_se rr_lb=_r_lb rr_ub=_r_ub rr_p=_r_p

* Init layout
collect layout (colname#result[_r_b _r_ci]) (cmdset#estimate[rr])
collect style use table-reg1-fv1
collect style row stack, nobinder indent
collect style header estimate, title(hide) level(hide)

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

* Replace aRR with "Ref" for referents
collect style cell colname[`basetags']#result[_r_b], nformat(%5.2f) minimum(999999, label("Ref")) font(,italic) halign(right)
collect preview
collect title "Supplemental Table 8. Stratified adjusted risk ratios of 2024 suicidal ideation by 2023 characteristics"

collect notes "Notes: From left to right, Supplemental Table 8 displays the adjusted risk ratios [95% CI] estimated for the White, non-Hispanic subgroup (n=`c1'), the Black, non-Hispanic subgroup (n=`c2'), the Hispanic subgroup (n=`c3'), and the Other, non-Hispanic subgroup (n=`c4'). See Supplemental Table 4 for a table with odds ratios for each group."
collect notes "Table presents main model adjusted risk ratios (ARR) for each covariate when all other covariates held at observed values. 95% CIs and p-values are computed on the log scale using the delta method and design-based degrees of freedom."

* Set model names
collect label levels cmdset ///
    1 "Model (1) White, non-Hispanic" 2 "Model (2) Black, non-Hispanic" ///
    3 "Model (3) Hispanic" 4 "Model (4) Other, non-Hispanic", modify
collect preview

*------------ Export? -----------------*
di "Export Supplemental Table 8? (Y/N)", _request(RESP)
if strlower("$RESP")=="y" collect export "$out/tblS8_stratified_models_ARRs.docx", replace
else di as err "Table not saved."

*-----------------------------------------------------*
* Supplemental Table 9. Joint tests of effect modification by race
*-----------------------------------------------------*
*--Fit main model + one race interaction per predictor and test interaction terms jointly.
collect clear
local order ""
foreach term of global stratpred {
    * Get var name from factor-variable term
    local v = substr("`term'", strpos("`term'", ".") + 1, .)
    local order `order' `v'

    * Fit main model + race interaction for this predictor
    qui svy, subpop(if _insample==1): logit si_T5 ${predictors} ib1.race_col_T4#`term'
    local n_sub = e(N_sub)

    * Joint design-adjusted Wald test of race x predictor terms
    qui testparm ib1.race_col_T4#`term'
    collect get ///
        n = (`n_sub') ///
        F = (r(F)) ///
        df1 = (r(df)) ///
        df2 = (r(df_r)) ///
        p = (r(p)), ///
        tags(predictor[`v'])

    * Label predictor with var label
    local lbl : var label `v'
    local x = ustrunescape("\u00d7")
    collect label levels predictor `v' "`lbl' `x' Race and Ethnicity", modify
}

* Style collect table
collect layout (predictor[`order']) (result[n F df1 p])
collect label dim predictor "Predictor", modify
collect label levels result n "N" F "F" df1 "df1" df2 "df2" p "p", modify
collect style cell result[n], nformat(%9.0fc)
collect style cell result[F], nformat(%5.2f)
collect style cell result[df1 df2], nformat(%3.0f)
collect style cell result[p], nformat(%5.3f) minimum(0.001)
collect title "Supplemental Table 9. Tests of effect modification by race and ethnicity"
collect notes "Abbreviations: df1 - number of interaction terms tested"
collect notes "Note: Each row displays a separate survey-weighted logistic regression of 2024 suicidal ideation on all main-model covariates plus an interaction term between race and ethnicity and the specified predictor. Estimates presented are from the design-adjusted Wald test assessing if all interaction terms for that predictor are jointly zero."
collect notes "Health insurance status has one race and ethnicity * insurance cell where no respondents reported suicidal ideation leading to an unestimable interaction term. This cell is excluded from the model leading to N = 1,891 with 2 degrees of freedom."
collect preview

*------------ Export? -----------------*
di "Export STable 9? (Y/N)", _request(RESP)
if strlower("$RESP")=="y" collect export "$out/tblS9_effect_modification_test.docx", replace
qui else di as err "Table not saved."

*-----------------------------------------------------*
* Supplemental Table 10. Single asset model series comparison
*-----------------------------------------------------*
*--Generate a comparison table between demos only, demos + 1 asset, and full model.
* Define variable macros
global base_covs "ib4.AGE4_T4 ib1.GENDER_T4 ib1.race_col_T4 ib0.prev_depression_T4"
global assets "ib3.hh_income_imp_tert_T4 ib3.locf_hh_savings_tert_T4 ib1.locf_hh_debt_tert_T4 ib1.insurance_binary_T4 ib1.home_own_T4 ib1.educ_college_T4 ib1.marital_binary_T4 ib1.religious_attendance_T4 ib1.employment_T4 ib1.social_support_T4"

collect clear

* Column 3: full model (estimated first to preserve var order)
collect, tag(model[3]): svy, subpop(if _insample==1): logistic si_T5 $predictors, baselevels
local N_full = e(N_sub)

* Column 1: base vars only
collect, tag(model[1]): svy, subpop(if _insample==1): logistic si_T5 $base_covs, baselevels

* Column 2: base vars + 1 asset per model
local j = 0
foreach asset of global assets {
    local ++j
    di as txt "Model 2.`j': `asset'"
    qui collect, tag(model[s`j']): svy, subpop(if _insample==1): logistic si_T5 $base_covs `asset', baselevels

    * Stop if sample is not equal to the full model sample
    if e(N_sub) != `N_full' {
        di as err "N_sub for `asset' (`e(N_sub)') differs from fully adjusted model (`N_full')"
        exit
    }

    * Get each assets levels and recode to display in column 2
    qui fvexpand `asset' if _insample==1
    local asset_tags = subinstr("`r(varlist)'", "b.", ".", .)
    collect recode model s`j' = 2, fortags(colname[`asset_tags'])
}

* Integrate the sample size (same for all col2 items after passing check above)
collect addtags extra[N_sub], fortags(result[N_sub])
collect label levels extra N_sub "# observations", modify
collect recode result N_sub = _r_b
collect recode model s1 = 2, fortags(extra[N_sub])

* Set column labels
collect label levels model 1 "Model 1: Base covariates" ///
                           2 "Model 2: Base + single asset" ///
                           3 "Model 3: Fully adjusted", modify
collect label levels result _r_b "Odds Ratio", modify

* Display OR + 95% CI only
local res "_r_b _r_ci"
collect layout (colname extra) (model[1 2 3]#result[`res'])
collect style use table-reg1-fv1
collect style row stack, nobinder indent
collect style header model, title(hide)

* Style cells
collect style cell result[_r_b _r_ci _r_se], nformat(%5.2f)
collect style cell result, empty("--")
collect style cell result[_r_ci], cidelimiter(", ")
collect style cell result[_r_ci], sformat("(%s)")
collect style cell extra[N_sub], nformat(%5.0f)
collect style showbase factor
collect style cell header_cell_contents[factor dimension], font(, bold) // bolded fv level headers
collect stars _r_p 0.001 "***" 0.01 "** " 0.05 "* ", attach(_r_b) shownote

*----- Label referent level rows -----*
* Get list of base vars with no "b" (e.g., ib2.SEX_T7 -> 2.SEX_T7)
local basetags
foreach term of global predictors {
    if regexm("`term'", "^ib([0-9]+)\.(.+)$") {
        local basetags "`basetags' `=regexs(1)'.`=regexs(2)'"
    }
}

* Replace OR with "Ref" for referents
collect style cell colname[`basetags']#result[_r_b], nformat(%5.2f) minimum(999999, label("Ref")) font(,italic) halign(right)

* Add text
local N_fmt = strtrim(string(`N_full', "%9.0fc"))
collect title "Supplemental Table 10. Sequential survey-weighted logistic regression models estimating 2024 suicidal ideation using 2023 characteristics"
collect notes "Notes: CLIMB Waves 4-5 data, collected March-April 2023-2024. All models use the same analytic sample (N=`N_fmt'). Base covariates are age, gender, race and ethnicity, and prior depression."
collect notes "Model 1 includes base covariates only. Model 2 displays each asset's odds ratios from a separate model containing that asset plus the base covariates. Base covariate estimates vary across these 10 models and are not shown. Model 3 is the main model and includes all assets."
collect notes "Estimands: The estimates in Model 2 assess the association between each asset and suicidal ideation conditional on the base covariates. Model 3 displays the net association of all assets; this removes confounding by other assets but may mask assessment of effects that operate through overlapping pathways."

* Output table
collect preview

*------------ Export? -----------------*
di "Export Supplemental Table 10? (Y/N)", _request(RESP)
if strlower("$RESP")=="y" collect export "$out/tblS10_sequential_models.docx", replace
qui else di as err "Table not saved."

*-----------------------------------------------------*
* Supplemental Figure 2. Coefplot
*-----------------------------------------------------*
*--Create a coefplot showing logistic regression results.
* Estimate main model and store
estimates clear
svy, subpop(if _insample==1): logistic si_T5 $predictors, baselevels
eststo main
cap mycolors

* Set local for variations (bw=0 -> color, bw=1 -> black and white)
local bw = 0
if `bw'==0 {
    local color_sig "$jamacolor1"
    local color_nonsig "$jamacolor2"
    local filename "sfig2_coefplot_main"
}
else {
    local color_sig "black"
    local color_nonsig "gs10"
    local filename "sfig2_coefplot_main_bw"
}

* Create coefplot 
coefplot ///
    /// significant covariates
    (main, ///
        keep(*AGE4_T4 *hh_income_imp_tert_T4 *educ_college_T4 *social_support_T4 *prev_depression_T4) ///
        msymbol(d) mcolor("`color_sig'") ///
        ciopts(lcolor("`color_sig'") lwidth(medium) lpattern(solid))) ///
    /// non-significant covariates
    (main, ///
        keep(*GENDER_T4 *race_col_T4 *locf_hh_savings_tert_T4 *locf_hh_debt_tert_T4 ///
            insurance_binary_T4 *home_own_T4 *marital_binary_T4 religious_attendance_T4 *employment_T4) ///
        msymbol(t) mcolor("`color_nonsig'") ///
        ciopts(lcolor("`color_nonsig'") lwidth(medium) lpattern(solid))), ///
    eform baselevels ///
    xline(1, lcolor(gs6) lpattern(dash)) ///
    xtitle("Odds Ratio") ///
    ylabel(, labsize(*0.575) labgap(0.1)) ///
    ysize(8.25in) xsize(6.25in) ///
    legend(off) ///
    headings( ///
        1.AGE4_T4                 = "{bf:Age}" ///
        1.hh_income_imp_tert_T4   = "{bf:Household income}" ///
        0.educ_college_T4         = "{bf:Education}" ///
        0.social_support_T4       = "{bf:Social support}" ///
        0.prev_depression_T4      = "{bf:Previous depression}" ///
        1.GENDER_T4               = "{bf:Gender}" ///
        1.race_col_T4             = "{bf:Race and ethnicity}" ///
        1.locf_hh_savings_tert_T4 = "{bf:Household savings}" ///
        1.locf_hh_debt_tert_T4    = "{bf:Household debt}" ///
        0.insurance_binary_T4     = "{bf:Insurance type}" ///
        0.home_own_T4             = "{bf:Home ownership}" ///
        0.marital_binary_T4       = "{bf:Marital status}" ///
        0.religious_attendance_T4 = "{bf:Religious service attendance}" ///
        0.employment_T4           = "{bf:Employment status}" ///
        , labsize(*0.65) gap(0.75) offset(-0.2) labgap(0)) ///
    name(`filename', replace)

*------------ Export? -----------------*
di "Export Supplemental Figure 2? (Y/N)", _request(RESP)
if strlower("$RESP")=="y" graph export "$out/`filename'.svg", replace name(`filename')
else di as err "Figure not saved."

*-----------------------------------------------------*
* Supplemental Figure 3. Stratified Models
*-----------------------------------------------------*
*--Create a coefplot showing race/ethnicity-stratified logistic regression results.
*   Note: We only report asset variables significant in at least one stratified model
*       These are: income, education, social support
*       We exclude the model for "Other, non-Hispanic"
*       We exclude control variables that are significant, e.g. age, previous depression 
* Estimate stratified models and store (1=NH White, 2=NH Black, 3=Hispanic)
estimates clear
forvalues r = 1/3 {
    svy, subpop(if _insample==1 & race_col_T4==`r'): logistic si_T5 $stratpred, baselevels
    eststo strat`r'
    local n`r' = strtrim(string(e(N_sub), "%9.0fc"))
}
cap mycolors

* Set local for variations (bw=0 -> color, bw=1 -> black and white)
local bw = 0
if `bw'==0 {
    local color1 "$jamacolor1"
    local color2 "$jamacolor2"
    local color3 "$jamacolor3"
    local lpat1 "solid"
    local lpat2 "solid"
    local lpat3 "solid"
    local filename "sfig3_coefplot_strat"
}
else {
    local color1 "black"
    local color2 "gs4"
    local color3 "gs8"
    local lpat1 "solid"
    local lpat2 "dash"
    local lpat3 "shortdash"
    local filename "sfig3_coefplot_strat_bw"
}

* Create coefplot
coefplot ///
    /// NH White
    (strat1, ///
        msymbol(o) mcolor("`color1'") ///
        ciopts(lcolor("`color1'") lwidth(medium) lpattern(`lpat1')) ///
        label("NH White (n=`n1')")) ///
    /// NH Black
    (strat2, ///
        msymbol(s) mcolor("`color2'") ///
        ciopts(lcolor("`color2'") lwidth(medium) lpattern(`lpat2')) ///
        label("NH Black (n=`n2')")) ///
    /// Hispanic
    (strat3, ///
        msymbol(t) mcolor("`color3'") ///
        ciopts(lcolor("`color3'") lwidth(medium) lpattern(`lpat3')) ///
        label("Hispanic (n=`n3')")), ///
    keep(*hh_income_imp_tert_T4 *educ_college_T4 *social_support_T4) ///
    eform baselevels ///
    xline(1, lcolor(gs6) lpattern(dash)) ///
    xtitle("Odds Ratio") ///
    ylabel(, labsize(*0.8) labgap(0.1)) ///
    ysize(5in) xsize(6.25in) ///
    legend(rows(1) position(6)) ///
    headings( ///
        1.hh_income_imp_tert_T4 = "{bf:Household income}" ///
        0.educ_college_T4       = "{bf:Education}" ///
        0.social_support_T4     = "{bf:Social support}" ///
        , labsize(*0.8) gap(0.75) offset(-0.2) labgap(0)) ///
    name(`filename', replace)

*------------ Export? -----------------*
di "Export Supplemental Figure 3? (Y/N)", _request(RESP)
if strlower("$RESP")=="y" graph export "$out/`filename'.svg", replace name(`filename')
else di as err "Figure not saved."
