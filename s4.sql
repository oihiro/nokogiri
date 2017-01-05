select t1.oss, count(*)
from (
  select model, oss
  from sony_oss_20161231
  group by model, oss
) as t1
group by t1.oss
order by count(*);
