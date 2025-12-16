# Runtime image for Spring Petclinic with AppDynamics Java agent
FROM eclipse-temurin:17-jre

# Build arguments to locate the Petclinic JAR and (optionally) download the AppDynamics agent
ARG JAR_FILE=target/*.jar
ARG APPD_AGENT_URL

# Working directory for the application
WORKDIR /app

# Copy application binary
COPY ${JAR_FILE} /app/petclinic.jar

# Prepare AppDynamics agent location and optionally download the Java agent
RUN set -eux; \
    mkdir -p /opt/appdynamics; \
    if [ -n "${APPD_AGENT_URL:-}" ]; then \
        apt-get update; \
        apt-get install -y --no-install-recommends curl unzip; \
        curl -fsSL "$APPD_AGENT_URL" -o /tmp/appdynamics.zip; \
        unzip /tmp/appdynamics.zip -d /tmp/appdynamics; \
        AGENT_PATH=$(find /tmp/appdynamics -name "javaagent.jar" | head -n 1); \
        if [ -z "$AGENT_PATH" ]; then echo "AppDynamics agent not found in archive"; exit 1; fi; \
        cp "$AGENT_PATH" /opt/appdynamics/javaagent.jar; \
        rm -rf /tmp/appdynamics /tmp/appdynamics.zip; \
        apt-get purge -y curl unzip; \
        apt-get autoremove -y; \
        rm -rf /var/lib/apt/lists/*; \
    fi; \
    if [ -n "${APPD_AGENT_URL:-}" ] && [ ! -f /opt/appdynamics/javaagent.jar ]; then echo "Provide APPD_AGENT_URL to supply the AppDynamics agent"; exit 1; fi

# Expose application port
EXPOSE 8080

# AppDynamics configuration
ENV APPDYNAMICS_CONTROLLER_HOST_NAME="" \
    APPDYNAMICS_CONTROLLER_PORT="8090" \
    APPDYNAMICS_CONTROLLER_SSL_ENABLED="false" \
    APPDYNAMICS_AGENT_APPLICATION_NAME="petclinic" \
    APPDYNAMICS_AGENT_TIER_NAME="web" \
    APPDYNAMICS_AGENT_NODE_NAME="petclinic-node" \
    APPDYNAMICS_AGENT_ACCOUNT_NAME="customer1" \
    APPDYNAMICS_AGENT_ACCOUNT_ACCESS_KEY="" \
    JAVA_TOOL_OPTIONS=""

# Default profile can be overridden at runtime via SPRING_PROFILES_ACTIVE
ENV SPRING_PROFILES_ACTIVE=""

# Start the application with AppDynamics instrumentation
ENTRYPOINT ["sh", "-c", "if [ -f /opt/appdynamics/javaagent.jar ]; then JAVA_TOOL_OPTIONS=\"-javaagent:/opt/appdynamics/javaagent.jar ${JAVA_TOOL_OPTIONS:-}\"; fi; exec java ${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }-jar /app/petclinic.jar"]
