/*	We need to make a sample for US listed firms with fiscal years 1962-1990

	From Compustat Funda we need:
	- gvkey		Firm identifier
	- datadate 	End of fiscal year
	- fyear		Fiscal year
	- epspx		EPS before extraordinary items
	- prcc_f 	Price at fiscal year end
	- csho 		Common shares outstanding end of year (to compute market cap)

	We also need lagged prcc_f (price at the end of the previous fiscal year)

	We also need to compute return over the fiscal year, so we need to match
	Compustat with CRSP and get monthly return (the return window starts the 
	4th month after fiscal year end)

	Since Compustat and CRSP are different data vendors, the matching is not straightforward
	(each vendor uses its own firm identifier; Compustat uses gvkey and CRSP uses permno)
	We use a linktable "ccmxpf_lnkhist" for which we lookup the permno given a gvkey and date.
*/

/* this piece of code makes a connection of your SAS instance with WRDS remote server */
%let wrds = wrds-cloud.wharton.upenn.edu 4016;options comamid = TCP remote=WRDS;
signon username=_prompt_;

rsubmit;

	/* Compustat */
	proc sql;
		create table myCompustat as
		select gvkey, datadate, fyear, epspx, prcc_f, 
			/*	Size measured as market cap (=#shares x price per share) */
			csho * prcc_f as size,
			/* 	Some shorthand to create a dummy, if the expression in parentheses is true it evaluates to 1
				otherwise 0, so loss will be 1 for loss-years only */
			(epspx < 0) as loss,
			/* 	The intnx function takes a date variable to construct another date variable;
			  	in this case, we want to go 11 months forward, and go the the first day of that month 
			  	(beginning of year)
			  	In SAS, dates are stored as numbers in memory, can be displayed human-friendly with a format
				We apply a date format to variable boy. (without the format=date9. it would print as a number)
				*/
			intnx('month', datadate, -8, 'B') as boy format=date9. ,
			intnx('month', datadate, +3, 'E') as eoy format=date9. ,
			/*	A variable to uniquely identify each firm-year will come in handy, the || glues variables 
				e.g. if gkvey is 00100 and fyear is 2010 then key is "00100_2010"
				put transforms a number into a string (glueing requires strings, not numbers), z4. is string length 4
				*/
			gvkey || "_" ||  put(fyear, z4.) as key
		from
			comp.funda 
		where
		/*	Relevant year range (1 year before 1962, because we need lagged eps and price) */
			1961 <= fyear <= 1990
		/* 	Require that epspx, prcc_f and csho are non-missing (missing in sum formula makes result missing)  */
		and missing(epspx + prcc_f + csho) eq 0
		/*	Boilerplate filters */
		and indfmt='INDL' and datafmt='STD' and popsrc='D' and consol='C'; 
	quit;

	/*	Sort (needed for next step) */
	proc sort data= myCompustat; by gvkey fyear; run;

	/*	Lagged eps and stock price, using the 'lag' function; ifn is 'if numeric' function:
		IFN (condition, value if true, value if false, value if missing)	*/
	data myCompustat;  
	set myCompustat;
	  by gvkey fyear;
	  /* If previous year is same firm (same gvkey) and this year is 1 year later, then take lag
	  	 otherwise, set it to missing (a period) */
	  epspx_lag  = ifn(gvkey=lag(gvkey) and fyear=lag(fyear)+1, lag(epspx), .);  
	  prcc_f_lag = ifn(gvkey=lag(gvkey) and fyear=lag(fyear)+1, lag(prcc_f), .);
	run; 

	/*	Print */
	proc print data=myCompustat (obs=10); run;

	/*	Download to local work library */	
	proc download data=myCompustat out=a_comp;run;
endrsubmit;

rsubmit;
	/*	Get permno using the CCM merge lookup table
		This is very boilerplate-like, the relevant thing is that this match gives
		the correct permno at date 'boy' (in this case) for a given gvkey */		
	proc sql; 
	  	create table myCompPermno as 
	  	select a.* , b.lpermno as permno
	  	from myCompustat a
	  	left join
			crsp.ccmxpf_lnkhist b
	  	on a.gvkey = b.gvkey
	  	and b.linktype in ("LC" "LN" "LU" "LX" "LD" "LS")
	  	and b.linkprim in ("C", "P")	  
	  	and ((a.boy >= b.LINKDT) or b.LINKDT = .B) and
	    	((a.boy <= b.LINKENDDT) or b.LINKENDDT = .E);
	quit;

	proc print data=myCompPermno (obs=30); run;

	/* 	Get stock return */
	proc sql;
	  create table getr_2 (keep = key permno boy eoy date ret) as
	  select a.*, b.date, b.ret
	  from   myCompPermno a, crsp.msf b
	  where a.boy <= b.date <= a.eoy
	  and a.permno = b.permno
	  and missing(b.ret) ne 1;
	quit;

	proc print data=getr_2 (obs=30); run;

	/* 	Compute compound return  -- yes, the exp(sum(log(1+ret))) is very compact! 
		Thanks to Lin, one of our graduated finance PhD students! */
	proc sql;
		create table getr_3 as 
		select key, exp(sum(log(1+ret)))-1 as ret
		from getr_2 
		/* this is where key is helpful */
		group by key;
	quit;

	proc print data=getr_3 (obs=30); run;

	/*	Append return to our dataset with Compustat variables (using 'key' again) */
	proc sql; create table sample as select a.*, b.ret from myCompPermno a left join getr_3 b on a.key = b.key;
	quit;

	/*	Download to local work library */	
	proc download data=sample out=b_sample;run;

endrsubmit;

