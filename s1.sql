select t1.model, max(t1.cnt)
from (
  select model, snd_ctg, count(*) as cnt
  from sony_oss_20161231
  where thd_ctg = 'Digital TV'
  group by model, snd_ctg
) as t1
group by t1.model
order by t1.model;
