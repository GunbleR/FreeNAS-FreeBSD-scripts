#!/bin/bash
my_msg="updateble_pkg.txt"
my_log="updateble_pkg.log"
dont_update=false
local_cache=false
restart_type=0
pkg_cache="pkg_cache"  #caching jail name
pkg_patch='/mnt/Data/apps/repo_cache/FreeBSD:11:amd64/latest/All/'  #cached pkg's path

echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@" >> ${my_log}
echo "" >> ${my_log}
#########################
# The command line help #
#########################
display_help() {
    echo "Usage: $0 [options...] " >&2
    echo "options:   "
    echo "  -u args, --update_args args	  pass-trught args to pkg update"
    echo "  -g args, --upgrade_args args  pass-trught args to pkg upgrade"
    echo "  -q	    quick, dont run pkg update"
    echo "  -c      enables local repo cache clearing on failed downloads. "
    echo "  -r arg,  --restart_type arg   choose jail restart type"
    echo " A - restart all jails with boot=1, U - restart only upgraded jails, Y - manual restart of upgraded jails, N - don't restart jails"
    exit 1
}

while :
do
    case "$1" in
      -h | --help)
          display_help  # Call your function
          exit 0
          ;;
      -g | --upgrade_args)
          upgrade_args="$2"   # You may want to check validity of $2
          shift 2
          ;;
      -u | --update_args)
          update_args="$2"   # You may want to check validity of $2
          shift 2
          ;;
      -s)
           scripted=true # not in use
           shift 1
           ;;
      -q)
           dont_update=true
           shift 1
           ;;
      -c)
           local_cache=true
           shift 1
           ;;
      -r | --restart_type)
          restart_type="$2"   # You may want to check validity of $2
          shift 2
          ;;
 
      --) # End of all options
          shift
          break
          ;;
      -*)
          echo "Error: Unknown option: $1" >&2
          echo use -h or --help for help
          ## or call function display_help
          exit 1
          ;;
      *)  # No more options
          break
          ;;
    esac
done


date > ${my_msg}
echo "" >> ${my_msg}
j_names=($( /usr/local/bin/iocage list -h | awk '{ print $2 }' ))
j_nums=($( /usr/local/bin/iocage list -h | awk '{ print $1 }' ))
j_states=($( /usr/local/bin/iocage list -h | awk '{ print $3 }' ))
j_basejail=($( /usr/local/bin/iocage list -l -h | awk '{ print $10 }' ))


#ASSUME_ALWAYS_YES=yes
#J=0
#for ((I = 0; I < ${#j_names[@]}; ++I )); do
##   iocage exec ${vars[I]} "pkg version | grep '>'"
#   if [ ${j_states[I]} == "up" ]; then
#      echo  "[$((I+1))/${#j_names[@]}] ${j_names[I]} bootstrapping package"
#      pkg -j ${j_nums[I]} bootstrap
#
#   else
#     echo  "[$((I+1))/${#j_names[@]}] ${j_names[I]} is down" >> ${my_msg}
#     echo  "[$((I+1))/${#j_names[@]}] ${j_names[I]} is down"
#   fi
##   echo ${vars[$I]}
#   echo "" >> ${my_msg}
#done
#ASSUME_ALWAYS_YES=no

if [ $local_cache == true ] ; then
iocage exec $pkg_cache "sh /root/meta_clear.sh" 2>/dev/null
fi
#### pkg update ###

if [ $dont_update == false ] ; then
echo -e "\e[92mupdating packages\e[0m"
J=0
for ((I = 0; I < ${#j_names[@]}; ++I )); do
#   iocage exec ${vars[I]} "pkg version | grep '>'"
   if [ ${j_states[I]} == "up" ]; then
      echo  "[$((I+1))/${#j_names[@]}] ${j_names[I]} updating package"
#      pkg -j ${j_nums[I]} update $update_args
#      iocage pkg ${j_names[I]} update $update_args
      iocage exec ${j_names[I]} "pkg update $update_args"
   else
     echo  "[$((I+1))/${#j_names[@]}] ${j_names[I]} is down" >> ${my_msg}
     echo  "[$((I+1))/${#j_names[@]}] ${j_names[I]} is down"
   fi
#   echo ${vars[$I]}
   echo "" >> ${my_msg}
done
fi
##### pkg upgrade ####
J=0
u=0
echo -e "\e[92mupgrading packages\e[0m"
for ((I = 0; I < ${#j_names[@]}; ++I )); do
#   iocage exec ${vars[I]} "pkg version | grep '>'"
   fail=0
#   if [ ${j_states[I]} == "up" ] && [ ${j_basejail[I]} == "no" ] ; then
   if [ ${j_states[I]} == "up" ] ; then
      echo  "[$((I+1))/${#j_names[@]}] ${j_names[I]}:"
      rm stdout.log stderr.log 2>/dev/null
      bad_pkg=""
      upg_flag=""
#      iocage pkg ${j_names[I]} upgrade ${upgrade_args} > >(tee -a stdout.log) 2> >(tee -a stderr.log >&2)
      iocage exec ${j_names[I]} "pkg upgrade ${upgrade_args}" > >(tee -a stdout.log) 2> >(tee -a stderr.log >&2)
#      pkg -j ${j_nums[I]} upgrade $upgrade_args > >(tee -a stdout.log) 2> >(tee -a stderr.log >&2)
     if [ $local_cache == true ] ; then
      bad_pkg="$(grep  'size mismatch, cannot continue' stderr.log)"
      while  [ ! -z "$bad_pkg" ] && (( fail < 5 ))  ; do  ##loop up to 5 times if upgrade failes
        ((fail=fail+1))
        bad_pkg=${bad_pkg:20}  		# Remove the first three chars (leaving 4..end)
        bad_pkg=${bad_pkg%:*}  		# retain the part before the colon
	echo -e "\e[31mError $fail out of 5. package $bad_pkg is corrupted."
	echo -e "clearing pkg from cache and restarting\e[0m"
        rm $pkg_patch$bad_pkg".txz"		# got local pkg caching, it removes bad file if connection got aborted mid download
        rm stdout.log stderr.log 2>/dev/null
        bad_pkg=""
#        pkg -j ${j_nums[I]} upgrade $upgrade_args > >(tee -a stdout.log) 2> >(tee -a stderr.log >&2)
        iocage exec ${j_names[I]} "pkg upgrade ${upgrade_args}" > >(tee -a stdout.log) 2> >(tee -a stderr.log >&2)
#	iocage pkg ${j_names[I]} upgrade ${upgrade_args} > >(tee -a stdout.log) 2> >(tee -a stderr.log >&2)
        bad_pkg="$(grep  'size mismatch, cannot continue' stderr.log)"
      done
     fi
      upg_flag="$(grep  'Installed packages to be UPGRADED:' stdout.log)"
      if [ ! -z "$upg_flag" ]; then
        upg_jail[u]=${j_names[I]}
        u=$((u+1))
      fi
      rm stdout.log stderr.log 2>/dev/null
#   elif [ ${j_states[I]} == "down" ] ; then
   else
     echo  "[$((I+1))/${#j_names[@]}] ${j_names[I]} is down" >> ${my_msg}
     echo  "[$((I+1))/${#j_names[@]}] ${j_names[I]} is down"
#   else
#     echo  "[$((I+1))/${#j_names[@]}] ${j_names[I]} is basejail, skipping to avoid loop" >> ${my_msg}
#     echo  "[$((I+1))/${#j_names[@]}] ${j_names[I]} is basejail, skipping to avoid loop"
 
   fi
#   echo ${vars[$I]}
   echo "" >> ${my_msg}
done
if [ $u == 0 ]; then
  echo " "
  echo -e "\e[36mno jails ware upgraded.\e[0m"
  echo " "
else
  echo " "
  echo -e "\e[92mupgraded jails are:"
  for ((I = 0; I < ${#upg_jail[@]}; ++I )); do
    echo -e "${upg_jail[I]}"
  done
  echo -e "\e[0m"





  while true; do
  if [ $restart_type == 0 ]; then
  echo "press 'U' to restart all upgraded."
  echo "press 'A' to restart all jails (with boot on)."
  echo "press 'Y' to restart one by one."
  read -p "press 'N' to not restart. " yn
  else
  yn=$restart_type
  restart_type=0
  fi
    case $yn in
      [Aa]* )  #restart all
           iocage stop ALL
           iocage start --rc
      break;;
      [Uu]* )  #restart all upgraded
        for ((I = 0; I < ${#upg_jail[@]}; ++I )); do
           iocage stop ${upg_jail[I]}
           iocage start ${upg_jail[I]}
        done
      break;;
      [Yy]* )  #restart 1 by 1
        for ((I = 0; I < ${#upg_jail[@]}; ++I )); do
          while true; do
            read -p "Restart ${upg_jail[I]} jail? " yn
            case $yn in
              [Yy]* )
                iocage stop ${upg_jail[I]}
                iocage start ${upg_jail[I]}
              break;;
              [Nn]* ) break;;
              * ) echo "Please answer yes or no.";;
            esac
          done
        done
      break;;
      [Nn]* ) exit;; #exit
      * ) echo "Please answer yes, no or All.";;
    esac
  done
fi

