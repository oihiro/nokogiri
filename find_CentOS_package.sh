for oss in $(sed -e 's/ *[0-9][0-9]* *\(.*\)/\1/' $1); do
    #echo $oss
    package=$(grep -i $oss $2 | head -1)
    echo "$oss $package"
done
