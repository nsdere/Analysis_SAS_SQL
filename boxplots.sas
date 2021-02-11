/* %let zbior_in = s1_s2_input_data; */
/* %let emp_LGD = adj_Empirical_LGD_ever_sk; */
/* %let model_LGD = adj_Model_lgd_ever; */
/* %let grupa = model_new currency_new; */
/* %let cap = 1; */

%let data_in = s3_input_data;
%let emp_LGD = Empirical_LGD_24M;
%let model_LGD = Model_lgd_24M;
%let group = model_new currency_new;
%let cap = 1;
%let exposure_id = Exposure_ID;
%let date_id = Reporting_date;


proc sort data =&data_in. out =backtest_1;
by &group. &exposure_id. &date_in.;
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
	by &group.;
	var &model_LGD.;
  output out=p_group pctlpre=P pctlpts= 25, 50, 75 ;
run;

%macro variables_1(variables, sep=%str( ));

proc sql;
create table backtest_2 as
select 
		%let StartNN=1;
		%let var=%scan(&variables.,&StartNN,%quote(&sep));
		%do %while (&var. ^= );
		a.&var.,
         %let StartNN= %eval(&StartNN. + 1);
         %let var=%scan(&variables.,&StartNN,%quote(&sep));
	%end;
		a.&exposure_id., a.&date_in., a.&emp_LGD., a.&model_LGD., c.p25, c.p50, c.p75,
		case when &model_LGD. <= c.p25 then 1
		when &model_LGD. <= c.p50 then 2
		when &model_LGD. <= c.p75 then 3
		else 4 end as Quartil_model_LGD_group
		
		
		
from backtest_1 a
left join p_group c on 
		%let StartNN=1;
		%let var=%scan(&variables.,&StartNN,%quote(&sep));
		%do %while (&var. ^= );
		%if &StartNN.=1 %then a.&var.=c.&var.;
		%else and a.&var.=c.&var.;
        %let StartNN= %eval(&StartNN. + 1);
        %let var=%scan(&variables.,&StartNN,%quote(&sep));
%end;
;quit;

%mend;

%variables_1 (&group.);

proc sort data =backtest_2;
by &group. Quartil_model_LGD_group;
run;

ods graphics on;
ods html5 path="..." (url=none)
body="boxplots.html";

title "Model LGD/Quartile LGD ";
proc boxplot data = backtest_2 ;
by &group.;
label &emp_LGD.="Empirical LGD" Quartil_model_LGD_group="Quartile of Model LGD";
	plot &emp_LGD.*Quartil_model_LGD_group;
run;

ods html5 close;
