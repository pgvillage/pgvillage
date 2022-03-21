#!/bin/bash

# Datum : 2021-04-16
# Usage : /home/postgres/bin/pg_multi_db_checks.sh [ <Naam van Postgre Check> [-c limiet voor CRITICAL]  [-w limiet voor WARNING] ] --help


# INVOER CONTROLEREN:

# Usage melding bij "--help"  parameter :
#----------------------------------------------------------------------------------------------------------------------------------------
function show_usage
{
   echo
   echo "Run as 'posgres' !!"
   echo
   echo "Usage : /home/postgres/bin/pg_multi_db_checks.sh [ <Naam van Postgre Check> [-c limiet voor CRITICAL]  [-w limiet voor WARNING] ] --help" 
   echo
   echo "LET OP! Check wordt altijd op de 'localhost' uitgevoerd!"
   echo
   exit 0 
}


# Controle op uit te voeren postgres check :
#----------------------------------------------------------------------------------------------------------------------------------------
if [ "${1}" == "--help" ]; then show_usage; exit 0; fi;

if [ "${1}" == "" ]; then pg_check_name="check_postgres_last_vacuum"; else pg_check_name=${1}; fi

# Controle op limiet parameters :
#----------------------------------------------------------------------------------------------------------------------------------------

# Initialiseer options_array :
# In de string array "options_array" worden eventueel als parameters meegegeven option voor "" geplaatst.
unset opts_array

# Default "-c", "-w" values: 
# Zeven (7) dagen terug is voor het laast 'vacuum' of ánalyse' uitgevoerd
# In seconden : -w WARNING : echo $(( 60*60*24*5 )) --> 432000  sec
#               -c CRITICAL: echo $(( 60*60*24*7 )) --> 604800 sec


function check_treshold_parms
{
   if ( [ "${1}" == "-c" ] || [ "${1}" == "-w" ] ) && ( [ "$(echo ${2}|sed -n -e 's/^[0-9][0-9]*$/NUMBERS/p')" == "NUMBERS" ] ); then
      echo "OK"
      return 0;
   else
      echo "NOK"
      return 2;
   fi;
}

if [ ${#} -ge 3 ]; then
   if [ "$(check_treshold_parms ${2} ${3})" == "OK" ];  then 
      opts_array+=("${2}")
      opts_array+=("${3}")
   else 
      echo;echo "Wrong treshold options ${2} and ${3}";echo; 
      exit 2; 
   fi 
fi;

if [ ${#} -ge 5 ]; then
   if [ "$(check_treshold_parms ${4} ${5})" == "OK" ];  then 
      opts_array+=("${4}")
      opts_array+=("${5}")
   else
      echo;echo "Wrong treshold options ${4} and ${5}";echo; 
      exit 2;
   fi
fi;
 
# echo "Options: ${opts_array[@]}"

# INITIALISATIE:

# De check statussen voor Nagios definieren in een string-array "status" :
#----------------------------------------------------------------------------------------------------------------------------------------
status=('OK' 'WARNING' 'CRITICAL' 'UNKNOWN')

# De lijst met Postgresql databases op de huidige server inlezen in een string array "db_list" : 
#----------------------------------------------------------------------------------------------------------------------------------------
unset db_list
export db_list=($(psql -A  -t -c "select datname from pg_database where datname not like '%template%';"))

if [ $(( ${#db_list[@]} )) -lt 1 ]; then
   echo "NO postgres databases found !?"
   exit 1
fi

unset chck_outp


# In de numerieke variabele "wurst" wordt de [index] bijgehouden van een element uit de status array.
# Dat element uit de status array geeft weer welke de ernstigste waarde is, die is tegengekomen bij het uitvoeren van de check_potgres
# voor elke db.
# De numerieke variabele "wurst" wordt geinitialiseerd op de waarde 0, welke overeenkomt met de check-status "OK" :
#----------------------------------------------------------------------------------------------------------------------------------------
export wurst=0
export wurst_db="ALL db's check OK !"

# UITVOERING "check_postgres" op elke database:

# De volgende for loop doorloopt de db_list array en voert voor elk element daaruit de check_postgres uit,
# en vergelijkt de check-status waarde met de ernstigste tot dan toe opgeslagen waarde in de variabele "wurst".
# Indien de laatste verkregen status check_postgres groter is dan de waarde in variabele "wurst",
# dan wordt aan de variabele "wurst" de nieuwe check_postgres status toegekend! :
#----------------------------------------------------------------------------------------------------------------------------------------
for db in ${db_list[@]} ; do 
       # export chck=$(sudo -iu postgres /opt/nagios/nrpe/$pg_check_name -H localhost  --db=$db ${opts_array[@]}\
       export chck=$(/opt/nagios/nrpe/$pg_check_name -H localhost  --db=$db ${opts_array[@]}\
          |sed -n -s "s/^\(..*\)\(OK\|WARNING\|CRITICAL\|UNKNOWN\)[^\"]*\([^ ]*\).*$/$pg_check_name \2: DB \3/p";);

       ch=$(echo $chck|sed -n -e 's/^\(.*\)\(OK\|WARNING\|CRITICAL\|UNKNOWN\)[:]\(.*\)$/\2/p')
       for (( i=0 ; $i  < ${#status[@]} ;  i=$(($i+1)) )) ; do \
           if [ "$ch" == "${status[$i]}" ] ; then 
              if [ ${i} -gt ${wurst} ] ; then let wurst=$i ; wurst_db=$chck; fi 
           fi; 
       done
       chck_outp+=("$chck");
       export chck_outp;
    done


# OUTPUT:

# Als eerste de ernstigste tegengekomen status, opgeslagen in de variabele "wurst", in tekst afdrukken :
#----------------------------------------------------------------------------------------------------------------------------------------
echo "${status[$wurst]} - $wurst_db"

# Vervolgens de lijst met check-status voor elke individuele database afdrukken :
#----------------------------------------------------------------------------------------------------------------------------------------
for (( idb=0 ; idb < ${#chck_outp[@]} ; idb=(($idb+1)) )) ; do echo '"'${chck_outp[$idb]}'"'; done

# Ten slotte wordt de exit status van dit script bepaald a.d.h.v. de index "wurst" :
#----------------------------------------------------------------------------------------------------------------------------------------
case ${status[$wurst]} in 
      ( 'OK' )
          exit 0;
          ;;

      ( 'WARNING' )
          exit 1;
          ;;

      ( 'CRITICAL' )
          exit 2;
          ;;

      ( 'UNKNOWN' )
          exit 3;
          ;;

   ( '.*' )
          exit 9;
          ;;
esac
