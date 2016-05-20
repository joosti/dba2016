/* 	Table 2
	Use firms that have at least 8 years of data
	Count the number of loss-years
*/
/* 	For each gvkey, count the #loss-years */
proc sql;
	create table d_table2_a as
	select gvkey, sum(loss) as lossYears from b_sample	
	/* gvkey must be in the following table */
	where gvkey IN (
			/* get gvkey from a table */
			select gvkey from (
					/* cook the table on the spot */
					/* count the number of years for each gvkey */
					select gvkey, count(*) as numYears 
					from b_sample 					
					group by gvkey 
					/* only if numyears is 8 or more, keep in result */
					having numYears >= 8
			)
		)
	group by gvkey;
quit;

proc format;
value myCountFormat
/* If 10 or higher */
10-100 = '10 or more'
/* Other values */
other = [best.];
run;

/* Using proc freq  */
proc freq data=d_table2_a;
	tables lossYears  / out=d_table2_b;
  /* Apply the format */
  format lossYears myCountFormat.;
run;
