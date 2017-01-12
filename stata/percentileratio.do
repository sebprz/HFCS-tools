capture program drop percentileratio

program define percentileratio, eclass properties(svyb mi)

/*******************************************************

PERCENTILERATIO - calculate a percentile ratio

This Stata command estimates the percentile ratios of the form pYY/pXX,
where YY>XX, and can be combined with the svy and mi commands, only 
with replicate weights.

Syntax: syntax varlist [weight] [if] [in] [, PERCentiles(string) INVerse] 

In order to combine with mi and svy, only one variable can 
be given in varlist.

* percentiles is a list of increasing percentiles, by default 20 80.
* inverse : to calculate pXX/pYY with YY>XX rather than the inverse


ECB - v 0.1 2016/11/16 - Sébastien Perez-Duarte


Changelog

v 0.1 initial version

*******************************************************/

    syntax varlist [aweight iweight pweight] [if] [in] [, PERCentiles(string) INVerse] 
    
    marksample touse, novarlist zeroweight
	
    * iweight cannot be used with qreg
    if "`weight'"!="" local weight="aweight" 
	
	* statistic by default - the median
    if "`percentiles'"=="" local percentiles="20 80"
	
	/* calculate the statistic of interest with tabstat */
	_pctile `varlist' [`weight'`exp'] if `touse', percentiles(`percentiles')
	
	if "`inverse'"=="inverse" {
		matrix _z=r(r1)/r(r2)	
	} 
	else {
		matrix _z=r(r2)/r(r1)	
	}
	
	/**** FIXME: add here the thing to add the colnames, as it is done in medianize ***/
	local perctmp1 : word 1 of `percentiles'
	local perctmp2 : word 2 of `percentiles'

	if "`inverse'"=="inverse" {
		local perctmp = "p`perctmp1'/p`perctmp2'"
	}
	else {
		local perctmp = "p`perctmp2'/p`perctmp1'"
	}
	
	matrix colnames _z = `perctmp'
		
	/* the sample used */
	tempname one
	gen `one'= `touse'
	ereturn post _z, esample(`one')

	/* arguments required by svy and mi */
	ereturn local cmd percentileratio
	ereturn local title "Percentileratio `statistic'"

	quiet count if `touse'
	ereturn local N r(N)

	capture matrix drop _z 
	
end

