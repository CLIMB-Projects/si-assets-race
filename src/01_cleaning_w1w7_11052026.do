*============================================================*
* Project: 	CLIMB - Universal Cleaning File (Wave 1 - Wave 7)
* File:    	01_cleaning_w1w7_11052026.do
* Author:  	Raj Satpathy-Horton
* Purpose: 	Implementation of a cross-project universal cleaning template. // updated for W7 
* Init:    	06/11/2025
* Updated: 	11/05/2026
*============================================================*
* Change Log
*		- 11/05/2026: (1) Corrected wave labels for insurance, (2) added binary insurance variable, (3) added dummy QUAL_T1 var.
*============================================================*
*============================================================*
* Importing CLIMB Data
*============================================================*
*** uncomment this section if running independently ***
// * Set globals and wd
// global proj	"C:/Users/rsatpath/Dropbox/CLIMB Operations/Projects/Chatbots and Mental Health"
// cd "$proj"

// * Import CLIMB data
// use "C:/Users/rsatpath/Dropbox/CLIMB Operations/Data (non-confidential)/Waves 1-7 - 08.04.2026/JHU_COVID-19 W1_W2_W3_W4_W5_W6_W7_Combined_File_20260804.dta", clear

*============================================================*
* Data Preparation
*============================================================*
*----------------------------------------------*
* Missing values
*----------------------------------------------*
* Mark all "Don't know (77)", "Skipped on web" and (98), and "refused to answer (99)" in CLIMB W6 variables. Profile vars are typically marked as missing already, but verify this prior to using a profile var. String variables are not changed. 
quietly {
	forval i=1/7 {
		ds *T`i'*, not(type string) 
		local vars = r(varlist)
		foreach v of local vars {
			if !strpos("`v'","WEIGHT") & !strpos("`v'","VPSU") & !strpos("`v'","VSTRAT") {
			replace `v' = . if inlist(`v',77,98,99)
			}
		}
	}
}

foreach x in x {
	di _n "Execution is complete."
	di `"Numeric variables with values of 77, 98, 99 have been set to missing (".")"'
}

*-----------------------------------------------------*
* Init global macros for unicode characters
*-----------------------------------------------------*
*--Init unicode characters using most recent .ado ("unicode_chars"), else manually if not present.
* Def global macros
cap which unicode_chars
if !_rc unicode_chars
if _rc {
	global ge =     ustrunescape("\u2265")  // greater than or equal to 
    global le =     ustrunescape("\u2264")  // less than or equal to
    global ss2 =    ustrunescape("\u00b2") // super script 2

    * Subscripts for on and off
    local sub_o =  ustrunescape("\u2092")
    local sub_n =  ustrunescape("\u2099")
    local sub_f =  ustrunescape("\u24a1")

    global sub_on =     "`sub_o'`sub_n'"
    global sub_off =    "`sub_o'`sub_f'`sub_f'"

	display "Initialized the following unicode characters:"
    di as text "\$ge = $ge"
    di as text "\$le = $le"
    di as text "\$ss2 = $ss2"
}

*-----------------------------------------------------*
* Init global macros for unicode characters
*-----------------------------------------------------*
*--Create a dummy QUAL_T1 variable to help with loops.
g QUAL_T1 = !missing(WEIGHT_T1)

*============================================================*
* Variable Relabeling: Minor tweaks 
*============================================================*
* Relabel vars that are fine as is, but need clearer labeling. 
*-------------------------------------------------------*
* Demographics
*-------------------------------------------------------*
* Sex - creates sex var to mirror gender in W6-W7
forval i = 6/7 {
	clonevar GENDER_T`i' = SEX_T`i'
	la var GENDER_T`i' "Respondent sex (from SEX_T`i')"
}

* Rurality 
forval i=5/7 {
	la var NEW_URBAN3_T`i' "Urbanicity (DOV)"
}

*-------------------------------------------------------*
* Financial assets
*-------------------------------------------------------*
* Insurance type
forval i=1/7 {
	la var F13_T`i' "W`i' Health Insurance Type"
}

* Binary health insurance status var
la def insurance_labels 0 "No insurance" 1 "Has insurance", replace
forval i=1/7 {
	g insurance_binary_T`i' = .
	replace insurance_binary_T`i' = 0 if F13_T`i'==6
	replace insurance_binary_T`i' = 1 if inrange(F13_T`i',1,5)
	la var insurance_binary_T`i' "Wave `i' Health Insurance"
	la val insurance_binary_T`i' insurance_labels
}

* Medical debt
forval i=4/7 {
	la var MEDDEBT_T`i' "W`i' Medical Debt"
}

*============================================================*
* Variable Creation: Demographics 
*============================================================*
* Generate sociodemographic variables.
*-------------------------------------------------------*
* Race + Ethnicity 
*-------------------------------------------------------*
* There are various ways to operationalize race/ethnicity. Options are below. 
*--------------------------*
* Collapsed (4 groups)
*--------------------------*
forval i = 1/7 {
	g race_col_T`i' = .
	replace race_col_T`i' = 1 if inlist(RACETHNICITY_T`i',1)
	replace race_col_T`i' = 2 if inlist(RACETHNICITY_T`i',2)
	replace race_col_T`i' = 3 if inlist(RACETHNICITY_T`i',4)
	replace race_col_T`i' = 4 if inlist(RACETHNICITY_T`i',3,5,6)
}

la def colracelab 1 "White" 2 "Black" 3 "Hispanic" 4 "Other", replace
forval i = 1/7 {
	la val race_col_T`i' colracelab
	la var race_col_T`i' `"Wave `i' Race or Ethnicity"'
}

*============================================================*
* Variable Creation: Mental Health
*============================================================*
* Generate PHQ9, GAD7, and PTSS scores based on survey responses.

*-------------------------------------------------------*
* PHQ-9 variable generation
*-------------------------------------------------------*
* Given that there is missingness in the PHQ9 items, there are two options: (a) count participants with incomplete PHQ surveys as missing, or (b) score PHQs even if incomplete. 
*	This file will score PHQ-9 surveys even if they are only partially complete.** 

*--------------------------*
* Wave-specific Missingness
*--------------------------*
forval i = 1/7 {
	di as red `"Missing value report for the Wave `i' PHQ-9 survey."'
	misstable summarize D6A_T`i' D6B_T`i' D6C_T`i' D6D_T`i' D6E_T`i' D6F_T`i' D6G_T`i' D6H_T`i' D6I_T`i'
}

*--------------------------*
* Continuous Score
*--------------------------*
forval i = 1/7 {
	qui g PHQ9_score_T`i' = 0
	egen rowmiss_PHQ9_T`i' = rowmiss(D6A_T`i' D6B_T`i' D6C_T`i' D6D_T`i' D6E_T`i' D6F_T`i' D6G_T`i' D6H_T`i' D6I_T`i')
	foreach x in D6A_T`i' D6B_T`i' D6C_T`i' D6D_T`i' D6E_T`i' D6F_T`i' D6G_T`i' D6H_T`i' D6I_T`i' {
		qui replace PHQ9_score_T`i' = PHQ9_score_T`i' + (`x'-1) if (`x'!=77 & `x'!=98 & `x'!=.) //& rowmiss_PHQ9_T6==0)
		qui replace PHQ9_score_T`i' = . if rowmiss_PHQ9_T`i'==9
	} 
	di as red `"Wave `i' PHQ-9 continuous measure generated as PHQ9_score_T`i'."'
}

*--------------------------*
* Full and partial incompleteness
*--------------------------*
forval i = 1/7 {
	di as red `"Partial and incomplete survey responses for Wave `i'"'
	tab PHQ9_score_T`i' rowmiss_PHQ9_T`i', m
}

*--------------------------*
* Binary Measure
*--------------------------*
forval i = 1/7 {
	qui g PHQ9_binary_T`i' = . 
	qui {
		replace PHQ9_binary_T`i' = 0 if inrange(PHQ9_score_T`i',0,9)
		replace PHQ9_binary_T`i' = 1 if inrange(PHQ9_score_T`i',10,28)
		replace PHQ9_binary_T`i' = . if rowmiss_PHQ9_T`i'==9 // binary outcome to missing only for fully incomplete surveys
	}
	di as red `"Binary PHQ-9 variable for Wave `i' created: PHQ9_binary_T`i'."'
}	

* Check harmonization with PHQ9 scores 
forval i = 1/7 {
	tab PHQ9_binary_T`i' PHQ9_score_T`i', m
}

* Label PHQ9_binary_T(i) for ease of understanding
la def PHQ9_binary_labels 0 "No depression" 1 "Probable depression (PHQ-9${ge}10)", replace
forval i = 1/7 {
	label values PHQ9_binary_T`i' PHQ9_binary_labels
	la var PHQ9_binary_T`i' `"Wave `i' Binary PHQ-9"'
}

*-------------------------------------------------------*
* GAD-7 variable generation
*-------------------------------------------------------*
* Note: Partially complete responses are not set to missing. 
forval i = 1/7 {
	di as red `"Missing values in" Wave `i' GAD-7 survey."'
	misstable summarize D8A_T`i' D8B_T`i' D8C_T`i' D8D_T`i' D8E_T`i' D8F_T`i' D8G_T`i'
}

*--------------------------*
* GAD-7 Continuous Measure
*--------------------------*
forval i = 1/7 {
	qui g GAD7_score_T`i' = 0
	egen rowmiss_GAD7_T`i' = rowmiss(D8A_T`i' D8B_T`i' D8C_T`i' D8D_T`i' D8E_T`i' D8F_T`i' D8G_T`i')
	foreach x in D8A_T`i' D8B_T`i' D8C_T`i' D8D_T`i' D8E_T`i' D8F_T`i' D8G_T`i' {
		qui replace GAD7_score_T`i' = GAD7_score_T`i' + (`x'-1) if (`x'!=77 & `x'!=98 & `x'!=.) // & rowmiss_GAD7_T`i'==0)
		qui replace GAD7_score_T`i' = . if rowmiss_GAD7_T`i'==7
	}
}	

* Evaluate complete and partial missingness in GAD7 scores across all waves
* Wave 1 - 
forval i = 1/7 {
	di as red `"Wave `i' full and partial missingness report."'
	tab GAD7_score_T`i' rowmiss_GAD7_T`i', m
}

*--------------------------*
* GAD-7 Binary Measure
*--------------------------*
forval i = 1/7 {
	qui g GAD7_binary_T`i' = .
	qui replace GAD7_binary_T`i' = 0 if inrange(GAD7_score_T`i',0,9)
	qui replace GAD7_binary_T`i' = 1 if inrange(GAD7_score_T`i',10,21)
	qui replace GAD7_binary_T`i' = . if rowmiss_GAD7_T`i'==9 // This sets GAD7 binary to missing if all GAD7 responses are missing
	di as red `"Wave `i' GAD-7 binary measure generated as GAD7_binary_T`i'."'
}

// Check if harmonized with GAD7 score variables at each wave.
forval i = 1/7 {
	di as red `"Checking Wave `i' harmonization between continuous and binary GAD-7 variables."'
	tab GAD7_binary_T`i' GAD7_score_T`i', m
}

// Label for GAD7 binary vars for comprehension
la def GAD7_binary_labels 0 "No anxiety" 1 "Probable anxiety (GAD-7${ge}10)", replace
forval i = 1/7 {
	label values GAD7_binary_T`i' GAD7_binary_labels
	la var GAD7_binary_T`i' `"Wave `i' Binary GAD-7"'
}

*-------------------------------------------------------*
* PC-PTSD variable generation
*-------------------------------------------------------*
* Note: Partially missing responses are not set to missing. 
* NOTE: PTSD screening status (binary) is defined using two methods below: (1) >=3 - usual construction AND (2) >=4 - more severe only
* Note: Continuous PTSD is defined using either the 4 question scale (all waves) or the 5 question scale (Waves 4 onwards)
*--------------------------*
* Harmonize variables
*--------------------------*
* Rename W4 PTSD "E" variable
rename D9_T4E D9E_T4

*--------------------------*
* Continuous PC-PTSD-4 (4 questions)
*--------------------------*
forval i = 1/7 {
	qui g PTSD4_score_T`i' = 0
	egen rowmiss_PTSD4_T`i' = rowmiss(D9A_T`i' D9B_T`i' D9C_T`i' D9D_T`i')
	foreach x in D9A_T`i' D9B_T`i' D9C_T`i' D9D_T`i' {
		qui replace PTSD4_score_T`i' = PTSD4_score_T`i' + 1 if `x'==1 // coded as 1=Yes, 2=No
	}
	qui replace PTSD4_score_T`i' = . if rowmiss_PTSD4_T`i'==4
	di as red `"Wave `i' PC-PTSD-4 continuous variable generated as PTSD4_score_T`i'."'
}

*--------------------------*
* Continuous PC-PTSD-5 (5 questions)
*--------------------------*
* Note: Not present in Waves 1-3
forval i = 4/7 {
	qui g PTSD5_score_T`i' = 0
	egen rowmiss_PTSD5_T`i' = rowmiss(D9A_T`i' D9B_T`i' D9C_T`i' D9D_T`i' D9E_T`i')
	foreach x in D9A_T`i' D9B_T`i' D9C_T`i' D9D_T`i' D9E_T`i' {
		qui replace PTSD5_score_T`i' = PTSD5_score_T`i' + 1 if `x'==1
		qui replace PTSD5_score_T`i' = . if rowmiss_PTSD5_T`i'==5
	}
	di as red `"Wave `i' PC-PTSD-5 continuous variable generated as PTSD5_score_T`i'."'
}

*==============*
* Binary: >=3pts
*==============*
*--------------------------*
* Binary PC-PTSD-4 (3pt)
*--------------------------*
forval i = 1/7 {
	qui {
		g PTSD4_binary_T`i' = .
		replace PTSD4_binary_T`i' = 0 if inrange(PTSD4_score_T`i',0,2)
		replace PTSD4_binary_T`i' = 1 if inrange(PTSD4_score_T`i',3,4)
		replace PTSD4_binary_T`i' = . if rowmiss_PTSD4_T`i'==4
	}
	di as red `"Binary Wave `i' PC-PTSD-4 variable (3 or above) generated as PTSD4_binary_T`i'."'
}

* Check harmonization
forval i = 1/7 {
	di as red `"Checking harmonization between Wave `i' binary and continuous variables."'
	tab PTSD4_binary_T`i' PTSD4_score_T`i', m
}

*--------------------------*
* Binary PC-PTSD-5 (3pt)
*--------------------------*
* Note: Only in Waves 4-7
forval i = 4/7 {
	qui {
		g PTSD5_binary_T`i' = .
		replace PTSD5_binary_T`i' = 0 if inrange(PTSD5_score_T`i',0,2)
		replace PTSD5_binary_T`i' = 1 if inrange(PTSD5_score_T`i',3,5)
		replace PTSD5_binary_T`i' = . if rowmiss_PTSD5_T`i'==5
	}
	di as red `"Binary Wave `i' PC-PTSD-5 variable (3 or above) generated as PTSD5_binary_T`i'."'
}

* Check harmonization
forval i = 4/7 {
	di as red `"Checking harmonization between Wave `i' binary and continuous variables."'
	tab PTSD5_binary_T`i' PTSD5_score_T`i', m
}

*--------------------------*
* Labeling PTSD binary vars
*--------------------------*
la def PTSD4_lab 0 "No PTSD" 1 "Probable PTSD (PC-PTSD-4${ge}3)", replace
la def PTSD5_lab 0 "No PTSD" 1 "Probable PTSD (PC-PTSD-5${ge}3)", replace

forval i = 1/7 {
	label values PTSD4_binary_T`i' PTSD4_lab
	la var PTSD4_binary_T`i' `"Wave `i' Binary PC-PTSD-4"'
}

forval i = 4/7 {
	la val PTSD5_binary_T`i' PTSD5_lab
	la var PTSD5_binary_T`i' `"Wave `i' Binary PC-PTSD-5"'
}

*============*
* >=4pts 
*============*
* Using the cutoff of 4 or above as a positive screen.
*--------------------------*
* Binary PC-PTSD-4 (4pt)
*--------------------------*
la def ptsd4lab_4pt 0 "No PTSD" 1 "Probable PTSD (PC-PTSD-4${ge}4)", replace

forval i = 1/7 {
	qui {
		g PTSD4_binary4_T`i' = .
		replace PTSD4_binary4_T`i' = 0 if inrange(PTSD4_score_T`i',0,3)
		replace PTSD4_binary4_T`i' = 1 if PTSD4_score_T`i'==4
		replace PTSD4_binary4_T`i' = . if rowmiss_PTSD4_T`i'==4
		la val PTSD4_binary4_T`i' ptsd4lab_4pt
	}
	di as red `"Binary Wave `i' PC-PTSD-4 variable (4 or above) generated as PTSD4_binary4_T`i'."'
}

* Check harmonization
forval i = 1/7 {
	di as red `"Checking harmonization between Wave `i' binary and continuous variables."'
	tab PTSD4_binary4_T`i' PTSD4_score_T`i', m
}

*--------------------------*
* Binary PC-PTSD-5 (4pt)
*--------------------------*
* Note: Only in Waves 4-7
la def ptsd5lab_4pt 0 "No PTSD" 1 "Probable PTSD (PC-PTSD-5${ge}4)", replace

forval i = 4/7 {
	qui {
		g PTSD5_binary4_T`i' = .
		replace PTSD5_binary4_T`i' = 0 if inrange(PTSD5_score_T`i',0,3)
		replace PTSD5_binary4_T`i' = 1 if inlist(PTSD5_score_T`i',4,5)
		replace PTSD5_binary4_T`i' = . if rowmiss_PTSD5_T`i'==5
		la val PTSD5_binary4_T`i' ptsd5lab_4pt
	}
	di as red `"Binary Wave `i' PC-PTSD-5 variable (4 or above) generated as PTSD5_binary4_T`i'."'
}

* Check harmonization
forval i = 4/7 {
	di as red `"Checking harmonization between Wave `i' binary and continuous variables."'
	tab PTSD5_binary4_T`i' PTSD5_score_T`i', m
}

*-------------------------------------------------------*
* Previous depression
*-------------------------------------------------------*
* Variable showing previous diagnosis of depression (12month)
forval i = 1/7 {
	g prev_depression_T`i' = . 
	replace prev_depression_T`i' = 1 if inlist(D5_T`i',1)
	replace prev_depression_T`i' = 0 if inlist(D5_T`i',2)
}

la def prevdeplab 0 "No depression" 1 "Previous depression" 
forval i = 1/7 {
	if `i'==1 la var prev_depression_T`i' `"Wave `i' Previous Depression (ever)"'
	else if `i'!=1 la var prev_depression_T`i' `"Wave `i' Previous Depression (past 12 months)"'
	la val prev_depression_T`i' prevdeplab
}

*============================================================*
* Variable Creation: Financial Assets
*============================================================*
* Define asset-based variables using CLIMB survey responses.

* Generate a general quartile-level label for use prior to specifying ranges manually.
la def qrtlabs 1 "Q1 (Low)" 2 "Q2" 3 "Q3" 4 "Q4 (High)", replace

* General label for groups (none vs tertiles)
la def grplabs 0 "None" 1 "First tertile (low)" 2 "Second tertile (mid)" 3 "Third tertile (high)", replace

*-------------------------------------------------------*
* Household-level Assets - quartiles
*-------------------------------------------------------*
* Generate household level financial quartiles
*--------------------------*
* Household income quartiles
*--------------------------*
forval i = 1/7 {
	qui xtile hh_income_quart_T`i' = F17_T`i', nq(4)
	la val hh_income_quart_T`i' qrtlabs
	la var hh_income_quart_T`i' `"Wave `i' Household Income"'
}

*--------------------------*
* Household savings quartiles
*--------------------------*
forval i = 1/7 {
	xtile hh_savings_quart_T`i' = F18_T`i', nq(4)
	la var hh_savings_quart_T`i' `"Wave `i' Household Savings (quartiles)"'
	la val hh_savings_quart_T`i' qrtlabs
}

*--------------------------*
* Household debt quartiles
*--------------------------*
forval i = 1/7 {
	xtile hh_debt_quart_T`i' = F19_T`i', nq(4)
	la val hh_debt_quart_T`i' qrtlabs
	la var hh_debt_quart_T`i' `"Wave `i' Household Debt (quartiles)"'
}

*-------------------------------------------------------*
* Household-level Assets - Groups 
*-------------------------------------------------------*
* Create groups for variables where there is a "none" response: 0=None, 1-3 are quartiles
*--------------------------*
* Household savings groups (W6 only)
*--------------------------*
* Groups are defined as 0 (no savings) followed by tertile distribution
forval i = 1/7 {
	xtile hh_savings_group_T`i' = F18_T`i' if F18_T`i'!=0, nq(3)
	replace hh_savings_group_T`i' = 0 if F18_T`i'==0

	la var hh_savings_group_T`i' "Wave `i' Household Savings (group)"
	la val hh_savings_group_T`i' grplabs
}

*--------------------------*
* Household debt groups
*--------------------------*
* Groups defined as 0 (no debt) followed by tertile distribution
forval i = 1/7 {
	xtile hh_debt_group_T`i' = F19_T`i' if F19_T`i'!=1, nq(3)
	replace hh_debt_group_T`i' = 0 if F19_T`i'==1 // 1="No debt"
	la val hh_debt_group_T`i' grplabs
	la var hh_debt_group_T`i' `"Wave `i' Household Debt (group)"'
}

// *-------------------------------------------------------*
// * Household-level Assets - Fixed 
// *-------------------------------------------------------*
// * Create fixed groupings for household level financial assets that are comparable across all waves. 
// *--------------------------*
// * Household income fixed
// *--------------------------*
// * Groups: 0-5k, 5k-25k, 25k-75k, 75k+
// forval i = 1/7 {
// 	g hh_income_fixed_T`i' = . 
// 	replace hh_income_fixed_T`i' = 1 if inlist(F17_T`i',0,1)
// 	replace hh_income_fixed_T`i' = 2 if inrange(F17_T`i',2,5)
// 	replace hh_income_fixed_T`i' = 3 if inrange(F17_T`i',6,10)
// 	replace hh_income_fixed_T`i' = 4 if F17_T`i'>10 & !missing(F17_T`i')
// }

// la def fixedinc 1 "$0 to ${le}$5k" 2 "$5k to ${le}$25k" 3 "$25k to ${le}$75k" 4 "${ge}$75k", replace
// forval i = 1/7 {
// 	la var hh_income_fixed_T`i' `"Wave `i' household income (fixed groups)"'
// 	la val hh_income_fixed_T`i' fixedinc
// }

// *--------------------------*
// * Household savings fixed
// *--------------------------*
// * Groups: 0-5k, 5k-25k, 25k-100k, 100k+
// forval i = 1/7 {
// 	g hh_savings_fixed_T`i' = . 
// 	replace hh_savings_fixed_T`i' = 1 if inrange(F18_T`i',0,1)
// 	replace hh_savings_fixed_T`i' = 2 if inrange(F18_T`i',2,5)
// 	replace hh_savings_fixed_T`i' = 3 if inrange(F18_T`i',6,11)
// 	replace hh_savings_fixed_T`i' = 4 if F18_T`i'>11 & !missing(F18_T`i')
// }

// la def fixedsav 1 "$0 to ${le}$5k" 2 "$5k to ${le}$25k" 3 "$25k to ${le}$100k" 4 "${ge}$100k"
// forval i = 1/7 {
// 	la var hh_savings_fixed_T`i' `"Wave `i' household income (fixed groups)"'
// 	la val hh_savings_fixed_T`i' fixedsav
// }

// *--------------------------*
// * Household debt fixed
// *--------------------------*
// * Groups: no debt, $1-$25k, $25k-$100k, $100k+
// forval i = 1/7 {
// 	g hh_debt_fixed_T`i' = . 
// 	replace hh_debt_fixed_T`i' = 1 if inlist(F19_T`i',1)
// 	replace hh_debt_fixed_T`i' = 2 if inrange(F19_T`i',2,8)
// 	replace hh_debt_fixed_T`i' = 3 if inrange(F19_T`i',9,14)
// 	replace hh_debt_fixed_T`i' = 4 if F19_T`i'>14 & !missing(F19_T`i')
// }

// la def fixeddebt 1 "No debt" 2 "$1 to ${le}$25k" 3 "$25k to ${le}$100k" 4 "${ge}$100k", replace
// forval i = 1/7 {
// 	la var hh_debt_fixed_T`i' `"Wave `i' household debt (fixed groups)"'
// 	la val hh_debt_fixed_T`i' fixeddebt
// }

// *--------------------------*
// * Validate fixed groupings
// *--------------------------*
// di "Household Income" 
// forval i = 1/7 {
// 	tab F17_T`i' hh_income_fixed_T`i', m
// }
// di "Household Savings" 
// forval i = 1/7 {
// 	tab F18_T`i' hh_savings_fixed_T`i', m
// }
// di "Household Debt" 
// forval i = 1/7 {
// 	tab F19_T`i' hh_debt_fixed_T`i', m
// }

*============================================================*
* Variable Creation: Debt
*============================================================*
*--------------------------*
* Student loan debt (collapsed)
*--------------------------*
g student_loans_T6 = . 
replace student_loans_T6 = 1 if inrange(STUDENTLOAN_T6,1,3)
replace student_loans_T6 = 0 if inlist(STUDENTLOAN_T6,4)

la def studentlab 1 "Public or private student loans" 0 "No student loans"
la val student_loans_T6 studentlab
la var student_loans_T6 "Wave 6 Student Loans"

*--------------------------*
* Medical debt
*--------------------------*
forval i = 4/7 {
	clonevar meddebt_amt_clean_T`i' = MEDDEBT_AMOUNT_T`i'
	replace meddebt_amt_clean_T`i' = 7 if (MEDDEBT_T`i'==1 & missing(MEDDEBT_AMOUNT_T`i'))
}

la def meddebtlab 1 "<$500" 2 "$500 to ${le}$1k" 3 "$1k to ${le}$2.5k" 4 "2.5k to ${le}$5k" 5 "$5k to ${le}$10k" 6 "${ge}$10k" 7 "Unknown amount of medical debt", replace
forval i = 4/7 {
	la val meddebt_amt_clean_T`i' meddebtlab 
	la var meddebt_amt_clean_T`i' `"Wave `i' Medical Debt Amount"'
}

*============================================================*
* Variable Creation: Social Assets 
*============================================================*
* Generate social asset variables.
*-------------------------------------------------------*
* Education
*-------------------------------------------------------*
* There are various ways to operationalize education. We use a college education as our boundary. 
*--------------------------*
* College (binary)
*--------------------------*
forval i = 1/7 {
	g educ_college_T`i' = . 
	if `i'==1 {
		replace educ_college_T`i' = 0 if inlist(EDUC4_T`i',1,2,3)
		replace educ_college_T`i' = 1 if inlist(EDUC4_T`i',4)
	}
	if `i'!=1 {
		replace educ_college_T`i' = 0 if inlist(EDUC5_T`i',1,2,3)
		replace educ_college_T`i' = 1 if inlist(EDUC5_T`i',4,5)
	}
}

la def collegelab 0 "Some college or less" 1 "College or more"
forval i = 1/7 {
	la val educ_college_T`i' collegelab
	la var educ_college_T`i' `"Wave `i' Education"'
}

*-------------------------------------------------------*
* Marital status
*-------------------------------------------------------*
*--------------------------*
* Binary (married or living with other)
*--------------------------*
* There are two variables: MARITAL vs MARITAL_STATUS. These do not align, so we stick with only definitions available through MARITAL_T`i'. 
forval i = 1/7 {
	g marital_binary_T`i' = .
	replace marital_binary_T`i' = 1 if inlist(MARITAL_T`i',1,6)
	replace marital_binary_T`i' = 0 if inlist(MARITAL_T`i',2,3,4,5)
}

la def maritallab 1 "Married" 0 "Not married or other"
forval i = 1/7 {
	la val marital_binary_T`i' maritallab
	la var marital_binary_T`i' `"Wave `i' Marital Status (binary)"'
}

*-------------------------------------------------------*
* Religious service attendance
*-------------------------------------------------------*
* We operationalize using a binary (ever vs never).
* Note: We only begin asking about religiousity in W3, so no W1 or W2 vars created.
*--------------------------*
* Binary attendance
*--------------------------*
forval i = 3/7 {
	g religious_attendance_T`i' = . 
	replace religious_attendance_T`i' = 0 if inlist(ATTEND_T`i',1)
	replace religious_attendance_T`i' = 1 if inrange(ATTEND_T`i',2,9)
}

la def religionlab 0 "Never attended" 1 "Ever attended", replace
forval i = 3/7 {
	la val religious_attendance_T`i' religionlab
	la var religious_attendance_T`i' `"Wave `i' Religious Service Attendance (binary)"'
}

*-------------------------------------------------------*
* Employment status
*-------------------------------------------------------*
* We operationalize using a binary (employed or other, not employed).
*--------------------------*
* Binary employment
*--------------------------*
forval i = 1/7 {
	g employment_T`i' = . 
	replace employment_T`i' = 0 if inlist(EMPLOY1_T`i',3)
	replace employment_T`i' = 1 if (inrange(EMPLOY1_T`i',1,10) & !inlist(EMPLOY1_T`i',3))
}

la def employlab 0 "Not employed" 1 "Employed or other", replace
forval i = 1/7 {
	la val employment_T`i' employlab
	la var employment_T`i' `"Wave `i' Employment Status"'
}

*-----------------------------------------------------*
* Perceived Social Support
*-----------------------------------------------------*
*--Define perceived social support as a tertile-based binary measure. 
* Create a cleaned social support variable in each wave
forval i = 3/7 {
	foreach s in "A" "B" "C" {
		g soc_sup_`s'_T`i' = C3`s'_T`i' if inrange(C3`s'_T`i',1,4) & QUAL_T`i'==1
	}
}

* Generate a variable with the sum of those if all are not missing
forval i = 3/7 {
	egen soc_sup_sum_T`i' = rowtotal(soc_sup_*_T`i') if !missing(soc_sup_A_T`i',soc_sup_B_T`i',soc_sup_C_T`i')
}

* Create a variable that has terciles of the sum
forval i = 3/7 {
	xtile soc_sup_terc_T`i' = soc_sup_sum_T`i', nquantiles(3)
}

* Create a binary var where highest tercile = low social support
la def soc_sup_labels 0 "Low social support" 1 "High social support"
forval i = 3/7 {
	g social_support_T`i' = .
	replace social_support_T`i' = 1 if inrange(soc_sup_terc_T`i',1,2)
	replace social_support_T`i' = 0 if soc_sup_terc_T`i'==3 // highest summed score = lowest support
	la val social_support_T`i' soc_sup_labels
}

*============================================================*
* Variable Creation: Physical Assets
*============================================================*
* Generate physical assets
*-------------------------------------------------------*
* Home ownership
*-------------------------------------------------------*
* Operationalized as a binary 
*--------------------------*
* Binary Ownership
*--------------------------*
forval i = 1/7 {
	g home_own_T`i' = . 
	if `i'==1 {
		replace home_own_T`i' = 0 if inlist(HOUSING_T`i',2,3)
		replace home_own_T`i' = 1 if inlist(HOUSING_T`i',1)
	}
	if `i'!=1 {
		replace home_own_T`i' = 0 if inlist(F16_T`i',2,3)
		replace home_own_T`i' = 1 if inlist(F16_T`i',1)
	}
}

la def homelab 0 "Does not own home" 1 "Owns home", replace
forval i = 1/7 {
	la val home_own_T`i' homelab
	la var home_own_T`i' `"Wave `i' Home Ownership"'
}

*============================================================*
* Variable Creation: Social Determinants of Health
*============================================================*
* Generate variables roughly within the SDOH domain.
*-------------------------------------------------------*
* Housing instability B6_18_T2 B6_19_T3 B6_11_T4 B6_11_T5 B6_11_T6
*-------------------------------------------------------*
* Not available for W1, W2+W3 have unique varnames, W4-W6 are consistent
forval i = 1/7 {
	g housing_instability_T`i' = . 
	if `i'==2 {
		replace housing_instability_T2 = 1 if inlist(B6_18_T2,1)
		replace housing_instability_T2 = 0 if inlist(B6_18_T2,0)
	}
	if `i'==3 {
		replace housing_instability_T3 = 1 if inlist(B6_19_T3,1)
		replace housing_instability_T3 = 0 if inlist(B6_19_T3,0)
	}
	else if inrange(`i',4,7) {
		replace housing_instability_T`i' = 1 if inlist(B6_11_T`i',1)
		replace housing_instability_T`i' = 0 if inlist(B6_11_T`i',0)
	}
}

la def homestablab 0 "No housing instability" 1 "Experienced housing instability", replace
forval i = 1/7 {
	la val housing_instability_T`i' homestablab
	la var housing_instability_T`i' `"Wave `i' Housing Instability"'
}

*-------------------------------------------------------*
* Unmet medical need (unable to pay for medical bills) (W4-W6 only)
*-------------------------------------------------------*
forval i = 4/7 {
	g unmet_medical_need_T`i' = . 
	replace unmet_medical_need_T`i' = 1 if inlist(B6_15_T`i',1)
	replace unmet_medical_need_T`i' = 0 if inlist(B6_15_T`i',0)
}

la def costlab 0 "No unmet medical needs" 1 "Experienced unmet medical needs", replace
forval i = 4/7 {
	la val unmet_medical_need_T`i' costlab
	la var unmet_medical_need_T`i' `"Wave `i' Unmet Medical Need"'
}

*============================================================*
* Variable Creation: Miscellaneous Longitudinal Variables
*============================================================*
* Generate variables for other non-standard longitudinal variables of interest.
*-------------------------------------------------------*
* Self-reported political affiliation
*-------------------------------------------------------*
*--------------------------*
* Self-reported Party Affiliation (W2-W6)
*--------------------------*
forval i = 2/7 {
	clonevar political_party_T`i' = PID1_T`i'
}

la def politicslab 1 "Democrat" 2 "Republican" 3 "Independent" 4 "None of the above" 
forval i = 2/7 {
	la val political_party_T`i' politicslab
	la var political_party_T`i' `"Wave `i' Self-reported Political Affiliation"'
}

*--------------------------*
* 5-level ideology (W5-W6)
*--------------------------*
forval i = 5/7 {
	g ideology_T`i' = IDEO_T`i' if IDEO_T`i'!=-1
	replace ideology_T`i' = . if IDEO_T`i'==-1
}

la def ideolab 1 "Very liberal" 2 "Somewhat liberal" 3 "Moderate" 4 "Somewhat conservative" 5 "Very conservative"
forval i = 5/7 {
	la val ideology_T`i' ideolab
	la var ideology_T`i' `"Wave `i' Political Ideology"'
}

*-------------------------------------------------------*
* Self-reported Physical Health
*-------------------------------------------------------*
*--------------------------*
* Binary (good or above vs fair or poor)
*--------------------------*
forval i = 1/7 {
	g physical_health_T`i' = . 
	replace physical_health_T`i' = 1 if inlist(D1_T`i',1,2,3)
	replace physical_health_T`i' = 0 if inlist(D1_T`i',4,5)
}

la def healthlab 1 "Good or above" 0 "Fair or poor", replace
forval i = 1/7 {
	la val physical_health_T`i' healthlab
	la var physical_health_T`i' `"Wave `i' Self-reported Physical Health"'
}

*-------------------------------------------------------*
* Self-reported Mental Health
*-------------------------------------------------------*
*--------------------------*
* Binary (good or above vs fair or poor)
*--------------------------*
forval i = 1/7 {
	g mental_health_T`i' = . 
	replace mental_health_T`i' = 1 if inlist(D2_T`i',1,2,3)
	replace mental_health_T`i' = 0 if inlist(D2_T`i',4,5)
}

forval i = 1/7 {
	la val mental_health_T`i' healthlab
	la var mental_health_T`i' `"Wave `i' Self-reported Mental Health"'
}

*-------------------------------------------------------*
* Combined parental status (4-level categorical)
*-------------------------------------------------------*
* Generate a combined parental status categorical variable. 
*--Note: It is possible to extrapolate 18+ children status in some waves, but not directly asked prior to W6. 
*--------------------------*
* W6 onwards
*--------------------------*
* Generate a variable that is "minor", "adult", "both", "none"
la def parents_lbl 1 "Minor and adult" 2 "Minor only" 3 "Adult only" 4 "No children", replace

forval i = 6/7 {
	g parent_combined_T`i' = . 
	replace parent_combined_T`i' = 1 if PARENT_T`i'==1 & PARENT_OLDERCHILD_T`i'==1 // both
	replace parent_combined_T`i' = 2 if PARENT_T`i'==1 & PARENT_OLDERCHILD_T`i'==2 // minor only
	replace parent_combined_T`i' = 3 if PARENT_T`i'==2 & PARENT_OLDERCHILD_T`i'==1 // adult only
	replace parent_combined_T`i' = 4 if PARENT_T`i'==2 & PARENT_OLDERCHILD_T`i'==2 // none

	la val parent_combined_T`i' parents_lbl
	la var parent_combined_T`i' "Wave `i' combined parental status"
}

*============================================================*
* Variable Creation: Miscellaneous, non-longitudinal variables
*============================================================*
* Generate variables which are not present in multiple years of data.
*--------------------------*
* 2024 Election Choice
*--------------------------*
* Operationalized as Kamala vs Trump vs Other
g vote_choice_2024 = .
replace vote_choice_2024 = 1 if inlist(CANDI2024_T6,1)
replace vote_choice_2024 = 2 if inlist(CANDI2024_T6,2)
replace vote_choice_2024 = 3 if inlist(CANDI2024_T6,3,4)

la def votelab 1 "Kamala Harris" 2 "Donald Trump" 3 "Other or did not vote"
la val vote_choice_2024 votelab
la var vote_choice_2024 "2024 Election Choice"

*============================================================*
* Variable Creation: Job Loss (self, household, either)
*============================================================*
* Generate variables operationalizing job loss and wage loss in all waves.
*-------------------------------------------------------*
* Wage Loss (hours cut) - not asked in Wave 2
*-------------------------------------------------------*
*--------------------------*
* Variable generation
*--------------------------*
* Loop through waves to generate consistent var
forval i = 1/7 {
	// W1
	if `i'==1 clonevar hours_cut_T1 = B6_12_T1
	// W2 - not asked, generating fully missing var
	if `i'==2 g hours_cut_T2 = . 
	// W3
	if `i'==3 clonevar hours_cut_T3 = B6_11_T3
	// W4 onwards
	if `i'>=4 clonevar hours_cut_T`i' = B6_5_T`i'
}

*--------------------------*
* Labeling
*--------------------------*
la def hourscutlab 0 "Hours not cut" 1 "Hours cut", replace
forval i = 1/7 {
	if `i'==2 {
		la var hours_cut_T`i' `"Wave `i' hours cut (not asked)"'
	}
	else {
		la var hours_cut_T`i' `"Wave `i' hours cut"'
		la val hours_cut_T`i' hourscutlab
	}
}

*-------------------------------------------------------*
* Self job loss
*-------------------------------------------------------*
*--------------------------*
* Variable generation
*--------------------------*
* Loop through all waves to create harmonized var
forval i = 1/7 {
	// W1
	if `i'==1 clonevar lost_job_indiv_T1 = B6_13_T1
	// W2
	if `i'==2 clonevar lost_job_indiv_T2 = B6_12_T2
	// W3
	if `i'==3 clonevar lost_job_indiv_T3 = B6_13_T3
	// W4 onwards
	if `i'>=4 clonevar lost_job_indiv_T`i' = B6_6_T`i'
}

*--------------------------*
* Labeling
*--------------------------*
la def selfjoblab 0 "No job loss" 1 "Self job loss", replace
forval i = 1/7 {
	la val lost_job_indiv_T`i' selfjoblab
	la var lost_job_indiv_T`i' `"Wave `i' Past 12-month Individual Job Loss"'
}

*-------------------------------------------------------*
* Household job loss
*-------------------------------------------------------*
*--------------------------*
* Variable generation
*--------------------------*
* Loop through waves to harmonize vars
forval i = 1/7 {
	// W1
	if `i'==1 clonevar lost_job_hh_T1 = B6_14_T1
	// W2
	if `i'==2 clonevar lost_job_hh_T2 = B6_13_T2
	// W3
	if `i'==3 clonevar lost_job_hh_T3 = B6_14_T3
	// W4 onwards
	if `i'>=4 clonevar lost_job_hh_T`i' = B6_7_T`i'
}

*--------------------------*
* Labeling
*--------------------------*
la def hhjoblab 0 "No job loss" 1 "Household job loss", replace
forval i = 1/7 {
	la val lost_job_hh_T`i' hhjoblab
	la var lost_job_hh_T`i' `"Wave `i' Past 12-month Household Job Loss"'
}

*-------------------------------------------------------*
* Any job loss (household or self)
*-------------------------------------------------------*
* Iterate through waves to generate a combined job loss var
forval i = 1/7 {
	g lost_job_any_T`i' = . 
	replace lost_job_any_T`i' = 1 if lost_job_indiv_T`i'==1 | lost_job_hh_T`i'==1
	replace lost_job_any_T`i' = 0 if lost_job_indiv_T`i'==0 & lost_job_hh_T`i'==0
}

la def anyjoblab 0 "No self or HH job loss" 1 "Any self or HH job loss", replace
forval i = 1/7 {
	la val lost_job_any_T`i' anyjoblab
	la var lost_job_any_T`i' `"Wave `i' Past 12-month Self OR Household Job Loss"'
}

*-----------------------------------------------------*
* Self-reported credit score
*-----------------------------------------------------*
*--Generate credit score variable.
la def selfcreditlbl 1 "300-600" 2 "601-660" 3 "661-780" 4 "781-850" 5 "No credit/not known", replace
forval i = 4/7 {
	g credit_selfreport_T`i' = . 
	replace credit_selfreport_T`i' = CONSUMERCREDIT_T`i' if inrange(CONSUMERCREDIT_T`i',1,4)
	replace credit_selfreport_T`i' = 5 if inrange(CONSUMERCREDIT_T`i',5,7)
	la val credit_selfreport_T`i' selfcreditlbl
	la var credit_selfreport_T`i' "W`i' self-reported credit score"
}