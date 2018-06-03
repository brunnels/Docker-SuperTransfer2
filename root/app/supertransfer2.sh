#!/bin/bash
echo -e " [INFO] Initializing Supertransfer2 Load Balanced Multi-SA Uploader..."
source /app/rcloneupload.sh
source /config/settings.conf
source /config/usersettings.conf
#dbug=on

# check to make sure filepaths are there
touch /tmp/superTransferUploadSuccess &>/dev/null
touch /tmp/superTransferUploadFail &>/dev/null
[[ -e $uploadHistory ]] || touch $uploadHistory &>/dev/null
[[ ! -e $userSettings ]] && echo -e " [FAIL] No User settings found in $userSettings. Exiting." && exit 1


clean_up(){
  echo -e " [INFO] SIGINT: Clearing filelocks and logs. Exiting."
  numSuccess=$(cat /tmp/superTransferUploadSuccess | wc -l)
  numFail=$(cat /tmp/superTransferUploadFail | wc -l)
  totalUploaded=$(gawk -F'=' '{ sum += $2 } END { print sum / 1000000 }' $gdsaDB)
  sizeLeft=$(du -hc ${localDir} | tail -1 | gawk '{print $1}')
  echo -e " [STAT]\t$numSuccess Successes, $numFail Failures, $sizeLeft left in $localDir, ${totalUploaded}GB total uploaded"
  rm ${logDir}/* &>/dev/null
  echo -n '' > ${fileLock}
  
  # if user added or removed GDSA remotes, reset the usage database in order to regenerate it
  numGdsaDB=$(cat ${gdsaDB} | wc -l)
  numGdsa=$(rclone listremotes --config=/root/.config/rclone/rclone.conf | wc -l)
  [[ $numGdsaDB == $numGdsa ]] || echo -n '' > ${gdsaDB}
  
  rm /tmp/superTransferUploadFail &>/dev/null
  rm /tmp/superTransferUploadSuccess &>/dev/null
  rm /tmp/.SA_error.log.tmp &>/dev/null
  rm /tmp/SA_error.log &>/dev/null
  exit 0
}
trap "clean_up" SIGINT
trap "clean_up" SIGTERM

round() {
    local df=${2:-3}
    printf '%.*f\n' "$df" "$(echo "a=$1; if(a>0) a+=5/10^($df+1) else if (a<0) a-=5/10^($df+1); scale=$df; a/1" | bc -l)"
}

############################################################################
# Least Usage Load Balancing of GDSA Accounts
############################################################################

numGdsa=$(cat $gdsaDB | wc -l)
maxDailyUpload=$(round "$numGdsa * 750 / 1000" 0)
echo -e " [INFO] START\tMax Concurrent Uploads: $maxConcurrentUploads, ${maxDailyUpload}TB Max Daily Upload"
echo -n '' > ${fileLock}

while true; do
  # purge empty folders
  find "${localDir}" -mindepth 2 -type d -empty -delete
  # remote duplicates from fileLock
  gawk -i inplace '!seen[$0]++' ${fileLock}
  # black magic: find list of all dirs that have files at least 1 minutes old that aren't hidden
  # and put the deepest directories in an array, then sort by dirsize
  sc=$(gawk -F"/" '{print NF-2}' <<<${localDir})
  unset a i
      while IFS=$(read -r -u3 -d $'\0' dir); do
          [[ $(find "${dir}" -type f -mmin -${modTime} -print -quit) == '' && ! $(find "${dir}" -name "*.partial~") ]] \
              && a[i++]=$(du -s "${dir}")
      done 3< <(find ${localDir} -mindepth $sc -type d -not -path '*/\.*' -links 2 -not -empty -prune -print0)

      # sort by largest files first
      IFS=$'\n' uploadQueueBuffer=($(sort -gr <<<"${a[*]}"))
      unset IFS

      # iterate through each folder and upload
      for i in $(seq 0 $((${#uploadQueueBuffer[@]}-1))); do
        flag=0
        # pause if max concurrent uploads limit is hit
        numCurrentTransfers=$(grep -c "$localDir" $fileLock)
        [[ $numCurrentTransfers -ge $maxConcurrentUploads ]] && break

        # get least used gdsa account
        gdsaLeast=$(sort -gr -k2 -t'=' ${gdsaDB} | egrep ^GDSA[0-9]+=. | tail -1 | cut -f1 -d'=')
        [[ -z $gdsaLeast ]] && echo -e " [FAIL] Failed To get gdsaLeast. Exiting." && exit 1

        # upload folder (rclone_upload function will skip on filelocked folders)
        if [[ -n "${uploadQueueBuffer[i]}" ]]; then
          [[ -n $dbug ]] && echo -e " [DBUG] Supertransfer rclone_upload input: "${file}""
          IFS=$'\t'
          #             |---uploadQueueBuffer--|
          #input format: <dirsize> <upload_dir>  <rclone> <remote_root_dir>
          rclone_upload ${uploadQueueBuffer[i]} $gdsaLeast $remoteDir &
          unset IFS
          sleep 0.2
        fi
      done
      unset -v uploadQueueBuffer[@]
      sleep $sleepTime
done