/*	For each size decile: compute #firm-years and #losses */

/*	Create size deciles */
proc rank data = b_sample out = e_ranked groups = 10;
var size; 		
ranks size_d ; 
run;

/*	Add 1 to rank (0-9 => 1-10) */
data e_ranked;
set e_ranked;
size_d = size_d + 1;
run;

proc sort data=e_ranked; by size_d; run;

/*	Format for deciles */
proc format;
value mySizeFormat
/* If 10 or higher */
1 = '1 (smallest firms)'
10 = '10 (largest firms)'
/* Other values */
other = [best.];
run;

proc means data=e_ranked noprint;
 	output out=f_table3 mean= sum= /autoname;
  	var loss;
  	format size_d mySizeFormat.;
  	by size_d;
run;
