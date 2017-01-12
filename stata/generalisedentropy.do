capture program drop generalisedentropy

program define generalisedentropy, eclass properties(svyb mi)

/*******************************************************

generalisedentropy - calculate generalisedentropy

This Stata command estimates the generalised entropy(alpha),
and can be combined with the svy and mi commands, only 
with replicate weights.

Syntax: generalisedentropy varname [weight] [if] [in] [, over(varname) alpha(real 1)] 

In order to combine with mi and svy, only one variable can 
be given in varlist.

alpha is the alpha value, by default 1 (Theil).

ECB - v 0.1 2016/11/16 - Sébastien Perez-Duarte


Changelog

v 0.1 initial version

*******************************************************/

    syntax varname [aweight iweight pweight / ] [if] [in] [, over(varname) alpha(real 1)] 
    
    marksample touse, novarlist zeroweight
	
	tempvar one
	
	gen `one'=1

	local weight="aweight" 
	
    * iweight cannot be used with qreg
    if "`weight'"=="" { 
		local exp=`one'
	}

	
	/* calculate the statistic of interest */
gsort `touse' `over' `varlist' , mfirst

tempvar ybarstrpos ye

quietly by `touse' `over': gen `ybarstrpos'=sum(`varlist'*`exp')/sum(`exp')
quietly by `touse' `over': replace `ybarstrpos'=`ybarstrpos'[_N] 

quietly {
	if `alpha'==0 {
		gen `ye'=-ln(`varlist'/`ybarstrpos')
	}
	else if `alpha'==1 {
		gen `ye'=`varlist'/`ybarstrpos'*ln(`varlist'/`ybarstrpos')
	}
	else {
		gen `ye'= ((`varlist'/`ybarstrpos')^`alpha'-1)/(`alpha'*(`alpha'-1))
	}
}

/*
sum `ye' `ybarstrpos' [`weight'=`exp'] if `touse'
list `varlist' `ye' `ybarstrpos' `exp'  if `touse'
*/
	/*quietly sum `ye' [`weight'=`exp'] if `touse'	

	matrix _z=r(mean)*/

	quietly tabstat `ye' [`weight'=`exp'] if `touse', by(`over') save	
	
	matrix _zz=r(Stat1)
	
	if _zz[1,1]==. matrix _zz=r(StatTotal)
	
	capture matrix drop _z

	/* construct the e(b) output and assign the correct colnames */
	local i=1
	local names
	while _zz[1,1] ~= . {
		if "`i'"=="1" matrix _z=_zz
		else matrix _z=_z,_zz
		
		/* replace spaces in the labels by underscores */
		local tempname `r(name`i')'
		local tempname : subinstr local tempname " " "_", all

		local names=`"`names' "`tempname'""'
		
		local ++i
		matrix _zz=r(Stat`i')
	}
	
	disp `"#`names'#"'
	matrix colnames _z = `names'
	disp "Generalized Entropy (`alpha')"
	matrix list _z

	/* the sample used */
	tempvar one
	gen `one'= `touse'
	ereturn post _z, esample(`one')

	/* arguments required by svy and mi */
	ereturn local cmd percentileratio
	ereturn local title "Percentileratio `statistic'"

	quiet count if `touse'
	ereturn local N r(N)

	capture matrix drop _z 
	
end

