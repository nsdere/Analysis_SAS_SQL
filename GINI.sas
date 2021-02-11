
%let emp_LGD = adj_Empirical_LGD_ever_sk;
%let model_LGD = adj_Model_lgd_ever;
%let data_in = s1_s2_input_data;
%let group = model_new;
%let cap = 1;
%let exposure_id = Exposure_ID;
%let date_id = Reporting_date;

/* %let emp_LGD = Empirical_LGD_24M; */
/* %let model_LGD = Model_lgd_24M; */
/* %let zbior_in = s3_input_data; */
/* %let grupa = model_new currency_new; */
/* %let cap = 1; */


proc sort data =&data_in. out =backtest_1;
by &group. &exposure_id. &date_id.;
run;

data backtest_1;
set backtest_1;
if &cap.=1 then 
	do;
		&emp_lgd. = max(min(&emp_lgd.,1),0);
		&model_lgd. = max(min(&model_lgd.,1),0);	
	end;

run;

proc univariate data=backtest_1 noprint;
  var &emp_LGD;
  output out=percentiles_0 pctlpre=P pctlpts= 5 to 25 by 5, 50, 75 to 95 by 5;
  by &group. 
;run;


%macro variables(variables, sep=%str( ));

proc sql;
create table input_data as
select median(&emp_LGD.) as emp_median, 
	case when &emp_LGD. < p.p5 then 0 else 1 end as BAD_p05,
	case when &emp_LGD. < p.p10 then 0 else 1 end as BAD_p10,
	case when &emp_LGD. < p.p15 then 0 else 1 end as BAD_p15,
	case when &emp_LGD. < p.p20 then 0 else 1 end as BAD_p20,					
	case when &emp_LGD. < p.p25 then 0 else 1 end as BAD_p25,
	case when &emp_LGD. < p.p50 then 0 else 1 end as BAD_p50,
	case when &emp_LGD. < p.p75 then 0 else 1 end as BAD_p75,
	case when &emp_LGD. < p.p80 then 0 else 1 end as BAD_p80,
	case when &emp_LGD. < p.p85 then 0 else 1 end as BAD_p85,
	case when &emp_LGD. < p.p90 then 0 else 1 end as BAD_p90,
	case when &emp_LGD. < p.p95 then 0 else 1 end as BAD_p95,
	*
from &data_in. a
left join percentiles_0 p
on 
		%let StartNN=1;
		%let var=%scan(&variables.,&StartNN,%quote(&sep));
		%do %while (&var. ^= );
			%if &StartNN.=1 %then a.&var.=p.&var.;
			%else and a.&var.=p.&var.;
	        %let StartNN= %eval(&StartNN. + 1);
	        %let var=%scan(&variables.,&StartNN,%quote(&sep));
		%end;

	;quit;

%mend;

options mprint;
%variables (&group.);


%macro gini(var,BAD);
PROC FREQ DATA = input_data NOPRINT;
  by &group.;
 	TABLE &BAD * &var / NOPRINT MEASURES ;
OUTPUT SMDCR OUT = statistics;
RUN;

/* DATA STATYSTYKI; */
/* 	SET FRQOUTBY; */
/* 	RUN; */

DATA GINI_&BAD;
	SET statistics;
	GINI = ABS(_SMDCR_);
	BAD ="&BAD";
	KEEP &group. GINI BAD;
RUN;
%mend;
%gini(&model_LGD., BAD_p05);
%gini(&model_LGD., BAD_p10);
%gini(&model_LGD., BAD_p15);
%gini(&model_LGD., BAD_p20);
%gini(&model_LGD., BAD_p25);
%gini(&model_LGD., BAD_p50);
%gini(&model_LGD., BAD_p75);
%gini(&model_LGD., BAD_p80);
%gini(&model_LGD., BAD_p85);
%gini(&model_LGD., BAD_p90);
%gini(&model_LGD., BAD_p95);


DATA GINI_All;
	SET Gini_BAD_p05 Gini_BAD_p10 Gini_BAD_p15 Gini_BAD_p20 Gini_BAD_p25 Gini_BAD_p50 Gini_BAD_p75 Gini_BAD_p80 Gini_BAD_p85 Gini_BAD_p90 Gini_BAD_p95;
	RUN;

proc sql;
DROP TABLE Backtest_1;
DROP TABLE GINI_BAD_P05;
DROP TABLE GINI_BAD_P10;
DROP TABLE GINI_BAD_P15;
DROP TABLE GINI_BAD_P20;
DROP TABLE GINI_BAD_P25;
DROP TABLE GINI_BAD_P50;
DROP TABLE GINI_BAD_P75;
DROP TABLE GINI_BAD_P80;
DROP TABLE GINI_BAD_P85;
DROP TABLE GINI_BAD_P90;
DROP TABLE GINI_BAD_P95;
DROP TABLE INPUT_DATA;
DROP TABLE statistics;
quit;




