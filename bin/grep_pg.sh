grep -v "^\@PG" | awk '{if($1 ~ /^\@/) {print($0)} else {if(and($2,64)>0) {print(1$0)} else {print(2$0)}}}'
