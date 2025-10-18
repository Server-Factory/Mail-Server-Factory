#!/bin/bash

set -e

echo "🔍 Starting SonarQube Code Quality Analysis..."

# Check if SonarQube containers are running
if ! docker ps | grep -q sonarqube; then
    echo "❌ SonarQube container not running. Please start containers with: docker compose up -d"
    exit 1
fi

if ! docker ps | grep -q postgresql; then
    echo "❌ PostgreSQL container not running. Please start containers with: docker compose up -d"
    exit 1
fi

# Wait for SonarQube to be ready
echo "⏳ Waiting for SonarQube to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:9000/api/system/status | grep -q '"status":"UP"'; then
        break
    fi
    echo "Waiting... ($i/30)"
    sleep 10
done

if ! curl -s http://localhost:9000/api/system/status | grep -q '"status":"UP"'; then
    echo "❌ SonarQube failed to start properly"
    exit 1
fi

echo "✅ SonarQube is ready"

# Run tests and generate coverage first
echo "🧪 Running tests and generating coverage..."
if ! ./gradlew test jacocoTestReport --console=plain; then
    echo "❌ Unit tests failed!"
    exit 1
fi

# Create temporary sonar-project.properties
cat > sonar-project.properties << EOF
sonar.projectKey=mail-server-factory
sonar.projectName=Mail Server Factory
sonar.projectVersion=1.0.0
sonar.sourceEncoding=UTF-8
sonar.language=kotlin

# Source directories
sonar.sources=Factory/src/main/kotlin,Application/src/main/kotlin
sonar.tests=Factory/src/test/kotlin,Core/Framework/src/test/kotlin

# Kotlin settings
sonar.kotlin.file.suffixes=.kt

# Coverage
sonar.coverage.jacoco.xmlReportPaths=Factory/build/reports/jacoco/test/jacocoTestReport.xml,Core/Framework/build/reports/jacoco/test/jacocoTestReport.xml

# Exclusions
sonar.exclusions=**/build/**,**/generated/**,**/*Test.kt,**/test/**,**/os/**,**/*BuildInfo.kt

# Quality gate
sonar.qualitygate.wait=true
sonar.qualitygate.timeout=300
EOF

# Run SonarQube scanner
echo "🔍 Running SonarQube analysis..."
docker run --rm \
    --network host \
    -v "$(pwd)":/usr/src \
    sonarsource/sonar-scanner-cli \
    -Dsonar.host.url=http://localhost:9000 \
    -Dsonar.login=admin \
    -Dsonar.password=admin

# Check quality gate result
echo "📊 Checking quality gate status..."
sleep 10

QUALITY_GATE_STATUS=$(curl -s -u admin:admin http://localhost:9000/api/qualitygates/project_status?projectKey=mail-server-factory | jq -r '.projectStatus.status' 2>/dev/null || echo "UNKNOWN")

if [ "$QUALITY_GATE_STATUS" = "OK" ]; then
    echo "✅ SONARQUBE QUALITY GATE PASSED - 100% SUCCESS ACHIEVED!"
    echo "🎉 All code quality checks passed. The codebase meets the highest standards."
    exit 0
else
    echo "❌ SONARQUBE QUALITY GATE FAILED - Status: $QUALITY_GATE_STATUS"
    echo "📋 Quality gate details:"
    curl -s -u admin:admin http://localhost:9000/api/qualitygates/project_status?projectKey=mail-server-factory | jq '.' 2>/dev/null || echo "Could not fetch details"
    echo ""
    echo "🔧 Issues found. Please fix all SonarQube issues to achieve 100% quality gate success."
    exit 1
fi