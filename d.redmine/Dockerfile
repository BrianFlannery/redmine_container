FROM redmine
# FROM centos
MAINTAINER Farts McButtons <example@example.com>

VOLUME /usr/src/redmine/db /usr/src/redmine/files /usr/src/redmine/log

COPY git_change.sh /git_change.sh
RUN { which which || yum -y install which ; } \
  && { which yum || { apt-get -y update && apt-get install -y --no-install-recommends apt-utils ; } ; } \
  && { which unzip || { which yum && yum -y install unzip || apt-get -y install zip ; } ; } \
  && which unzip \
  && bash -c "[[ -d /tmp/logs ]] || mkdir -p /tmp/logs"
ENV git_debug=''

RUN mkdir /usr/src/redmine/sqlite
COPY redmine.db /usr/src/redmine/sqlite/
COPY config_database.yml /usr/src/redmine/config/database.yml

# # PLUGINS
COPY redmine_checklists-3_1_5.zip /tmp/
RUN cd /usr/src/redmine/plugins && unzip -q /tmp/redmine_checklists-3_1_5.zip \
  && rm -rf /tmp/redmine_checklists-3_1_5.zip \
  && cd redmine_checklists && bundle install \
  && bundle exec rake redmine:plugins NAME=redmine_checklists RAILS_ENV=production \
  && cd /usr/src/redmine/sqlite && cp redmine.db redmine.db.after_redmine_checklists \
  && bash /git_change.sh "02a" "after_redmine_checklists"
COPY redmine_agile-1_4_3-light.zip /tmp/
RUN cd /usr/src/redmine/plugins && unzip -q /tmp/redmine_agile-1_4_3-light.zip \
  && rm -rf /tmp/redmine_agile-1_4_3-light.zip \
  && cd redmine_agile && bundle install \
  && bundle exec rake redmine:plugins NAME=redmine_agile RAILS_ENV=production \
  && cd /usr/src/redmine/sqlite && cp redmine.db redmine.db.after_redmine_agile \
  && bash /git_change.sh "02b" "after_redmine_agile"

RUN cat /docker-entrypoint.sh > /tmp/docker-entrypoint.sh \
  && sed '$d' /tmp/docker-entrypoint.sh > /docker-entrypoint.sh \
  && echo "ls /tmp/logs/* > /dev/null && mv /tmp/logs/* /usr/src/redmine/log/ || true\n\
ls -lart /usr/src/redmine/db/ > /usr/src/redmine/log/db.log\n\
ls -lart /usr/src/redmine/log/ > /usr/src/redmine/log/log.log\n\
bash -c \"cd /usr/src/redmine && { [[ -L sqlite ]] || { mv sqlite sqlite_orig && ln -s vsqlite/ sqlite && [[ -e vsqlite/init ]] || { cp -rp sqlite_orig/* vsqlite/ && touch vsqlite/init ; } ; } ; }\"\n\
bash -c \"sleep 5 ; cd /usr/src/redmine && { [[ -e sqlite/config_database.yml ]] || cat config/database.yml > sqlite/config_database.yml ; }\"\n\
nohup bash -c \"sleep 30 ; cd /usr/src/redmine && { [[ -e log/05_after_startup.log ]] || bash /git_change.sh "after_startup" > log/05_after_startup.log ; }\" & echo '(Backgrounded.)'\n\
\n\
exec \"\$@\"\n" >> /docker-entrypoint.sh
RUN tail /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]
