/*  Example of how to use SAS to retrieve data from WRDS
    Computing market-to-book ratio for years 2000-, and benchmark it against
    other firms in the industry */
    
/* this piece of code makes a connection of your SAS instance with WRDS remote server */
%let wrds = wrds-cloud.wharton.upenn.edu 4016;options comamid = TCP remote=WRDS;
signon username=_prompt_;

/* any code executed on WRDS needs to go in a remote submit block, for example: */

rsubmit;
%put Hi there! ;
endrsubmit;

/* Let's get the MTB data for Google, notice how we compute it straight in the query */
rsubmit;
proc sql;
	/* create a table and name it 'myData' */
	create table myData as
		/* which variables to select: company name, fiscal year and compute market to book */
		select conm, fyear, (csho * prcc_f / ceq) as mtb
		/* where to get it from: compustat fundamental annual */
		from comp.funda
		/* filter: just get Google */
		where TIC eq "GOOGL"
		/* this is some boilerplate filtering (gets rid of doubles) */
		and indfmt='INDL' and datafmt='STD' and popsrc='D' and consol='C';

quit;
proc print;run;
endrsubmit;


/* How about a benchmark: median firm in the industry (SIC: 7370) 
	7370: SERVICES-COMPUTER PROGRAMMING, DATA PROCESSING, ETC., see https://www.sec.gov/info/edgar/siccodes.htm */
rsubmit;
proc sql;
	/* create a table and name it 'myData2' */
	create table myData2 as
		/* which variables to select: fiscal year and compute market to book */
		select fyear, count(*) as numFirms, median(mtb) as median_mtb
		/* where to get it from: compustat fundamental annual */
		from (
			select fyear, (csho * prcc_f / ceq) as mtb from comp.funda
			/* filter: get all firms in industry 7370 after 2000 */
			where SICH eq 7370 and fyear > 2000
			/* this is some boilerplate filtering (gets rid of doubles) */
			and indfmt='INDL' and datafmt='STD' and popsrc='D' and consol='C'
			)
		/* compute it for each year => GROUP BY */
		group by fyear;

quit;
proc print;run;
endrsubmit;

/* lets combine the two tables (match on year) */
rsubmit;
proc sql;
	create table myData3 as 
	/* from table a (myData) get fyear and mtb (rename as mtb_google) */
	select a.fyear, a.mtb as mtb_google, 
	/* from table b (myData2) get everything ('*') */
	b.* 
	from myData a, myData2 b 
	/* join on fiscal year (we want to match Google's mtb to the industry median for each year)*/
	where a.fyear = b.fyear;
quit;
proc print;run;
endrsubmit;
