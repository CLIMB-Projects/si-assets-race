*=====================================================*
* Project: CLIMB - Assets and SI
* File:    02_si_vars.do
* Author:  Rajesh Satpathy-Horton
* Purpose: Generate SI analysis-specific variables.
* Init:    11/5/2026
* Updated: 11/5/2026
*=====================================================*
*-----------------------------------------------------*
* Init
*-----------------------------------------------------*
*--Init items for analysis -- uncomment if running alone
* Set globals and working dir
// edit $climb and $proj to run in local env; other globals can be kept the same
// global climb    "C:/Users/rsatpat1/Dropbox/CLIMB Operations/Data (non-confidential)/Waves 1-7 - 08.04.2026/JHU_COVID-19 W1_W2_W3_W4_W5_W6_W7_Combined_File_20260804.dta"
// global proj     "C:/Users/rsatpat1/Dropbox/CLIMB Operations/Projects/PHQ9 Suicidal Ideation"

// global code "$proj/03_code"
// global out  "$proj/04_output"

// cd "$proj"

// * Import W1-W7 data and clean
// use "$climb", clear 
// run "$code/01_cleaning_w1w7_11052026.do"

*==================================*
* Verify ADO statuses.
di "Verifying custom ADOs..."
* ADOs needed are:
local adolist "seqmiss fvdel"
foreach ado of local adolist {
    cap which `ado'
    if _rc {
        di as err "ADO not found: `ado' - request from RSH if required."
    }
}
*==================================*
*-----------------------------------------------------*
* Outcome: W5 suicidal ideation
*-----------------------------------------------------*
*--Define binary SI outcome vars.
* Def SI vars for each wave
la def silbl 0 "No suicidal ideation" 1 "Suicidal ideation", replace
forval i=1/7 {
    g si_T`i' = . 
    replace si_T`i' = 0 if D6I_T`i'==1
    replace si_T`i' = 1 if inrange(D6I_T`i',2,4)
    la var si_T`i' "Wave `i' suicidal ideation"
    la val si_T`i' silbl
}

*-----------------------------------------------------*
* Variable Creation
*-----------------------------------------------------*
*--Create any vars needed.
*----------------------------------*
* PHQ-8 (score without SI question)
*----------------------------------*
*--Create PHQ-8 scores for analysis.
* Generate PHQ-8 score
forval i = 1/7 {
	qui g PHQ8_score_T`i' = 0
	egen rowmiss_PHQ8_T`i' = rowmiss(D6A_T`i' D6B_T`i' D6C_T`i' D6D_T`i' D6E_T`i' D6F_T`i' D6G_T`i' D6H_T`i')
	foreach x in D6A_T`i' D6B_T`i' D6C_T`i' D6D_T`i' D6E_T`i' D6F_T`i' D6G_T`i' D6H_T`i' {
		qui replace PHQ8_score_T`i' = PHQ8_score_T`i' + (`x'-1) if (`x'!=77 & `x'!=98 & `x'!=.)
		qui replace PHQ8_score_T`i' = . if rowmiss_PHQ8_T`i'==8
	} 
	di as red `"Wave `i' PHQ-8 continuous measure generated as PHQ8_score_T`i'."'
}

*----------------------------------*
* Asset tertiles
*----------------------------------*
*--Create income, savings, and debt tertiles within the sample.
* Def common tertile label
la def tertlbl 1 "T1 (low)" 2 "T2" 3 "T3 (high)", replace

* Loop through each asset type within sample
local assets "income savings debt"
local bases "F17_T4 F18_T4 F19_T4"

forval iter=1/3 {
	local a = word("`assets'", `iter') // get asset type
	local b = word("`bases'", `iter') // get asset type base varname

	xtile hh_`a'_tert_T4 = `b' if (QUAL_T4==1 & QUAL_T5==1), n(3)
	la var hh_`a'_tert_T4 "Wave 4 household `a'"
	la val hh_`a'_tert_T4 tertlbl
}

*-----------------------------------------------------*
* Labels
*-----------------------------------------------------*
*--Label vars as needed.
* Relabel items
la var AGE4_T4 "Age"
la var GENDER_T4 "Gender"
la var educ_college_T4 "Education"
la var race_col_T4 "Race and Ethnicity"
la var marital_binary_T4 "Marital Status"
la var hh_income_tert_T4 "Household Income"
la var hh_savings_tert_T4 "Household Savings"
la var hh_debt_tert_T4 "Household Debt"
la var insurance_binary_T4 "Health Insurance Status"
la var home_own_T4 "Home Ownership Status"
la var religious_attendance_T4 "Religious Event Attendance"
la var employment_T4 "Employment Status"
la var social_support_T4 "Social Support Level" 
la var prev_depression_T4 "Previous Diagnosis of Depression"
la var si_T4 "Suicidal Ideation (2023)"
la var si_T5 "Suicidal Ideation (2024)"

* Relabel values
la def agelbl 1 "18-29" 2 "30-44" 3 "45-59" 4 "${ge}60", replace
la val AGE4_T4 agelbl

la def maritallbl 0 "Not married" 1 "Married", replace
la val marital_binary_T4 maritallbl

la def inclbl 1 "$0 - $54,999" 2 "$55,000 - $99,999" 3 "$100,000 or more", replace 
la val hh_income_tert_T4 inclbl

la def savlbl 1 "$0 - $9,999" 2 "$10,000 - $149,999" 3 "$150,000 or more", replace
la val hh_savings_tert_T4 savlbl

la def debtlbl 1 "$0 - $2,499" 2 "$2,500 - $14,999" 3 "$15,000 or more", replace
la val hh_debt_tert_T4 debtlbl

la def socsuplbl 0 "Low social support" 1 "High social support", replace
la val social_support_T4 socsuplbl

la def prevdeplbl 0 "No previous depression" 1 "Previous depression", replace
la val prev_depression_T4 prevdeplbl