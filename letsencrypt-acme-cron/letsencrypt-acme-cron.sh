#!/bin/bash

# Intended to be set as cron job for LetsEncrypt certificate renew. 
# Sends colorized html-emails on successful renewal or by errors 

# Licence: LGPLv2
# Author:
#     Vadim Dor https://github.com/VadimDor/
# Usage: download, change emails parameters below, localize messages, enjoy
# Depends on:
#    ansi2html.sh    located http://github.com/pixelb/scripts/commits/master/scripts/ansi2html.sh
#    acme.sh         located https://github.com/acmesh-official/acme.sh
# Changes:
#    V0.1, 28 Oct 2020, Initial release
#      https://github.com/VadimDor/acme-cron.sh

source ./acme.sh    -v > /dev/null 2>/dev/null  # to enable _info and _err messaging in this script
SYS_LOG=$SYSLOG_LEVEL_INFO # to force syslog for err and info messages from this script 
ACME_FORCE_COLOR=1   # to force err and info messages from this script  in emails

to_email="info@sample.ru"
from_email="info@sample.ru"
achmesh="/root/.acme.sh"
all_ok="Subject: All OK"
log_msg="cron job acme.sh to check LetsEncrypt certificate maintenance"
sbj="$log_msg"
attention_utf8="ВНИМАНИЕ!!"

_info "=== Start of $log_msg ==="

umask 077  #assure safe temp files creation
d=$(mktemp -d -t acme_cron.XXXXXXXXXX)
trap "rm -fr "${d}"" EXIT   #assure deletion on any script exit or abortion
temp_file_acme_output=$(mktemp ${d}/acme_output.XXXXXXXXXX)
temp_file_errors=$(mktemp ${d}/errors.XXXXXXXXXX)
temp_file_html_body=$(mktemp ${d}/html_body.XXXXXXXXXX)
temp_file_email=$(mktemp ${d}/email.XXXXXXXXXX)

# check if there are errors in acme.sh runnung
_errors() {
  errfilesize=$(stat --format=%s $temp_file_errors)
  if [ "$errfilesize" = "0" ]; then 
    return 1
  else  
	return 0
  fi 
}

# email headers
_headers() {
  printf \
  "To: $to_email\nFrom: $from_email\nContent-Type: text/html; charset=UTF-8\nContent-Disposition: inline\nMIME-Version: 1.0\nSensitivity: Personal"
}

_acme_cron() {
 (("$achmesh"/acme.sh --notify-level 2 --notify-mode 0 --syslog 3 --cron --home "$achmesh" --force-color  2>&1 1>&3; )  \
  | tee $temp_file_errors; ) 3>&1
}

# preprocess for html emails
_2html() {
  sed -n -e 'H;${x;s/\n/<br>/g;s/^<br>//;p;}'\
  |$achmesh/ansi2html.sh       \
  | sed  "s/<pre>/<br>/g"\
  | sed  "s/<\/pre>/<br>/g" \
  | sed  "s/&lt;br&gt;/<br>/g" 
}
 
# set subject, depends on
_setSubject() {
 if _errors ; then 
    printf "Subject: $attention_utf8 Error(s) by $sbj\nImportance: High\nPriority: urgent\n"
 else  
	printf "$all_ok by $sbj\n"   
 fi 
} 

# colorize and emphase summary in emails (if falls)
_check_errors() {
if _errors ; then 
    # see colors https://misc.flogisoft.com/bash/tip_colors_and_formatting
    #   red  , underlined	
	echo -e "\e[4m\e[1m" 
	echo  $(_err "=== Error(s) by $log_msg ===") 
	echo -e "\e[21m\e[24m\e[49m\e[39m"
else  
    #   green  , underlined	
	echo -e "\e[97m\e[102m\e[4m\e[1m" $(_info  "$(__green "=== No problems by $log_msg ===")") "\n\e[21m\e[24m\e[49m\e[39m"
fi 
} 
 
 # script body
_acme_cron   > $temp_file_acme_output
( _check_errors 2>&1| cat - $temp_file_acme_output ) | _2html > $temp_file_html_body
( _setSubject; _headers; cat  $temp_file_html_body ) > $temp_file_email

if _errors  || grep -q "renewed" "$temp_file_acme_output"; then 
  #send mails only by errors or some domain was renewed
  cat $temp_file_email | mail $to_email 
else
  _info "$(__green 'All is ok, will not bother admin with emails')"
fi 

#finalizing
rm -fr "${d}"
_info "=== End of $log_msg ==="
exit 0
 
