#!/bin/bash

skip_docker_run=false
use_aws_ecs=true
v=0.0.5
name=fcredminesimple
namespace=bbuckets
localport=65531

checklists_plugin_dir='redmine_checklists'
checklists_plugin_file="${checklists_plugin_dir}-3_1_5.zip"
checklists_plugin_url="http://example.com/${checklists_plugin_file}"

agile_plugin_dir='redmine_agile'
agile_plugin_file="${agile_plugin_dir}-1_4_3-light.zip"
agile_plugin_url="http://example.com/${agile_plugin_file}"

main() {
  init ;
  [[ -d d.simple ]] || mkdir d.simple ;
  cd d.simple && {
    mkdirp files db logs ;
    if [[ sqlite == $db ]] ; then
      [[ ! -e db/redmine.db ]] || [[ db/redmine.db -ot redmine.db ]] || { bak redmine.db; cp -rp db/redmine.db redmine.db; }
    fi ;
    # [[ -e $agile_plugin_file ]] || curl -Ls $agile_plugin_url > $agile_plugin_file
    # [[ -e $checklists_plugin_file ]] || curl -Ls $checklists_plugin_url > $checklists_plugin_file
    mk_dockerfile ;
    # mk_git_change_script ;

    say_do docker build --tag $namespace/$name:latest --tag $namespace/$name:$v .
    if [[ false == $skip_docker_run ]] ; then
      docker rm -f dockerredmine || true ;
      vol3='' ;
      if [[ sqlite == $db ]] ; then vol3="-v    $(pwd)/db:/usr/src/redmine/vsqlite" ; fi ;
      execute docker run --name "dockerredmine" -d -p $localport:3000 \
        -v $(pwd)/files:/usr/src/redmine/files \
        -v  $(pwd)/logs:/usr/src/redmine/log \
        $vol3 \
        $namespace/$name
      #
    fi ;
    if [[ true == $use_aws_ecs ]] ; then
      local docker_login=$(aws ecr get-login --no-include-email --region us-west-1)
      echo "docker_login = {$docker_login}" ;
      $docker_login ;
      docker tag $namespace/$name:latest $aws_namespace/$name:latest
      docker tag $namespace/$name:latest $aws_namespace/$name:$v
      local cmd="docker push $aws_namespace/$name:latest"
      echo $cmd > docker_push_command.sh
      $cmd
    fi ; # END: if [[ true == $use_aws_ecs ]] ; else
    echo "Success."
  }
}

init() {
  which aws &>/dev/null || die "ERROR: Please install AWS cli."
}
final() {
  [[ ! -e db/redmine.db ]] || [[ db/redmine.db -ot redmine.db ]] || { bak redmine.db; cp -rp db/redmine.db redmine.db; }
}
execute() {
  "$@" || die "ERROR: '$?' from {$*}."
}
vexecute() {
  local e=''
  echo "$@" 1>&2 ;
  "$@" || e=$?
  echo 1>&2 ;
  [[ 0 -eq $e ]] || die "ERROR: '$?' from {$*}."
}
say_do() {
  echo "$@" 1>&2 ;
  "$@"
}
vsay_do() {
  local e=''
  say_do "$@" || e=$?
  echo 1>&2 ;
  return $e
}
die() { echo $1 ; exit 1 ; }
rdie() { echo $1 ; return 1 ; }
bak() {
  local f=$1 ;
  local fbak=$(bak_date "$f") ;
  cp -rp "$f" "$fbak" || die "ERROR: Failed to cp -rp $f $fbak: $?."
  echo "Copied $f to $fbak." 1>&2 ;
}
bak_date() {
  local f=$1 ;
  local d=$(date -u +'d%Y%m%dz') ;
  local fbak="$f.bak.$d"
  if [[ -e "$fbak" ]] ; then
    d=$(date -u +'d%Y%m%dz') ;
    fbak="$f.bak.$d"
  fi ;
  if [[ -e "$fbak" ]] ; then
    d=$(date -u +'d%Y%m%dT%Hz') ;
    fbak="$f.bak.$d"
  fi ;
  if [[ -e "$fbak" ]] ; then
    d=$(date -u +'d%Y%m%dT%H%Mz') ;
    fbak="$f.bak.$d"
  fi ;
  if [[ -e "$fbak" ]] ; then
    d=$(date -u +'d%Y%m%dT%H%M%Sz') ;
    fbak="$f.bak.$d"
  fi ;
  if [[ -e "$fbak" ]] ; then
    fbak=$(bak_i "$fbak")
  fi ;
  echo "$fbak"
}
bak_i() {
  local f=$1 ;
  local i=1 ;
  while [[ -e "$f.bak$i" ]] ; do
    i=$((i+1)) ;
  done ;
  echo "$f.bak$i" ;
}
mkdirp() {
  local d=''
  for d in "$@" ; do
    [[ -d "$d" ]] || mkdir -p "$d" ;
  done ;
}
mk_dockerfile() {
    cat > Dockerfile <<EOFdf
FROM redmine
# FROM centos
MAINTAINER Farts McButtons <example@example.com>

# VOLUME /usr/src/redmine/db /usr/src/redmine/files /usr/src/redmine/log

RUN { which which || yum -y install which ; } \\
  && { which yum || { apt-get -y update && apt-get install -y --no-install-recommends apt-utils ; } ; } \\
  && { which unzip || { which yum && yum -y install unzip || apt-get -y install zip ; } ; } \\
  && which unzip \\
  && bash -c "[[ -d /tmp/logs ]] || mkdir -p /tmp/logs"
EOFdf
    # mk_df_init_git ;
    echo >> Dockerfile ;
    mk_df_init_db ;
    echo >> Dockerfile ;
    echo "# # PLUGINS" >> Dockerfile ;
    # mk_df_checklists_plugin ;
    # mk_df_agile_plugin ;
    echo >> Dockerfile ;
    mk_df_prep_init_config ;
    cat >> Dockerfile <<EOFdfy

ENTRYPOINT ["/docker-entrypoint.sh"]
EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]
EOFdfy
}
mk_df_init_db() {
  local copy_init_db=false
  if [[ sqlite == $db ]] ; then
    if [[ -e redmine.db ]] ; then
      copy_init_db=true
    fi ;
  fi ;
  if [[ true == $copy_init_db ]] ; then
    cat >> Dockerfile <<EOFdf2a
RUN mkdir /usr/src/redmine/sqlite
COPY redmine.db /usr/src/redmine/sqlite/
COPY config_database.yml /usr/src/redmine/config/database.yml
RUN chown -R redmine /usr/src/redmine
EOFdf2a
  else
    cat >> Dockerfile <<EOFdf2
RUN nohup /docker-entrypoint.sh "rails" "server" "-b" "0.0.0.0" & sleep 20
RUN cd /usr/src/redmine/sqlite && cp redmine.db redmine.db.init || true
EOFdf2
  fi ;
}
mk_df_checklists_plugin() {
    cat >> Dockerfile <<EOFdf1ma
COPY $checklists_plugin_file /tmp/
RUN cd /usr/src/redmine/plugins && unzip -q /tmp/$checklists_plugin_file \\
  && rm -rf /tmp/$checklists_plugin_file \\
  && cd $checklists_plugin_dir && bundle install \\
  && bundle exec rake redmine:plugins NAME=redmine_checklists RAILS_ENV=production \\
  && true
EOFdf1ma
}
mk_df_agile_plugin() {
    cat >> Dockerfile <<EOFdf1ma
COPY $agile_plugin_file /tmp/
RUN cd /usr/src/redmine/plugins && unzip -q /tmp/$agile_plugin_file \\
  && rm -rf /tmp/$agile_plugin_file \\
  && cd $agile_plugin_dir && bundle install \\
  && bundle exec rake redmine:plugins NAME=redmine_agile RAILS_ENV=production \\
  && true
EOFdf1ma
}
mk_df_prep_init_config() {
    cat >> Dockerfile <<EOFdfy
RUN cat /docker-entrypoint.sh > /tmp/docker-entrypoint.sh \\
  && sed '\$d' /tmp/docker-entrypoint.sh > /docker-entrypoint.sh \\
  && echo "ls /tmp/logs/* &> /dev/null && mv /tmp/logs/* /usr/src/redmine/log/ || true\n\\
nohup bash -c \"cd /usr/src/redmine && { while [[ 1 ]] ; do sleep 30 ; cp -f sqlite/* vsqlite/ ; done ; }\" & echo '(Backgrounded db copy.)'\n\\
bash -c \"sleep 5 ; cd /usr/src/redmine && { [[ -e sqlite/config_database.yml ]] || cat config/database.yml > sqlite/config_database.yml ; }\"\n\\
ls -lart /usr/src/redmine/ > /usr/src/redmine/log/redmine.log\n\\
ls -lart /usr/src/redmine/db/ > /usr/src/redmine/log/db.log\n\\
ls -lart /usr/src/redmine/sqlite/ > /usr/src/redmine/log/sqlite.log\n\\
ls -lart /usr/src/redmine/vsqlite/ > /usr/src/redmine/log/vsqlite.log\n\\
ls -lart /usr/src/redmine/log/ > /usr/src/redmine/log/log.log\n\\
\n\\
exec \"\\\$@\"\n" >> /docker-entrypoint.sh
RUN tail /docker-entrypoint.sh
VOLUME /usr/src/redmine/vsqlite
# RUN chown -R redmine /usr/src/redmine
EOFdfy
}

main_() {
  local e=''
  main "$@" || e=$?
  final ;
  [[ 0 -eq $e ]] || echo "ERROR: exit code '$e' from main." 1>&2 ;
  return $e
}
cd $(dirname $0) && main_ "$@" ;

#
