for url in $(cut -d ',' -f3 $1); do
    #echo $url
    package=$(echo $url | sed -e 's/.*\/\([^\/][^\/]*\)$/\1/')
    if [ $(echo $url | grep 'github\.com') ]; then
	#echo "YES"
	project=$(echo $url | cut -d '/' -f5)
	#echo $project
	#echo $package
	output=${project}_${package}
    else
	#echo "NO"
	output=$package
    fi
    #echo "wget -nv -P $2 -O $output $url"
    wget -nv -P $2 -O $output $url
done