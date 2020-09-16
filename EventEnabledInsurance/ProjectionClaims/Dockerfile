FROM gradle:jdk8 AS build
COPY --chown=gradle:gradle build.gradle /home/gradle/src/
COPY --chown=gradle:gradle src /home/gradle/src/src
WORKDIR /home/gradle/src
RUN gradle fatJar --no-daemon

# Use this for debug, includes curl etc:
# FROM openjdk:8

# Use this for a small production image
FROM openjdk:8-jre-slim
EXPOSE 8080
RUN mkdir /app
COPY --from=build /home/gradle/src/build/libs/*.jar /app/ProjectionClaims.jar
CMD ["java", "-jar","/app/ProjectionClaims.jar"]
