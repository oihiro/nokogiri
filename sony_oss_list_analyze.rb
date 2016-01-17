#
# sony_oss_list_analyze.rb
#

oss_global_unique = {}

# This file is created by sony_oss.rb
open("sony_oss_list.txt", "r") do |f|
  f.each do |l|
    modu = l.strip
    if modu =~ /[-_\.]\d/ then # take words before of version
      modu = $`
    end
    if modu =~ /(\.tar(\.b?zip|\.bz2|\.gz)?|\.zip|\.tgz)$/ then
      modu = $`
    end
    if modu =~ /^1\dSTR-/ then
      modu = $'
    end
    if modu =~ /arm-sony-linux-gnueabi-arm(v7a)?-dev(tool)?-/ then
      modu = $'
    end
    if modu =~ /arm-sony-linux-gnueabi-cross-/ then
      modu = $'
    end
    if modu =~ /^hhl-target-/ then
      modu = $'
    end
    if modu =~ /^mips-ce3m-linux-/ then
      modu = $'
    end
    if modu =~ /^sony-(cross|target-(dev(tool)?|(g|s)?rel))-/ then
      modu = $'
    end
    modu.downcase!
    if not modu or modu.size == 0 then
      puts l.strip
    end
    unless oss_global_unique[modu] then
      oss_global_unique[modu] = 1
    else
      oss_global_unique[modu] = oss_global_unique[modu] + 1
    end
  end
end

puts "oss_global_unique size=#{oss_global_unique.keys.size}"

topn = 20
puts "oss_global_unique top #{topn}"
ary = oss_global_unique.sort {|(k1, v1), (k2, v2)| v2 <=> v1}
ary.first(topn).each do |e|
  puts "#{e[0]}:#{e[1]}"
end

open("sony_oss_list_unique.txt", "w") do |f|
  oss_global_unique.keys.each do |k|
    f.puts k
  end
end

