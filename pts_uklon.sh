#!/bin/sh

num=$2
max=$3

val=$4
step=$5

while [ "$num" -le "$max" ]; do
    # echo $num $val
    
    v.db.update map=$1 col=paleo_hgt value=$val where="cat = "$num"" --q
    
    # echo "UPDATE $1 SET paleo_hgt = "$val" WHERE cat = "$num"" | db.execute

    num=$((num+1))
    val=$((val+step))
done




