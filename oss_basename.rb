#
# OSS ベース名を取り出す
# ベース名：バージョン番号、拡張子、固有プレフィクスを取り除く
#
while str = STDIN.gets
  oss = str.strip
  oss.sub!(/[-_][vV]?\d+[-\._]\d.*$/, "")
  oss.sub!(/(\.tar)?\.(gz|tgz|zip|bzip|bz2|tbz2|xz)$/i, "")
  oss.sub!(/\.(orig|rar|tar|gpl)$/i, "")
  oss.sub!(/[-_]\d+$/, "")  # year/month/date
  oss.sub!(/[-_]\d{8}.*$/, "") # year/month/date

  # Sony OSS
  oss.sub!(/^1\dSTR-/, "")
  oss.sub!(/arm-sony-linux-gnueabi-arm(v7a)?-dev(tool)?-/, "")
  oss.sub!(/arm-sony-linux-gnueabi-cross-/, "")
  oss.sub!(/^hhl-target-/, "")
  oss.sub!(/^mips-ce3m-linux-/, "")
  oss.sub!(/^sony-(cross|target-(dev(tool)?|(g|s)?rel))-/, "")
  
  puts oss
end
