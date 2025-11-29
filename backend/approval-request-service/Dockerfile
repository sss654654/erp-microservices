FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app

# pom.xml과 소스 복사
COPY approval-request-service/pom.xml .
COPY approval-request-service/src ./src

# proto 파일 복사 (프로젝트 루트에)
COPY proto ./proto

# 빌드
RUN mvn clean package -DskipTests

FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8082 9091
ENTRYPOINT ["java", "-jar", "app.jar"]
