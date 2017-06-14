#!/bin/bash
[[ ${git_debug+x} ]] || git_debug=''
main() {
  local num=$1 ; shift ;
  local commit_note="$*" ;
  if [[ $git_debug ]] ; then
    cd /usr/src/redmine \
    && git_change "$commit_note" &> /tmp/logs/${num}_${commit_note}.log ;
  fi
}
git_change() {
  local commit_note=$1 ;
  echo 'git status' ;
  git status ;
  
  echo "\n\n\n" ;
  
  echo 'git add' ;
  git add -A . ;
  
  echo "\n\n\n" ;

  echo 'git commit' ;
  git commit -m "$commit_note" || echo $?
}
main "$@"
