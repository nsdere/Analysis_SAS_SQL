/* The loss capture curve */

%macro licz_lcc (dane_in, cap, emp_lgd, mod_lgd, grupa, sample, opis1, opis2);
data backtest11;
set &dane_in.;
run;


data backtest12;
set backtest11;
%if &cap.=1 %then %do;
empiryczny_lgd = max(min(&emp_lgd.,1),0);
model_lgd = max(min(&mod_lgd.,1),0);
%end;
%else %do;
empiryczny_lgd = &emp_lgd.;
model_lgd = &mod_lgd.;
%end;
run;

proc sql;
create table dane as
select *,
sum(empiryczny_lgd) as sum_empiryczny_lgd,
sum(model_lgd) as sum_model_lgd ,
empiryczny_lgd/sum(empiryczny_lgd) as empiryczny_lgd_frac,
max(0,empiryczny_lgd)/sum(max(0,empiryczny_lgd)) as empiryczny_lgd_frac_cap,
model_lgd/sum(model_lgd) as model_lgd_frac_sam,
model_lgd/sum(empiryczny_lgd) as model_lgd_frac,
model_lgd/sum(max(0,empiryczny_lgd)) as model_lgd_frac_cap,
count(*) as l_obs
from backtest12
group by &grupa., &sample.;
quit;

ods html;
ods html5 path="/home/agenda/Wyniki" (url=none)
body="LCC.html";

proc sql;
select &grupa.,&sample.,
sum(model_lgd_frac) as model_lgd_frac, sum(empiryczny_lgd_frac) as empiryczny_lgd_frac,
sum(model_lgd) as sum_model_lgd, sum(empiryczny_lgd) as sum_empiryczny_lgd
from dane
group by &grupa., &sample.;
quit;

proc sort data=dane;
by &grupa. &sample. descending empiryczny_lgd descending model_lgd;
run;

data dane1;
set dane;
by &grupa. &sample.;
if first.&sample. then do;
c_empiryczny_lgd_frac=empiryczny_lgd_frac;
ordered_population_emp=1/l_obs;
end;
else do;
c_empiryczny_lgd_frac+empiryczny_lgd_frac;
ordered_population_emp+1/l_obs;
end;
run;

proc sort data=dane1;
by &grupa. &sample. descending model_lgd descending empiryczny_lgd;
run;

data lcc;
set dane1;
by &grupa. &sample.;
if first.&sample. then do;
c_model_lgd_frac=empiryczny_lgd_frac;
ordered_population=1/l_obs;
end;
else do;
c_model_lgd_frac+empiryczny_lgd_frac;
ordered_population+1/l_obs;
end;
run;

proc sql;
create table do_wykresu as
select a.&grupa., a.&sample.,
a.c_empiryczny_lgd_frac,
a.ordered_population_emp as ordered_population,
b.c_model_lgd_frac,
a.empiryczny_lgd,
b.model_lgd,
sum(a.empiryczny_lgd) as sum_emp, 
sum(b.model_lgd) as sum_m
from lcc as a
left join lcc as b
on a.ordered_population_emp=b.ordered_population and a.&grupa.=b.&grupa. and a.&sample.=b.&sample.
group by a.&grupa., a.&sample.
order by a.&grupa., a.&sample., b.ordered_population;
quit;

proc sort data=do_wykresu nodupkey dupout=i;
by &grupa. &sample. ordered_population;
run;

/*ods html5*/
/*path="D:\Projects\Raiff LGD\NEW\Przetwarzanie\Kody SAS\JM\" (url=none)*/
/*body=&nazwa style=htmlblue;*/
title &opis1;
proc sql;
select &grupa., &sample., sum(abs(c_model_lgd_frac-ordered_population))/sum(abs(c_empiryczny_lgd_frac-ordered_population)) as Loss_Capture_Ratio,count(*) as Obs
from do_wykresu
group by &grupa., &sample.;
quit;

axis1 label=(j=c rotate=0 a=90 "Actual loss captured (%)"   );
axis2 label=("Ordered population (worst to best)" );
title &opis2;
proc gplot data=do_wykresu;
label &grupa.="Segment" &sample.="Sample"
c_empiryczny_lgd_frac="Ideal" c_model_lgd_frac="Model" ordered_population="Random";
format &grupa. &sample.;
by &grupa. &sample.; 
   plot 
c_empiryczny_lgd_frac*ordered_population
c_model_lgd_frac*ordered_population
ordered_population*ordered_population
/ overlay  legend=legend1   vaxis=axis1 haxis=axis2; 

symbol1 v=dot width=0.1 i=join h = 0.1 c=black;
symbol2 v=dot width=0.1 i=join h = 0.1 c=blue;
symbol3 v=dot width=0.1 i=join h = 0.1 c=green;
symbol4 v=dot width=0.1 i=join h = 0.1 c=red;
symbol5 v=dot width=0.1 i=join h = 0.1 c=violet;
 
run;                                                                                                                                    
quit;

ods html5 close;

%mend;

%licz_lcc(s1_s2_input_data,1, adj_Empirical_LGD_ever_sk, adj_Model_lgd_ever, 
model_new, currency_new, "Loss Capture Ratio","Loss Capture Curve");

/* %licz_lcc(s3_input_data,1, Empirical_LGD_24M, Model_LGD_24M,  */
/* model_new, currency_new, "Loss Capture Ratio","Loss Capture Curve"); */











/* The loss capture curve */

%macro licz_lcc_ead(dane_in, cap, emp_lgd, mod_lgd, grupa, sample, opis1, opis2, ead);

data backtest11;
set &dane_in.;
run;

data backtest12;
set backtest11;
%if &cap=1 %then %do;
empiryczny_lgd = max(min(&emp_lgd.,1),0);
model_lgd = max(min(&mod_lgd.,1),0);
%end;
%else %do;
empiryczny_lgd = &emp_lgd.;
model_lgd = &mod_lgd.;
%end;
run;

proc sql;
create table dane as
select *,
sum(empiryczny_lgd) as sum_empiryczny_lgd,
sum(model_lgd) as sum_lgd ,
empiryczny_lgd*&ead. as empiryczny_lgd_ead,
model_lgd*&ead. as model_lgd_ead,
empiryczny_lgd*&ead./sum(empiryczny_lgd*&ead.) as empiryczny_lgd_frac,
/*max(0,&emp_lgd.)/sum(max(0,empiryczny_lgd)) as empiryczny_lgd_frac_cap,*/
model_lgd/sum(model_lgd) as model_lgd_frac_sam,
model_lgd/sum(empiryczny_lgd) as model_lgd_frac,
model_lgd/sum(max(0,empiryczny_lgd)) as model_lgd_frac_cap,
count(*) as l_obs
from backtest11
group by &grupa., &sample.
;
quit;


ods html;
ods html5 path="/home/agenda/Wyniki" (url=none)
body="LCC_EAD.html";


proc sort data=dane;
by &grupa. &sample. descending empiryczny_lgd_ead descending model_lgd_ead;
run;

data dane1;
set dane;
by &grupa. &sample.;
if first.&sample. then do;
c_empiryczny_lgd_frac=empiryczny_lgd_frac;
ordered_population_emp=1/l_obs;
end;
else do;
c_empiryczny_lgd_frac+empiryczny_lgd_frac;
ordered_population_emp+1/l_obs;
end;
run;
proc sort data=dane1;
by &grupa. &sample. descending model_lgd_ead descending empiryczny_lgd_ead;
run;
data lcc;
set dane1;
by &grupa. &sample.;
if first.&sample. then do;
c_model_lgd_frac=empiryczny_lgd_frac;
ordered_population=1/l_obs;
end;
else do;
c_model_lgd_frac+empiryczny_lgd_frac;
ordered_population+1/l_obs;
end;
run;



/*  */
/* data dane1; */
/* set dane; */
/* by &grupa. &sample.; */
/* if first.&sample. then do; */
/* c_empiryczny_lgd_frac=empiryczny_lgd_frac; */
/* ordered_population_emp=1/l_obs; */
/* end; */
/* else do; */
/* c_empiryczny_lgd_frac+empiryczny_lgd_frac; */
/* ordered_population_emp+1/l_obs; */
/* end; */
/* run; */
/*  */
/* proc sort data=dane1; */
/* by &grupa. &sample. descending model_lgd_ead descending empiryczny_lgd_ead; */
/* run; */
/*  */
/* data lcc; */
/* set dane1; */
/* by &grupa. &sample.; */
/* if first.&sample. then do; */
/* c_model_lgd_frac=empiryczny_lgd_frac; */
/* ordered_population=1/l_obs; */
/* end; */
/* else do; */
/* c_model_lgd_frac+empiryczny_lgd_frac; */
/* ordered_population+1/l_obs; */
/* end; */
/* run; */



proc sql;
create table do_wykresu as
select a.&grupa., a.&sample., a.c_empiryczny_lgd_frac,a.ordered_population_emp as ordered_population,
b.c_model_lgd_frac,a.empiryczny_lgd,b.model_lgd,sum(a.empiryczny_lgd) as sum_emp, sum(b.model_lgd) as sum_m
from lcc as a
left join lcc as b
on a.ordered_population_emp=b.ordered_population and a.&grupa.=b.&grupa. and a.&sample.=b.&sample.
group by a.&grupa., a.&sample.
order by a.&grupa., a.&sample., b.ordered_population;
quit;

proc sort data=do_wykresu nodupkey dupout=i;
by &grupa. &sample. ordered_population;
run;


title &opis1;
proc sql;
select &grupa., &sample., sum(abs(c_model_lgd_frac-ordered_population))/sum(abs(c_empiryczny_lgd_frac-ordered_population)) as Loss_Capture_Ratio,count(*) as Obs
from do_wykresu
group by &grupa., &sample.;
quit;

axis1 label=(j=c rotate=0 a=90 "Actual loss captured (%)"   );
axis2 label=("Ordered population (worst to best)" );
title &opis2;
proc gplot data=do_wykresu;
label &grupa.="Segment" &sample.="Sample"
c_empiryczny_lgd_frac="Ideal" c_model_lgd_frac="Model" ordered_population="Random";
format &grupa. &sample.;
by &grupa. &sample.; 
   plot 
c_empiryczny_lgd_frac*ordered_population
c_model_lgd_frac*ordered_population
ordered_population*ordered_population
/ overlay  legend=legend1   vaxis=axis1 haxis=axis2; 

symbol1 v=dot width=0.1 i=join h = 0.1 c=black;
symbol2 v=dot width=0.1 i=join h = 0.1 c=blue;
symbol3 v=dot width=0.1 i=join h = 0.1 c=green;
symbol4 v=dot width=0.1 i=join h = 0.1 c=red;
symbol5 v=dot width=0.1 i=join h = 0.1 c=violet;
 
run;                                                                                                                                    
quit;

ods html5 close;
%mend;

%licz_lcc_ead(s1_s2_input_data,1, adj_Empirical_LGD_ever_sk, adj_Model_lgd_ever, 
model_new, currency_new, "Loss Capture Ratio","Loss Capture Curve", coalesce(Exposure_Balance,0) + coalesce(Exposure_Offbalance,0) - coalesce(direct_cost,0));
