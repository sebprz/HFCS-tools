capture program drop meanmedian

program define meanmedian, eclass properties(svyb mi)

/*******************************************************

meanmedian - calculate meanmedian index

This Stata command estimates the ratio of the mean to the median,
and can be combined with the svy and mi commands, only 
with replicate weights.

Syntax: meanmedian varname [weight] [if] [in] [, over(varname) ] 

In order to combine with mi and svy, only one variable can 
be given in varlist.


ECB - v 0.1 2016/12/14 - Sébastien Perez-Duarte


Changelog

v 0.1 initial version

*******************************************************/

    syntax varname [aweight iweight pweight] [if] [in] [, over(varname)] 
    
    marksample touse, novarlist zeroweight
	
	tempvar one
	
	gen `one'=1

    * iweight cannot be used with qreg
    if "`weight'"=="" { 
		local exp=`one'
	}

	local weight="aweight" 
		
	/* calculate the statistic of interest with tabstat */
	quietly tabstat `varlist' [`weight'`exp'] if `touse', s(mean median)  by(`over') save

	matrix _zz=r(Stat1)
	
	matrix _rr=_zz[1,1]/_zz[2,1]
	
	capture matrix drop _z

	/* construct the e(b) output and assign the correct colnames */
	local i=1
	local names
	while _zz[1,1] ~= . {
		if "`i'"=="1" matrix _z=_rr
		else matrix _z=_z,_rr
		
		/* replace spaces in the labels by underscores */
		local tempname `r(name`i')'

		if `"`tempname'"'==`""' {
			local tempname="`varlist'"
		}
		local tempname : subinstr local tempname " " "_", all

		local names=`"`names' "`tempname'""'

		local ++i
		matrix _zz=r(Stat`i')
		matrix _rr=_zz[1,1]/_zz[2,1]

	}

	matrix _zz=r(StatTotal)
	matrix _rr=_zz[1,1]/_zz[2,1]
	if "`i'"=="1" matrix _z=_rr
	else matrix _z=_z,_rr
	local names=`"`names' "Total""'

	if `"`names'"'==`" "' {

	}
		
	
	matrix colnames _z = `names'
	matrix rownames _z = "Mean-median ratio"
	disp "Mean-median ratio"
	matrix list _z

	/* the sample used */
	tempname one
	gen `one'= `touse'
	ereturn post _z, esample(`one')

	/* arguments required by svy and mi */
	ereturn local cmd meanmedian
	ereturn local title "Mean-median ratio"

	quiet count if `touse'
	ereturn local N r(N)

	capture matrix drop _z 
	capture matrix drop _zz
	capture matrix drop _rr
	
end

