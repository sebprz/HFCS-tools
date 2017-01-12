/****************************************************************

   Example file to prepare the HFCS to use with Stata

   ECB (c) 2016  - Version 2.1  2016-05-27

   This do-file saves in the working folder the files:
     h, w, p, d, h_mi, h_mi_wide, hd_mi, hp_mi, hp_mi_wide,
	 hd_mi_wide, hdw_mi_wide.
	 
   Execute as: run "Userguide HFCS in Stata.do"
   
   This file will have the following effect on the data stored in the
   working files, depending on the memory available:
     *  the replicate weights are stored with single precision (float)
	 *  the flag variables may be dropped from the files
	 *  the youngest household members are dropped from the files
   
****************************************************************/

/***************** user specified parameters *******************/

cd "<LOCAL FOLDER TO STORE THE MODIFIED FILES>"

global HFCSDATA "<FOLDER WHERE THE ORIGINAL HFCS STATA FILES ARE STORED"

/*******************************************************************/
/*************** no need to modify the document after this *********/
/*******************************************************************/

clear all

version 12.1

set more off

set maxvar 7500 /* 6000 was needed for the wide format file 
                   combining the H, P and W, but is not enough in wave 2 */

/* this program converts a string variable to a numerical 
   variable with a label for the values */
program encodestrings
	syntax varlist

    * the order of the countries follows the official ordering of the European Union
	label define country 1 "BE" 2 "BG" 3 "CZ" 4 "DK" 5 "DE" 6 "EE" 7 "IE" 8 "GR" 9 "ES" 10 "FR" 11 "HR" 12 "IT" 13 "CY" 14 "LV" ///
	  15 "LT" 16 "LU" 17 "HU" 18 "MT" 19 "NL" 20 "AT" 21 "PL" 22 "PT" 23 "RO" 24 "SI" 25 "SK" 26 "FI" 27 "SE" 28 "UK"

	foreach var of varlist `varlist' {
		capture confirm numeric variable `var'
		if _rc {
			rename `var' `var'_string
			if "`var'"=="sa0100" {
				* we treat differently the sa0100 variable for the labels
				disp "Encoding variable sa0100"
				encode `var'_string, gen(`var') label(country) noextend
			} 
			else {
				encode `var'_string, gen(`var')
			}
			drop `var'_string
		}
	}
end

* define once and for all the corresponding number of the country in official EC order
capture label drop country
label define country 1 "BE" 2 "BG" 3 "CZ" 4 "DK" 5 "DE" 6 "EE" 7 "IE" 8 "GR" 9 "ES" 10 "FR" 11 "HR" 12 "IT" 13 "CY" 14 "LV" ///
  15 "LT" 16 "LU" 17 "HU" 18 "MT" 19 "NL" 20 "AT" 21 "PL" 22 "PT" 23 "RO" 24 "SI" 25 "SK" 26 "FI" 27 "SE" 28 "UK"

/****************************************/
/* we process the different input files */
/* and save them all to the working     */
/* directory                            */   
/****************************************/
noisily disp "Processing the input files..."

use "$HFCSDATA\w"
encodestrings sa0100
quietly recast float wr*, force
save w, replace

use "$HFCSDATA\d1"
replace im0100=0
append using "$HFCSDATA\d1" "$HFCSDATA\d2" "$HFCSDATA\d3" "$HFCSDATA\d4" "$HFCSDATA\d5"
encodestrings sa0100 
save d, replace

use "$HFCSDATA\p1"
replace im0100=0
append using "$HFCSDATA\p1" "$HFCSDATA\p2" "$HFCSDATA\p3" "$HFCSDATA\p4" "$HFCSDATA\p5"
/* for some strange reason string variables do not play well with mi and need to be encoded */
encodestrings sa0100 pe0300 pe0400  ra0400
save p, replace

use "$HFCSDATA\h1"
replace im0100=0
append using "$HFCSDATA\h1" "$HFCSDATA\h2" "$HFCSDATA\h3" "$HFCSDATA\h4" "$HFCSDATA\h5"
/* for some strange reason string variables do not play well with mi and need to be encoded */
encodestrings sa0100 sb1000 hd030*
save h, replace

noisily disp "All input files saved in working folder."

/****************************************/
/* we process the H file first          */
/****************************************/
noisily disp "Now processing the files and preparing for mi..."

/* set as missing in im0100==0 all values varying, and also those whose flags set them as imputed */
global IMPUTEDVARSH ""
foreach var of varlist hb* hc* hd* hg* hh* hi* {
	capture confirm numeric variable `var'
	if !_rc {
		tempvar sd count
		quietly bysort sa0100 sa0010 : egen `sd'=sd(`var')
		quietly bysort sa0100 sa0010 : egen `count'=count(`var')
		quietly count if ( (`sd'>0 & `sd' <. ) | inrange(`count',1,5)  | (f`var'>4000 & f`var'<5000) ) & im0100==0 
		if r(N)>0 global IMPUTEDVARSH "$IMPUTEDVARSH `var'"
		quietly replace `var'=. if ( (`sd'>0 & `sd' <. ) | inrange(`count',1,5)  | (f`var'>4000 & f`var'<5000) ) & im0100==0
		drop `sd' `count'
		disp ".", _continue
	}
}
/* some more housekeeping */
drop id

mi import flong, m(im0100) id(sa0100 sa0010) clear
* if the previous command fails because of not unique observations, issue: duplicates drop sa0100 sa0010 im0100

mi register imputed $IMPUTEDVARSH

if 0 { /* the code below is provided as an alternative to the procedure abov */
	mi varying
	local unregistered `r(uvars_v)'
	mi register imputed `unregistered'
}

* only to check that nothing appears in the unregistered varying categories other than the
* flag variables
mi varying

save h_mi, replace

*** we convert the H file into the wide format
drop im0100
mi convert wide, clear
save h_mi_wide, replace

*** we merge with the weights
merge 1:1 sa0100 sa0010 using w
drop _merge
save hw_mi_wide, replace

/****************************************/
/* we process the D - derived variables */
/****************************************/
* merge the D file and correct the zeroeth-implicate
use h_mi, clear
merge 1:1 sa0100 sa0010 im0100 using d
drop _merge
global IMPUTEDVARSD ""
foreach var of varlist d* {
	capture confirm numeric variable `var'
	if !_rc {
		tempvar sd count
		quietly bysort sa0100 sa0010 : egen `sd'=sd(`var')
		quietly bysort sa0100 sa0010 : egen `count'=count(`var')
		quietly count if ( (`sd'>0 & `sd' <. ) | inrange(`count',1,5) ) & im0100==0 
		if r(N)>0 global IMPUTEDVARSD "$IMPUTEDVARSD `var'"
		quietly replace `var'=. if ( (`sd'>0 & `sd' <. ) | inrange(`count',1,5) ) & im0100==0
		drop `sd' `count'
		disp ".", _continue
	}
}
mi register imputed $IMPUTEDVARSD
save hd_mi, replace

drop im0100
mi convert wide, clear
save hd_mi_wide, replace

merge 1:1 sa0100 sa0010 using w
drop _merge
save hdw_mi_wide, replace

/****************************************/
/* we process the P file                */
/****************************************/
use p, clear

*** convert to wide - each household is a single line
*** but first we re-arrange the rows to have: ra0100=1 and 2 in front, and the others sorted
*** by descending age

gen sortcrit=ra0100 if ra0100<=2 /* the sort criterion */
replace sortcrit=3 if ra0100>2
sort sa0100 sa0010 ra0010
by sa0100 sa0010 ra0010: egen ave_ra0300_b=mean(ra0300_b) /* average age across implicates */
gsort im0100 sa0100 sa0010 sortcrit - ave_ra0300_b ra0010
by im0100 sa0100 sa0010: egen pid=seq() /* pid is the new personal identification number */
/* a quick check shows that after pid>=9 these have no income, and are all 19 or younger */

gen tmp="_"+string(pid)
** we can potentially drop all the persons over a certain pid number - this saves a lot of memory */
if 1 {
	drop if pid >=9 
	noisily disp "Some household members have been dropped from the P file"
}

drop id pid sortcrit  ave_ra0300_b
reshape wide r* p* f* , i(sa0100 sa0010 im0100) j(tmp) string
save p_wide, replace

* attempt to merge - if failure, drop the flag variables and merge
global USEFLAGS 1
capture merge 1:1 sa0100 sa0010 im0100 using h_mi
capture drop _merge
if _rc {
    global USEFLAGS 0
	noisily disp "! Due to memory issues, the flags could not be kept in the H&P merged file"
	drop f*
	merge 1:1 sa0100 sa0010 im0100 using h_mi
	drop _merge
}	

* set to missing the zeroeth-implicate
global IMPUTEDVARSP ""
foreach var of varlist p* ra01* ra02* ra03* ra04* ra05* {
	capture confirm numeric variable `var'
	if !_rc {
		tempvar sd count
		quietly bysort sa0100 sa0010 : egen `sd'=sd(`var')
		quietly bysort sa0100 sa0010 : egen `count'=count(`var')
		if $USEFLAGS {
			quietly count if ( (`sd'>0 & `sd' <. ) | inrange(`count',1,5) | (f`var'>4000 & f`var'<5000) ) & im0100==0
			if r(N)>0 global IMPUTEDVARSP "$IMPUTEDVARSP `var'"
			quietly replace `var'=. if ( (`sd'>0 & `sd' <. ) | inrange(`count',1,5) | (f`var'>4000 & f`var'<5000) ) & im0100==0
		}
 		else {
			quietly count if ( (`sd'>0 & `sd' <. ) | inrange(`count',1,5) ) & im0100==0 
			if r(N)>0 global IMPUTEDVARSP "$IMPUTEDVARSP `var'"
			quietly replace `var'=. if ( (`sd'>0 & `sd' <. ) | inrange(`count',1,5) ) & im0100==0
		}
		drop `sd' `count'
		disp ".", _continue
	}
}
mi register imputed $IMPUTEDVARSP
save hp_mi , replace

** convert to wide form, dropping the flag variables in case of failure
drop im0100
capture mi convert wide, clear
if _rc {
	drop f*
	noisily disp "! Due to memory issues, the flags could not be kept in the H&P wide file"
	mi convert wide, clear
}
save hp_mi_wide, replace

** add the weights
merge 1:1 sa0100 sa0010 using w
drop _merge
save hpw_mi_wide, replace


/****************************************/
/* Examples using the replicate weights */
/****************************************/
if 0 {

* this program is used to calculate medians and percentiles with mi bootstrap data;
* Can be downloaded from GitHub https://github.com/sebprz/HFCS-tools/
run "medianize.do"


	use  hw_mi_wide, clear

	mi svyset [pw=hw0010], bsrweight(wr0001-wr1000) ///
		vce(bootstrap)

	mi estimate, vceok: svy: mean hb0100
	mi estimate, vceok: svy: proportion hb0300 
	mi estimate, vceok: svy: ratio hi0100 hb0100 
	mi estimate, vceok: svy: regress hb0100 hb0300

	mi estimate, vceok esampvaryok: svy: mean hb0900
	mi estimate, vceok esampvaryok: svy: ratio hb0900 hb0800
	mi estimate, vceok esampvaryok: svy: regress hb0900 hb0800 hb0700

	mi estimate, vceok: svy: medianize hb1701
	mi estimate, vceok: svy: medianize hb1701, over(sa0100)
	mi estimate, vceok: svy: medianize hb1701, over(sa0100) stat(p10)

****

	use hdw_mi_wide, clear
	
	* select a subset of variables
	keep sa0010 im0100 hw0010 d* wr* sa0100 _mi* _*_d*

	mi svyset [pw=hw0010], bsrweight(wr0001-wr0010) vce(bootstrap)
	
	mi estimate, vceok: svy: mean da3001, over(sa0100)

	mi passive: gen xda1000=cond(da1000==.,0,da1000)
	mi estimate, vceok esampvaryok: svy: ratio xda1000 da3001, over(sa0100)
}
