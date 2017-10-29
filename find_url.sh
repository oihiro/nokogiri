for oss in $(sed -e 's/ *[0-9][0-9]* *\(.*\)/\1/' $1); do
    #echo $oss
    grep $oss $2 | head -1 | cut -d ',' -f6
done
