#!/bin/bash
#
#

ARGS=($@)
cfg="errors.cfg"

# check time
hour=$(date +%H)
time_now=$(echo "$hour>=9 && $hour<=22"|bc)


# initialize arrays from error config file
# based on time
if [ $time_now -eq 1 ];then
	declare -A err_arr
	while read -d';' -ra line;
	do
  		key=${line%=*}
  		val=${line#*=}
  		err_arr["$key"]="$val"
	done < <(grep -E "^err@9-22" $cfg | cut -d';' -f2-)
else
	declare -A err_arr
	while read -d';' -ra line;
	do
  		key=${line%=*}
  		val=${line#*=}
  		err_arr["$key"]="$val"
	done < <(grep -E "^err@23-8" $cfg | cut -d';' -f2-)
fi

for cdr in ${ARGS[@]};
do
	echo -e "Processing file $cdr ...\n"
	sort_and_out(){
		cat $cdr | sort -t, -k 401,401 |\
		awk -p 'BEGIN{FS=",";"grep \"^ISUP|\" errors.cfg | cut -d\";\" -f2-"|getline ISUP}
		{
			if(FNR=1 && prev==""){prev=$401;s=s+1}
			else if(prev!=$401)
				{printf "%s=%d",prev,s;prev=$401;s=1;for(i in arr){printf ";%s=%s",i,arr[i]};delete arr;printf"\n"}
			else{prev=$401;s=s+1}
			if(match(ISUP,$401) && length($171)==0){arr["ISUP"]++}
			else if(match(ISUP,$401)){arr[$171]++}
			else if(length($420)==0){arr["00000"]++}else{arr[$420]++}
		}'
	}

	while IFS=';' read -ra line;do
		unset IFS
		total=${line#*=}
		direction=${line%=*}
		declare -a tmp_arr
		count=0
		for i in ${line[@]:1};do
			err_n=${i%=*}; err_n=${err_n:2}
			err_o=${i#*=}

			# check if we have describe this error treshold

			tres=${err_arr[$err_n]}
			if [ -z $tres ];
			then
				continue
			fi
			# floating comparison workaround. This slow down about 1 sec in total.
			# TODO: find more fast solution.
			res=$(printf "%.2f" $(echo "$err_o*100/${total}." | bc -l))
			alarm=$(echo "$res>$tres" | bc)	

			if [[ $alarm -eq 1 ]];
			then		
				tmp_arr[$count]="\ncode=$err_n|total=$total|errors=$err_o|perc=$res%|treshold=$tres%"
				(( count++ ))
			fi
		done
		if [[ $count -gt 1 ]];
		then
			echo -en "Direction ==> $direction"
			echo -e "${tmp_arr[@]}"
			echo
		fi
		unset tmp_arr
	done < <(sort_and_out)
done
