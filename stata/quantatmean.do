capture program drop quantatmean

program define quantatmean, eclass properties(svyb mi)

/*******************************************************

quantatmean - calculate Quantile At Mean index

This Stata command estimates the hoover,
and can be combined with the svy and mi commands, only 
with replicate weights.

Syntax: quantatmean varname [weight] [if] [in] [, over(varname) ] 

In order to combine with mi and svy, only one variable can 
be given in varlist.


ECB - v 0.1 2016/12/14 - Sébastien Perez-Duarte


Changelog

v 0.1 initial version

*******************************************************/

    syntax varname [aweight iweight pweight / ] [if] [in] [, over(varname)] 
    
    marksample touse, novarlist zeroweight
	
	tempvar one
	
	gen `one'=1

    * iweight cannot be used with qreg
    if "`weight'"=="" { 
		local exp=`one'
	}

	local weight="aweight" 
		
	/* calculate the statistic of interest */
	sort `touse' `over', stable

	tempvar ymean popshare

	quietly by `touse' `over': gen `ymean'=sum(`varlist'*`exp')/sum(`exp')
	quietly by `touse' `over': replace `ymean'=`ymean'[_N] 

	tab `ymean'
	
	quietly by `touse' `over': gen `popshare'=(`varlist'<`ymean')
	
	tab `popshare' [aw=hw0010]
	
	tabstat `popshare' [`weight'=`exp'] if `touse', by(`over') save	

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

		if `"`tempname'"'==`""' {
			local tempname="`varlist'"
		}
		local tempname : subinstr local tempname " " "_", all

		local names=`"`names' "`tempname'""'

		local ++i
		matrix _zz=r(Stat`i')

	}

	if `"`names'"'==`" "' {

	}
	
	matrix colnames _z = `names'
	matrix rownames _z = "Quantatmean"
	disp "Quantile at mean"
	matrix list _z

	/* the sample used */
	tempname one
	gen `one'= `touse'
	ereturn post _z, esample(`one')

	/* arguments required by svy and mi */
	ereturn local cmd quantatmean
	ereturn local title "Quantile at mean"

	quiet count if `touse'
	ereturn local N r(N)

	capture matrix drop _z 
	
end

