FROM tomcat:10.1.40-jdk17

# Instala curl para baixar o Jolokia agent
RUN apt-get update && apt-get install -y curl

#Definição das pastas de deploy
ENV CATALINA_HOME /usr/local/tomcat
ENV DEPLOY $CATALINA_HOME/webapps

# Baixa o Jolokia Agent WAR
ADD https://search.maven.org/remotecontent?filepath=org/jolokia/jolokia-agent-war-unsecured/2.2.9/jolokia-agent-war-unsecured-2.2.9.war $DEPLOY/jolokia.war

# Copia o Jenkins WAR
ADD https://get.jenkins.io/war-stable/2.504.1/jenkins.war $DEPLOY/jenkins.war

# Expõe portas do Tomcat e Jolokia
EXPOSE 8080     

CMD ["catalina.sh", "run"]
