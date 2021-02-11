%let emp_lgd = adj_Empirical_LGD_ever_sk;
%let model_lgd = adj_Model_lgd_ever;
%let data_in = s1_s2_input_data;
%let group = model_new currency_new;
%let exposure_id = Exposure_ID;


proc sort data = &data_in.;
by &group.;
run;

data backtest_1;
set &data_in.;
if &cap.=1 then 
	do;
		&emp_lgd. = max(min(&emp_lgd.,1),0);
		&model_lgd. = max(min(&model_lgd.,1),0);	
	end;

run;

proc univariate data=backtest_1 noprint;
  var &model_lgd.;
  by &group.;
  output out=percentyle_all pctlpre=P_all pctlpts= 10 to 90 by 10;
run;

%macro variables(variables, sep=%str( ));

proc sql;
create table zzz as
select 		
	%let StartNN=1;
	%let var=%scan(&variables.,&StartNN,%quote(&sep));
	%do %while (&var. ^= );
		 t.&var.,
         %let StartNN= %eval(&StartNN. + 1);
         %let var=%scan(&variables.,&StartNN,%quote(&sep));
	%end;
 	&exposure_id.,
	case when &emp_lgd. <= p.p_all10 then 1
		when &emp_lgd. <= p.p_all20 then 2
		when &emp_lgd. <= p.p_all30 then 3
		when &emp_lgd. <= p.p_all40 then 4
		when &emp_lgd. <= p.p_all50 then 5
		when &emp_lgd. <= p.p_all60 then 6
		when &emp_lgd. <= p.p_all70 then 7
		when &emp_lgd. <= p.p_all80 then 8
		when &emp_lgd. <= p.p_all90 then 9
		else 10 end as empi_group_all,

	case when &model_lgd. <= p.p_all10 then 1
		when &model_lgd. <= p.p_all20 then 2
		when &model_lgd. <= p.p_all30 then 3
		when &model_lgd. <= p.p_all40 then 4
		when &model_lgd. <= p.p_all50 then 5
		when &model_lgd. <= p.p_all60 then 6
		when &model_lgd. <= p.p_all70 then 7
		when &model_lgd. <= p.p_all80 then 8
		when &model_lgd. <= p.p_all90 then 9
		else 10 end as model_group_all,

	&model_lgd., &emp_lgd., p.*
	from backtest_1 t
		left join percentyle_all p on

		%let StartNN=1;
		%let var=%scan(&variables.,&StartNN,%quote(&sep));
		%do %while (&var. ^= );
			%if &StartNN.=1 %then t.&var.=p.&var.;
			 %else and t.&var.=p.&var.;
	         %let StartNN= %eval(&StartNN. + 1);
	         %let var=%scan(&variables.,&StartNN,%quote(&sep));
		%end;

	;quit;

%mend;

/* options mprint; */
%variables (&group.);

/*macierz*/
%macro matrices (zb);

title " Confusion matrix ";
proc tabulate data= &zb. out = cm;
by &group.;
	class empi_group_all model_group_all;
	table empi_group_all, model_group_all*N;
	run;

%mend;
%matrices(zzz);



%macro car(variables, sep=%str( ));

title " CAR coefficient ";
proc sql;
select 
	%let StartNN=1;
	%let var=%scan(&variables.,&StartNN,%quote(&sep));
	%do %while (&var. ^= );
		&var.,
	    %let StartNN= %eval(&StartNN. + 1);
	    %let var=%scan(&variables.,&StartNN,%quote(&sep));
	%end;
	sum(N) as denominator,
	sum(case when empi_group_all = model_group_all or
				empi_group_all = model_group_all + 1 or
				empi_group_all = model_group_all - 1 
			then N else 0 end) as nominator,
	calculated nominator / calculated denominator as CAR
from cm
group by 
		%let StartNN=1;
		%let var=%scan(&variables.,&StartNN,%quote(&sep));
		%do %while (&var. ^= );
			%if &StartNN.=1 %then &var.;
			%else ,&var.;
	        %let StartNN= %eval(&StartNN. + 1);
	        %let var=%scan(&variables.,&StartNN,%quote(&sep));
		%end;


%mend;
%car(&group.);

ods graphics on;
ods html5 path="..." (url=none)
body="confusion_matrix.html";
%macierze(zzz);
ods html5 close;

ods graphics on;
ods html5 path="..." (url=none)
body="CAR coefficient.html";
%car (&group.);
ods html5 close;



