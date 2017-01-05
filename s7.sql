select top_ctg, thd_ctg, regexp_replace(oss, '^(.*?)[-_\.][0-9].*$', '\1') as osstype
from sony_oss_20161231
group by top_ctg, thd_ctg, osstype;
