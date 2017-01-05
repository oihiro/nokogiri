select sum(t2.x) as sum, avg(t2.x) as avg
from (
select t1.model, max(t1.cnt) as x
from (
  select model, snd_ctg, count(*) as cnt
  from sony_oss_20161231
  where thd_ctg = 'Digital TV'
  group by model, snd_ctg
) as t1
group by t1.model
) as t2;

