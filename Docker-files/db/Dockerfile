FROM mysql:8.0.33
LABEL project="vprofile" tier="db"
ENV MYSQL_DATABASE="accounts"
# Any .sql in this folder runs once, on first start with an empty data volume
COPY db_backup.sql /docker-entrypoint-initdb.d/db_backup.sql
