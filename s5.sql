select t11.top_ctg, t11.thd_ctg, t11.modelcnt, t21.osscnt
from (
  select t1.top_ctg as top_ctg, t1.thd_ctg as thd_ctg, count(*) as modelcnt
  from (
    select top_ctg, thd_ctg, model
    from sony_oss_20161231
    group by top_ctg, thd_ctg, model
  ) as t1
  group by t1.top_ctg, t1.thd_ctg
) as t11
inner join (
  select t2.top_ctg as top_ctg, t2.thd_ctg as thd_ctg, count(*) as osscnt
  from (
    select top_ctg, thd_ctg, oss
    from sony_oss_20161231
    group by top_ctg, thd_ctg, oss
  ) as t2
  group by t2.top_ctg, t2.thd_ctg
) as t21
on t11.top_ctg = t21.top_ctg and t11.thd_ctg = t21.thd_ctg
;
