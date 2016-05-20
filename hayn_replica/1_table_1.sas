/* 	Table 1
	Left panel shows by year the #obs, and the #loss years
	Right panel shows the same, but for firms that were in the sample from 1968 
	through 1990 (23 years)
*/

/*	Left panel */

/* 	Using SQL */
proc sql;
	create table c_table1_a_1 as
	select fyear, count(*) as numObs, sum(loss) as numLossFirms, 
	/* 'calculated' refers to a variable constructed in the query (as opposed to a variable on the dataset) */
	calculated numLossFirms / calculated numObs as percLoss
	from b_sample group by fyear;
quit;

proc print;run;

/* Using proc means */
proc sort data=b_sample; by fyear; run;
proc means data=b_sample noprint;
 	output out=c_table1_a_2 n= mean= sum= /autoname;
  var loss;
  by fyear;
run;

/* Using proc freq (needs further processing, from 'long' to 'wide' format) */
proc freq data=b_sample;
	tables loss * fyear / out=c_table1_a_3;
	by fyear;
run;

/*	How to group years 1962-1967 without changing any of the data (just the presentation) */

/*	Define a format */
proc format;
value myYearFormat
/* For any values between 1962 and 1967 */
1962-1967 = '1962-1967'
/* Other values */
other = [best.];
run;

/*	Repeat the proc means with the format applied to fyear */
proc means data=b_sample noprint;
 	output out=c_table1_a_4 n= mean= sum= /autoname;
  var loss;
  /* Apply the format */
  format fyear myYearFormat.;
  by fyear;
run;


/*	Right panel */

/*	We need the subsample of firms that have 23 years of data over 1968-1990 */
proc sql;
	create table c_table1_b1 as 
		select gvkey, count(*) as numYears 
		from b_sample 
		where 1968 <= fyear <= 1990 
		group by gvkey 
		having numYears eq 23;
quit;

/* 	Using SQL */
proc sql;
	create table c_table1_b2 as
	select fyear, count(*) as numObs, sum(loss) as numLossFirms, 
	/* 'calculated' refers to a variable constructed in the query (as opposed to a variable on the dataset) */
	calculated numLossFirms / calculated numObs as percLoss
	from b_sample
	where 1968 <= fyear <= 1990 
	and gvkey IN (select gvkey from c_table1_b1)
	group by fyear;
quit;
