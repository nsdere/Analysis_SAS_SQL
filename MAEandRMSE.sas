/* proc datasets lib=work kill noprint; */
/* run; */

/* proc datasets lib=work nolist; */
/* delete TMP:; */
/* run; */

%let data_in = s1_s2_input_data;
%let emp_lgd = adj_Empirical_LGD_ever_sk;
%let model_lgd = adj_Model_lgd_ever;
%let group = model_new currency_new;
%let cap = 1;

/* %let zbior_in = s3_input_data; */
/* %let emp_lgd = Empirical_LGD_24M; */
/* %let model_lgd = Model_lgd_24M; */
/* %let grupa = model_new; */
/* %let cap = 1; */

proc sort data=&data_in. out=tmp_cut;
by &group.;
run;

data tmp_cut;
set tmp_cut;
if &cap.=1 then 
	do;
		&emp_lgd. = max(min(&emp_lgd.,1),0);
		&model_lgd. = max(min(&model_lgd.,1),0);	
	end;

run;

/***HISTOGRAM***/

ods html5 path="..." (url=none)
body="Histogram.html" style=htmlblue;
goptions reset=all;
                                                                    
legend1 position=(bottom left )                                                                                                    
        label=none                                                                                                                      
        mode=share; 
legend2 position=(bottom right )                                                                                                    
        label=none                                                                                                                      
        mode=share; 

ods html5;

title "Histogram of observed and modeled LGD ";

proc sgplot data=tmp_cut;
  label &emp_lgd.="Observed LGD" &model_lgd.="Model LGD";
   histogram &emp_lgd. / fillattrs=graphdata2 transparency=0.5  BINWIDTH=0.05;
    histogram &model_lgd. / fillattrs=graphdata1 transparency=0.7  BINWIDTH=0.05;
     keylegend / location=inside position=topright noborder across=1;
   yaxis grid;
   xaxis display=(nolabel);
   by &group.;
run;
ods html5 close;

/***Calculation of MAE and RMSE***/
/**************************************************************************/

ods output SpearmanCorr = SpearmanOut;
title "Spearman correlation";
proc corr data=tmp_cut spearman;
	var &emp_lgd. &model_lgd.;
	by &group.;
run;

proc sql;
create table cor as
	select 
		&emp_lgd. as corr,
		* 
	from SpearmanOut
	where Variable="&model_lgd.";
quit;

%macro variables_1(variables, sep=%str( ));

proc sql noprint;
create table errors_gr as
    select 
    	%let StartNN=1;
		%let var=%scan(&variables.,&StartNN,%quote(&sep));
		%do %while (&var. ^= );
			&var.,
	        %let StartNN= %eval(&StartNN. + 1);
	        %let var=%scan(&variables.,&StartNN,%quote(&sep));
		%end;
		 count(*) as count, 
		 mean(abs(&emp_lgd.-&model_lgd.)) as mae,
		 sqrt(mean((&emp_lgd.-&model_lgd.)**2)) as rmse 
from tmp_cut
group by
		%let StartNN=1;
		%let var=%scan(&variables.,&StartNN,%quote(&sep));
		%do %while (&var. ^= );
			%if &StartNN.=1 %then &var.;
			%else ,&var.;
	        %let StartNN= %eval(&StartNN. + 1);
        	%let var=%scan(&variables.,&StartNN,%quote(&sep));
		%end;
;quit;

proc sql;
create table errors_gr as
	select 
		b.corr, 
		a.* 
	from errors_gr as a 
		left join cor as b on
			%let StartNN=1;
			%let var=%scan(&variables.,&StartNN,%quote(&sep));
			%do %while (&var. ^= );
				%if &StartNN.=1 %then a.&var.=b.&var.;
				%else and a.&var.=b.&var.;
		        %let StartNN= %eval(&StartNN. + 1);
		        %let var=%scan(&variables.,&StartNN,%quote(&sep));
			%end;

;quit;

%mend;

%variables_1 (&group.);


/***Calculation of MAE and RMSE for benchmark model - simple average***/

proc means
          data = tmp_cut
          noprint
          mean;
          var &emp_lgd.;
          by &group.;
          output
          out =backtest_cap (drop = _TYPE_ _FREQ_)    
          mean = lgd_emp_cap_mean;
run;

%macro variables_2(variables, sep=%str( ));

proc sql;
create table tmp_cut_2 as
	SELECT 
		b.lgd_emp_cap_mean, 
		a.*
	FROM tmp_cut a
	LEFT JOIN backtest_cap b on
		%let StartNN=1;
		%let var=%scan(&variables.,&StartNN,%quote(&sep));
		%do %while (&var. ^= );
		%if &StartNN.=1 %then a.&var.=b.&var.;
		%else and a.&var.=b.&var.;
        %let StartNN= %eval(&StartNN. + 1);
        %let var=%scan(&variables.,&StartNN,%quote(&sep));
	%end;

;quit;

%mend;

%variables_2 (&group.);


%macro variables_3(variables, sep=%str( ));

proc sql noprint;
create table errors_sr as
    select 
	    	%let StartNN=1;
			%let var=%scan(&variables.,&StartNN,%quote(&sep));
			%do %while (&var. ^= );
			&var.,
	        %let StartNN= %eval(&StartNN. + 1);
	        %let var=%scan(&variables.,&StartNN,%quote(&sep));
		%end;
 		count(*) as count, 
		mean(abs(&emp_lgd.-lgd_emp_cap_mean))  as mae,
		sqrt(mean((&emp_lgd.-lgd_emp_cap_mean)**2)) as rmse 
	from tmp_cut_2
	group by
		%let StartNN=1;
		%let var=%scan(&variables.,&StartNN,%quote(&sep));
		%do %while (&var. ^= );
			%if &StartNN.=1 %then &var.;
			%else ,&var.;
	         %let StartNN= %eval(&StartNN. + 1);
	         %let var=%scan(&variables.,&StartNN,%quote(&sep));
		%end;
;quit;

proc sql;
create table errors_all as
	select 
		a.*, 
		b.mae as mae_benchmark, 
		b.rmse as rmse_benchmark 
	from errors_gr as a 
		left join errors_sr as b on
			%let StartNN=1;
			%let var=%scan(&variables.,&StartNN,%quote(&sep));
			%do %while (&var. ^= );
				%if &StartNN.=1 %then a.&var.=b.&var.;
				%else and a.&var.=b.&var.;
		        %let StartNN= %eval(&StartNN. + 1);
		        %let var=%scan(&variables.,&StartNN,%quote(&sep));
			%end;

;quit;

%mend;

options mprint;
%variables_3 (&group.);
