/*	Regressions */

/*	Some variables need to be created */
data g_sample;
set b_sample;
/* earnings per share scaled by beginning of year stock price */
e_p = epspx / prcc_f_lag;
/* change in eps scaled by boy stock price */
ch_e_p = (epspx - epspx_lag) / prcc_f_lag;
/* keep observations with no missings */
if missing(e_p + ch_e_p + ret) eq 0;
run;


/* 	Let's inspect the data: descriptive statistics */
proc means data=g_sample mean median min max N;
  var e_p ch_e_p ret;  
run;


/*	Winsorize outliers ('dampens' first and last percentile) */

/*	Import winsorize macro */
filename m1 url 'https://gist.githubusercontent.com/JoostImpink/497d4852c49d26f164f5/raw/11efba42a13f24f67b5f037e884f4960560a2166/winsorize.sas';
%include m1;

/*	Invoke winsorize */
%winsor(dsetin=g_sample, byvar=fyear, dsetout=g_sample_wins, vars=e_p ch_e_p ret, type=winsor, pctl=1 99);

/*	Take another look at descriptive statistics */
proc means data=g_sample_wins mean median min max N;
  var e_p ch_e_p ret;  
run;

/*	Regressions */
/*	Pooled, levels */
proc reg data= g_sample_wins;		
	model ret = e_p ;
	ods output	ParameterEstimates  = regout_1a
	            FitStatistics 		= regout_1b;
quit;

/*	Pooled, changes */
proc reg data= g_sample_wins;		
	model ret = ch_e_p;
	ods output	ParameterEstimates  = regout_2a
	            FitStatistics 		= regout_2b;
quit;

/*	Pooled, levels, loss years only */
proc reg data= g_sample_wins (where= (loss eq 1));		
	model ret = e_p;
	ods output	ParameterEstimates  = regout_3a
	            FitStatistics 		= regout_3b;
quit;


/*	Assignment: replicate panel 4b 

	Panel 4b uses firm-specific regressions, in Hayn's sample there are 4,148 firms, so there are 4,148 regressions
	The median coefficients and R-squared are reported

	To repeat a regression for each firm, add 'by gvkey' to the proc reg (and do a proc sort 'by gvkey' to get the data sorted) 

	Then, the results need to be merged back to the dataset, in order to show the median coefficient for different #loss years 
	(i.e. median coefficient/R-squared for firms with no losses, same for 1 loss, etc). Repeat for changes, levels
*/


proc sort data=g_sample_wins; by gvkey;run;
  
proc reg data= g_sample_wins;		
model ret = e_p ;
ods output ParameterEstimates = regout_1a FitStatistics = regout_1b;
/* adding by gvkey will result in separate regressions for each firm */
by gvkey;
quit;
