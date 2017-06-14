#!/bin/bash

[[ ${git_debug+x} ]] || git_debug=''

skip_docker_run=false
use_aws_ecs=true
v=0.0.5
name=fcredmine
namespace=bbuckets
localport=65531

checklists_plugin_dir='redmine_checklists'
checklists_plugin_file="${checklists_plugin_dir}-3_1_5.zip"
checklists_plugin_url="http://example.com/${checklists_plugin_file}"

agile_plugin_dir='redmine_agile'
agile_plugin_file="${agile_plugin_dir}-1_4_3-light.zip"
agile_plugin_url="http://example.com/${agile_plugin_file}"

# try_crappy_old_kanban=''
# if [[ $try_crappy_old_kanban ]] ; then
#   kanban_proper_name=redmine_kanban
#   kanban_plugin_commit_id='6776731'
#   kanban_plugin_dir="${kanban_proper_name}-kostgr-$kanban_plugin_commit_id"
#   kanban_plugin_file="${kanban_plugin_dir}.tar.gz"
#   # kanban_plugin_url="https://github.com/edavis10/redmine_kanban/archive/v0.2.0.tar.gz"
#   kanban_plugin_url="https://github.com/kostgr/redmine_kanban.git"
#   # kanban_gems="aasm block_helpers redmine_plugin_support faker rspec-rails webrat debugger"
#   kanban_gems="aasm block_helpers redmine_plugin_support faker rspec-rails webrat"
# else
#   kanban_proper_name=redhopper
#   kanban_plugin_commit_id='1.0.7'
#   kanban_plugin_dir="${kanban_proper_name}-infopiiaf-$kanban_plugin_commit_id"
#   kanban_plugin_file="${kanban_plugin_dir}.tar.gz"
#   kanban_plugin_url="https://git.framasoft.org/infopiiaf/redhopper"
#   kanban_gems="json -v 1.8.3; gem install minitest -v 5.8.0; gem install thread_safe -v 0.3.5; gem install tzinfo -v 1.2.2; gem install activesupport -v 4.2.3"
# fi ;

main() {
  init ;
  [[ -d d.redmine ]] || mkdir d.redmine ;
  cd d.redmine && {

    execute echo hi ;
    execute true ;
    execute false ;
    say_do echo howdy ;
    say_do true ;
    say_do false ;
    vexecute true ;
    vexecute false ;

    mkdirp files db logs ;
    [[ ! -e db/redmine.db ]] || [[ db/redmine.db -ot redmine.db ]] || { bak redmine.db; cp -rp db/redmine.db redmine.db; }
    [[ -e $agile_plugin_file ]] || curl -Ls $agile_plugin_url > $agile_plugin_file
    # [[ -e $kanban_plugin_file ]] || curl -Ls $kanban_plugin_url > $kanban_plugin_file
    get_kanban ;
    mk_dockerfile ;
    mk_git_change_script ;

    say_do docker build --tag $namespace/$name:latest --tag $namespace/$name:$v .
    if [[ false == $skip_docker_run ]] ; then
      docker rm -f dockerredmine || true ;
      execute docker run --name "dockerredmine" -d -p $localport:3000 \
        -v $(pwd)/files:/usr/src/redmine/files \
        -v    $(pwd)/db:/usr/src/redmine/vsqlite \
        -v  $(pwd)/logs:/usr/src/redmine/log \
        $namespace/$name
      #
    fi ;
    if [[ true == $use_aws_ecs ]] ; then
      local docker_login=$(aws ecr get-login --no-include-email --region us-west-1)
      echo "docker_login = {$docker_login}" ;
      $docker_login ;
      docker tag $namespace/$name:latest $aws_namespace/$name:latest
      docker tag $namespace/$name:latest $aws_namespace/$name:$v
      docker push $aws_namespace/$name:latest
    fi ; # END: if [[ true == $use_aws_ecs ]] ; else
    echo "Success."
  }
}

init() {
  which aws || die "ERROR: Please install AWS cli."
}
final() {
  [[ ! -e db/redmine.db ]] || [[ db/redmine.db -ot redmine.db ]] || { bak redmine.db; cp -rp db/redmine.db redmine.db; }
}
say_do() {
  echo "$@"
  "$@"
}
die() { echo $1 ; exit 1 ; }
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
execute() {
  "$@" || die "ERROR: '$?' from {$@}."
}
vexecute() {
  local e=''
  execute say_do "$@" || e=$?
  echo 1>&2 ;
  return $?
}
get_kanban() {
  [[ -e $kanban_plugin_file ]] || {
    local tmpd=`mktemp -d "tmp.d.XXXXXXXXXX"` ;
    ( cd $tmpd ;
      git clone $kanban_plugin_url $kanban_plugin_dir ;
      cd $kanban_plugin_dir ; git checkout $kanban_plugin_commit_id ; cd ../ ;
      rm -rf $kanban_plugin_dir/.git ;
      tar -czf ../$kanban_plugin_file $kanban_plugin_dir ;
    ) ;
    rm -rf tmp.d.* ;
  }
}
mk_dockerfile() {
    cat > Dockerfile <<EOFdf
FROM redmine
# FROM centos
MAINTAINER Farts McButtons <example@example.com>

VOLUME /usr/src/redmine/db /usr/src/redmine/files /usr/src/redmine/log

COPY git_change.sh /git_change.sh
RUN { which which || yum -y install which ; } \\
  && { which yum || { apt-get -y update && apt-get install -y --no-install-recommends apt-utils ; } ; } \\
  && { which unzip || { which yum && yum -y install unzip || apt-get -y install zip ; } ; } \\
  && which unzip \\
  && bash -c "[[ -d /tmp/logs ]] || mkdir -p /tmp/logs"
ENV git_debug='${git_debug}'
EOFdf
    mk_df_init_git ;
    echo >> Dockerfile ;
    mk_df_init_db ;
    echo >> Dockerfile ;
    echo "# # PLUGINS" >> Dockerfile ;
    mk_df_checklists_plugin ;
    mk_df_agile_plugin ;
    # mk_df_kanban_plugin ;
    echo >> Dockerfile ;
    mk_df_prep_init_config ;
    cat >> Dockerfile <<EOFdfy

ENTRYPOINT ["/docker-entrypoint.sh"]
EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]
EOFdfy
}
mk_df_init_git() {
    if [[ $git_debug ]] ; then
    cat >> Dockerfile <<EOFdf1a

# RUN which yum && yum -y install timeout || apt-get -y install coreutils
# RUN timeout 5 sleep 10 || echo \$?
RUN which yum && yum -y install git || apt-get -y install git \\
  && git config --global user.email "example@example.com" \\
  && git config --global user.name "Farts McButtons" \\
  && cd /usr/src/redmine && { git init ; git add . ; git commit -m 'init' ; } > /tmp/logs/01_git_commit_init.log
EOFdf1a
    fi ;
}
mk_df_init_db() {
    if [[ -e redmine.db ]] ; then
    cat >> Dockerfile <<EOFdf2a
RUN mkdir /usr/src/redmine/sqlite
COPY redmine.db /usr/src/redmine/sqlite/
COPY config_database.yml /usr/src/redmine/config/database.yml
EOFdf2a
    else
    cat >> Dockerfile <<EOFdf2
RUN nohup /docker-entrypoint.sh "rails" "server" "-b" "0.0.0.0" & sleep 20 \\
  && bash /git_change.sh "01" "after_rails_server_runs_once" \\
  && cd /usr/src/redmine/sqlite && cp redmine.db redmine.db.init
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
  && cd /usr/src/redmine/sqlite && cp redmine.db redmine.db.after_redmine_checklists \\
  && bash /git_change.sh "02a" "after_redmine_checklists"
EOFdf1ma
}
mk_df_agile_plugin() {
    cat >> Dockerfile <<EOFdf1ma
COPY $agile_plugin_file /tmp/
RUN cd /usr/src/redmine/plugins && unzip -q /tmp/$agile_plugin_file \\
  && rm -rf /tmp/$agile_plugin_file \\
  && cd $agile_plugin_dir && bundle install \\
  && bundle exec rake redmine:plugins NAME=redmine_agile RAILS_ENV=production \\
  && cd /usr/src/redmine/sqlite && cp redmine.db redmine.db.after_redmine_agile \\
  && bash /git_change.sh "02b" "after_redmine_agile"
EOFdf1ma
}
mk_df_kanban_plugin_gem_junk() {
  if [[ $try_crappy_old_kanban ]] ; then
  cat <<EOFdf1mkgj
  && sed -i 's/^.*debugger.*\$//' Gemfile \\
  && echo "gem 'rake'" >> Gemfile \\
  && echo "gem 'redmine_plugin_support'" >> Gemfile \\
  && gem install $kanban_gems \\
  && ls -lart \\
EOFdf1mkgj
  echo ;
  else
  echo "&& mv Gemfile Gemfile.old && echo \"source 'https://rubygems.org'\\n\" | tee Gemfile \\"
  # echo "&& mv Gemfile Gemfile.old && echo \"source 'https://rubygems.org'\\n\" > Gemfile \\"

  echo "&& echo \"gem 'rake'\" | tee -a Gemfile \\"
  # echo "&& echo \"gem 'rails', '<4.1'\" | tee -a Gemfile \\"
  echo "&& echo \"gem 'actionpack-xml_parser'\" | tee -a Gemfile \\"
  echo "&& echo \"gem 'sqlite3'\" | tee -a Gemfile \\"
  echo "&& echo \"gem 'json'\" | tee -a Gemfile \\"
  echo "&& echo \"gem 'activemodel'\" | tee -a Gemfile \\"
  # # To cure {LoadError: cannot load such file -- openid}:
  # echo "&& echo \"gem 'openid'\" | tee -a Gemfile \\"
  # echo "&& echo \"gem 'ruby-openid'\" | tee -a Gemfile \\"
  echo "&& echo \"gem 'rack-openid'\" | tee -a Gemfile \\"
  # # To cure {NoMethodError: undefined method `configure'}:
  # echo "&& echo \"gem 'rspec-core'\" | tee -a Gemfile \\"
  # echo "&& echo \"gem 'rspec-core', '2.14.7'\" | tee -a Gemfile \\"
  # echo "&& echo \"gem 'activesupport', '=4.2.3'\" | tee -a Gemfile \\"
  # # To cure {NoMethodError: undefined method `attr_protected'}:
  # echo "&& echo \"gem 'rails'\" | tee -a Gemfile \\"
  # echo "&& echo \"gem 'activerecord', '<3.0'\" | tee -a Gemfile \\"
  # echo "&& echo \"gem 'rails', '~> 4.0.1'\" | tee -a Gemfile \\"
  # echo "&& echo \"gem 'rails', '< 4.0'\" | tee -a Gemfile \\"
  echo "&& echo \"gem 'bundler'\" | tee -a Gemfile \\"
  # echo "&& echo \"gem 'rails', '~> 3.2'\" | tee -a Gemfile \\"
  # echo "&& echo \"gem 'rails', '~> 4.0.8'\" | tee -a Gemfile \\"
  # echo "&& echo \"gem 'rails', '<= 4.0.8'\" | tee -a Gemfile \\"
  echo "&& echo \"gem 'rails', '> 4.1.16', '< 4.2.0'\" | tee -a Gemfile \\"
  echo "&& echo \"gem 'activerecord', '> 4.1.16'\" | tee -a Gemfile \\"

  echo "&& cat Gemfile.old | tee -a Gemfile \\"
  # echo "&& cat Gemfile.old >> Gemfile \\"
  echo "&& mv Gemfile.lock Gemfile.lock.old \\"
  fi ;
}
mk_df_kanban_plugin() {
    rake_cmd='redmine:plugins:migrate'
    rake_cmd='redmine:plugins'
    cat >> Dockerfile <<EOFdf1mk
COPY $kanban_plugin_file /tmp/

# xxx
RUN which yum && yum -y install make gcc || apt-get -y install make gcc
RUN gem install nokogiri

RUN cd /usr/src/redmine/plugins && tar -xzf /tmp/$kanban_plugin_file \\
  && rm -rf /tmp/$kanban_plugin_file && mv $kanban_plugin_dir redmine_kanban \\
  && cd redmine_kanban \\
  && { which yum && yum -y install make gcc || apt-get -y install make gcc ; } \\
  $(mk_df_kanban_plugin_gem_junk)
  && bundle install \\
  && { diff -dbB Gemfile.lock.old Gemfile.lock || true ; } \\
  && bundle exec rake $rake_cmd NAME=$kanban_proper_name RAILS_ENV=production \\
  && cd /usr/src/redmine/sqlite && cp redmine.db redmine.db.after_redmine_kanban \\
  && bash /git_change.sh "02k" "after_redmine_kanban"
EOFdf1mk
}
mk_df_prep_init_config() {
    cat >> Dockerfile <<EOFdfy
RUN cat /docker-entrypoint.sh > /tmp/docker-entrypoint.sh \\
  && sed '\$d' /tmp/docker-entrypoint.sh > /docker-entrypoint.sh \\
  && echo "ls /tmp/logs/* > /dev/null && mv /tmp/logs/* /usr/src/redmine/log/ || true\n\\
ls -lart /usr/src/redmine/ > /usr/src/redmine/log/redmine.log\n\\
ls -lart /usr/src/redmine/db/ > /usr/src/redmine/log/db.log\n\\
ls -lart /usr/src/redmine/log/ > /usr/src/redmine/log/log.log\n\\
bash -c \"cd /usr/src/redmine && { [[ -L sqlite ]] || { mv sqlite sqlite_orig && ln -s vsqlite/ sqlite && [[ -e vsqlite/init ]] || { cp -rp sqlite_orig/* vsqlite/ && touch vsqlite/init ; } ; } ; }\"\n\\
bash -c \"sleep 5 ; cd /usr/src/redmine && { [[ -e sqlite/config_database.yml ]] || cat config/database.yml > sqlite/config_database.yml ; }\"\n\\
nohup bash -c \"sleep 30 ; cd /usr/src/redmine && { [[ -e log/05_after_startup.log ]] || bash /git_change.sh "after_startup" > log/05_after_startup.log ; }\" & echo '(Backgrounded.)'\n\\
\n\\
exec \"\\\$@\"\n" >> /docker-entrypoint.sh
RUN tail /docker-entrypoint.sh
EOFdfy
}
mk_git_change_script() {
    cat > git_change.sh <<'EOFgc'
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
EOFgc
}

main_() {
  local e=''
  main "$@" || e=$?
  final ;
  echo "ERROR: exit code $e from main." 1>&2 ;
  exit $e
}
cd $(dirname $0) && main_ "$@" ;

#
