#!/bin/bash

#   This script report a snapshot of the current procecess.
#   v.1.0.0

#    Copyright (C) 2019  Juan Caamaño Rivas
#       
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.


process=""
total_pcpu=0
total_pmem=0
total_rss=0
total_size=0
array=""
show_details=0
sort_by=""
number_of_process=0

#ToDo
#color
#multiple sort


function help(){
cat <<ENDHELP

    This script report a snapshot of the current processes,
    so it must be defined correctly. (ps -ef |grep -> process name)

    Example: resources_by_process -p <process>
    Options:
        -p|--process) Obligatory
        -d|--details) Show full command path (ex:tomcat type)
        -s|--sort)  Show in Human Readable   (not full path)
                pid
                rss
                size
                pmem
                pcpu
        -h|--help)

ENDHELP
exit 0
}

function human_readable() {
    local -i bytes=$1;
    bytes=$(($bytes*1024))

    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes}B"
    elif [[ $bytes -lt 1048576 ]]; then
        echo "${bytes}" | awk '{ printf "%.2f%s", ($1/1024),"KB" }'
    elif [[ $bytes -lt 1073741824 ]]; then
        echo "${bytes}" | awk '{ printf "%.2f%s", ($1/1048576),"MB" }'
    else
        echo "${bytes}" | awk '{ printf "%.2f%s", ($1/1073741824),"GB" }'
     fi
}


function sum(){
        total_rss=$(echo "$total_rss" + "$process_rss" |bc -l)
        total_size=$(echo "$total_size" + "$process_size" |bc -l)
        total_pmem=$(echo "$total_pmem" + "$process_pmem" |bc -l)
        total_pcpu=$(echo "$total_pcpu" + "$process_pcpu" |bc -l)
        number_of_process=$(($number_of_process+1))
}

function show_details(){
    echo -e "\n\nDetails by PID\n"
    if [[ ! -z "$sort_by" ]];then
        case "$sort_by" in
            pid)
                column_to_sort=1
                ;;
            rss)
                column_to_sort=2
                ;;
            size)
                column_to_sort=3
                ;;
            pmem)
                column_to_sort=4
                ;;
            pcpu)
                column_to_sort=5
                ;;
            *) help
            ;;
        esac                   
        echo -e  "$array" | sort -k${column_to_sort} -nr |awk '
        function human(j) {
            if (j == 1)
                { x=$2 }
            else
                { x=$3 }

            s="KiB MiB GiB TiB EiB PiB"
            while (x>=1024 && length(s)>1)
            {
               x/=1024;
               s=substr(s,5)
            }
            s=substr(s,0,3)
            return sprintf( "%.2f%s", x, s)
        }
        
        function add_percent(j){
            if (j == 1)
                { x=$4 }
            else
                { x=$5 }
            s="%"
            return sprintf("%s%s",x,s)
        }    

        BEGIN {printf("%s\t %s\t\t %s\t\t %s\t %s\t %s\n" ,"PID", "RSS", "SIZE", "PMEM","PCPU","CMD")}
        {printf("%s\t %s\t %s\t %s\t %s\t %s\n", $1, human(1), human(2), add_percent(1), add_percent(2), $6)}' |head -n-1
    else
        printf "%s\t %s\t %s\t %s\t %s\t %s\n" "PID" "RSS" "SIZE" "PMEM" "PCPU" "CMD"
        echo -e  "$array" |awk '{printf("%s\t %s\t %s\t %s\t %s\t", $1, $2, $3, $4, $5)}{for(i=6;i<=NF;++i) printf("%s ",$i)} {print ""}' |head -n-1     
    fi
    
}

#Main

while (( "$#" )); do
    case "$1" in
        -p|--process)
            shift 1
            process=$1
            ;;
        -d|--details)
            show_details=1
            ;;
        -s|--sort)
            shift 1
            sort_by=$1
            ;;
        -h|--help)
            help
            ;;
        *) help
            ;;
    esac
    shift 1
done


process_list=$(pgrep -x "$process")

if [[ $? -ne 0 ]];then
    echo -e "ERROR: process $process NOT found"
    exit 0
fi

while read -r line; do
        data_to_process=$(ps axo pid,rss,size,pmem,pcpu,cmd |grep $line |grep -v grep)
        while read -r line_to_process;do
            array="$line_to_process \n$array"
            process_pid=$(echo $line_to_process |awk '{print $1}')
            process_rss=$(echo $line_to_process |awk '{print $2}')
            process_size=$(echo $line_to_process |awk '{print $3}')
            process_pmem=$(echo $line_to_process |awk '{print $4}')
            process_pcpu=$(echo $line_to_process |awk '{print $5}')
            sum
        done <<< "$data_to_process"
done <<< "$process_list"

echo -e "\nTotal: $number_of_process"
echo -e "RSS: $(human_readable $total_rss) \t SIZE: $(human_readable $total_size) \t CPU: $total_pcpu% \t  PMEM: $total_pmem%"


if [ "$show_details" -eq "1" ];then
    show_details
fi
