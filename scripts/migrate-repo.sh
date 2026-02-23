#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="$1"
PROFILE="$2"
SPRING_BOOT_VERSION="$3"
CONTROL_PLANE_DIR="$4"

cd "$TARGET_DIR"

if [[ "$PROFILE" != "spring-petclinic" ]]; then
  echo "Unsupported profile: $PROFILE"
  exit 1
fi

mkdir -p .github/workflows .github/rewrite .github src/main/resources src/main/java/org/springframework/samples/petclinic

cp "$CONTROL_PLANE_DIR/templates/repo-patches/spring-petclinic/pom.xml" pom.xml
sed -i "s/__SPRING_BOOT_VERSION__/${SPRING_BOOT_VERSION}/g" pom.xml

cp "$CONTROL_PLANE_DIR/templates/repo-patches/spring-petclinic/src/main/resources/application.properties" src/main/resources/application.properties
cp "$CONTROL_PLANE_DIR/templates/repo-patches/spring-petclinic/src/main/java/org/springframework/samples/petclinic/PetClinicApplication.java" src/main/java/org/springframework/samples/petclinic/PetClinicApplication.java
cp "$CONTROL_PLANE_DIR/templates/dependency-check-suppressions.xml" .github/dependency-check-suppressions.xml
cp "$CONTROL_PLANE_DIR/templates/migration-recipe.yml" .github/rewrite/migration-recipe.yml

if [[ -f src/main/resources/spring/business-config.xml ]]; then
  sed -i '/persistenceUnitName/d' src/main/resources/spring/business-config.xml
  if ! grep -q 'SharedEntityManagerBean' src/main/resources/spring/business-config.xml; then
    perl -0777 -i -pe 's|(<bean id="entityManagerFactory" class="org\.springframework\.orm\.jpa\.LocalContainerEntityManagerFactoryBean"[\s\S]*?</bean>)|$1\n\n        <bean id="entityManager" class="org.springframework.orm.jpa.support.SharedEntityManagerBean"\n              p:entityManagerFactory-ref="entityManagerFactory"/>|s' src/main/resources/spring/business-config.xml
  fi
fi

rm -rf target .rewrite rewrite.patch || true

mvn -B -ntp clean verify \
  -Ddb.script=h2 \
  -Djpa.database=H2 \
  -Djdbc.driverClassName=org.h2.Driver \
  -Djdbc.url=jdbc:h2:mem:petclinic \
  -Djdbc.username=sa \
  -Djdbc.password=

mvn -B -ntp -DskipTests \
  org.owasp:dependency-check-maven:12.1.0:check \
  -DfailBuildOnCVSS=0 \
  -DossindexAnalyzerEnabled=false \
  -DsuppressionFiles=.github/dependency-check-suppressions.xml \
  -Dformats=HTML,JSON

rm -rf target .rewrite rewrite.patch || true
