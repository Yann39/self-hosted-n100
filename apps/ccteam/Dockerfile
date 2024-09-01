FROM eclipse-temurin:21-jre

LABEL maintainer="Yann39"

COPY ./ccteam-graphql.jar /opt/app.jar

RUN groupadd --gid 999 --system javauser && \
    useradd --uid 999 --system javauser -g javauser && \
    chown javauser:javauser /opt/app.jar && \
    chmod 644 /opt/app.jar

USER 999

WORKDIR /opt

ENTRYPOINT ["java", "-Dfile.encoding=UTF-8", "-Duser.timezone=Europe/Zurich", "-XX:MaxRAMPercentage=50", "-XshowSettings:vm", "-jar", "/opt/app.jar"]
