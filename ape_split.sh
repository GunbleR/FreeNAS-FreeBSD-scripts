#!/usr/local/bin/bash

#var preset
template='%n_-_%t'
scripted=false


#########################
# The command line help #
#########################
display_help() {
    echo "Usage: $0 [option...] [path_to/file.ape]" >&2
    echo "options:   "
    echo "   -c, --cue xyz	name of cue file"
    echo "   -t, --template xyz	output name template, use 'man shnsplit' for info, default:'$template'"
    echo "   -d, --directory	output directory, defaults to input file"
    echo "   -s,    		disables prompts and picks 1st detected file, use for scripts, run at your own risk"
    echo " 			ex: find . -name "*.ape" | xargs -I '{}' ~/scripts/ape_split.sh -s '{}'  "
    echo
    echo "This script requires installation of: cuetools, shntool and flac"
    echo
    exit 1
}
var_tst(){
echo
echo "input	$in_file"
echo "cue	$cue"
echo "template	$template"
echo "dir	$dir"
echo "odir	$o_dir"
echo "sc	$scripted"
echo "cuelist 	${cue_file[@]}"
echo "ape_lst 	${ape_files[@]}"
echo "scripted	$scripted"
echo
exit 0
}

prompt_confirm() {
  while true; do
    if $scripted ; then return 0; fi
    read -r -n 1 -p "${1:-Continue?} [y/n]: " REPLY
    case $REPLY in
      [yY]) echo ; return 0 ;;
      [nN]) echo ; return 1 ;;
      *) printf " \033[31m %s \n\033[0m" "invalid input"
    esac 
  done  
}

#filename_edit(){
#for f in shn-outp*
#do
#  new="$f $1"
#  if [ "$new" != "$f" ]
#  then
#    if [ -e "$new" ]
#    then
#      echo not renaming \""$f"\" because \""$new"\" already exists
#    else
#      echo moving "$f" to "$new"
#    mv "$f" "$new"
#  fi
#fi
#done
#}

to_underscores(){
for f in shn-outp*
do
  new="${f// /_}"
  if [ "$new" != "$f" ]
  then
    if [ -e "$new" ]
    then
      echo not renaming \""$f"\" because \""$new"\" already exists
    else
      echo moving "$f" to "$new"
    mv "$f" "$new"
  fi
fi
done
}

to_spaces(){
for f in shn-outp*
do
  new="${f//_/ }"
  if [ "$new" != "$f" ]
  then
    if [ -e "$new" ]
    then
      echo not renaming \""$f"\" because \""$new"\" already exists
    else
      echo moving "$f" to "$new"
    mv "$f" "$new"
  fi
fi
done
}

rem_prefix(){
for f in shn-outp*
do
  new=${f#"shn-outp"}
  if [ "$new" != "$f" ]
  then
    if [ -e "$new" ]
    then
      echo not renaming \""$f"\" because \""$new"\" already exists
    else
      echo moving "$f" to "$new"
    mv "$f" "$new"
  fi
fi
done
}

fat_fix(){  ### remove illegal chars for windows file system
for f in shn-outp*
do
  new="${f/[?<>\\:*|\"]/_}"
  echo "$new"
  if [ "$new" != "$f" ]
  then
    if [ -e "$new" ]
    then
      echo not renaming \""$f"\" because \""$new"\" already exists
    else
      echo moving "$f" to "$new"
    mv "$f" "$new"
  fi
fi
done
}

set_pregap_name(){
  al_performer=$(cueprint -d '%P' "$cue")
  al_title=$(cueprint -d '%T' "$cue")
  pregap_name="${template//'%p'/$al_performer}"
  pregap_name="${pregap_name//'%a'/$al_title}"
  pregap_name="${pregap_name//'%n'/00}"
  pregap_name="${pregap_name//'%t'/pregap}"
  pregap_name="shn-outp${pregap_name}.flac"
}
################################
# Check if parameters options  #
# are given on the commandline #
################################
while :
do
    case "$1" in
      -h | --help)
          display_help  # Call your function
          exit 0
          ;;
      -c | --cue)
          cue="$2"   # You may want to check validity of $2
          shift 2
          ;;
      -d | --directory)
          o_dir="$2"   # You may want to check validity of $2
          shift 2
          ;;
      -t | --template)
          template="$2"
           shift 2
           ;;
      -s)
           scripted=true
           shift 1
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



in_file="$1"
if [ -z "$in_file" ] # auto find ape input file
then
  ape_files=()
  while IFS=  read -r -d $'\0'; do
    ape_files+=("$REPLY")
  done < <(find "$PWD" -name '*.ape' -print0)
  if [ "${#ape_files[@]}" -eq 1 ]
  then
    in_file="${ape_files[0]}"
    prompt_confirm "Confirm using ape: $in_file" || exit 0
  elif [ "${#ape_files[@]}" -eq 0 ]
  then
    echo 'error!!!'
    echo "no ape files detected or specified. use -h or --help for info"
    echo
    exit 0
  else
    echo "  ${#ape_files[@]} ape files found"
    echo
    i=1
    for each in "${ape_files[@]}"
    do
      echo -e "\e[32m$i. $each"
      i=$((i+1))
    done
    echo -e "\e[39m"
    if $scripted ; then in_file="${ape_files[0]}"; fi
    while [ -z "$in_file" ] ; do
      read -r  -p "  specify file index between 1-${#ape_files[@]} or enter q to exit:" REPLY
      if [[ $REPLY =~ ^[Qq]$ ]]
      then
        exit 0
      elif (( $REPLY > 0 && $REPLY <= "${#ape_files[@]}" ))
      then
        echo "$REPLY"
        in_file="${ape_files[REPLY-1]}"           ### set input ape file
      else
        echo "invalid input"
      fi
    done
  fi
fi
in_file=$(readlink -f "$in_file")
dir=$(dirname "$in_file")
if [ -z "$o_dir" ]
then
  o_dir="$dir"
fi
cd "$o_dir"

if [ -z "$cue" ] # auto find cue file
then
#file exist, check for multiple files
  cue_file=()
  while IFS=  read -r -d $'\0'; do
    cue_file+=("$REPLY")
  done < <(find "$dir" -name '*.cue' -print0)
    if [ "${#cue_file[@]}" -eq 1 ]
    then
      cue="${cue_file[0]}"
      prompt_confirm "Confirm using cue: $cue" || exit 0
    elif [ "${#cue_file[@]}" -eq 0 ]
    then
      echo 'error!!!'
      echo 'no cue file found, please specify cue using -c parameter'
      exit 0
    else
      echo "  ${#cue_file[@]} cue files found"
      echo
      i=1
      for each in "${cue_file[@]}"
      do
        echo -e "\e[32m$i. $each"
        i=$((i+1))
      done
      echo -e "\e[39m"
    if $scripted ; then cue="${cue_file[0]}"; fi
    while [ -z "$cue" ] ; do
      read -r  -p "  specify file index between 1-${#cue_file[@]} or enter q to exit:" REPLY
      if [[ $REPLY =~ ^[Qq]$ ]]
      then
        exit 0
      elif (( $REPLY > 0 && $REPLY <= "${#cue_file[@]}" ))
      then
        echo "$REPLY"
        cue="${cue_file[REPLY-1]}"               ### set input cue file
      else
        echo "invalid input"
      fi
    done

  fi
fi

if  $scripted ; then
  echo
  echo -e "\e[96mape: $in_file"
  echo -e "cue: $cue \e[39m"
fi


rm "shn-outp"* 2>/dev/null  ### actual work starts here
ffmpeg -i "${in_file}" -acodec flac "${in_file}.flac"
in_file="${in_file}.flac"
set_pregap_name 		# find exact pregap name for later removal
cuebreakpoints  "$cue" | shnsplit -f "$cue" -t "shn-outp${template}"  -o flac  "${in_file}"  # split apes
if [ $? -ne 0 ]; then  		# stop on error
  echo -e "\e[31m shnsplit error!! \e[39m"
  echo
  exit 0
fi
rm "$pregap_name" #2>/dev/null  # remove pregap
fat_fix 			# fix illigal chars for windows fs
to_underscores			# convert staces to underscores, cuetag.sh cant work with spaces
#echo "${DIR}/outp"*
#ls | grep -E 'shn-outp00' | xargs -I '{}' rm '{}'
cuetag.sh "${cue}"  shn-outp*.flac	# fill metadata tags
to_spaces			# remove underscores
rem_prefix			# remove temp prefix
