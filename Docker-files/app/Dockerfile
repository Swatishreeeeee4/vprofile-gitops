# ---- Stage 1: build the WAR from THIS repo's source (not a remote clone) ----
FROM maven:3.9.9-eclipse-temurin-21-jammy AS build
WORKDIR /src
COPY pom.xml .
RUN mvn -q dependency:go-offline           # cached layer: dependencies only change when pom.xml does
COPY src ./src
RUN mvn -q -DskipTests package

# ---- Stage 2: runtime image, only Tomcat + the WAR ----
FROM tomcat:10-jdk21
LABEL project="vprofile" tier="app"
RUN rm -rf /usr/local/tomcat/webapps/*
COPY --from=build /src/target/vprofile-v2.war /usr/local/tomcat/webapps/ROOT.war
EXPOSE 8080
CMD ["catalina.sh", "run"]
