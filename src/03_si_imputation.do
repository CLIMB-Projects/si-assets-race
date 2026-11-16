*=====================================================*
* Project: CLIMB - Assets and SI
* File:    03_si_locf_imputation.do
* Author:  Rajesh Satpathy-Horton
* Purpose: Implement LOCF imputation on items with missingness.
* Init:    11/05/2026
* Updated: 11/05/2026
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

// * Import W1-W7 data, clean data, and generate analytic vars
// use "$climb", clear 
// run "$code/01_cleaning_w1w7_11052026.do"
// run "$code/02_si_vars.do"

* Init global macros
global predictors "ib4.AGE4_T4 i.GENDER_T4 i.race_col_T4 ib3.hh_income_tert_T4 ib3.hh_savings_tert_T4 ib3.hh_debt_tert_T4 ib1.insurance_binary_T4 ib1.home_own_T4 ib1.educ_college_T4 ib1.marital_binary_T4 ib1.religious_attendance_T4 ib1.employment_T4 ib1.social_support_T4 ib0.prev_depression_T4"
fvdel, in($predictors) out(predictors_list)

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
* Define sample
*-----------------------------------------------------*
*--Generate var with analytic sample to ID items for imputation.
* Def base sample (qual + non-missing outcome)
g base_sample = QUAL_T4==1 & QUAL_T5==1 & !missing(si_T5) & inrange(AGE4_T4,1,4) // AGE excludes <18yo 

* Identify complete case sample (byte required for markout)
g byte _insample = base_sample
markout _insample $predictors

* Evaluate sequential missingness
seqmiss $predictors_list if base_sample // will impute income, savings, debt

*-----------------------------------------------------*
* Household Income Imputation // recovers n=57
*-----------------------------------------------------*
*--Impute missing CLIMB household income using NORC income.
* Create new base imputed var
clonevar hh_income_imp_T4 = F17_T4
la var hh_income_imp_T4 "Household income (profile imputation)"

* Impute using parallel NORC income variable
local m "missing(hh_income_imp_T4)"

replace hh_income_imp_T4 = INCOME_T4 if inrange(INCOME_T4,1,5) & `m' // 1-5 are the same in both vars
replace hh_income_imp_T4 = 6 if inlist(INCOME_T4,6,7) & `m' // 25-35
replace hh_income_imp_T4 = 7 if inlist(INCOME_T4,8,9) & `m' // 35-40k + 40-50k (midpt: 44999.5)
replace hh_income_imp_T4 = 8 if inlist(INCOME_T4,10) & `m' // 50-60k (midpt: 54999.5)
    // skipping hh_income_imp_T4==9 (55-65) because next INCOME_T4 midpoint is >65k
replace hh_income_imp_T4 = 10 if inlist(INCOME_T4,11) & `m' // 60-75k (midpt: 67499.5)
replace hh_income_imp_T4 = 11 if inlist(INCOME_T4,12,13) & `m' // 75-85k + 85-100k
replace hh_income_imp_T4 = 12 if inlist(INCOME_T4,14,15) & `m' // 100-125k + 125-150k
replace hh_income_imp_T4 = 13 if inlist(INCOME_T4,16,17) & `m' // 150-175k + 175-200k
replace hh_income_imp_T4 = 14 if inlist(INCOME_T4,18) & `m' // 200k+ (max boundary)

* Generate a new tertile using the imputed values in the sample
xtile hh_income_imp_tert_T4 = hh_income_imp_T4 if base_sample, nq(3)
la var hh_income_imp_tert_T4 "Household Income"

* Get and set labels 
forval i=1/3 {
  di _n "Q`i'"
  qui sum hh_income_imp_T4 if hh_income_imp_tert_T4==`i'
  local min = r(min)
  local max = r(max)
  tab hh_income_imp_T4 if hh_income_imp_T4==`min'
  tab hh_income_imp_T4 if hh_income_imp_T4==`max'
}
la def impinclbl 1 "$0 - $54,999" 2 "$55,000 - $99,999" 3 "$100,000 or more", replace 
la val hh_income_imp_tert_T4 impinclbl

* Output comparison of quartiles
tab hh_income_tert_T4 hh_income_imp_tert_T4 if base_sample, m 

* Replace in predictors and assess sequential missingness again
global predictors_imp1 : subinstr global predictors "hh_income_tert_T4" "hh_income_imp_tert_T4"
fvdel, in($predictors_imp1) out(predictors_imp1_list)
seqmiss $predictors_imp1_list if base_sample

*-----------------------------------------------------*
* Household Savings Imputation // recovers n=27
*-----------------------------------------------------*
*--Impute missing CLIMB household income using NORC income.
* Create new base imputed var
clonevar locf_hh_savings_tert_T4 = hh_savings_tert_T4
tempvar locf_target

g `locf_target' = missing(locf_hh_savings_tert_T4) & base_sample
local n_recovered = 0 

forval i=3(-1)1 {
  qui count if `locf_target'
  local start = r(N)
  
  replace locf_hh_savings_tert_T4 = 1 if `locf_target' & inrange(F18_T`i',1,2)
  replace locf_hh_savings_tert_T4 = 2 if `locf_target' & inrange(F18_T`i',3,12) 

  replace `locf_target' = 0 if !missing(locf_hh_savings_tert_T4)
  qui count if `locf_target'
  local end = r(N)
  local replaced = `start' - `end'
  di as res "Replaced " `replaced' " missing observations in Wave `i'." _n `end' " missing values remain."
  local n_recovered = `n_recovered' + `replaced'
}
qui count if `locf_target'
di as res "Total recovered = " `n_recovered' _n "Still missing = `r(N)'"

* Replace in predictors and assess sequential missingness again
global predictors_imp2 : subinstr global predictors_imp1 "hh_savings_tert_T4" "locf_hh_savings_tert_T4"
fvdel, in($predictors_imp2) out(predictors_imp2_list)
seqmiss $predictors_imp2_list if base_sample

*-----------------------------------------------------*
* Household debt imputation (LOCF) // recovers n=18
*-----------------------------------------------------*
*--Implement LOCF imputation to recover savings values.
* Household debt
clonevar locf_hh_debt_tert_T4 = hh_debt_tert_T4
tempvar locf_target

g `locf_target' = missing(locf_hh_debt_tert_T4) & base_sample
local n_recovered = 0 

forval i=3(-1)1 {
  qui count if `locf_target'
  local start = r(N)
  
  replace locf_hh_debt_tert_T4 = 1 if `locf_target' & inrange(F19_T`i',1,3)
  replace locf_hh_debt_tert_T4 = 2 if `locf_target' & inrange(F19_T`i',4,6) 
  replace locf_hh_debt_tert_T4 = 3 if `locf_target' & inrange(F19_T`i',7,15)

  replace `locf_target' = 0 if !missing(locf_hh_debt_tert_T4)
  qui count if `locf_target'
  local end = r(N)
  local replaced = `start' - `end'
  di as res "Replaced " `replaced' " missing observations in Wave `i'." _n `end' " missing values remain."
  local n_recovered = `n_recovered' + `replaced'
}
qui count if `locf_target'
di as res "Total recovered = " `n_recovered' _n "Still missing = `r(N)'"

* Replace in predictors and assess sequential missingness again
global predictors_imp3 : subinstr global predictors_imp2 "hh_debt_tert_T4" "locf_hh_debt_tert_T4"
fvdel, in($predictors_imp3) out(predictors_imp3_list)
seqmiss $predictors_imp3_list if base_sample

* Display and replace predictor list
di as res "Final predictors list with imputed variables: predictors_imp3" _n "$predictors_imp3"

