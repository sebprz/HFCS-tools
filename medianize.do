capture program drop medianize

program define medianize, eclass properties(svyb mi)
/*******************************************************

MEDIANIZE - calculate a median

This Stata command estimates the median and can be combined 
with the svy and mi commands, only with replicate weights.

Syntax: syntax varlist [weight] [if] [in] [, over(varname) Statistic(string)] 

In order to combine with mi and svy, only one variable can 
be given in varlist.

Statistic is any statistic accepter by tabstat.


ECB - v 0.5 2016/10/21 - Sébastien Perez-Duarte



Changelog

v 0.5 Added the novarlist option to marksample

v 0.4 Fixed a bug in the colnames. Spaces in the labels of varname
                  will get replaced by underscores. 

*******************************************************/

    syntax varlist [aweight iweight pweight] [if] [in] [,over(varname) Statistic(string)] 
    
    marksample touse, novarlist zeroweight
	
    * iweight cannot be used with qreg
    if "`weight'"!="" local weight="aweight" 
	
	* statistic by default - the median
    if "`statistic'"=="" local statistic="p50"
	
	/* calculate the statistic of interest with tabstat */
	tabstat `varlist' [`weight'`exp'] if `touse', s(`statistic')  by(`over') save

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
	
	matrix colnames _z = `names'
	
	*matrix list _z
	*disp `" `names' "' 
	/* the sample used */
	tempvar one
	gen `one'= `touse'
	ereturn post _z, esample(`one')

	/* arguments required by svy and mi */
	ereturn local cmd medianize
	ereturn local title "Medianize `statistic'"

	quiet count if `touse'
	ereturn local N r(N)

	capture matrix drop _z _zz
end

