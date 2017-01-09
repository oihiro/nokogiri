select t11.top_ctg, t11.thd_ctg, t11.modelcnt, t21.osscnt, t31.osstypecnt
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
inner join (
  select t3.top_ctg as top_ctg, t3.thd_ctg as thd_ctg, count(*) as osstypecnt
  from (
    select top_ctg, thd_ctg, regexp_replace(oss, '^(.*?)[-_\.][A-Za-z]?[0-9].*$', '\1') as osstype
    from sony_oss_20161231
    group by top_ctg, thd_ctg, osstype
  ) as t3
  group by t3.top_ctg, t3.thd_ctg
) as t31
on t11.top_ctg = t31.top_ctg and t11.thd_ctg = t31.thd_ctg
order by t21.osscnt desc offset 0 limit 10
;
