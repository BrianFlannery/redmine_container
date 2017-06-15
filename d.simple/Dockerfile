FROM redmine
# FROM centos
MAINTAINER Farts McButtons <example@example.com>

# VOLUME /usr/src/redmine/db /usr/src/redmine/files /usr/src/redmine/log

RUN { which which || yum -y install which ; } \
  && { which yum || { apt-get -y update && apt-get install -y --no-install-recommends apt-utils ; } ; } \
  && { which unzip || { which yum && yum -y install unzip || apt-get -y install zip ; } ; } \
  && which unzip \
  && bash -c "[[ -d /tmp/logs ]] || mkdir -p /tmp/logs"

RUN nohup /docker-entrypoint.sh "rails" "server" "-b" "0.0.0.0" & sleep 20 \
  && cd /usr/src/redmine/sqlite && cp redmine.db redmine.db.init

# # PLUGINS

RUN cat /docker-entrypoint.sh > /tmp/docker-entrypoint.sh \
  && sed '$d' /tmp/docker-entrypoint.sh > /docker-entrypoint.sh \
  && echo "ls /tmp/logs/* &> /dev/null && mv /tmp/logs/* /usr/src/redmine/log/ || true\n\
nohup bash -c \"cd /usr/src/redmine && { while [[ 1 ]] ; do sleep 30 ; cp -f sqlite/* vsqlite/ ; done ; }\" & echo '(Backgrounded db copy.)'\n\
bash -c \"sleep 5 ; cd /usr/src/redmine && { [[ -e sqlite/config_database.yml ]] || cat config/database.yml > sqlite/config_database.yml ; }\"\n\
ls -lart /usr/src/redmine/ > /usr/src/redmine/log/redmine.log\n\
ls -lart /usr/src/redmine/db/ > /usr/src/redmine/log/db.log\n\
ls -lart /usr/src/redmine/sqlite/ > /usr/src/redmine/log/sqlite.log\n\
ls -lart /usr/src/redmine/vsqlite/ > /usr/src/redmine/log/vsqlite.log\n\
ls -lart /usr/src/redmine/log/ > /usr/src/redmine/log/log.log\n\
\n\
exec \"\$@\"\n" >> /docker-entrypoint.sh
RUN tail /docker-entrypoint.sh
VOLUME /usr/src/redmine/vsqlite
# RUN chown -R redmine /usr/src/redmine

ENTRYPOINT ["/docker-entrypoint.sh"]
EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]
